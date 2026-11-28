/// High-tier fighters' dynamic gauge (under the HP bar).
public enum UniqueGaugeType: String, Sendable, Equatable, Codable, CaseIterable {
    /// +25 % per strike / blast card; at 100 %: +40 Ki, draw a special, 10 s cover nullification, +25 % damage.
    case attack
    /// Refills over time / while moving; idle or moving fighters automatically evade strike / blast cards for 35 %.
    case autoEvade
    /// +15 % per hit taken or over time; at 100 % a strike / blast hit is countered (knock away, break combo).
    case counter
    /// Charged by cards and Ki charge; at 100 % permanently enter an overload form.
    case release

    public var nameZH: String {
        switch self {
        case .attack: return "攻击爆发"
        case .autoEvade: return "自动闪避"
        case .counter: return "受击反制"
        case .release: return "形态充能"
        }
    }
}
