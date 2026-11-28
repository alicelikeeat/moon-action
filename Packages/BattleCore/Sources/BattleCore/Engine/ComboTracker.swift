/// Advanced combo routes (brief §4.3).
public enum ComboStep: Sendable, Equatable { case dash, side, charge }

public enum ComboRoute: Sendable, Equatable {
    /// Up-dash → left/right side-step → card within 0.42 s: +8 Ki, +10 % vanish, faster draw.
    case sideStep
    /// After a blast: up-dash → hold charge 0.25–0.38 s → card: +15 Ki.
    case chargeStep
}

/// Per-side combo bookkeeping: input buffer, route steps since the last card, drop timer.
public struct ComboTracker: Sendable, Equatable {
    /// When the last card's final hit landed / went out — route timers start here.
    public internal(set) var lastCardEnd: Double?
    public internal(set) var lastCardKind: HitKind?
    public internal(set) var steps: [ComboStep] = []
    public internal(set) var chargeStart: Double?
    public internal(set) var chargeHeld: Double = 0
    /// Hand slot queued within 0.25 s before the current card's recovery.
    public internal(set) var buffered: Int?

    public init() {}

    mutating func reset() { self = ComboTracker() }
}

extension Tune {
    public static let inputBuffer = 0.25
    public static let sideStepWindow = 0.42
    public static let dropWindow = 0.45
    public static let sideStepKi = 8.0
    public static let sideStepVanish = 10.0
    public static let sideStepDraw = 0.3
    public static let chargeStepKi = 15.0
    public static let chargeStepHold = 0.25...0.38
}

extension BattleEngine {
    /// Between cards of a live combo: route moves (dash / side-step / charge) are allowed and cancel recovery.
    public func routeOpen(_ s: Int) -> Bool {
        guard let end = sides[s].combo.lastCardEnd, time >= end, sides[1 - s].current.phase == .stunned else { return false }
        let f = sides[s].current
        if f.phase == .acting { return f.action?.chainable(at: time) ?? false }
        return f.canAct
    }

    mutating func noteRouteStep(_ s: Int, _ step: ComboStep) {
        guard routeOpen(s) else { return }
        sides[s].combo.steps.append(step)
    }

    /// Called when a card is played: resolve a route bonus, then start timing from this card.
    mutating func resolveRoute(_ s: Int, card: ArtsCard, action: Action?, _ events: inout [BattleEvent]) {
        var c = sides[s].combo
        if let start = c.chargeStart {
            c.chargeHeld = time - start
            c.chargeStart = nil
            if c.steps.last != .charge { c.steps.append(.charge) }
        }
        if let end = c.lastCardEnd, sides[1 - s].current.phase == .stunned {
            let elapsed = time - end
            if c.steps.count >= 2, c.steps[0] == .dash, c.steps.contains(.side), elapsed <= Tune.sideStepWindow {
                sides[s].ki = min(Tune.kiMax, sides[s].ki + Tune.sideStepKi)
                sides[s].current.vanish = min(Tune.vanishMax, sides[s].current.vanish + Tune.sideStepVanish)
                for i in 0..<4 { if let at = sides[s].refillAt[i] { sides[s].refillAt[i] = at - Tune.sideStepDraw } }
                events.append(.comboRoute(side: s, route: .sideStep))
            } else if c.lastCardKind == .blast, c.steps.first == .dash, c.steps.contains(.charge),
                      Tune.chargeStepHold.contains(c.chargeHeld) {
                sides[s].ki = min(Tune.kiMax, sides[s].ki + Tune.chargeStepKi)
                events.append(.comboRoute(side: s, route: .chargeStep))
            }
        }
        c.steps = []
        c.chargeHeld = 0
        c.buffered = nil
        if let a = action, card.kind != .support {
            let last = a.lastHitTime + (a.isProjectile ? gap / Self.shotSpeed : 0)
            c.lastCardEnd = last
            c.lastCardKind = a.kind
        }
        sides[s].combo = c
    }

    /// Input buffer: a card pressed within 0.25 s before the current card's last hit is queued.
    mutating func bufferCard(_ s: Int, slot: Int, _ events: inout [BattleEvent]) -> Bool {
        let f = sides[s].current
        guard slot >= 0, slot < 4, let hc = sides[s].hand[slot], f.phase == .acting, let act = f.action, act.card != nil,
              time < act.lastHitTime, act.lastHitTime - time <= Tune.inputBuffer,
              sides[s].ki >= cost(of: hc.card, side: s) else { return false }
        sides[s].combo.buffered = slot
        events.append(.inputBuffered(side: s, slot: slot))
        return true
    }

    mutating func stepCombos(_ events: inout [BattleEvent]) {
        for s in 0..<2 {
            // Fire a buffered card on the recovery frame.
            if let slot = sides[s].combo.buffered {
                if canPlay(side: s, slot: slot) {
                    sides[s].combo.buffered = nil
                    _ = playCard(s, slot: slot, &events)
                } else if sides[s].current.phase != .acting {
                    sides[s].combo.buffered = nil
                }
            }
            // Drop combo: a dash / charge route that takes longer than 0.45 s frees the defender.
            let c = sides[s].combo
            let d = 1 - s
            if let end = c.lastCardEnd, !c.steps.isEmpty || c.chargeStart != nil, time - end > Tune.dropWindow,
               sides[d].current.phase == .stunned, !sides[d].current.hitstun.isAilment {
                sides[d].current.phase = .idle
                sides[d].current.hitstun = .none
                sides[d].current.phaseUntil = time
                sides[s].comboCards = 0
                sides[s].comboHits = 0
                sides[d].specialCoverUsed = false
                sides[s].combo.reset()
                events.append(.comboDropped(side: s))
            }
        }
    }
}
