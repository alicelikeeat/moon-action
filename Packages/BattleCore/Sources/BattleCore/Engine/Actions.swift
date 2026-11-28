/// A card (or basic attack) in progress.
public struct Action: Sendable, Equatable {
    public let card: ArtsCard?          // nil = basic attack
    public let kind: HitKind
    public let start: Double
    /// Strike / special: impact times. Blast: shot release times.
    public let times: [Double]
    public internal(set) var done = 0
    public let end: Double
    public let dashUntil: Double
    public let comboIndex: Int
    public let perHit: Double
    public let armor: Bool
    public let bonus: Double
    public internal(set) var counted = false
    public internal(set) var warned = false

    public var lastHitTime: Double { times.last ?? start }
    public var isProjectile: Bool { kind == .blast || (kind == .basic && card?.kind == .blast) }
    /// The next card can be chained once the last hit has gone out (recovery is cancelable).
    public func chainable(at t: Double) -> Bool { card != nil && t >= lastHitTime }
}

/// An energy shot in flight.
public struct Shot: Sendable, Equatable {
    public let owner: Int
    public let target: Int
    public let arrive: Double
    public let power: Double
    public let kind: HitKind
    public let heavy: Bool
    public let comboIndex: Int
    public let index: Int
    public let fromCard: Bool
    /// The whole card's multiplier (for the per-card defense subtraction).
    public let cardTotal: Double
    public internal(set) var warned = false
}

extension BattleEngine {
    static let strikeReach = 2.6
    static let strikeStand = 1.6
    static let shotSpeed = 28.0
    static let critChance = 0.08
    static let orbChance = 0.3

    // MARK: Hand

    mutating func drawCard(_ s: Int) -> HandCard {
        if sides[s].deck.isEmpty {
            var d = sides[s].current.def.deck + sides[s].current.def.deck
            for i in stride(from: d.count - 1, to: 0, by: -1) { d.swapAt(i, rng.int(i + 1)) }
            sides[s].deck = d
        }
        let c = sides[s].deck.removeLast()
        defer { nextCardID += 1 }
        return HandCard(id: nextCardID, card: c, orb: rng.chance(Self.orbChance))
    }

    mutating func fillHand(_ s: Int) {
        for i in 0..<4 where sides[s].hand[i] == nil {
            sides[s].hand[i] = drawCard(s)
            sides[s].refillAt[i] = nil
        }
    }

    /// New fighter in: fresh deck and hand.
    mutating func refreshHand(_ s: Int) {
        sides[s].deck = []
        sides[s].hand = [nil, nil, nil, nil]
        fillHand(s)
    }

    mutating func refillHand(_ s: Int, _ events: inout [BattleEvent]) {
        var changed = false
        for i in 0..<4 {
            if let at = sides[s].refillAt[i], time >= at {
                sides[s].hand[i] = drawCard(s)
                sides[s].refillAt[i] = nil
                changed = true
            }
        }
        if changed { events.append(.handChanged(side: s)) }
    }

    func drawDelay(_ s: Int) -> Double {
        sides[s].current.def.drawSpeed * (time < sides[s].fastDrawUntil ? 0.5 : 1)
    }

    /// Ki the card costs this side right now.
    public func cost(of card: ArtsCard, side s: Int) -> Double {
        Double(max(0, card.cost - (card.kind == .blast ? sides[s].current.def.blastDiscount : 0)))
    }

    /// Can the card in `slot` be played right now (Ki, state, chain window)?
    public func canPlay(side s: Int, slot: Int) -> Bool {
        guard !over, slot >= 0, slot < 4, let hc = sides[s].hand[slot] else { return false }
        let f = sides[s].current
        let chaining = f.phase == .acting && (f.action?.chainable(at: time) ?? false)
        return (f.canAct || chaining) && sides[s].ki >= cost(of: hc.card, side: s)
    }

