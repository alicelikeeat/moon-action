/// Unique gauges (brief §5.2), strike clash and Rising Rush.

public struct ClashState: Sendable, Equatable {
    public let start: Double
    public let end: Double
    public internal(set) var scores: [Int?] = [nil, nil]
    /// Bar position 0…999 at a time (fast back-and-forth, one sweep every 0.6 s).
    public func bar(at t: Double) -> Int {
        let u = ((t - start) / 0.6).truncatingRemainder(dividingBy: 2)
        let tri = u < 1 ? u : 2 - u
        return Int((tri * 999).rounded())
    }
}

public struct RushState: Sendable, Equatable {
    public let attacker: Int
    /// Hit check time (startup), then the 4-way guess window.
    public let impact: Double
    public internal(set) var guessUntil: Double = 0
    public internal(set) var pick: Int
    public internal(set) var guess: Int?
    public internal(set) var landed = false
}

extension Tune {
    public static let attackGaugePerCard = 25.0
    public static let attackBurstKi = 40.0
    public static let attackBurstDuration = 10.0
    public static let attackBurstDamage = 0.25
    public static let autoEvadeRegen = 6.0          // per second, ×2 while moving
    public static let autoEvadeCost = 35.0
    public static let counterPerHit = 15.0
    public static let counterRegen = 3.0
    public static let counterMaxUses = 3
    public static let releasePerCard = 12.0
    public static let releaseChargeRate = 10.0
    public static let overloadDamage = 0.3
    public static let clashDuration = 3.0
    public static let clashWindow = 0.3
    public static let rushOrbs = 7
    public static let rushStartup = 0.6
    public static let rushGuessTime = 3.0
    public static let rushPower = 9.0
}

extension BattleEngine {
    // MARK: Unique gauges

    func gaugeType(_ s: Int) -> UniqueGaugeType? { sides[s].current.def.gauge }

    /// Extra damage-up from gauges (attack burst / overload).
    func gaugeDamageBonus(_ s: Int) -> Double {
        let f = sides[s].current
        return (time < f.attackBurstUntil ? Tune.attackBurstDamage : 0) + (f.overload ? Tune.overloadDamage : 0)
    }

    mutating func addGauge(_ s: Int, _ amount: Double, _ events: inout [BattleEvent]) {
        guard gaugeType(s) != nil, !sides[s].current.isKO else { return }
        if gaugeType(s) == .release && sides[s].current.overload { return }
        if gaugeType(s) == .counter && sides[s].current.counterUses >= Tune.counterMaxUses { return }
        sides[s].current.gauge = min(100, sides[s].current.gauge + amount)
        guard sides[s].current.gauge >= 100 else { return }
        switch gaugeType(s) {
        case .attack?:
            // Burst: +40 Ki, draw a special, 10 s cover nullification and +25 % damage.
            sides[s].current.gauge = 0
            sides[s].ki = min(Tune.kiMax, sides[s].ki + Tune.attackBurstKi)
            sides[s].coverNullUntil = max(sides[s].coverNullUntil, time + Tune.attackBurstDuration)
            sides[s].current.attackBurstUntil = time + Tune.attackBurstDuration
            grantSpecial(s, &events)
            events.append(.gaugeTriggered(side: s, type: .attack))
        case .release?:
            // Permanent overload form.
            sides[s].current.overload = true
            sides[s].fastDrawUntil = .infinity
            events.append(.gaugeTriggered(side: s, type: .release))
        default: break
        }
    }

    mutating func grantSpecial(_ s: Int, _ events: inout [BattleEvent]) {
        guard let sp = sides[s].current.def.deck.first(where: { $0.kind == .special }) else { return }
        let slot = sides[s].hand.firstIndex { $0 == nil } ?? 3
        setHand(side: s, slot: slot, card: sp)
        events.append(.handChanged(side: s))
    }

