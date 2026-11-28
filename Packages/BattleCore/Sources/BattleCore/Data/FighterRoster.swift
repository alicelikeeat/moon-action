/// Main ability: unlocks after `MainAbility.unlockTime`, once per fighter per battle.
public enum MainAbility: Sendable, Equatable {
    /// Draw this fighter's ultimate card and heal a fraction of max HP.
    case ultimateAndHeal(heal: Double)
    /// Replace the whole hand with blast cards and gain Ki.
    case blastHand(ki: Double)
    /// Draw a special card and draw faster for a while.
    case specialRush(fastDraw: Double)
    /// Clear debuffs; teammates deal more damage for the rest of the battle.
    case rally(damage: Double)
    /// Heal and gain super armor for a while.
    case fortress(heal: Double, armor: Double)
    /// Transform: all stats up and heal.
    case transform(stats: Double, heal: Double)

    public static let unlockTime = 18.0
}

/// Special cover tag: when tagged in during an opponent's card of this kind, the fighter cuts in,
/// knocks the opponent away and resets to long range (once per combo).
public enum CoverTag: Sendable, Equatable { case none, strike, blast }

public enum Passive: Sendable, Equatable {
    case blastDiscount(Int)        // blast cards cost less Ki
    case vanishCrit                // after a successful vanish the next hit is a guaranteed crit
    case tenacity                  // the first lethal hit leaves 1 HP (once)
    case switchOutKi(Double)       // switching out gives the incoming teammate Ki
}

public struct FighterDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let nameEN: String
    public let nameZH: String
    public let roleZH: String
    public let element: Element
    public let maxHP: Double
    public let attack: Double
    public let defense: Double
    /// Seconds a hand slot takes to refill after a card is played.
    public let drawSpeed: Double
    public let deck: [ArtsCard]
    public let ultimate: ArtsCard
    public let ability: MainAbility
    public let cover: CoverTag
    public let passives: [Passive]

    public func has(_ p: Passive) -> Bool { passives.contains(p) }

    public var blastDiscount: Int {
        for p in passives { if case .blastDiscount(let n) = p { return n } }
        return 0
    }
}

/// Six original fighters (sci-fi martial artists) covering every element.
public enum FighterRoster {
    public static let all: [FighterDef] = [kai, nova, zero, lan, aegis, sera]

    public static func byID(_ id: String) -> FighterDef? { all.first { $0.id == id } }