    /// Test / ability hook: put a specific card in a hand slot.
    public mutating func setHand(side s: Int, slot: Int, card: ArtsCard, orb: Bool = false) {
        sides[s].hand[slot] = HandCard(id: nextCardID, card: card, orb: orb)
        sides[s].refillAt[slot] = nil
        nextCardID += 1
    }

    // MARK: Playing cards

    mutating func playCard(_ s: Int, slot: Int, _ events: inout [BattleEvent]) -> Bool {
        guard canPlay(side: s, slot: slot), let hc = sides[s].hand[slot] else { return false }
        let card = hc.card
        sides[s].ki -= cost(of: card, side: s)
        sides[s].hand[slot] = nil
        sides[s].refillAt[slot] = time + drawDelay(s)
        if hc.orb { sides[s].orbs = min(7, sides[s].orbs + 1) }
        let d = 1 - s
        let comboIndex = sides[d].current.phase == .stunned ? sides[s].comboCards + 1 : 1
        events.append(.cardPlayed(side: s, card: card, comboIndex: comboIndex))
        events.append(.handChanged(side: s))
        var f = sides[s].current
        f.action = nil
        switch card.kind {
        case .strike:
            let bonus = f.nextStrikeBonus
            f.nextStrikeBonus = 0
            let dash = gap > 1.9 ? min(0.45, max(0.08, (gap - Self.strikeStand) / 30)) : 0
            if dash > 0 {
                moveGap(to: Self.strikeStand, over: dash)
                events.append(.dash(side: s, duration: dash))
            }
            let times = (0..<max(1, card.hits)).map { time + dash + 0.1 + Double($0) * 0.12 }
            f.action = Action(card: card, kind: .strike, start: time, times: times, end: times.last! + 0.3,
                              dashUntil: time + dash, comboIndex: comboIndex, perHit: card.power / Double(max(1, card.hits)),
                              armor: card.superArmor, bonus: bonus)
        case .blast:
            let times = (0..<max(1, card.hits)).map { time + 0.15 + Double($0) * 0.13 }
            f.action = Action(card: card, kind: .blast, start: time, times: times, end: times.last! + 0.3,
                              dashUntil: 0, comboIndex: comboIndex, perHit: card.power / Double(max(1, card.hits)),
                              armor: false, bonus: 0)
        case .special, .ultimate:
            let startup = card.kind == .ultimate ? 0.8 : 0.55
            cinematicUntil = time + startup
            events.append(.cinematic(side: s, card: card))
            let times = (0..<max(1, card.hits)).map { time + startup + Double($0) * 0.07 }
            f.action = Action(card: card, kind: card.kind == .ultimate ? .ultimate : .special, start: time, times: times,
                              end: times.last! + 0.45, dashUntil: 0, comboIndex: comboIndex,
                              perHit: card.power / Double(max(1, card.hits)), armor: true, bonus: 0)
        case .support:
            sides[s].current = f
            applySupport(s, card.support, &events)
            f = sides[s].current
            f.phase = .acting
            f.phaseUntil = time + 0.35
            sides[s].current = f
            return true
        }
        f.phase = .acting
        f.phaseUntil = f.action?.end ?? time
        sides[s].current = f
        // Chaining keeps the defender locked through the new card's startup.
        if sides[d].current.phase == .stunned, let first = f.action?.times.first {
            let impact = card.kind == .blast ? first + gap / Self.shotSpeed : first
            sides[d].current.phaseUntil = max(sides[d].current.phaseUntil, impact + 0.05)
        }
        return true
    }

