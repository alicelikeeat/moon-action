/// Tuning constants (seconds / Ki / gauge points). One Timer Count = 1 second.
public enum Tune {
    public static let step = 1.0 / 60.0           // fixed simulation step
    public static let maxFrameDT = 1.0 / 30.0     // clamp per rendered frame (no time jumps)
    public static let battleTime = 180.0
    public static let kiMax = 100.0
    public static let kiRegen = 8.0               // per second, always (except KO)
    public static let chargeRate = 32.0           // per second while holding
    public static let vanishMax = 100.0
    public static let vanishRegen = 6.0
    public static let vanishCost = 100.0
    public static let warningWindow = 0.35...0.5
    public static let switchCooldown = 10.0
    public static let moveTime = 0.3
    /// Gap (metres) used for each zone when moving into it.
    public static let zoneGap: [Zone: Double] = [.close: 2.2, .mid: 6.5, .long: 12.0]
    public static let dashGap = 1.6               // swipe up at close range: dash into the opponent's face
    public static let closeMax = 4.0
    public static let midMax = 9.5
}

public enum Zone: Int, Sendable, Comparable, CaseIterable {
    case close, mid, long

    public static func of(_ gap: Double) -> Zone {
        gap < Tune.closeMax ? .close : (gap < Tune.midMax ? .mid : .long)
    }

    public static func < (a: Zone, b: Zone) -> Bool { a.rawValue < b.rawValue }

    public var closer: Zone { Zone(rawValue: max(0, rawValue - 1)) ?? .close }
    public var farther: Zone { Zone(rawValue: min(2, rawValue + 1)) ?? .long }
}

public enum CombatMath {
    /// Combo compensation by card order within one combo (1-based):
    /// 100 % → 95 % → 85 % → 75 % → 65 % → 50 % (6th card and later).
    public static let comboTable: [Double] = [1.0, 0.95, 0.85, 0.75, 0.65, 0.5]

    public static func comboScale(cardIndex: Int) -> Double {
        comboTable[min(comboTable.count - 1, max(0, cardIndex - 1))]
    }

    public static let critFactor = 1.25
    public static let varianceRange = 0.97...1.03

    /// Layered damage (brief §8):
    /// Raw = max(1, ATK × CardMultiplier − DEF × 0.55)
    /// Buff = (1 + DamageUp) × max(0.2, 1 − max(0, DamageCut − CutPenetration))
    /// Final = Int(Raw × Buff × Element × Combo × Crit × Variance)
    public static func damage(attack: Double, cardMultiplier: Double, defense: Double,
                              damageUp: Double = 0, damageCut: Double = 0, cutPenetration: Double = 0,
                              attacker: Element, defender: Element, cardIndex: Int = 1,
                              crit: Bool = false, variance: Double = 1) -> Double {
        let raw = max(1, attack * cardMultiplier - defense * 0.55)
        let buff = (1 + damageUp) * max(0.2, 1 - max(0, damageCut - cutPenetration))
        let element = Element.damageMultiplier(attacker: attacker, defender: defender)
        let v = raw * buff * element * comboScale(cardIndex: cardIndex) * (crit ? critFactor : 1) * variance
        return Double(Int(v))
    }
}
