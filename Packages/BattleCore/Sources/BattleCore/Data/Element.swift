/// Element wheel: RED > YEL > PUR > GRN > BLU > RED; LGT is neutral.
public enum Element: String, CaseIterable, Sendable, Codable {
    case red, yel, pur, grn, blu, lgt

    /// The element this one has the advantage over (nil for neutral LGT).
    public var beats: Element? {
        switch self {
        case .red: return .yel
        case .yel: return .pur
        case .pur: return .grn
        case .grn: return .blu
        case .blu: return .red
        case .lgt: return nil
        }
    }

    /// Advantage: +50% damage dealt. Attacking into a disadvantage: -30% (i.e. the advantaged side takes 30% less).
    public static let advantageDealt = 1.5
    public static let disadvantageDealt = 0.7

    public static func damageMultiplier(attacker: Element, defender: Element) -> Double {
        if attacker.beats == defender { return advantageDealt }
        if defender.beats == attacker { return disadvantageDealt }
        return 1
    }

    public enum Matchup: Sendable { case advantage, neutral, disadvantage }

    public static func matchup(attacker: Element, defender: Element) -> Matchup {
        if attacker.beats == defender { return .advantage }
        if defender.beats == attacker { return .disadvantage }
        return .neutral
    }

    public var nameZH: String {
        switch self {
        case .red: return "炽焰"
        case .yel: return "雷霆"
        case .pur: return "暗影"
        case .grn: return "疾风"
        case .blu: return "寒冰"
        case .lgt: return "圣光"
        }
    }

    public var nameEN: String {
        switch self {
        case .red: return "Blaze"
        case .yel: return "Thunder"
        case .pur: return "Shadow"
        case .grn: return "Gale"
        case .blu: return "Frost"
        case .lgt: return "Light"
        }
    }
}