    mutating func applySupport(_ s: Int, _ effect: SupportEffect?, _ events: inout [BattleEvent]) {
        guard let effect else { return }
        var f = sides[s].current
        switch effect {
        case .kiCharge(let ki, let bonus):
            sides[s].ki = min(Tune.kiMax, sides[s].ki + ki)
            f.nextStrikeBonus = bonus
        case .shield(let r, let duration):
            f.shieldUntil = time + duration
            f.shieldReduction = r
            if gap < Tune.closeMax { moveGap(to: Tune.zoneGap[.mid] ?? 6.2, over: 0.25) }
        case .vanishRefill(let x):
            f.vanish = min(Tune.vanishMax, f.vanish + Tune.vanishMax * x)
        case .teamHeal(let x):
            sides[s].current = f
            for i in sides[s].team.indices where !sides[s].team[i].isKO {
                let m = sides[s].team[i].maxHP
                sides[s].team[i].hp = min(m, sides[s].team[i].hp + m * x)
            }
            f = sides[s].current
        case .freezeCounter(let window, let stun):
            f.counterUntil = time + window
            f.counterStun = stun
        case .kiCoverNull(let ki, let duration):
            sides[s].ki = min(Tune.kiMax, sides[s].ki + ki)
            sides[s].coverNullUntil = time + duration
        case .gravityBind(let duration):
            moveGap(to: Tune.zoneGap[.close] ?? 2.2, over: 0.25)
            sides[s].current = f
            applyStun(side: 1 - s, duration: duration, &events)
            f = sides[s].current
        case .kiBurst(let ki):
            sides[s].ki = min(Tune.kiMax, sides[s].ki + ki)
            let o = 1 - s
            sides[o].current.nextStrikeBonus = 0
            sides[o].current.shieldUntil = 0
            sides[o].current.damageBonus = 0
            sides[o].current.armorUntil = 0
        }
        sides[s].current = f
        events.append(.support(side: s, effect: effect))
    }

    // MARK: Basic attack (tap)

    mutating func basicAttack(_ s: Int, _ events: inout [BattleEvent]) -> Bool {
        var f = sides[s].current
        guard f.canAct else { return false }
        if zone == .close {
            let times = (0..<3).map { time + 0.08 + Double($0) * 0.14 }
            f.action = Action(card: nil, kind: .basic, start: time, times: times, end: times.last! + 0.2,
                              dashUntil: 0, comboIndex: 1, perHit: 0.55 / 3, armor: false, bonus: 0)
        } else {
            let pseudo = ArtsCard(id: "basic.shot", en: "Ki Shot", zh: "试探气弹", kind: .blast, cost: 0, power: 0.5, hits: 1)
            f.action = Action(card: pseudo, kind: .basic, start: time, times: [time + 0.1], end: time + 0.35,
                              dashUntil: 0, comboIndex: 1, perHit: 0.5, armor: false, bonus: 0)
        }
        f.phase = .acting
        f.phaseUntil = f.action!.end
        sides[s].current = f
        return true
    }

    // MARK: Vanish / sidestep

    /// Soonest incoming card impact on side `s` (seconds from now), if any.
    public func incomingThreat(on s: Int) -> Double? {
        var best: Double?
        let a = sides[1 - s].current
        if let act = a.action, act.card != nil, !act.isProjectile, act.done < act.times.count {
            best = act.times[act.done] - time
        }
        for sh in shots where sh.target == s && sh.fromCard {
            let lead = sh.arrive - time
            if best == nil || lead < best! { best = lead }
        }
        return best.map { max(0, $0) }
    }

    mutating func sidestep(_ s: Int, dir: Int, _ events: inout [BattleEvent]) -> Bool {
        var f = sides[s].current
        guard f.canAct else { return false }
        if let lead = incomingThreat(on: s), lead <= Tune.warningWindow.upperBound, f.vanish >= Tune.vanishCost {
            // Vanishing step: blink behind the attack, the attacker whiffs and is left open.
            f.vanish -= Tune.vanishCost
            f.phase = .vanishing
            f.phaseUntil = time + 0.35
            f.invulnUntil = time + 0.4
            f.action = nil
            if f.def.has(.vanishCrit) { f.guaranteedCrit = true }
            sides[s].current = f
            let a = 1 - s
            if let act = sides[a].current.action, !act.isProjectile, act.card != nil {
                stun(side: a, until: time + (act.kind == .strike ? 0.6 : 0.8))
                events.append(.whiff(side: a))
            }
            shots.removeAll { $0.target == s && $0.fromCard }
            events.append(.vanished(side: s))
            return true
        }
        f.phase = .moving
        f.pendingRecovery = 0
        f.phaseUntil = time + 0.25
        sides[s].current = f
        events.append(.sidestep(side: s, dir: dir))
        return true
    }

