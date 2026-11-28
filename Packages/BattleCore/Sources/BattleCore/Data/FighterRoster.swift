/// Main ability: unlocks after `unlockTime` seconds, once per fighter per battle.
public struct MainAbility: Sendable, Equatable {
    public var unlockTime: Double
    public var drawUltimate = false
    public var heal = 0.0                 // fraction of max HP
    public var ki = 0.0
    public var purgeEnemyBuffs = false
    public var fillGauge = false
    public var enemySwitchDelay = 0.0     // seconds added to the opponent's switch cooldown
    public var fasterDraw = false         // draw speed +1 for the rest of the battle
    public var blastHand = false          // turn the whole hand into blast cards
    public var teamDamageUp = 0.0
    public var teamDamageDuration = 0.0
    public var transformStats = 0.0       // all stats up (transformation)

    public init(unlockTime: Double) { self.unlockTime = unlockTime }
}

/// Special cover tag: switching in during an opponent's card of this kind knocks the opponent away (once per combo).
public enum CoverTag: Sendable, Equatable { case none, strike, blast }

public enum Passive: Sendable, Equatable {
    case blastDiscount(Int)        // blast cards cost less Ki
    case vanishCrit                // after a successful vanish the next hit is a guaranteed crit
    case tenacity(heal: Double)    // Endurance: first lethal hit leaves 1 HP and heals a fraction (once)
    case switchOutKi(Double)       // switching out gives the incoming teammate Ki
    case coverDamageCut(Double)    // no special cover; cover changes take reduced damage instead
}

public struct FighterDef: Sendable, Equatable, Identifiable {
    public let id: String
    public let nameEN: String
    public let nameZH: String
    public let roleZH: String
    public let rarity: Rarity
    public let element: Element
    public let tags: [Tag]
    /// Stats at Lv.5000 / 7★ (the brief's benchmark); Lv.1 / 1★ base is derived from it.
    public let benchmark: StatBlock
    /// Seconds a hand slot takes to refill after a card is played.
    public let drawSpeed: Double
    public let deck: [ArtsCard]
    public let ultimate: ArtsCard
    public let ability: MainAbility
    public let cover: CoverTag
    public let gauge: UniqueGaugeType?
    public let zAbility: ZAbility
    public let passives: [Passive]

    public func has(_ p: Passive) -> Bool { passives.contains(p) }

    public var blastDiscount: Int {
        for p in passives { if case .blastDiscount(let n) = p { return n } }
        return 0
    }

    public var tenacityHeal: Double? {
        for p in passives { if case .tenacity(let h) = p { return h } }
        return nil
    }

    /// Lv.1 / 1★ base stats: benchmark ÷ (level factor 10 × star factor 1.18).
    public var baseLv1: StatBlock { benchmark.scaled(1 / (Progression.levelFactor(5000) * Progression.starFactor(7))) }

    /// Benchmark HP (Lv.5000 / 7★) — convenience for UI and tests.
    public var maxHP: Double { benchmark.hp }
}

/// Six original fighters: 2 UL, 2 LL (Legendary Finish), 2 SP — one per element.
public enum FighterRoster {
    public static let all: [FighterDef] = [kross, sephi, kai, nova, lan, sera]

    public static func byID(_ id: String) -> FighterDef? { all.first { $0.id == id } }