    /// Per-step passive gauge charge.
    mutating func stepGauges(_ dt: Double, _ events: inout [BattleEvent]) {
        for s in 0..<2 {
            let f = sides[s].current
            guard let g = f.def.gauge, !f.isKO else { continue }
            switch g {
            case .autoEvade:
                let rate = Tune.autoEvadeRegen * (f.phase == .moving ? 2 : 1)
                sides[s].current.gauge = min(100, f.gauge + rate * dt)
            case .counter:
                if f.counterUses < Tune.counterMaxUses { sides[s].current.gauge = min(100, f.gauge + Tune.counterRegen * dt) }
            case .release:
                if f.phase == .charging && !f.overload { addGauge(s, Tune.releaseChargeRate * dt, &events) }
            case .attack: break
            }
        }
    }

    mutating func gaugeOnCardPlayed(_ s: Int, _ card: ArtsCard, _ events: inout [BattleEvent]) {
        switch gaugeType(s) {
        case .attack? where card.kind == .strike || card.kind == .blast: addGauge(s, Tune.attackGaugePerCard, &events)
        case .release?: addGauge(s, Tune.releasePerCard, &events)
        default: break
        }
    }

    /// Defensive gauges, checked when a card hit is about to land. Returns true if the hit is negated.
    mutating func gaugeDefends(defender d: Int, kind: HitKind, _ events: inout [BattleEvent]) -> Bool {
        guard kind == .strike || kind == .blast else {
            return false
        }
        var t = sides[d].current
        switch t.def.gauge {
        case .autoEvade? where t.gauge >= Tune.autoEvadeCost && (t.phase == .idle || t.phase == .moving || t.phase == .charging):
            t.gauge -= Tune.autoEvadeCost
            t.phase = .vanishing
            t.phaseUntil = time + 0.35
            t.invulnUntil = time + 0.5
            t.action = nil
            sides[d].current = t
            shots.removeAll { $0.target == d && $0.fromCard }
            events.append(.autoEvaded(side: d))
            return true
        case .counter? where t.gauge >= 100 && t.counterUses < Tune.counterMaxUses:
            let a = 1 - d
            t.gauge = 0
            t.counterUses += 1
            t.phase = .idle
            t.hitstun = .none
            t.invulnUntil = time + 0.4
            sides[d].current = t
            stun(side: a, until: time + Hitstun.heavy.duration, type: .heavy)
            shots.removeAll { $0.owner == a }
            sides[a].comboCards = 0
            sides[a].comboHits = 0
            sides[a].combo.reset()
            moveGap(to: (Tune.zoneGap[.mid] ?? 6.5) - 1.5, over: 0.3)
            grantSpecial(d, &events)
            events.append(.gaugeTriggered(side: d, type: .counter))
            return true
        default:
            return false
        }
    }

    mutating func gaugeOnHitTaken(_ d: Int, _ events: inout [BattleEvent]) {
        if gaugeType(d) == .counter { addGauge(d, Tune.counterPerHit, &events) }
    }

    // MARK: Clash (both strike cards collide)

    mutating func checkClash(_ events: inout [BattleEvent]) {
        guard clash == nil, rush == nil,
              let a = sides[0].current.action, let b = sides[1].current.action,
              sides[0].current.phase == .acting, sides[1].current.phase == .acting,
              a.kind == .strike, b.kind == .strike, a.card != nil, b.card != nil,
              a.done == 0, b.done == 0, abs(a.start - b.start) <= Tune.clashWindow else { return }
        let c = ClashState(start: time, end: time + Tune.clashDuration)
        clash = c
        cinematicUntil = max(cinematicUntil, c.end)
        for s in 0..<2 {
            sides[s].current.action = nil
            sides[s].current.phase = .acting
            sides[s].current.phaseUntil = c.end
        }
        moveGap(to: 1.2, over: 0.15)
        shots.removeAll()
        events.append(.clashStarted(until: c.end))
    }

    mutating func lockClash(_ s: Int, _ events: inout [BattleEvent]) -> Bool {
        guard var c = clash, c.scores[s] == nil else { return false }
        let v = c.bar(at: time)
        c.scores[s] = v
        clash = c
        events.append(.clashLocked(side: s, score: v))
        if c.scores.allSatisfy({ $0 != nil }) { resolveClash(&events) }
        return true
    }

    mutating func stepClash(_ events: inout [BattleEvent]) {
        guard let c = clash, time >= c.end else { return }
        resolveClash(&events)
    }

