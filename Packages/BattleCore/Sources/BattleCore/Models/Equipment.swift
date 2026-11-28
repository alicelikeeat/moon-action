public enum EquipStat: String, Sendable, Codable, CaseIterable {
    case strikeAtk, blastAtk, hp, defense, specialDamage, ultimateDamage, kiRecovery, damageCut
    /// +x pure damage per teammate sharing the equipment's tag.
    case pureDamage

    public var nameZH: String {
        switch self {
        case .strikeAtk: return "打击攻击"
        case .blastAtk: return "射击攻击"
        case .hp: return "最大体力"
        case .defense: return "防御"
        case .specialDamage: return "必杀伤害"
        case .ultimateDamage: return "究极伤害"
        case .kiRecovery: return "气力回复"
        case .damageCut: return "伤害减免"
        case .pureDamage: return "同标签纯伤害"
        }
    }
}

public enum EquipRestriction: Sendable, Equatable {
    case none
    case element(Element)
    case rarity([Rarity])
    case tag(Tag)
}

public struct EquipSlotSpec: Sendable, Equatable {
    public let stat: EquipStat
    public let range: ClosedRange<Double>
    public init(_ stat: EquipStat, _ range: ClosedRange<Double>) {
        self.stat = stat
        self.range = range
    }
}

public struct EquipmentTemplate: Sendable, Equatable, Identifiable {
    public let id: String
    public let nameZH: String
    public let nameEN: String
    public let restriction: EquipRestriction
    /// Tag counted by a pure-damage slot (defaults to Star Warrior).
    public let pureTag: Tag
    public let slots: [EquipSlotSpec]

    public init(id: String, zh: String, en: String, restriction: EquipRestriction = .none, pureTag: Tag = .starWarrior,
                slots: [EquipSlotSpec]) {
        self.id = id
        self.nameZH = zh
        self.nameEN = en
        self.restriction = restriction
        self.pureTag = pureTag
        self.slots = slots
    }

    public func canEquip(_ def: FighterDef) -> Bool {
        switch restriction {
        case .none: return true
        case .element(let e): return def.element == e
        case .rarity(let r): return r.contains(def.rarity)
        case .tag(let t): return def.tags.contains(t)
        }
    }
}

/// Roll quality bead per slot: green < 75 %, gold 75–92 %, red ≥ 93 % of the slot's range.
public enum Bead: String, Sendable, Codable { case green, gold, red }

public enum EquipGrade: String, Sendable, Codable, CaseIterable, Comparable {
    case b = "B", a = "A", s = "S", z = "Z", zPlus = "Z+", godly = "神"

    public static func < (x: EquipGrade, y: EquipGrade) -> Bool {
        EquipGrade.allCases.firstIndex(of: x)! < EquipGrade.allCases.firstIndex(of: y)!
    }
}

/// An owned piece of equipment: 3 rolled slots stored as fractions (0…1) of each slot's range.
public struct EquipmentItem: Sendable, Equatable, Codable, Identifiable {
    public let id: Int
    public let templateID: String
    public internal(set) var rolls: [Double]

    public init(id: Int, templateID: String, rolls: [Double]) {
        self.id = id
        self.templateID = templateID
        self.rolls = rolls.map { min(1, max(0, $0)) }
    }

    public var template: EquipmentTemplate? { EquipmentCatalog.byID(templateID) }

    public func value(slot i: Int) -> Double {
        guard let t = template, t.slots.indices.contains(i), rolls.indices.contains(i) else { return 0 }
        let r = t.slots[i].range
        return r.lowerBound + rolls[i] * (r.upperBound - r.lowerBound)
    }

    public static func bead(_ fraction: Double) -> Bead { fraction >= 0.93 ? .red : (fraction >= 0.75 ? .gold : .green) }
    public func bead(slot i: Int) -> Bead { EquipmentItem.bead(rolls.indices.contains(i) ? rolls[i] : 0) }

    /// Godly needs all three slots red; otherwise by the average roll.
    public var grade: EquipGrade {
        if rolls.count == 3 && rolls.allSatisfy({ $0 >= 0.93 }) { return .godly }
        let avg = rolls.reduce(0, +) / Double(max(1, rolls.count))
        switch avg {
        case ..<0.55: return .b
        case ..<0.7: return .a
        case ..<0.82: return .s
        case ..<0.9: return .z
        default: return .zPlus
        }
    }

    public static func roll(templateID: String, id: Int, rng: inout SplitMix64) -> EquipmentItem {
        let n = EquipmentCatalog.byID(templateID)?.slots.count ?? 3
        return EquipmentItem(id: id, templateID: templateID, rolls: (0..<n).map { _ in rng.unit() })
    }

    /// Slot remover: reroll slot 2 or 3 (index 1 / 2). Secure upgrade never rolls lower than before.
    public mutating func reforge(slot i: Int, secure: Bool, rng: inout SplitMix64) {
        guard i == 1 || i == 2, rolls.indices.contains(i) else { return }
        let old = rolls[i]
        rolls[i] = secure ? old + rng.unit() * (1 - old) : rng.unit()
    }
}

/// Sum of equipment effects on one wearer.
struct EquipmentTotals {
    var strikeAtk = 0.0, blastAtk = 0.0, hp = 0.0, defense = 0.0
    var specialDamage = 0.0, ultimateDamage = 0.0, kiRecovery = 0.0, damageCut = 0.0, pure = 0.0

    mutating func add(_ item: EquipmentItem, wearer: FighterDef, team: [FighterDef]) {
        guard let t = item.template, t.canEquip(wearer) else { return }
        for (i, slot) in t.slots.enumerated() {
            let v = item.value(slot: i)
            switch slot.stat {
            case .strikeAtk: strikeAtk += v
            case .blastAtk: blastAtk += v
            case .hp: hp += v
            case .defense: defense += v
            case .specialDamage: specialDamage += v
            case .ultimateDamage: ultimateDamage += v
            case .kiRecovery: kiRecovery += v
            case .damageCut: damageCut += v
            case .pureDamage:
                let mates = team.filter { $0.id != wearer.id && $0.tags.contains(t.pureTag) }.count
                pure += v * Double(mates)
            }
        }
    }
}
