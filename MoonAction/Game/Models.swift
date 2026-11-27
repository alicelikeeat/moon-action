import UIKit

// MARK: - Cards

enum CardKind {
    case strike     // 拳击: dash forward and attack in melee
    case blast      // 射击: ranged energy shots
    case special    // 必杀: fighter-specific cinematic art
    case ultimate   // 究极: unlocked by the ultimate gauge
    case effect     // 特殊卡: heal / barrier / buff / debuff
    case eclipse    // 合击: team finisher from 7 moon shards
}

enum CardEffect {
    case heal(Double)        // fraction of max HP
    case barrier(Double)     // seconds of 60% damage reduction
    case powerUp(Double)     // seconds of +30% attack
    case energy(Double)      // instant energy
    case curse(Double)       // seconds of -30% enemy defense
}

struct Card {
    let id: String
    let name: Text
    let kind: CardKind
    let cost: Int
    let power: Double
    let hits: Int
    var effect: CardEffect? = nil
}

enum SpecialStyle { case beam, rush, volley }
enum UltimateStyle { case beam, meteor }

/// Teleport speed class: drives dash speed, evade travel time, invulnerability and perfect-evade window.
enum SpeedClass {
    case fast, medium, slow

    var dashSpeed: Float { self == .fast ? 32 : (self == .medium ? 24 : 18) }
    var vanishTime: Double { self == .fast ? 0.06 : (self == .medium ? 0.11 : 0.17) }
    var invuln: Double { self == .fast ? 0.36 : (self == .medium ? 0.42 : 0.5) }
    var perfectWindow: Double { self == .fast ? 0.2 : (self == .medium ? 0.17 : 0.14) }
    var label: String { L(self == .fast ? "speed.fast" : (self == .medium ? "speed.medium" : "speed.slow")) }
    var icon: String { self == .fast ? "hare.fill" : (self == .medium ? "figure.run" : "tortoise.fill") }
}

/// Parameters for the procedural 3D model (see FighterModel / MeshKit).
struct Look {
    var primary: UIColor
    var secondary: UIColor
    var accent: UIColor
    var hair: UIColor
    var skin: UIColor
    var eyes: UIColor
    var aura: UIColor
    var hairStyle: Int
    var height: Float = 1
    var bulk: Float = 1
    var sleeves: Int = 1          // 0 none, 1 short, 2 long
    var coat: Bool = false
    var scarf: Bool = false
    var shoulderPads: Bool = false
    var gloves: Bool = false
    var cape: Bool = false
    var headband: Bool = false
}

/// All fighters, names, looks and moves in Moon Action are original creations.
struct FighterDef {
    let id: String
    let name: Text
    let title: Text
    let rarity: Int
    let speed: SpeedClass
    let look: Look
    let hp: Double
    let atk: Double
    let defense: Double
    let cards: [Card]
    let effectCard: Card
    let specialName: Text
    let specialStyle: SpecialStyle
    let specialPower: Double
    let ultimateName: Text
    let ultimateStyle: UltimateStyle
    let ultimatePower: Double

    var aura: UIColor { look.aura }
    var shortName: String { L10n.isZH ? name.zh.components(separatedBy: "·").first ?? name.zh : name.en.components(separatedBy: " ").first ?? name.en }

    var specialCard: Card {
        Card(id: id + ".sp", name: specialName, kind: .special, cost: 40, power: specialPower, hits: specialStyle == .rush ? 7 : 6)
    }

    var ultimateCard: Card {
        Card(id: id + ".ult", name: ultimateName, kind: .ultimate, cost: 0, power: ultimatePower, hits: 8)
    }

    /// Fresh shuffled deck: 2× each basic art, 1 special art, 1 effect card.
    func makeDeck() -> [Card] {
        (cards + cards + [specialCard, effectCard]).shuffled()
    }
}

private func c(_ hex: UInt32) -> UIColor { UIColor(hex: hex) }

enum Roster {
    static let all: [FighterDef] = [kai, luna, rook, ivy, nyx, blaze, mira, taro, zephyr, sable, orion, kira, drake, aria, bram, vex, rin, juno, kael, nova]

    static func byID(_ id: String) -> FighterDef { all.first { $0.id == id } ?? kai }

    static let eclipseCard = Card(id: "eclipse", name: Text("Eclipse Rush", "月蚀突袭"), kind: .eclipse, cost: 0, power: 4.2, hits: 9)