    // MARK: Simulation of attacks

    mutating func stepActions(_ events: inout [BattleEvent]) {
        for s in 0..<2 {
            guard var act = sides[s].current.action, sides[s].current.phase == .acting else { continue }
            while act.done < act.times.count && time >= act.times[act.done] {
                let i = act.done
                act.done += 1
                sides[s].current.action = act
                let last = act.done == act.times.count
                if act.isProjectile {
                    let travel = max(0.05, gap / Self.shotSpeed)
                    let big = act.card?.hits == 1 && act.kind == .blast
                    shots.append(Shot(owner: s, target: 1 - s, arrive: time + travel, power: act.perHit,
                                      kind: act.kind, heavy: last && act.kind == .blast, comboIndex: act.comboIndex,
                                      index: i, fromCard: act.kind == .blast, cardTotal: act.card?.power ?? act.perHit))
                    events.append(.shotFired(side: s, travel: travel, big: big))
                } else {
                    events.append(.swing(side: s, kind: act.kind, hitIndex: i, heavy: last && act.kind != .basic))
                    strikeLands(s, act, index: i, last: last, &events)
                }
                guard let a2 = sides[s].current.action else { break }   // interrupted (countered / KO)
                act = a2
            }
        }
    }

    mutating func strikeLands(_ s: Int, _ act: Action, index i: Int, last: Bool, _ events: inout [BattleEvent]) {
        let d = 1 - s
        let t = sides[d].current
        guard !t.isKO, time >= t.invulnUntil, t.phase != .vanishing else { return }
        // Attack tracking: committed melee hits home in instead of whiffing.
        if act.kind == .strike || act.kind == .basic, gap > Self.strikeReach {
            if gap > Self.strikeReach + 3 { return }
            moveGap(to: Self.strikeStand, over: 0.04)
            gap = Self.strikeStand
        }
        landHit(attacker: s, kind: act.kind, power: act.perHit * (last && act.kind != .basic ? 1.3 : 1),
                heavy: last && act.kind != .basic, index: i, comboIndex: act.comboIndex, bonus: act.bonus,
                cardTotal: act.card?.power ?? act.perHit * Double(act.times.count), &events)
    }

    mutating func stepShots(_ events: inout [BattleEvent]) {
        guard !shots.isEmpty else { return }
        var remaining: [Shot] = []
        for sh in shots {
            guard time >= sh.arrive else { remaining.append(sh); continue }
            let t = sides[sh.target].current
            if t.isKO || time < t.invulnUntil || t.phase == .vanishing { continue }
            if let act = t.action, t.phase == .acting {
                // Super-armored strikes plow through blasts; any card attack shrugs off basic shots.
                if act.kind == .strike && act.armor && act.done == 0 {
                    events.append(.armorBreak(side: sh.target))
                    continue
                }
                if sh.kind == .basic && act.card != nil && act.kind != .basic { continue }
            }
            landHit(attacker: sh.owner, kind: sh.kind, power: sh.power, heavy: sh.heavy, index: sh.index,
                    comboIndex: sh.comboIndex, bonus: 0, cardTotal: sh.cardTotal, &events)
        }
        shots = remaining
    }

    /// Warn the defender 0.35–0.5 s before a card attack lands ("!").
    mutating func stepWarnings(_ events: inout [BattleEvent]) {
        let lead = Tune.warningWindow.upperBound
        for s in 0..<2 {
            let d = 1 - s
            if var act = sides[s].current.action, act.card != nil, act.kind != .basic, !act.isProjectile, !act.warned,
               act.done < act.times.count, act.times[act.done] - time <= lead {
                act.warned = true
                sides[s].current.action = act
                events.append(.warning(side: d, lead: act.times[act.done] - time))
            }
        }
        var warnedTargets = Set<Int>()
        for i in shots.indices where shots[i].fromCard && !shots[i].warned && shots[i].arrive - time <= lead {
            for j in shots.indices where shots[j].owner == shots[i].owner { shots[j].warned = true }
            if !warnedTargets.contains(shots[i].target) {
                warnedTargets.insert(shots[i].target)
                events.append(.warning(side: shots[i].target, lead: shots[i].arrive - time))
            }
        }
    }