    private static func strike(_ id: String, _ en: String, _ zh: String, _ p: Double, _ h: Int, armor: Bool = false) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .strike, power: p, hits: h, superArmor: armor)
    }
    private static func blast(_ id: String, _ en: String, _ zh: String, _ p: Double, _ h: Int, cost: Int? = nil) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .blast, cost: cost, power: p, hits: h)
    }
    private static func special(_ id: String, _ en: String, _ zh: String, _ p: Double, _ h: Int) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .special, power: p, hits: h)
    }
    private static func green(_ id: String, _ en: String, _ zh: String, _ e: SupportEffect, cost: Int = 20) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .support, cost: cost, power: 0, hits: 0, support: e)
    }
    private static func ult(_ id: String, _ en: String, _ zh: String, _ p: Double) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .ultimate, power: p, hits: 10)
    }

    public static let kai = FighterDef(
        id: "kai", nameEN: "Blazeblade Kai", nameZH: "炎刃·凯", roleZH: "近战爆发", element: .red,
        maxHP: 24000, attack: 2500, defense: 1050, drawSpeed: 0.9,
        deck: [strike("kai.s1", "Flare Rush", "烈焰连打", 1.1, 4), strike("kai.s2", "Ember Breaker", "余烬崩拳", 1.25, 3, armor: true),
               blast("kai.b1", "Cinder Shot", "炎弹", 1.0, 3), special("kai.sp", "Inferno Lance", "炼狱炎枪", 2.8, 6),
               green("kai.g", "Fire Charge", "火焰充能", .kiCharge(ki: 35, nextStrikeBonus: 0.25), cost: 15)],
        ultimate: ult("kai.ult", "Solar Cataclysm", "日轮天灾", 5.5),
        ability: .ultimateAndHeal(heal: 0.25), cover: .strike, passives: [])

    public static let nova = FighterDef(
        id: "nova", nameEN: "Thunder Nova", nameZH: "雷霆·诺瓦", roleZH: "远程压制", element: .yel,
        maxHP: 22500, attack: 2550, defense: 1000, drawSpeed: 0.85,
        deck: [strike("nova.s1", "Spark Jab", "电光刺拳", 0.95, 3), blast("nova.b1", "Volt Barrage", "雷电连射", 1.1, 4),
               blast("nova.b2", "Rail Shot", "电磁轨炮", 1.3, 2), special("nova.sp", "Storm Cannon", "风暴电炮", 2.9, 6),
               green("nova.g", "EM Shield", "电磁护盾", .shield(reduction: 0.4, duration: 8))],
        ultimate: ult("nova.ult", "Heaven Thunder", "九天雷罚", 5.3),
        ability: .blastHand(ki: 40), cover: .none, passives: [.blastDiscount(5)])

    public static let zero = FighterDef(
        id: "zero", nameEN: "Shadow Zero", nameZH: "影袭·零", roleZH: "敏捷刺客", element: .pur,
        maxHP: 21000, attack: 2600, defense: 950, drawSpeed: 0.75,
        deck: [strike("zero.s1", "Phantom Cuts", "幻影连斩", 1.05, 5), strike("zero.s2", "Night Fang", "夜牙", 1.2, 3),
               blast("zero.b1", "Void Needles", "虚空针", 0.9, 4), special("zero.sp", "Eclipse Edge", "蚀月之刃", 2.7, 7),
               green("zero.g", "Void Step", "虚空步", .vanishRefill(0.7), cost: 15)],
        ultimate: ult("zero.ult", "Thousand Shadows", "千影灭", 5.4),
        ability: .specialRush(fastDraw: 10), cover: .none, passives: [.vanishCrit])

    public static let lan = FighterDef(
        id: "lan", nameEN: "Gale Lan", nameZH: "疾风·岚", roleZH: "均衡辅助", element: .grn,
        maxHP: 23000, attack: 2350, defense: 1100, drawSpeed: 0.85,
        deck: [strike("lan.s1", "Wind Palm", "风掌", 1.0, 3), blast("lan.b1", "Gale Disc", "疾风轮", 1.05, 3),
               strike("lan.s2", "Cyclone Kick", "旋风腿", 1.15, 3), special("lan.sp", "Tempest Bloom", "暴风华", 2.6, 6),
               green("lan.g", "Healing Wind", "治愈之风", .teamHeal(0.15))],
        ultimate: ult("lan.ult", "Sky Requiem", "天籁镇魂", 5.0),
        ability: .rally(damage: 0.2), cover: .none, passives: [.switchOutKi(25)])

    public static let aegis = FighterDef(
        id: "aegis", nameEN: "Frostshield Aegis", nameZH: "霜盾·艾格", roleZH: "防御坦克", element: .blu,
        maxHP: 27000, attack: 2300, defense: 1250, drawSpeed: 1.0,
        deck: [strike("aegis.s1", "Glacier Fist", "冰川拳", 1.15, 3, armor: true), blast("aegis.b1", "Frost Volley", "霜弹", 1.0, 3),
               strike("aegis.s2", "Iceberg Slam", "冰山砸", 1.3, 2), special("aegis.sp", "Absolute Spear", "绝冰长枪", 2.7, 6),
               green("aegis.g", "Absolute Zero", "绝对零度", .freezeCounter(window: 2.5, stun: 2.0))],
        ultimate: ult("aegis.ult", "Permafrost", "永冻冰河", 5.2),
        ability: .fortress(heal: 0.35, armor: 10), cover: .blast, passives: [])

    public static let sera = FighterDef(
        id: "sera", nameEN: "Starlight Sera", nameZH: "星辉·塞拉", roleZH: "全能主角", element: .lgt,
        maxHP: 24500, attack: 2500, defense: 1100, drawSpeed: 0.85,
        deck: [strike("sera.s1", "Starfall Combo", "星落连击", 1.1, 4), blast("sera.b1", "Comet Shots", "彗星弹", 1.05, 3),
               strike("sera.s2", "Nova Knee", "新星膝撞", 1.2, 3), special("sera.sp", "Galaxy Ray", "银河光线", 2.85, 6),
               green("sera.g", "Ki Burst", "气功爆发", .kiBurst(ki: 25))],
        ultimate: ult("sera.ult", "Supernova Finale", "超新星终章", 5.6),
        ability: .transform(stats: 0.2, heal: 0.3), cover: .none, passives: [.tenacity])
}
