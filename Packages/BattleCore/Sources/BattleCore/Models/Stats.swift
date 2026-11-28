/// Base combat stats (HP, strike / blast attack, defense used against both).
public struct StatBlock: Sendable, Equatable, Codable {
    public var hp: Double
    public var strikeAtk: Double
    public var blastAtk: Double
    public var defense: Double

    public init(hp: Double, strikeAtk: Double, blastAtk: Double, defense: Double) {
        self.hp = hp
        self.strikeAtk = strikeAtk
        self.blastAtk = blastAtk
        self.defense = defense
    }

    public static func * (s: StatBlock, k: Double) -> StatBlock { s.scaled(k) }

    public func scaled(_ k: Double) -> StatBlock {
        StatBlock(hp: hp * k, strikeAtk: strikeAtk * k, blastAtk: blastAtk * k, defense: defense * k)
    }
}

/// Fully resolved stats a fighter enters battle with (after level, stars, Z ability, leader, equipment).
public struct FinalStats: Sendable, Equatable {
    public var hp: Double
    public var strikeAtk: Double
    public var blastAtk: Double
    public var defense: Double
    /// Additive damage-dealt bonus (InflictedDamageUp), e.g. 0.3 = +30 %.
    public var damageUp: Double = 0
    /// Damage cut (EnemyDamageCut on the defender side).
    public var damageCut: Double = 0
    public var specialDamageUp: Double = 0
    public var ultimateDamageUp: Double = 0
    /// Ki recovery multiplier bonus, 0.3 = +30 %.
    public var kiRecoveryUp: Double = 0

    public init(hp: Double, strikeAtk: Double, blastAtk: Double, defense: Double) {
        self.hp = hp
        self.strikeAtk = strikeAtk
        self.blastAtk = blastAtk
        self.defense = defense
    }

    public init(_ s: StatBlock) {
        self.init(hp: s.hp, strikeAtk: s.strikeAtk, blastAtk: s.blastAtk, defense: s.defense)
    }
}