    private static func strike(_ id: String, _ en: String, _ zh: String, _ p: Double = 1.1, _ h: Int = 4, armor: Bool = false) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .strike, power: p, hits: h, superArmor: armor)
    }
    private static func blast(_ id: String, _ en: String, _ zh: String, _ p: Double = 1.2, _ h: Int = 6) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .blast, power: p, hits: h)
    }
    private static func special(_ id: String, _ en: String, _ zh: String, _ p: Double = 3.0, _ h: Int = 8) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .special, power: p, hits: h)
    }
    private static func green(_ id: String, _ en: String, _ zh: String, _ e: SupportEffect, cost: Int = 20) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .support, cost: cost, power: 0, hits: 0, support: e)
    }
    private static func ult(_ id: String, _ en: String, _ zh: String, _ p: Double = 5.0) -> ArtsCard {
        ArtsCard(id: id, en: en, zh: zh, kind: .ultimate, power: p, hits: 10)
    }

    private static func ability(_ t: Double, _ build: (inout MainAbility) -> Void) -> MainAbility {
        var a = MainAbility(unlockTime: t)
        build(&a)
        return a
    }

    public static let kross = FighterDef(
        id: "kross", nameEN: "Star God Kross", nameZH: "星神·克洛斯", roleZH: "究极近战", rarity: .ul, element: .red,
        tags: [.starWarrior, .ultimateForm, .melee],
        benchmark: StatBlock(hp: 2_650_000, strikeAtk: 275_000, blastAtk: 235_000, defense: 175_000), drawSpeed: 0.85,
        deck: [strike("kross.s1", "Star Fist Barrage", "星拳连打"), strike("kross.s2", "Crimson Knee", "赤红膝撞", 1.2),
               blast("kross.b1", "Nova Spread", "新星散弹"), special("kross.sp", "Crimson Lotus Slash", "红莲斩", 3.2),
               green("kross.g", "Star Command", "星神号令", .kiCoverNull(ki: 30, duration: 10))],
        ultimate: ult("kross.ult", "Star Core Annihilation", "星核终焉爆", 5.6),
        ability: ability(25) { $0.drawUltimate = true; $0.heal = 0.3; $0.purgeEnemyBuffs = true },
        cover: .strike, gauge: .counter, zAbility: ZAbility(tag: .starWarrior, tiers: [0.20, 0.24, 0.27, 0.30]), passives: [])

    public static let sephi = FighterDef(
        id: "sephi", nameEN: "Aurora Sephi", nameZH: "极光·瑟菲", roleZH: "灵能远程", rarity: .ul, element: .blu,
        tags: [.starWarrior, .psychic, .ranged],
        benchmark: StatBlock(hp: 2_580_000, strikeAtk: 240_000, blastAtk: 282_000, defense: 172_000), drawSpeed: 0.85,
        deck: [strike("sephi.s1", "Aurora Palm", "极光掌", 1.0), blast("sephi.b1", "Prism Rain", "棱光雨"),
               blast("sephi.b2", "Star Needles", "星针", 1.3), special("sephi.sp", "Aurora Star-Piercer", "极光贯星炮", 3.1),
               green("sephi.g", "Gravity Field", "重力领域", .gravityBind(duration: 2.0))],
        ultimate: ult("sephi.ult", "Heaven-Splitting Slash", "苍穹裂界斩", 5.5),
        ability: ability(25) { $0.drawUltimate = true; $0.fillGauge = true; $0.enemySwitchDelay = 3 },
        cover: .blast, gauge: .autoEvade, zAbility: ZAbility(tag: .psychic, tiers: [0.20, 0.24, 0.27, 0.30]), passives: [])

    public static let kai = FighterDef(
        id: "kai", nameEN: "Blazeblade Kai", nameZH: "炎刃·凯", roleZH: "烈焰爆发", rarity: .ll, element: .pur,
        tags: [.starWarrior, .flame, .burst],
        benchmark: StatBlock(hp: 2_480_000, strikeAtk: 262_000, blastAtk: 245_000, defense: 166_000), drawSpeed: 0.85,
        deck: [strike("kai.s1", "Flame Fang Barrage", "炎牙连斩", 1.1, 4, armor: true), strike("kai.s2", "Ember Breaker", "余烬崩拳", 1.2),
               blast("kai.b1", "Cinder Shot", "炎弹"), special("kai.sp", "Burst Dragon Fang", "爆裂龙牙突", 3.0),
               green("kai.g", "Flame Charge", "烈焰充能", .kiCharge(ki: 35, nextStrikeBonus: 0.3), cost: 15)],
        ultimate: ult("kai.ult", "Blazing Meteor Slash", "炽星流星斩", 5.4),
        ability: ability(20) { $0.drawUltimate = true; $0.heal = 0.25; $0.fasterDraw = true },
        cover: .strike, gauge: .attack, zAbility: ZAbility(tag: .flame, tiers: [0.18, 0.22, 0.25, 0.28]), passives: [])

    public static let nova = FighterDef(
        id: "nova", nameEN: "Thunder Nova", nameZH: "雷霆·诺瓦", roleZH: "雷霆压制", rarity: .ll, element: .yel,
        tags: [.mechWarrior, .thunder, .suppression],
        benchmark: StatBlock(hp: 2_450_000, strikeAtk: 238_000, blastAtk: 268_000, defense: 168_000), drawSpeed: 0.85,
        deck: [strike("nova.s1", "Spark Jab", "电光刺拳", 1.0), blast("nova.b1", "Volt Barrage", "雷电连射"),
               blast("nova.b2", "Rail Shot", "电磁轨炮", 1.3), special("nova.sp", "High-Voltage Railgun", "高压磁轨炮", 3.1),
               green("nova.g", "EM Pulse", "电磁脉冲", .freezeCounter(window: 2.5, stun: 2.0))],
        ultimate: ult("nova.ult", "Thousand-Thunder Matrix", "千雷裁决矩阵", 5.4),
        ability: ability(20) { $0.drawUltimate = true; $0.blastHand = true; $0.ki = 45 },
        cover: .blast, gauge: .release, zAbility: ZAbility(tag: .mechWarrior, tiers: [0.18, 0.22, 0.25, 0.28]), passives: [])

    public static let lan = FighterDef(
        id: "lan", nameEN: "Gale Lan", nameZH: "疾风·岚", roleZH: "均衡辅助", rarity: .sp, element: .grn,
        tags: [.starWarrior, .support],
        benchmark: StatBlock(hp: 2_420_000, strikeAtk: 232_000, blastAtk: 230_000, defense: 164_000), drawSpeed: 0.85,
        deck: [strike("lan.s1", "Wind Palm", "风掌", 1.0), strike("lan.s2", "Cyclone Kick", "旋风腿", 1.15),
               blast("lan.b1", "Gale Disc", "疾风轮"), special("lan.sp", "Cyclone Combo Wave", "旋风连击波", 2.8),
               green("lan.g", "Healing Wind", "治愈之风", .teamHeal(0.15))],
        ultimate: ult("lan.ult", "Sky Requiem", "天籁镇魂", 4.8),
        ability: ability(15) { $0.teamDamageUp = 0.25; $0.teamDamageDuration = 20 },
        cover: .none, gauge: nil, zAbility: ZAbility(tag: .support, tiers: [0.14, 0.17, 0.20, 0.22]),
        passives: [.switchOutKi(30), .coverDamageCut(0.35)])

    public static let sera = FighterDef(
        id: "sera", nameEN: "Starlight Sera", nameZH: "星辉·塞拉", roleZH: "全能主角", rarity: .sp, element: .lgt,
        tags: [.starWarrior, .protagonist],
        benchmark: StatBlock(hp: 2_500_000, strikeAtk: 248_000, blastAtk: 248_000, defense: 169_000), drawSpeed: 0.85,
        deck: [strike("sera.s1", "Starfall Combo", "星落连击"), strike("sera.s2", "Nova Knee", "新星膝撞", 1.2),
               blast("sera.b1", "Comet Shots", "彗星弹"), special("sera.sp", "Starlight Impact", "星辉冲击波", 3.0),
               green("sera.g", "Ki Burst", "气功爆发", .kiBurst(ki: 30))],
        ultimate: ult("sera.ult", "Supernova Finale", "超新星终章", 5.0),
        ability: ability(15) { $0.transformStats = 0.2; $0.heal = 0.3; $0.ki = 40 },
        cover: .strike, gauge: nil, zAbility: ZAbility(tag: .starWarrior, tiers: [0.14, 0.17, 0.20, 0.22]),
        passives: [.tenacity(heal: 0.25)])
}
