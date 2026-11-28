/// SP (Sparking) / LL (Legends Limited, has a Legendary Finish) / UL (Ultra).
public enum Rarity: String, CaseIterable, Sendable, Codable, Comparable {
    case sp, ll, ul

    public static func < (a: Rarity, b: Rarity) -> Bool {
        let order: [Rarity] = [.sp, .ll, .ul]
        return order.firstIndex(of: a)! < order.firstIndex(of: b)!
    }

    public var label: String {
        switch self {
        case .sp: return "SP"
        case .ll: return "LL"
        case .ul: return "UL"
        }
    }

    /// LL and UL fighters get a Legendary Finish on their ultimate.
    public var hasLegendaryFinish: Bool { self != .sp }
}

/// Character tags used by Z abilities, equipment restrictions and Ultra abilities.
public enum Tag: String, CaseIterable, Sendable, Codable {
    case starWarrior        // 星际战士
    case ultimateForm       // 究极体
    case melee              // 近战
    case psychic            // 灵能者
    case ranged             // 远程
    case flame              // 烈焰系
    case burst              // 爆发
    case mechWarrior        // 机甲武者
    case thunder            // 雷霆系
    case suppression        // 压制
    case support            // 支援系
    case protagonist        // 主角系

    public var nameZH: String {
        switch self {
        case .starWarrior: return "星际战士"
        case .ultimateForm: return "究极体"
        case .melee: return "近战"
        case .psychic: return "灵能者"
        case .ranged: return "远程"
        case .flame: return "烈焰系"
        case .burst: return "爆发"
        case .mechWarrior: return "机甲武者"
        case .thunder: return "雷霆系"
        case .suppression: return "压制"
        case .support: return "支援系"
        case .protagonist: return "主角系"
        }
    }
}
