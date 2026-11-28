/// The 10 first-release equipment templates.
public enum EquipmentCatalog {
    public static let all: [EquipmentTemplate] = [
        EquipmentTemplate(id: "eq.fist", zh: "斗魂拳套", en: "Fighting Spirit Gauntlets",
                          slots: [.init(.strikeAtk, 0.08...0.16), .init(.strikeAtk, 0.04...0.10), .init(.defense, 0.03...0.08)]),
        EquipmentTemplate(id: "eq.core", zh: "星核气珠", en: "Star Core Orb",
                          slots: [.init(.blastAtk, 0.08...0.16), .init(.blastAtk, 0.04...0.10), .init(.kiRecovery, 0.03...0.08)]),
        EquipmentTemplate(id: "eq.armor", zh: "陨铁战甲", en: "Meteor-Iron Armor",
                          slots: [.init(.hp, 0.06...0.14), .init(.defense, 0.05...0.12), .init(.damageCut, 0.02...0.06)]),
        EquipmentTemplate(id: "eq.halo", zh: "必杀光环", en: "Special Art Halo",
                          slots: [.init(.specialDamage, 0.10...0.25), .init(.strikeAtk, 0.03...0.08), .init(.blastAtk, 0.03...0.08)]),
        EquipmentTemplate(id: "eq.crown", zh: "究极王冠", en: "Ultimate Crown", restriction: .rarity([.ll, .ul]),
                          slots: [.init(.ultimateDamage, 0.15...0.35), .init(.specialDamage, 0.05...0.15), .init(.hp, 0.04...0.10)]),
        EquipmentTemplate(id: "eq.flame", zh: "赤焰纹章", en: "Crimson Crest", restriction: .element(.red),
                          slots: [.init(.strikeAtk, 0.10...0.20), .init(.blastAtk, 0.06...0.12), .init(.kiRecovery, 0.03...0.08)]),
        EquipmentTemplate(id: "eq.frost", zh: "霜极纹章", en: "Frost Crest", restriction: .element(.blu),
                          slots: [.init(.blastAtk, 0.10...0.20), .init(.defense, 0.06...0.12), .init(.damageCut, 0.02...0.05)]),
        EquipmentTemplate(id: "eq.pure", zh: "星际战士徽记", en: "Star Warrior Insignia", restriction: .tag(.starWarrior),
                          pureTag: .starWarrior,
                          slots: [.init(.pureDamage, 0.03...0.05), .init(.strikeAtk, 0.04...0.10), .init(.blastAtk, 0.04...0.10)]),
        EquipmentTemplate(id: "eq.wind", zh: "疾风护符", en: "Gale Charm",
                          slots: [.init(.kiRecovery, 0.06...0.15), .init(.hp, 0.03...0.08), .init(.defense, 0.03...0.08)]),
        EquipmentTemplate(id: "eq.relic", zh: "传说圣遗物", en: "Legendary Relic", restriction: .rarity([.ul]),
                          slots: [.init(.strikeAtk, 0.08...0.18), .init(.blastAtk, 0.08...0.18), .init(.ultimateDamage, 0.10...0.25)]),
    ]

    public static func byID(_ id: String) -> EquipmentTemplate? { all.first { $0.id == id } }
}