    static let kai = FighterDef(
        id: "kai", name: Text("Kai Solaris", "凯·索拉里斯"), title: Text("Dawn Brawler", "黎明斗士"), rarity: 2, speed: .medium,
        look: Look(primary: c(0xF2F4F8), secondary: c(0x1F8A8A), accent: c(0x2B2D3A), hair: c(0xC93A2C), skin: c(0xF1C7A1),
                   eyes: c(0x1E6B8F), aura: c(0xFFB347), hairStyle: 0, height: 1.0, bulk: 1.0, sleeves: 1,
                   coat: false, scarf: true, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 24000, atk: 2400, defense: 1100,
        cards: [
            Card(id: "kai.0", name: Text("Sunrise Jab", "旭日连拳"), kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(id: "kai.1", name: Text("Solar Knee", "烈阳膝撞"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "kai.2", name: Text("Flare Shot", "耀斑弹"), kind: .blast, cost: 20, power: 0.95, hits: 1),
            Card(id: "kai.3", name: Text("Corona Spread", "日冕散射"), kind: .blast, cost: 30, power: 1.35, hits: 3),
        ],
        effectCard: Card(id: "kai.fx", name: Text("Rising Focus", "旭升集中"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .powerUp(10)),
        specialName: Text("Daybreak Cannon", "破晓炮"), specialStyle: .beam, specialPower: 2.7,
        ultimateName: Text("Zenith Sunburst", "天顶日爆"), ultimateStyle: .beam, ultimatePower: 5.0)

    static let luna = FighterDef(
        id: "luna", name: Text("Luna Vey", "露娜·薇"), title: Text("Moonblade Dancer", "月刃舞者"), rarity: 2, speed: .fast,
        look: Look(primary: c(0x3A2D7A), secondary: c(0xB8C0D8), accent: c(0xD9C27A), hair: c(0xDAD4F5), skin: c(0xF6D7C3),
                   eyes: c(0x7A4FD6), aura: c(0xB18CFF), hairStyle: 1, height: 0.95, bulk: 0.9, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 22500, atk: 2500, defense: 1050,
        cards: [
            Card(id: "luna.0", name: Text("Crescent Cut", "新月斩"), kind: .strike, cost: 20, power: 1.05, hits: 3),
            Card(id: "luna.1", name: Text("Tidal Step", "潮汐步"), kind: .strike, cost: 30, power: 1.4, hits: 4),
            Card(id: "luna.2", name: Text("Silver Needle", "银针"), kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(id: "luna.3", name: Text("Night Petals", "夜之花瓣"), kind: .blast, cost: 30, power: 1.3, hits: 3),
        ],
        effectCard: Card(id: "luna.fx", name: Text("Moonveil", "月纱护幕"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(8)),
        specialName: Text("Eclipse Waltz", "月蚀圆舞"), specialStyle: .rush, specialPower: 2.8,
        ultimateName: Text("Silver Tide", "银色潮汐"), ultimateStyle: .meteor, ultimatePower: 4.9)

    static let rook = FighterDef(
        id: "rook", name: Text("Rook Thunderhart", "洛克·雷心"), title: Text("Storm Knuckle", "风暴铁拳"), rarity: 2, speed: .slow,
        look: Look(primary: c(0xE5B93C), secondary: c(0x23252E), accent: c(0x3A6FD8), hair: c(0x24418F), skin: c(0xC98E62),
                   eyes: c(0x2A9BD8), aura: c(0x5CE1FF), hairStyle: 2, height: 1.1, bulk: 1.25, sleeves: 0,
                   coat: false, scarf: false, shoulderPads: true,
                   gloves: true, cape: false, headband: false),
        hp: 27500, atk: 2300, defense: 1300,
        cards: [
            Card(id: "rook.0", name: Text("Iron Hook", "钢铁勾拳"), kind: .strike, cost: 20, power: 1.1, hits: 2),
            Card(id: "rook.1", name: Text("Quake Stomp", "震地踏"), kind: .strike, cost: 30, power: 1.55, hits: 3),
            Card(id: "rook.2", name: Text("Spark Toss", "电光投"), kind: .blast, cost: 20, power: 0.9, hits: 1),
            Card(id: "rook.3", name: Text("Static Hail", "静电冰雹"), kind: .blast, cost: 30, power: 1.35, hits: 4),
        ],
        effectCard: Card(id: "rook.fx", name: Text("Iron Will", "钢铁意志"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(10)),
        specialName: Text("Thunderclap Rush", "雷鸣连打"), specialStyle: .rush, specialPower: 2.9,
        ultimateName: Text("Skybreaker Bolt", "裂空雷霆"), ultimateStyle: .meteor, ultimatePower: 4.9)

    static let ivy = FighterDef(
        id: "ivy", name: Text("Ivy Thorne", "艾薇·索恩"), title: Text("Verdant Warden", "翠林守望者"), rarity: 2, speed: .medium,
        look: Look(primary: c(0x2E7D4F), secondary: c(0x6B4F2A), accent: c(0xE0C36A), hair: c(0x7FD35B), skin: c(0xEBC2A0),
                   eyes: c(0x2F9E5A), aura: c(0x9BFF6A), hairStyle: 3, height: 0.96, bulk: 0.92, sleeves: 1,
                   coat: false, scarf: true, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 23000, atk: 2350, defense: 1200,
        cards: [
            Card(id: "ivy.0", name: Text("Bramble Kick", "荆棘踢"), kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(id: "ivy.1", name: Text("Oak Palm", "橡木掌"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "ivy.2", name: Text("Seed Burst", "种子爆发"), kind: .blast, cost: 20, power: 1.05, hits: 3),
            Card(id: "ivy.3", name: Text("Pollen Comet", "花粉彗星"), kind: .blast, cost: 30, power: 1.35, hits: 1),
        ],
        effectCard: Card(id: "ivy.fx", name: Text("Verdant Bloom", "翠绿绽放"), kind: .effect, cost: 30, power: 0, hits: 0, effect: .heal(0.18)),
        specialName: Text("Thorn Storm", "荆棘风暴"), specialStyle: .volley, specialPower: 2.7,
        ultimateName: Text("World Root Bloom", "世界树之花"), ultimateStyle: .meteor, ultimatePower: 5.0)

    static let nyx = FighterDef(
        id: "nyx", name: Text("Nyx Obsidian", "尼克斯·黑曜"), title: Text("Void Walker", "虚空行者"), rarity: 3, speed: .fast,
        look: Look(primary: c(0x1F1D2B), secondary: c(0x8E1B3A), accent: c(0xC7B3FF), hair: c(0xF0F0F5), skin: c(0xD9B8A5),
                   eyes: c(0xD04CFF), aura: c(0xD04CFF), hairStyle: 4, height: 1.04, bulk: 0.95, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: false,
                   gloves: true, cape: false, headband: false),
        hp: 22000, atk: 2700, defense: 1050,
        cards: [
            Card(id: "nyx.0", name: Text("Shade Fang", "暗影獠牙"), kind: .strike, cost: 20, power: 1.1, hits: 3),
            Card(id: "nyx.1", name: Text("Rift Lunge", "裂隙突刺"), kind: .strike, cost: 30, power: 1.45, hits: 2),
            Card(id: "nyx.2", name: Text("Null Orb", "虚无球"), kind: .blast, cost: 20, power: 1.05, hits: 1),
            Card(id: "nyx.3", name: Text("Gravity Rain", "重力之雨"), kind: .blast, cost: 30, power: 1.45, hits: 4),
        ],
        effectCard: Card(id: "nyx.fx", name: Text("Null Curse", "虚无诅咒"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .curse(10)),
        specialName: Text("Abyss Lance", "深渊长枪"), specialStyle: .beam, specialPower: 3.0,
        ultimateName: Text("Event Horizon", "事件视界"), ultimateStyle: .beam, ultimatePower: 5.4)

    static let blaze = FighterDef(
        id: "blaze", name: Text("Blaze Ardent", "布雷兹·炽焰"), title: Text("Ember Fist", "余烬之拳"), rarity: 3, speed: .medium,
        look: Look(primary: c(0xB22222), secondary: c(0x30302F), accent: c(0xFFB000), hair: c(0xFF8C1A), skin: c(0xE3B08A),
                   eyes: c(0xE0531F), aura: c(0xFF5A1F), hairStyle: 5, height: 1.05, bulk: 1.1, sleeves: 0,
                   coat: false, scarf: false, shoulderPads: true,
                   gloves: false, cape: false, headband: false),
        hp: 25000, atk: 2600, defense: 1120,
        cards: [
            Card(id: "blaze.0", name: Text("Cinder Combo", "余烬连击"), kind: .strike, cost: 20, power: 1.05, hits: 4),
            Card(id: "blaze.1", name: Text("Magma Uppercut", "熔岩上勾拳"), kind: .strike, cost: 30, power: 1.55, hits: 2),
            Card(id: "blaze.2", name: Text("Ember Dart", "火星镖"), kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(id: "blaze.3", name: Text("Wildfire", "燎原之火"), kind: .blast, cost: 30, power: 1.45, hits: 3),
        ],
        effectCard: Card(id: "blaze.fx", name: Text("Kindle", "点燃"), kind: .effect, cost: 0, power: 0, hits: 0, effect: .energy(35)),
        specialName: Text("Inferno Combo", "炼狱连打"), specialStyle: .rush, specialPower: 2.9,
        ultimateName: Text("Phoenix Meteor", "凤凰陨星"), ultimateStyle: .meteor, ultimatePower: 5.2)

    static let mira = FighterDef(
        id: "mira", name: Text("Mira Frost", "米拉·霜语"), title: Text("Glacier Sage", "冰川贤者"), rarity: 2, speed: .slow,
        look: Look(primary: c(0xE8F4FF), secondary: c(0x2C5F8A), accent: c(0x8FD8FF), hair: c(0x9ED8F0), skin: c(0xF3D6C6),
                   eyes: c(0x3AA0E0), aura: c(0x8FE3FF), hairStyle: 6, height: 0.97, bulk: 0.95, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 26000, atk: 2250, defense: 1250,
        cards: [
            Card(id: "mira.0", name: Text("Frost Palm", "霜掌"), kind: .strike, cost: 20, power: 1.0, hits: 2),
            Card(id: "mira.1", name: Text("Icicle Knee", "冰锥膝"), kind: .strike, cost: 30, power: 1.4, hits: 3),
            Card(id: "mira.2", name: Text("Snow Lance", "雪之矛"), kind: .blast, cost: 20, power: 1.0, hits: 1),
            Card(id: "mira.3", name: Text("Hail Spiral", "冰雹螺旋"), kind: .blast, cost: 30, power: 1.4, hits: 4),
        ],
        effectCard: Card(id: "mira.fx", name: Text("Ice Mirror", "冰镜之壁"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(9)),
        specialName: Text("Glacial Ray", "冰河射线"), specialStyle: .beam, specialPower: 2.8,
        ultimateName: Text("Absolute Winter", "绝对寒冬"), ultimateStyle: .meteor, ultimatePower: 5.0)

    static let taro = FighterDef(
        id: "taro", name: Text("Taro Ironwood", "太郎·铁木"), title: Text("Mountain Monk", "山岳武僧"), rarity: 2, speed: .slow,
        look: Look(primary: c(0xC46A2A), secondary: c(0x5A3A22), accent: c(0x2E2E2E), hair: c(0x2A2522), skin: c(0xD9A27A),
                   eyes: c(0x3A2A1A), aura: c(0xFFC46B), hairStyle: 10, height: 1.08, bulk: 1.2, sleeves: 0,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: true),
        hp: 28000, atk: 2250, defense: 1350,
        cards: [
            Card(id: "taro.0", name: Text("Boulder Fist", "巨岩拳"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "taro.1", name: Text("Hundred Palms", "百裂掌"), kind: .strike, cost: 30, power: 1.5, hits: 5),
            Card(id: "taro.2", name: Text("Ki Pebble", "气之石"), kind: .blast, cost: 20, power: 0.9, hits: 2),
            Card(id: "taro.3", name: Text("Mountain Echo", "山之回响"), kind: .blast, cost: 30, power: 1.3, hits: 1),
        ],
        effectCard: Card(id: "taro.fx", name: Text("Inner Calm", "内心平静"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .heal(0.16)),
        specialName: Text("Avalanche Rush", "雪崩连打"), specialStyle: .rush, specialPower: 3.0,
        ultimateName: Text("Heaven Peak Drop", "天峰坠"), ultimateStyle: .meteor, ultimatePower: 5.0)

    static let zephyr = FighterDef(
        id: "zephyr", name: Text("Zephyr Gale", "泽菲尔·疾风"), title: Text("Sky Courier", "天空信使"), rarity: 2, speed: .fast,
        look: Look(primary: c(0x7ED6A8), secondary: c(0x2D4A5A), accent: c(0xF2F2F2), hair: c(0x2FA4A0), skin: c(0xF0C8A8),
                   eyes: c(0x1D8F8A), aura: c(0x7FFFD4), hairStyle: 9, height: 0.98, bulk: 0.92, sleeves: 1,
                   coat: false, scarf: true, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 22500, atk: 2450, defense: 1080,
        cards: [
            Card(id: "zephyr.0", name: Text("Gust Jab", "阵风刺拳"), kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(id: "zephyr.1", name: Text("Cyclone Kick", "旋风踢"), kind: .strike, cost: 30, power: 1.35, hits: 3),
            Card(id: "zephyr.2", name: Text("Wind Shear", "风切"), kind: .blast, cost: 20, power: 1.05, hits: 2),
            Card(id: "zephyr.3", name: Text("Tempest Bolt", "暴风弹"), kind: .blast, cost: 30, power: 1.35, hits: 3),
        ],
        effectCard: Card(id: "zephyr.fx", name: Text("Tailwind", "顺风"), kind: .effect, cost: 0, power: 0, hits: 0, effect: .energy(30)),
        specialName: Text("Gale Barrage", "疾风乱射"), specialStyle: .volley, specialPower: 2.7,
        ultimateName: Text("Sky Sunder", "断空"), ultimateStyle: .beam, ultimatePower: 5.0)

    static let sable = FighterDef(
        id: "sable", name: Text("Sable Quinn", "赛博·奎因"), title: Text("Shadow Fox", "影狐"), rarity: 3, speed: .fast,
        look: Look(primary: c(0x5A1A2A), secondary: c(0x1A1A20), accent: c(0xE04A5A), hair: c(0x1E1A1E), skin: c(0xF2D0BA),
                   eyes: c(0xE04A5A), aura: c(0xFF4A6A), hairStyle: 7, height: 0.95, bulk: 0.9, sleeves: 2,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: true, cape: false, headband: false),
        hp: 21500, atk: 2750, defense: 1000,
        cards: [
            Card(id: "sable.0", name: Text("Fox Fang", "狐牙"), kind: .strike, cost: 20, power: 1.1, hits: 3),
            Card(id: "sable.1", name: Text("Silent Step", "无声步"), kind: .strike, cost: 30, power: 1.45, hits: 4),
            Card(id: "sable.2", name: Text("Shadow Kunai", "影苦无"), kind: .blast, cost: 20, power: 1.0, hits: 3),
            Card(id: "sable.3", name: Text("Crimson Moon", "赤月"), kind: .blast, cost: 30, power: 1.4, hits: 1),
        ],
        effectCard: Card(id: "sable.fx", name: Text("Fox Hex", "狐之咒"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .curse(10)),
        specialName: Text("Nine Tails Dance", "九尾之舞"), specialStyle: .rush, specialPower: 3.0,
        ultimateName: Text("Shadow Eclipse", "影之月蚀"), ultimateStyle: .beam, ultimatePower: 5.3)

    static let orion = FighterDef(
        id: "orion", name: Text("Orion Vale", "奥利安·维尔"), title: Text("Star Lancer", "星枪骑士"), rarity: 3, speed: .medium,
        look: Look(primary: c(0x1E2C5A), secondary: c(0xC9A227), accent: c(0xE8E8F0), hair: c(0x2C3E7A), skin: c(0xF0C8A8),
                   eyes: c(0x4A7AE0), aura: c(0x7FA8FF), hairStyle: 4, height: 1.06, bulk: 1.05, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: true,
                   gloves: false, cape: false, headband: false),
        hp: 25500, atk: 2600, defense: 1180,
        cards: [
            Card(id: "orion.0", name: Text("Comet Thrust", "彗星突刺"), kind: .strike, cost: 20, power: 1.1, hits: 2),
            Card(id: "orion.1", name: Text("Orbit Sweep", "轨道横扫"), kind: .strike, cost: 30, power: 1.45, hits: 3),
            Card(id: "orion.2", name: Text("Star Shard", "星之碎片"), kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(id: "orion.3", name: Text("Nebula Shot", "星云弹"), kind: .blast, cost: 30, power: 1.4, hits: 1),
        ],
        effectCard: Card(id: "orion.fx", name: Text("Starlight Oath", "星光誓约"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .powerUp(10)),
        specialName: Text("Constellation Lance", "星座之枪"), specialStyle: .beam, specialPower: 2.9,
        ultimateName: Text("Supernova Fall", "超新星坠落"), ultimateStyle: .meteor, ultimatePower: 5.3)

    static let kira = FighterDef(
        id: "kira", name: Text("Kira Bloom", "绮拉·花绽"), title: Text("Petal Striker", "花瓣突击手"), rarity: 2, speed: .fast,
        look: Look(primary: c(0xF7F2F7), secondary: c(0xE86A9A), accent: c(0xF7C6D9), hair: c(0xF28AB2), skin: c(0xF6D7C3),
                   eyes: c(0xD8467A), aura: c(0xFF8AC0), hairStyle: 7, height: 0.93, bulk: 0.88, sleeves: 1,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 21800, atk: 2450, defense: 1050,
        cards: [
            Card(id: "kira.0", name: Text("Petal Flurry", "花瓣乱舞"), kind: .strike, cost: 20, power: 1.0, hits: 4),
            Card(id: "kira.1", name: Text("Blossom Kick", "绽放踢"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "kira.2", name: Text("Sakura Shot", "樱花弹"), kind: .blast, cost: 20, power: 1.0, hits: 3),
            Card(id: "kira.3", name: Text("Pollen Burst", "花粉爆"), kind: .blast, cost: 30, power: 1.35, hits: 2),
        ],
        effectCard: Card(id: "kira.fx", name: Text("Spring Rain", "春雨"), kind: .effect, cost: 30, power: 0, hits: 0, effect: .heal(0.18)),
        specialName: Text("Thousand Petals", "千瓣风暴"), specialStyle: .volley, specialPower: 2.7,
        ultimateName: Text("Eternal Bloom", "永恒绽放"), ultimateStyle: .meteor, ultimatePower: 4.9)

    static let drake = FighterDef(
        id: "drake", name: Text("Drake Cinder", "德雷克·灰烬"), title: Text("Dragon Scale", "龙鳞战士"), rarity: 3, speed: .slow,
        look: Look(primary: c(0x2E5E3E), secondary: c(0x1E1E1E), accent: c(0xC9A227), hair: c(0xD23A2A), skin: c(0xD9A27A),
                   eyes: c(0xE0A020), aura: c(0xFF7A3A), hairStyle: 8, height: 1.12, bulk: 1.25, sleeves: 0,
                   coat: false, scarf: false, shoulderPads: true,
                   gloves: true, cape: false, headband: false),
        hp: 28500, atk: 2550, defense: 1300,
        cards: [
            Card(id: "drake.0", name: Text("Scale Smash", "龙鳞粉碎"), kind: .strike, cost: 20, power: 1.2, hits: 2),
            Card(id: "drake.1", name: Text("Tail Whip", "龙尾鞭"), kind: .strike, cost: 30, power: 1.55, hits: 3),
            Card(id: "drake.2", name: Text("Dragon Breath", "龙息"), kind: .blast, cost: 20, power: 1.0, hits: 1),
            Card(id: "drake.3", name: Text("Ember Scales", "余烬龙鳞"), kind: .blast, cost: 30, power: 1.4, hits: 3),
        ],
        effectCard: Card(id: "drake.fx", name: Text("Dragon Hide", "龙之皮甲"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(10)),
        specialName: Text("Wyrm Rampage", "巨龙狂暴"), specialStyle: .rush, specialPower: 3.1,
        ultimateName: Text("Dragonfire Nova", "龙炎新星"), ultimateStyle: .beam, ultimatePower: 5.3)

    static let aria = FighterDef(
        id: "aria", name: Text("Aria Lux", "艾莉亚·辉光"), title: Text("Radiant Herald", "光辉先驱"), rarity: 3, speed: .medium,
        look: Look(primary: c(0xF5F3EA), secondary: c(0x8A7DD8), accent: c(0xF2D27A), hair: c(0xF6D2B0), skin: c(0xF6D7C3),
                   eyes: c(0xC08A2A), aura: c(0xFFF0A8), hairStyle: 1, height: 0.97, bulk: 0.9, sleeves: 2,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: false, cape: true, headband: false),
        hp: 23500, atk: 2500, defense: 1150,
        cards: [
            Card(id: "aria.0", name: Text("Halo Strike", "光环击"), kind: .strike, cost: 20, power: 1.05, hits: 3),
            Card(id: "aria.1", name: Text("Dawn Arc", "晨曦弧"), kind: .strike, cost: 30, power: 1.4, hits: 3),
            Card(id: "aria.2", name: Text("Light Arrow", "光之箭"), kind: .blast, cost: 20, power: 1.05, hits: 2),
            Card(id: "aria.3", name: Text("Prism Rain", "棱镜之雨"), kind: .blast, cost: 30, power: 1.4, hits: 4),
        ],
        effectCard: Card(id: "aria.fx", name: Text("Sanctuary", "圣域"), kind: .effect, cost: 30, power: 0, hits: 0, effect: .heal(0.2)),
        specialName: Text("Radiant Spear", "辉光圣枪"), specialStyle: .beam, specialPower: 2.8,
        ultimateName: Text("Heaven's Verdict", "天之审判"), ultimateStyle: .beam, ultimatePower: 5.2)

    static let bram = FighterDef(
        id: "bram", name: Text("Bram Stonejaw", "布拉姆·石颚"), title: Text("Granite Guard", "花岗守卫"), rarity: 2, speed: .slow,
        look: Look(primary: c(0x6A6F78), secondary: c(0x3A2E26), accent: c(0xB08A5A), hair: c(0x8A8F98), skin: c(0xC98E62),
                   eyes: c(0x5A6A7A), aura: c(0xC8B48A), hairStyle: 2, height: 1.12, bulk: 1.3, sleeves: 1,
                   coat: false, scarf: false, shoulderPads: true,
                   gloves: true, cape: false, headband: false),
        hp: 29000, atk: 2200, defense: 1400,
        cards: [
            Card(id: "bram.0", name: Text("Rock Crusher", "碎岩拳"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "bram.1", name: Text("Granite Slam", "花岗重击"), kind: .strike, cost: 30, power: 1.5, hits: 2),
            Card(id: "bram.2", name: Text("Pebble Shot", "碎石弹"), kind: .blast, cost: 20, power: 0.9, hits: 3),
            Card(id: "bram.3", name: Text("Landslide", "山崩"), kind: .blast, cost: 30, power: 1.3, hits: 1),
        ],
        effectCard: Card(id: "bram.fx", name: Text("Stone Skin", "石肤"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(10)),
        specialName: Text("Earthshaker", "撼地者"), specialStyle: .rush, specialPower: 2.9,
        ultimateName: Text("Titan's Fall", "泰坦陨落"), ultimateStyle: .meteor, ultimatePower: 5.0)

    static let vex = FighterDef(
        id: "vex", name: Text("Vex Morrow", "维克斯·莫罗"), title: Text("Hex Duelist", "咒术决斗者"), rarity: 2, speed: .medium,
        look: Look(primary: c(0x2A1E3A), secondary: c(0x4A2A6A), accent: c(0xA86AE0), hair: c(0x7A3AB0), skin: c(0xE8C6B0),
                   eyes: c(0xB060FF), aura: c(0xB060FF), hairStyle: 9, height: 1.0, bulk: 0.95, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 23000, atk: 2450, defense: 1100,
        cards: [
            Card(id: "vex.0", name: Text("Hex Jab", "咒印刺拳"), kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(id: "vex.1", name: Text("Curse Kick", "诅咒踢"), kind: .strike, cost: 30, power: 1.35, hits: 2),
            Card(id: "vex.2", name: Text("Rune Bolt", "符文弹"), kind: .blast, cost: 20, power: 1.05, hits: 2),
            Card(id: "vex.3", name: Text("Grim Volley", "冥咒连射"), kind: .blast, cost: 30, power: 1.4, hits: 4),
        ],
        effectCard: Card(id: "vex.fx", name: Text("Withering Hex", "枯萎咒"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .curse(10)),
        specialName: Text("Rune Barrage", "符文乱射"), specialStyle: .volley, specialPower: 2.8,
        ultimateName: Text("Abyssal Seal", "深渊封印"), ultimateStyle: .beam, ultimatePower: 5.1)

    static let rin = FighterDef(
        id: "rin", name: Text("Rin Kazane", "凛·风音"), title: Text("Wind Blade", "风之刃"), rarity: 3, speed: .fast,
        look: Look(primary: c(0xF4F4F0), secondary: c(0x1E2440), accent: c(0xC23A3A), hair: c(0x1C2440), skin: c(0xF2D0BA),
                   eyes: c(0x2A4A8A), aura: c(0x9AD8FF), hairStyle: 3, height: 0.97, bulk: 0.9, sleeves: 2,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: false, cape: false, headband: false),
        hp: 22000, atk: 2750, defense: 1050,
        cards: [
            Card(id: "rin.0", name: Text("Iai Flash", "居合一闪"), kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(id: "rin.1", name: Text("Gale Blades", "疾风刃"), kind: .strike, cost: 30, power: 1.45, hits: 4),
            Card(id: "rin.2", name: Text("Air Slash", "空斩"), kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(id: "rin.3", name: Text("Crescent Gale", "新月疾风"), kind: .blast, cost: 30, power: 1.4, hits: 1),
        ],
        effectCard: Card(id: "rin.fx", name: Text("Focus Breath", "凝神呼吸"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .powerUp(10)),
        specialName: Text("Thousand Cuts", "千刃"), specialStyle: .rush, specialPower: 3.0,
        ultimateName: Text("Heaven Splitter", "断天"), ultimateStyle: .beam, ultimatePower: 5.4)

    static let juno = FighterDef(
        id: "juno", name: Text("Juno Volt", "朱诺·伏特"), title: Text("Spark Engineer", "电光工程师"), rarity: 2, speed: .medium,
        look: Look(primary: c(0xF2A33A), secondary: c(0x3A3A42), accent: c(0x5CE1FF), hair: c(0xF07A2A), skin: c(0xF1C7A1),
                   eyes: c(0x2A8AD8), aura: c(0xFFE45A), hairStyle: 6, height: 0.95, bulk: 0.95, sleeves: 1,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: true, cape: false, headband: true),
        hp: 23000, atk: 2400, defense: 1150,
        cards: [
            Card(id: "juno.0", name: Text("Wrench Swing", "扳手挥击"), kind: .strike, cost: 20, power: 1.05, hits: 2),
            Card(id: "juno.1", name: Text("Piston Punch", "活塞拳"), kind: .strike, cost: 30, power: 1.4, hits: 3),
            Card(id: "juno.2", name: Text("Volt Pellet", "电弹"), kind: .blast, cost: 20, power: 1.0, hits: 3),
            Card(id: "juno.3", name: Text("Coil Cannon", "线圈炮"), kind: .blast, cost: 30, power: 1.4, hits: 1),
        ],
        effectCard: Card(id: "juno.fx", name: Text("Overcharge", "超载"), kind: .effect, cost: 0, power: 0, hits: 0, effect: .energy(35)),
        specialName: Text("Drone Swarm", "无人机群"), specialStyle: .volley, specialPower: 2.8,
        ultimateName: Text("Megawatt Storm", "兆瓦风暴"), ultimateStyle: .meteor, ultimatePower: 5.0)

    static let kael = FighterDef(
        id: "kael", name: Text("Kael Ashborn", "凯尔·灰生"), title: Text("Phoenix Heir", "不死鸟继承者"), rarity: 3, speed: .medium,
        look: Look(primary: c(0x1A1A1A), secondary: c(0x8A1A1A), accent: c(0xFF7A2A), hair: c(0xA8282A), skin: c(0xE3B08A),
                   eyes: c(0xFF8A2A), aura: c(0xFF6A2A), hairStyle: 11, height: 1.06, bulk: 1.05, sleeves: 2,
                   coat: true, scarf: false, shoulderPads: false,
                   gloves: true, cape: false, headband: false),
        hp: 25000, atk: 2700, defense: 1120,
        cards: [
            Card(id: "kael.0", name: Text("Ash Fang", "灰烬之牙"), kind: .strike, cost: 20, power: 1.1, hits: 3),
            Card(id: "kael.1", name: Text("Rebirth Knee", "重生膝"), kind: .strike, cost: 30, power: 1.45, hits: 3),
            Card(id: "kael.2", name: Text("Cinder Feather", "余烬之羽"), kind: .blast, cost: 20, power: 1.05, hits: 2),
            Card(id: "kael.3", name: Text("Pyre Wave", "火葬之浪"), kind: .blast, cost: 30, power: 1.45, hits: 3),
        ],
        effectCard: Card(id: "kael.fx", name: Text("Rekindle", "再燃"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .powerUp(10)),
        specialName: Text("Phoenix Lance", "凤凰之枪"), specialStyle: .beam, specialPower: 3.0,
        ultimateName: Text("Ashen Rebirth", "灰烬重生"), ultimateStyle: .meteor, ultimatePower: 5.4)

    static let nova = FighterDef(
        id: "nova", name: Text("Nova Celeste", "诺娃·天穹"), title: Text("Galaxy Empress", "银河女帝"), rarity: 3, speed: .slow,
        look: Look(primary: c(0x1C1E4A), secondary: c(0x6A4AD8), accent: c(0xF2D27A), hair: c(0x22264A), skin: c(0xF6D7C3),
                   eyes: c(0x8A6AFF), aura: c(0x8A9AFF), hairStyle: 1, height: 1.0, bulk: 0.95, sleeves: 2,
                   coat: false, scarf: false, shoulderPads: false,
                   gloves: false, cape: true, headband: false),
        hp: 26000, atk: 2650, defense: 1200,
        cards: [
            Card(id: "nova.0", name: Text("Nebula Palm", "星云掌"), kind: .strike, cost: 20, power: 1.1, hits: 2),
            Card(id: "nova.1", name: Text("Meteor Heel", "陨石踵"), kind: .strike, cost: 30, power: 1.5, hits: 2),
            Card(id: "nova.2", name: Text("Star Dust", "星尘"), kind: .blast, cost: 20, power: 1.05, hits: 3),
            Card(id: "nova.3", name: Text("Galactic Ring", "银河之环"), kind: .blast, cost: 30, power: 1.45, hits: 1),
        ],
        effectCard: Card(id: "nova.fx", name: Text("Gravity Bind", "重力束缚"), kind: .effect, cost: 20, power: 0, hits: 0, effect: .curse(10)),
        specialName: Text("Cosmic Ray", "宇宙射线"), specialStyle: .beam, specialPower: 2.9,
        ultimateName: Text("Big Crunch", "宇宙坍缩"), ultimateStyle: .meteor, ultimatePower: 5.5)
}

// MARK: - Persistence

struct SaveData: Codable {
    var coins: Int = 600
    var stage: Int = 1
    var unlocked: [String] = ["kai", "luna", "rook"]
    var xp: [String: Int] = [:]
    var team: [String] = ["kai", "luna", "rook"]
    var wins: Int = 0
    var losses: Int = 0
    var soundOn: Bool = true
}

@MainActor
final class Save {
    static let shared = Save()
    private let key = "moonaction.save.v2"
    var data: SaveData

    static let maxLevel = 60
    static let summonCost = 300
    static let duplicateXP = 300

    private init() {
        if let d = UserDefaults.standard.data(forKey: key),
           let s = try? JSONDecoder().decode(SaveData.self, from: d) {
            data = s
        } else {
            data = SaveData()
        }
    }

    func persist() {
        if let d = try? JSONEncoder().encode(data) { UserDefaults.standard.set(d, forKey: key) }
    }

    static func xpNeeded(forLevel l: Int) -> Int { 100 + (l - 1) * 25 }

    func levelInfo(_ id: String) -> (level: Int, into: Int, need: Int) {
        var remaining = data.xp[id] ?? 0
        var lvl = 1
        while lvl < Save.maxLevel && remaining >= Save.xpNeeded(forLevel: lvl) {
            remaining -= Save.xpNeeded(forLevel: lvl)
            lvl += 1
        }
        return (lvl, remaining, Save.xpNeeded(forLevel: lvl))
    }

    func level(_ id: String) -> Int { levelInfo(id).level }
    func addXP(_ id: String, _ amount: Int) { data.xp[id, default: 0] += amount }
    func isUnlocked(_ id: String) -> Bool { data.unlocked.contains(id) }

    static func enemyLevel(stage: Int) -> Int { min(maxLevel, max(1, stage + stage / 4)) }
}