    // MARK: Hits

    mutating func landHit(attacker s: Int, kind: HitKind, power: Double, heavy: Bool, index: Int, comboIndex: Int,
                          bonus: Double, cardTotal: Double = 0, _ events: inout [BattleEvent]) {
        let d = 1 - s
        var t = sides[d].current
        var a = sides[s].current
        // Counter stance (green card): negate the hit and freeze the attacker.
        if time < t.counterUntil && kind != .basic {
            t.counterUntil = 0
            sides[d].current = t
            stun(side: s, until: time + t.counterStun, type: .stun)
            shots.removeAll { $0.owner == s }
            events.append(.countered(side: d))
            return
        }
        let crit = a.guaranteedCrit || rng.chance(Self.critChance)
        if a.guaranteedCrit {
            a.guaranteedCrit = false
            sides[s].current = a
        }
        let reduction = time < t.shieldUntil ? t.shieldReduction : 0
        // Light hitstun for an opening basic jab, combo stun inside a string, heavy knockback on the final hit.
        let stunType: Hitstun = time < t.armorUntil ? .none
            : (heavy ? .heavy : (kind == .basic && sides[s].comboHits == 0 ? .light : .combo))
        let melee = kind == .strike || kind == .basic
        // Strikes / basic melee use strike attack, blasts use blast attack, specials and ultimates the higher one.
        let base = kind == .blast ? a.stats.blastAtk : (melee ? a.stats.strikeAtk : max(a.stats.strikeAtk, a.stats.blastAtk))
        let atk = base * (1 + a.statBonus)
        var up = a.stats.damageUp + a.damageBonus + bonus + sides[s].teamDamageBonus(at: time)
        if kind == .special { up += a.stats.specialDamageUp }
        if kind == .ultimate { up += a.stats.ultimateDamageUp }
        // Per-hit share of the whole card's layered damage (defense is subtracted once per card).
        let cardMultiplier = max(power, cardTotal)
        let whole = CombatMath.damage(attack: atk, cardMultiplier: cardMultiplier, defense: t.stats.defense * (1 + t.statBonus),
                                      damageUp: up, damageCut: t.stats.damageCut + reduction,
                                      attacker: a.def.element, defender: t.def.element, cardIndex: comboIndex,
                                      crit: crit, variance: CombatMath.varianceRange.lowerBound + rng.unit() * 0.06)
        let dmg = max(1, (whole * power / cardMultiplier).rounded())
        if kind != .basic, var act = sides[s].current.action, !act.counted {
            act.counted = true
            sides[s].current.action = act
            sides[s].comboCards += 1
        }
        sides[s].comboHits += 1
        events.append(.hit(HitInfo(attacker: s, kind: kind, damage: dmg, crit: crit,
                                   matchup: Element.matchup(attacker: a.def.element, defender: t.def.element),
                                   heavy: heavy, hitIndex: index, comboHits: sides[s].comboHits, stun: stunType)))
        if reduction > 0 { events.append(.shieldBlocked(side: d)) }
        // Hit-lock: the defender cannot act or vanish until the combo ends.
        if stunType != .none {
            stun(side: d, until: time + stunType.duration, type: stunType)
            shots.removeAll { $0.owner == d }
            if heavy {
                let far = kind == .special || kind == .ultimate
                moveGap(to: far ? (Tune.zoneGap[.long] ?? 11) : (Tune.zoneGap[.mid] ?? 6.2) - 1.5, over: 0.3)
            }
        }
        events += damage(dmg, to: d)
    }
}
