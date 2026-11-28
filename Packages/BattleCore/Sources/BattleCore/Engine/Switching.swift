extension BattleEngine {
    /// Can side `s` tag in member `i` now? Allowed while free or while being hit (cover change), on cooldown.
    public func canSwitch(side s: Int, to i: Int) -> Bool {
        guard !over, i >= 0, i < sides[s].team.count, i != sides[s].active, !sides[s].team[i].isKO,
              time >= sides[s].switchReadyAt else { return false }
        let f = sides[s].current
        return f.canAct || f.phase == .stunned
    }

    /// Seconds until the switch is available again (0 = ready).
    public func switchCooldown(side s: Int) -> Double { max(0, sides[s].switchReadyAt - time) }

    mutating func switchFighter(_ s: Int, to i: Int, _ events: inout [BattleEvent]) -> Bool {
        guard canSwitch(side: s, to: i) else { return false }
        let o = 1 - s
        var old = sides[s].current
        let cover = old.phase == .stunned
        old.phase = .idle
        old.action = nil
        sides[s].current = old
        for p in old.def.passives { if case .switchOutKi(let ki) = p { sides[s].ki = min(Tune.kiMax, sides[s].ki + ki) } }
        sides[s].active = i
        sides[s].switchReadyAt = time + Tune.switchCooldown
        var n = sides[s].current
        n.phase = .idle
        n.action = nil
        n.invulnUntil = time + (cover ? 0.6 : 0.3)
        sides[s].current = n
        shots.removeAll { $0.target == s }
        refreshHand(s)
        var special = false
        if cover {
            // Cover change: the attacker's card is interrupted and the combo ends.
            let interrupted = sides[o].current.action
            if sides[o].current.phase == .acting {
                sides[o].current.phase = .idle
                sides[o].current.action = nil
            }
            shots.removeAll { $0.owner == o }
            sides[o].comboCards = 0
            sides[o].comboHits = 0
            // Special cover: matching tag knocks the attacker away to long range (once per combo).
            if let card = interrupted?.card, !sides[s].specialCoverUsed,
               (n.def.cover == .strike && card.kind == .strike) || (n.def.cover == .blast && card.kind == .blast) {
                special = true
                sides[s].specialCoverUsed = true
                stun(side: o, until: time + 0.6)
                moveGap(to: Tune.zoneGap[.long] ?? 11, over: 0.3)
            }
        }
        events.append(.tagged(side: s, to: i, cover: cover, special: special))
        events.append(.handChanged(side: s))
        return true
    }
}
