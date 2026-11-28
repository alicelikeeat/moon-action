/// Z ability: a tag-scoped bonus to strike / blast attack and defense; tier I–IV unlocks with stars.
public struct ZAbility: Sendable, Equatable {
    public let tag: Tag
    /// Bonus for tiers I, II, III, IV (e.g. 0.28 = +28 %).
    public let tiers: [Double]

    public init(tag: Tag, tiers: [Double]) {
        self.tag = tag
        self.tiers = tiers
    }

    /// Tier index unlocked at a star count: I from 1★, II at 3★, III at 6★, IV at 14★.
    public static func tier(stars: Int) -> Int {
        stars >= 14 ? 3 : (stars >= 6 ? 2 : (stars >= 3 ? 1 : 0))
    }

    public func value(stars: Int) -> Double { tiers[min(tiers.count - 1, ZAbility.tier(stars: stars))] }
}

public enum Progression {
    public static let maxLevel = 5000
    public static let maxStars = 14

    /// CurrentStat = BaseStat_Lv1 × (1 + (Level − 1) / 4999 × 9)
    public static func levelFactor(_ level: Int) -> Double {
        let l = Double(max(1, min(maxLevel, level)))
        return 1 + (l - 1) / Double(maxLevel - 1) * 9
    }

    /// Each star above 1★ adds +3 % (14★ = +39 %).
    public static func starFactor(_ stars: Int) -> Double {
        1 + 0.03 * Double(max(1, min(maxStars, stars)) - 1)
    }

    /// Base stats at a level and star count (no Z ability / equipment).
    public static func baseStats(_ def: FighterDef, level: Int, stars: Int) -> StatBlock {
        let k: Double = levelFactor(level) * starFactor(stars)
        return def.baseLv1.scaled(k)
    }

    /// Equipment slots unlocked: 1, a 2nd at Lv.1000, a 3rd at Lv.3000.
    public static func equipmentSlots(level: Int) -> Int { level >= 3000 ? 3 : (level >= 1000 ? 2 : 1) }

    /// Star-up cost in star souls for going from `stars` to `stars + 1`.
    public static func starCost(from stars: Int) -> Int { 10 + stars * 10 }
}

/// One fighter as brought into battle.
public struct FighterLoadout: Sendable, Equatable {
    public let def: FighterDef
    public var level: Int
    public var stars: Int
    public var equipment: [EquipmentItem]

    public init(def: FighterDef, level: Int = Progression.maxLevel, stars: Int = 7, equipment: [EquipmentItem] = []) {
        self.def = def
        self.level = level
        self.stars = stars
        self.equipment = equipment
    }
}

/// Resolves a team's final battle stats: Z abilities with the leader rule, Ultra ability, equipment.
public enum TeamBuild {
    /// Z bonus a member receives. Leader rule: the leader (index 0) gets every teammate's Z ability regardless
    /// of tags, and the leader's own Z ability covers the whole team regardless of tags.
    public static func zBonus(for member: Int, team: [FighterLoadout]) -> Double {
        guard team.indices.contains(member) else { return 0 }
        var total = 0.0
        for (i, provider) in team.enumerated() {
            let z = provider.def.zAbility
            let applies = i == 0 || member == 0 || team[member].def.tags.contains(z.tag)
            if applies { total += z.value(stars: provider.stars) }
        }
        return total
    }

    /// Ultra ability: a UL leader gives the whole team +30 % damage and +30 % Ki recovery; a UL elsewhere
    /// gives +10 % of each per other teammate sharing one of its tags.
    public static func ultraBonus(team: [FighterLoadout]) -> Double {
        var best = 0.0
        for (i, m) in team.enumerated() where m.def.rarity == .ul {
            if i == 0 {
                best = max(best, 0.3)
            } else {
                let sharing = team.indices.filter { $0 != i && !Set(team[$0].def.tags).isDisjoint(with: m.def.tags) }.count
                best = max(best, 0.1 * Double(sharing))
            }
        }
        return best
    }

    public static func finalStats(team: [FighterLoadout]) -> [FinalStats] {
        let ultra = ultraBonus(team: team)
        return team.indices.map { i in
            let m = team[i]
            let base = Progression.baseStats(m.def, level: m.level, stars: m.stars)
            let z = zBonus(for: i, team: team)
            var eq = EquipmentTotals()
            for item in m.equipment.prefix(Progression.equipmentSlots(level: m.level)) {
                eq.add(item, wearer: m.def, team: team.map(\.def))
            }
            // FinalATK = Base × (1 + Z% + BaseEquip%) × (1 + PureEquip%)
            var f = FinalStats(
                hp: base.hp * (1 + eq.hp),
                strikeAtk: base.strikeAtk * (1 + z + eq.strikeAtk) * (1 + eq.pure),
                blastAtk: base.blastAtk * (1 + z + eq.blastAtk) * (1 + eq.pure),
                defense: base.defense * (1 + z + eq.defense))
            f.damageUp = ultra
            f.kiRecoveryUp = ultra + eq.kiRecovery
            f.damageCut = eq.damageCut
            f.specialDamageUp = eq.specialDamage
            f.ultimateDamageUp = eq.ultimateDamage
            return f
        }
    }
}