    mutating func resolveClash(_ events: inout [BattleEvent]) {
        guard let c = clash else { return }
        clash = nil
        cinematicUntil = time
        let p = c.scores[0] ?? 0, e = c.scores[1] ?? 0
        let winner: Int? = p == e ? nil : (p > e ? 0 : 1)
        for s in 0..<2 {
            sides[s].current.phase = .idle
            sides[s].current.phaseUntil = time
        }
        events.append(.clashResolved(winner: winner, scores: [p, e]))
        guard let w = winner else {
            moveGap(to: Tune.zoneGap[.mid] ?? 6.5, over: 0.3)
            return
        }
        // Winner's free follow-up: a guaranteed heavy blow, loser left in combo stun.
        landHit(attacker: w, kind: .special, power: 1.2, heavy: true, index: 0, comboIndex: 1, bonus: 0, cardTotal: 1.2, &events)
    }

    // MARK: Rising Rush (7 orbs)

    public func canRush(side s: Int) -> Bool {
        !over && clash == nil && rush == nil && sides[s].orbs >= Tune.rushOrbs && (sides[s].current.canAct || routeOpen(s))
    }

    mutating func startRush(_ s: Int, _ events: inout [BattleEvent]) -> Bool {
        guard canRush(side: s) else { return false }
        sides[s].orbs = 0
        let r = RushState(attacker: s, impact: time + Tune.rushStartup, pick: rng.int(4))
        rush = r
        cinematicUntil = max(cinematicUntil, r.impact)
        sides[s].current.action = nil
        sides[s].current.phase = .acting
        sides[s].current.phaseUntil = r.impact + 0.1
        events.append(.rushStarted(side: s))
        return true
    }

    /// Attacker chooses the card the defender has to guess (optional; defaults to random).
    mutating func rushPick(_ s: Int, slot: Int) -> Bool {
        guard var r = rush, r.attacker == s, (0..<4).contains(slot), r.guess == nil else { return false }
        r.pick = slot
        rush = r
        return true
    }

    mutating func rushGuess(_ s: Int, slot: Int, _ events: inout [BattleEvent]) -> Bool {
        guard var r = rush, r.landed, r.attacker == 1 - s, r.guess == nil, (0..<4).contains(slot) else { return false }
        r.guess = slot
        rush = r
        resolveRush(&events)
        return true
    }

    mutating func stepRush(_ events: inout [BattleEvent]) {
        guard var r = rush else { return }
        let a = r.attacker, d = 1 - a
        if !r.landed, time >= r.impact {
            let t = sides[d].current
            if t.isKO || time < t.invulnUntil || t.phase == .vanishing {
                rush = nil
                events.append(.rushMissed(side: a))
                return
            }
            r.landed = true
            r.guessUntil = time + Tune.rushGuessTime
            rush = r
            cinematicUntil = max(cinematicUntil, r.guessUntil)
            for s in 0..<2 {
                sides[s].current.action = nil
                sides[s].current.phase = s == a ? .acting : .stunned
                sides[s].current.hitstun = s == a ? .none : .stun
                sides[s].current.phaseUntil = r.guessUntil
            }
            events.append(.rushGuessing(defender: d, until: r.guessUntil))
        } else if r.landed, time >= r.guessUntil {
            resolveRush(&events)
        }
    }

    mutating func resolveRush(_ events: inout [BattleEvent]) {
        guard let r = rush else { return }
        rush = nil
        cinematicUntil = time
        let a = r.attacker, d = 1 - a
        for s in 0..<2 {
            sides[s].current.phase = .idle
            sides[s].current.hitstun = .none
            sides[s].current.phaseUntil = time
        }
        if r.guess == r.pick {
            // Read correctly: the rush is parried and the attacker is left open.
            stun(side: a, until: time + Hitstun.heavy.duration, type: .heavy)
            events.append(.rushParried(side: d))
        } else {
            events.append(.rushFinish(side: a))
            landHit(attacker: a, kind: .ultimate, power: Tune.rushPower, heavy: true, index: 0, comboIndex: 1,
                    bonus: 0, cardTotal: Tune.rushPower, &events)
        }
    }
}
