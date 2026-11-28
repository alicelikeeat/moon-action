public enum CardKind: String, CaseIterable, Sendable, Codable {
    case strike     // red: dash in, multi-hit melee
    case blast      // yellow: volley of energy shots
    case special    // blue: special move (beam / rush)
    case support    // green: special arts (heal, buff, Ki, counter…)
    case ultimate   // purple: only drawn through a main ability, once per battle

    public var defaultCost: Int {
        switch self {
        case .strike: return 20
        case .blast: return 30
        case .special: return 50
        case .support: return 20
        case .ultimate: return 20
        }
    }
}

/// Green-card effects.
public enum SupportEffect: Sendable, Equatable {
    /// +Ki and the next strike card deals bonus damage.
    case kiCharge(ki: Double, nextStrikeBonus: Double)
    /// Damage reduction for a duration; pushes back an adjacent opponent.
    case shield(reduction: Double, duration: Double)
    /// Refill the vanish gauge by a fraction (0…1).
    case vanishRefill(Double)
    /// Heal every living teammate by a fraction of max HP.
    case teamHeal(Double)
    /// Counter stance: the next hit taken is negated and stuns the attacker.
    case freezeCounter(window: Double, stun: Double)
    /// +Ki and remove the opponent's buffs.
    case kiBurst(ki: Double)
}

public struct ArtsCard: Sendable, Equatable, Identifiable {
    public let id: String
    public let nameEN: String
    public let nameZH: String
    public let kind: CardKind
    public let cost: Int
    /// Damage multiplier of the whole card (split over its hits).
    public let power: Double
    public let hits: Int
    public let support: SupportEffect?
    /// Strike that breaks through blasts (super armor during its dash).
    public let superArmor: Bool

    public init(id: String, en: String, zh: String, kind: CardKind, cost: Int? = nil, power: Double = 1, hits: Int = 1,
                support: SupportEffect? = nil, superArmor: Bool = false) {
        self.id = id
        self.nameEN = en
        self.nameZH = zh
        self.kind = kind
        self.cost = cost ?? kind.defaultCost
        self.power = power
        self.hits = hits
        self.support = support
        self.superArmor = superArmor
    }
}

/// A card instance in hand (may carry an energy orb for the rush gauge).
public struct HandCard: Sendable, Equatable, Identifiable {
    public let id: Int
    public let card: ArtsCard
    public let orb: Bool

    public init(id: Int, card: ArtsCard, orb: Bool) {
        self.id = id
        self.card = card
        self.orb = orb
    }
}
