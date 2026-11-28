/// Main ability (once per fighter, unlocks after `unlockTime` s of battle) and Legendary Finish.
extension BattleEngine {
    /// Seconds of battle time elapsed (timer counts down from 180).
    public var battleElapsed: Double { Tune.battleTime - timer }

    public func abilityReady(side s: Int) -> Bool {
        let f = sides[s].current
        return !over && clash == nil && rush == nil && !f.abilityUsed && !f.isKO && f.phase != .stunned
            && battleElapsed >= f.def.ability.unlockTime
    }

    /// Seconds until the active fighter's main ability unlocks (0 = ready or used).
    public func abilityCountdown(side s: Int) -> Double {
        max(0, sides[s].current.def.ability.unlockTime - battleElapsed)
    }

    mutating func useAbility(_ s: Int, _ events: inout [BattleEvent]) -> Bool {
        guard abilityReady(side: s) else { return false }
        let a = sides[s].current.def.ability
        let o = 1 - s
        var f = sides[s].current
        f.abilityUsed = true
        if a.heal > 0 { f.hp = min(f.maxHP, f.hp + f.maxHP * a.heal) }
        if a.transformStats > 0 { f.statBonus += a.transformStats }
        if a.fillGauge, f.def.gauge != nil { f.gauge = 100 }
        sides[s].current = f
        if a.ki > 0 { sides[s].ki = min(Tune.kiMax, sides[s].ki + a.ki) }
        if a.purgeEnemyBuffs {
            var t = sides[o].current
            t.nextStrikeBonus = 0
            t.shieldUntil = 0
            t.counterUntil = 0
            t.statBonus = 0
            t.attackBurstUntil = 0
            sides[o].current = t
            sides[o].teamDamageUntil = 0
            sides[o].coverNullUntil = 0
        }
        if a.enemySwitchDelay > 0 { sides[o].switchReadyAt = max(sides[o].switchReadyAt, time) + a.enemySwitchDelay }
        if a.fasterDraw { sides[s].fastDrawUntil = .infinity }
        if a.teamDamageUp > 0 {
            sides[s].teamDamageUp = a.teamDamageUp
            sides[s].teamDamageUntil = time + a.teamDamageDuration
        }
        if a.blastHand, let blast = f.def.deck.first(where: { $0.kind == .blast }) {
            for i in 0..<4 { setHand(side: s, slot: i, card: blast) }
        }
        if a.drawUltimate {
            let slot = sides[s].hand.firstIndex { $0 == nil } ?? 0
            setHand(side: s, slot: slot, card: f.def.ultimate)
        }
        events.append(.mainAbility(side: s))
        events.append(.handChanged(side: s))
        return true
    }

    /// Legendary Finish: an LL / UL fighter's ultimate KOs the opponent's last fighter.
    mutating func checkLegendaryFinish(attacker s: Int, kind: HitKind, _ events: inout [BattleEvent]) {
        guard kind == .ultimate, over, winner == s, sides[s].current.def.rarity.hasLegendaryFinish else { return }
        events.append(.legendaryFinish(side: s))
    }
}
