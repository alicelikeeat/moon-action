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
    public static let zoneGap: [Zone: Double] = [.close: 2.6, .mid: 6.2, .long: 11.0]
    public static let dashGap = 1.6               // swipe up at close range: dash into the opponent's face
    public static let closeMax = 3.6
    public static let midMax = 8.0
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
    /// Combo compensation by card position in one combo (1-based):
    /// cards 1–2 full damage, then 100% → 90% → 80% → 70% → 60% from the 3rd card on.
    public static func comboScale(cardIndex: Int) -> Double {
        guard cardIndex >= 3 else { return 1 }
        return max(0.6, 1.0 - 0.1 * Double(cardIndex - 3))
    }

    /// Damage of one hit.
    /// - power: share of the card's power carried by this hit
    /// - bonus: additive damage bonus (buffs), reduction: fraction blocked (shields)
    public static func damage(power: Double, attack: Double, defense: Double,
                              attacker: Element, defender: Element, cardIndex: Int = 1,
                              crit: Bool = false, bonus: Double = 0, reduction: Double = 0) -> Double {
        var d = power * attack * (1000 / (1000 + defense)) * 1.6
        d *= Element.damageMultiplier(attacker: attacker, defender: defender)
        d *= comboScale(cardIndex: cardIndex)
        d *= 1 + bonus
        d *= max(0, 1 - reduction)
        if crit { d *= 1.5 }
        return d.rounded()
    }
}
