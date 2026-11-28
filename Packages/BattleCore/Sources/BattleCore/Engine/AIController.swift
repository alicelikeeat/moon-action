public enum Difficulty: String, CaseIterable, Sendable {
    case novice, standard, challenge

    /// Chance to vanish an incoming card attack.
    public var vanishChance: Double {
        switch self {
        case .novice: return 0.25
        case .standard: return 0.55
        case .challenge: return 0.8
        }
    }

    /// Reaction delay before acting on a warning.
    public var reaction: Double {
        switch self {
        case .novice: return 0.28
        case .standard: return 0.16
        case .challenge: return 0.08
        }
    }

    /// Pause between decisions while neutral.
    public var think: ClosedRange<Double> {
        switch self {
        case .novice: return 0.9...1.6
        case .standard: return 0.55...1.1
        case .challenge: return 0.3...0.7
        }
    }

    /// Chance to chain another card when a card connects.
    public var chainChance: Double {
        switch self {
        case .novice: return 0.3
        case .standard: return 0.6
        case .challenge: return 0.85
        }
    }

    public var nameZH: String {
        switch self {
        case .novice: return "新手"
        case .standard: return "标准"
        case .challenge: return "挑战"
        }
    }
}

/// Utility-scored decision maker driving one side through the same inputs as a player.
public struct AIController: Sendable {
    public let side: Int
    public var difficulty: Difficulty
    var nextThink: Double = 1.2
    var vanishAt: Double?
    var decidedThreat = false
    var chargeUntilKi: Double?
    var lastChainCheck: Double = -1

    public init(side: Int, difficulty: Difficulty) {
        self.side = side
        self.difficulty = difficulty
    }

    /// Call once per rendered frame after `engine.advance`.
    public mutating func update(_ e: inout BattleEngine, _ events: inout [BattleEvent]) {
        guard !e.over else { return }
        let me = e.sides[side].current
        // Defense: decide once per threat whether to vanish, then react after a human-like delay.
        if let lead = e.incomingThreat(on: side), lead <= Tune.warningWindow.upperBound {
            if !decidedThreat {
                decidedThreat = true
                if me.vanish >= Tune.vanishCost && e.rng.chance(difficulty.vanishChance) {
                    vanishAt = e.time + min(difficulty.reaction, max(0, lead - 0.05))
                }
            }
        } else {
            decidedThreat = false
        }
        if let at = vanishAt, e.time >= at {
            vanishAt = nil
            e.apply(.sidestep(e.rng.chance(0.5) ? 1 : -1), side: side, events: &events)
            return
        }
        // Charging until the Ki target, unless threatened.
        if me.phase == .charging {
            if let target = chargeUntilKi, e.sides[side].ki < target, e.incomingThreat(on: side) == nil { return }
            chargeUntilKi = nil
            e.apply(.chargeEnd, side: side, events: &events)
        }
        // Offense: chain off a connecting card.
        if me.phase == .acting, let act = me.action, act.chainable(at: e.time), e.time > lastChainCheck {
            lastChainCheck = act.lastHitTime + 1
            if e.sides[1 - side].current.phase == .stunned, e.rng.chance(difficulty.chainChance),
               let slot = bestSlot(&e, chaining: true) {
                e.apply(.play(slot), side: side, events: &events)
            }
            return
        }
        guard me.canAct, e.time >= nextThink else { return }
        nextThink = e.time + difficulty.think.lowerBound + e.rng.unit() * (difficulty.think.upperBound - difficulty.think.lowerBound)
        if let slot = bestSlot(&e, chaining: false) {
            e.apply(.play(slot), side: side, events: &events)
        } else if e.sides[side].ki < 40 && e.zone != .close {
            chargeUntilKi = 60 + e.rng.unit() * 30
            e.apply(.chargeBegin, side: side, events: &events)
        } else if e.zone == .long || (e.zone == .mid && e.rng.chance(0.4)) {
            e.apply(.moveForward, side: side, events: &events)
        } else {
            e.apply(.tap, side: side, events: &events)
        }
    }

    /// Utility score of each playable card for the current situation.
    func bestSlot(_ e: inout BattleEngine, chaining: Bool) -> Int? {
        var best: (Int, Double)?
        for slot in 0..<4 where e.canPlay(side: side, slot: slot) {
            guard let c = e.sides[side].hand[slot]?.card else { continue }
            var score = 1.0
            switch c.kind {
            case .strike: score = e.zone == .long ? 1.2 : 2.0
            case .blast: score = e.zone == .close ? 1.0 : 1.8
            case .special: score = e.sides[side].ki >= 70 ? 2.4 : 0.6
            case .ultimate: score = 3.0
            case .support:
                let me = e.sides[side].current
                if case .teamHeal? = c.support { score = me.hp < me.def.maxHP * 0.6 ? 2.2 : 0.3 } else { score = chaining ? 0.1 : 1.0 }
            }
            if chaining && c.kind == .support { score *= 0.1 }
            score += e.rng.unit() * 0.4
            if best == nil || score > best!.1 { best = (slot, score) }
        }
        return best?.0
    }
}
