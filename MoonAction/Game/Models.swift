import UIKit

// MARK: - Cards

enum CardKind {
    case strike     // melee: fists and kicks
    case blast      // ranged: energy shots
    case special    // special art: fighter-specific cinematic move
    case ultimate   // ultimate art: unlocked by the ultimate gauge
    case effect     // effect card: heal / barrier / buff / debuff
    case eclipse    // team finisher: unlocked by collecting 7 moon shards
}

enum CardEffect {
    case heal(Double)        // fraction of max HP
    case barrier(Double)     // seconds of 60% damage reduction
    case powerUp(Double)     // seconds of +30% attack
    case energy(Double)      // instant energy
    case curse(Double)       // seconds of -30% enemy defense
}

struct Card {
    let name: String
    let kind: CardKind
    let cost: Int
    let power: Double
    let hits: Int
    var effect: CardEffect? = nil
}

enum SpecialStyle { case beam, rush, volley }
enum UltimateStyle { case beam, meteor }

/// Build / silhouette of a procedurally generated 3D fighter.
struct Look {
    let primary: UIColor      // top / jacket
    let secondary: UIColor    // pants / trims
    let accent: UIColor       // belt, wristbands, boots
    let hair: UIColor
    let skin: UIColor
    let eyes: UIColor
    let aura: UIColor
    let hairStyle: Int
    let height: Float         // overall scale
    let bulk: Float           // 0.9 slim … 1.25 heavy
    let coat: Bool            // long coat tails
    let scarf: Bool
    let shoulderPads: Bool
}

/// All fighters, names, looks and moves in Moon Action are original creations.
struct FighterDef {
    let id: String
    let name: String
    let title: String
    let rarity: Int
    let look: Look
    let hp: Double
    let atk: Double
    let defense: Double
    let cards: [Card]
    let effectCard: Card
    let specialName: String
    let specialStyle: SpecialStyle
    let specialPower: Double
    let ultimateName: String
    let ultimateStyle: UltimateStyle
    let ultimatePower: Double

    var aura: UIColor { look.aura }

    var specialCard: Card {
        Card(name: specialName, kind: .special, cost: 40, power: specialPower, hits: specialStyle == .rush ? 7 : 6)
    }

    var ultimateCard: Card {
        Card(name: ultimateName, kind: .ultimate, cost: 0, power: ultimatePower, hits: 8)
    }

    /// Fresh shuffled deck: 2× each basic art, 1 special art, 1 effect card.
    func makeDeck() -> [Card] {
        (cards + cards + [specialCard, effectCard]).shuffled()
    }
}

enum Roster {
    static let all: [FighterDef] = [kai, luna, rook, ivy, nyx, blaze]

    static func byID(_ id: String) -> FighterDef { all.first { $0.id == id } ?? kai }

    static let eclipseCard = Card(name: "Eclipse Rush", kind: .eclipse, cost: 0, power: 4.2, hits: 9)

    static let kai = FighterDef(
        id: "kai", name: "Kai Solaris", title: "Dawn Brawler", rarity: 2,
        look: Look(primary: UIColor(hex: 0xF2F4F8), secondary: UIColor(hex: 0x1F8A8A), accent: UIColor(hex: 0x2B2D3A),
                   hair: UIColor(hex: 0xC93A2C), skin: UIColor(hex: 0xF1C7A1), eyes: UIColor(hex: 0x1E6B8F),
                   aura: UIColor(hex: 0xFFB347), hairStyle: 0, height: 1.0, bulk: 1.0, coat: false, scarf: true, shoulderPads: false),
        hp: 24000, atk: 2400, defense: 1100,
        cards: [
            Card(name: "Sunrise Jab", kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(name: "Solar Knee", kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(name: "Flare Shot", kind: .blast, cost: 20, power: 0.95, hits: 1),
            Card(name: "Corona Spread", kind: .blast, cost: 30, power: 1.35, hits: 3),
        ],
        effectCard: Card(name: "Rising Focus", kind: .effect, cost: 20, power: 0, hits: 0, effect: .powerUp(10)),
        specialName: "Daybreak Cannon", specialStyle: .beam, specialPower: 2.7,
        ultimateName: "Zenith Sunburst", ultimateStyle: .beam, ultimatePower: 5.0)

    static let luna = FighterDef(
        id: "luna", name: "Luna Vey", title: "Moonblade Dancer", rarity: 2,
        look: Look(primary: UIColor(hex: 0x3A2D7A), secondary: UIColor(hex: 0xB8C0D8), accent: UIColor(hex: 0xD9C27A),
                   hair: UIColor(hex: 0xDAD4F5), skin: UIColor(hex: 0xF6D7C3), eyes: UIColor(hex: 0x7A4FD6),
                   aura: UIColor(hex: 0xB18CFF), hairStyle: 1, height: 0.95, bulk: 0.9, coat: true, scarf: false, shoulderPads: false),
        hp: 22500, atk: 2500, defense: 1050,
        cards: [
            Card(name: "Crescent Cut", kind: .strike, cost: 20, power: 1.05, hits: 3),
            Card(name: "Tidal Step", kind: .strike, cost: 30, power: 1.4, hits: 4),
            Card(name: "Silver Needle", kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(name: "Night Petals", kind: .blast, cost: 30, power: 1.3, hits: 3),
        ],
        effectCard: Card(name: "Moonveil", kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(8)),
        specialName: "Eclipse Waltz", specialStyle: .rush, specialPower: 2.8,
        ultimateName: "Silver Tide", ultimateStyle: .meteor, ultimatePower: 4.9)

    static let rook = FighterDef(
        id: "rook", name: "Rook Thunderhart", title: "Storm Knuckle", rarity: 2,
        look: Look(primary: UIColor(hex: 0xE5B93C), secondary: UIColor(hex: 0x23252E), accent: UIColor(hex: 0x3A6FD8),
                   hair: UIColor(hex: 0x24418F), skin: UIColor(hex: 0xC98E62), eyes: UIColor(hex: 0x2A9BD8),
                   aura: UIColor(hex: 0x5CE1FF), hairStyle: 2, height: 1.1, bulk: 1.25, coat: false, scarf: false, shoulderPads: true),
        hp: 27500, atk: 2300, defense: 1300,
        cards: [
            Card(name: "Iron Hook", kind: .strike, cost: 20, power: 1.1, hits: 2),
            Card(name: "Quake Stomp", kind: .strike, cost: 30, power: 1.55, hits: 3),
            Card(name: "Spark Toss", kind: .blast, cost: 20, power: 0.9, hits: 1),
            Card(name: "Static Hail", kind: .blast, cost: 30, power: 1.35, hits: 4),
        ],
        effectCard: Card(name: "Iron Will", kind: .effect, cost: 20, power: 0, hits: 0, effect: .barrier(10)),
        specialName: "Thunderclap Rush", specialStyle: .rush, specialPower: 2.9,
        ultimateName: "Skybreaker Bolt", ultimateStyle: .meteor, ultimatePower: 4.9)

    static let ivy = FighterDef(
        id: "ivy", name: "Ivy Thorne", title: "Verdant Warden", rarity: 2,
        look: Look(primary: UIColor(hex: 0x2E7D4F), secondary: UIColor(hex: 0x6B4F2A), accent: UIColor(hex: 0xE0C36A),
                   hair: UIColor(hex: 0x7FD35B), skin: UIColor(hex: 0xEBC2A0), eyes: UIColor(hex: 0x2F9E5A),
                   aura: UIColor(hex: 0x9BFF6A), hairStyle: 3, height: 0.96, bulk: 0.92, coat: false, scarf: true, shoulderPads: false),
        hp: 23000, atk: 2350, defense: 1200,
        cards: [
            Card(name: "Bramble Kick", kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(name: "Oak Palm", kind: .strike, cost: 20, power: 1.15, hits: 2),
            Card(name: "Seed Burst", kind: .blast, cost: 20, power: 1.05, hits: 3),
            Card(name: "Pollen Comet", kind: .blast, cost: 30, power: 1.35, hits: 1),
        ],
        effectCard: Card(name: "Verdant Bloom", kind: .effect, cost: 30, power: 0, hits: 0, effect: .heal(0.18)),
        specialName: "Thorn Storm", specialStyle: .volley, specialPower: 2.7,
        ultimateName: "World Root Bloom", ultimateStyle: .meteor, ultimatePower: 5.0)

    static let nyx = FighterDef(
        id: "nyx", name: "Nyx Obsidian", title: "Void Walker", rarity: 3,
        look: Look(primary: UIColor(hex: 0x1F1D2B), secondary: UIColor(hex: 0x8E1B3A), accent: UIColor(hex: 0xC7B3FF),
                   hair: UIColor(hex: 0xF0F0F5), skin: UIColor(hex: 0xD9B8A5), eyes: UIColor(hex: 0xD04CFF),
                   aura: UIColor(hex: 0xD04CFF), hairStyle: 4, height: 1.04, bulk: 0.95, coat: true, scarf: false, shoulderPads: false),
        hp: 22000, atk: 2700, defense: 1050,
        cards: [
            Card(name: "Shade Fang", kind: .strike, cost: 20, power: 1.1, hits: 3),
            Card(name: "Rift Lunge", kind: .strike, cost: 30, power: 1.45, hits: 2),
            Card(name: "Null Orb", kind: .blast, cost: 20, power: 1.05, hits: 1),
            Card(name: "Gravity Rain", kind: .blast, cost: 30, power: 1.45, hits: 4),
        ],
        effectCard: Card(name: "Null Curse", kind: .effect, cost: 20, power: 0, hits: 0, effect: .curse(10)),
        specialName: "Abyss Lance", specialStyle: .beam, specialPower: 3.0,
        ultimateName: "Event Horizon", ultimateStyle: .beam, ultimatePower: 5.4)

    static let blaze = FighterDef(
        id: "blaze", name: "Blaze Ardent", title: "Ember Fist", rarity: 3,
        look: Look(primary: UIColor(hex: 0xB22222), secondary: UIColor(hex: 0x30302F), accent: UIColor(hex: 0xFFB000),
                   hair: UIColor(hex: 0xFF8C1A), skin: UIColor(hex: 0xE3B08A), eyes: UIColor(hex: 0xE0531F),
                   aura: UIColor(hex: 0xFF5A1F), hairStyle: 5, height: 1.05, bulk: 1.1, coat: false, scarf: false, shoulderPads: true),
        hp: 25000, atk: 2600, defense: 1120,
        cards: [
            Card(name: "Cinder Combo", kind: .strike, cost: 20, power: 1.05, hits: 4),
            Card(name: "Magma Uppercut", kind: .strike, cost: 30, power: 1.55, hits: 2),
            Card(name: "Ember Dart", kind: .blast, cost: 20, power: 1.0, hits: 2),
            Card(name: "Wildfire", kind: .blast, cost: 30, power: 1.45, hits: 3),
        ],
        effectCard: Card(name: "Kindle", kind: .effect, cost: 0, power: 0, hits: 0, effect: .energy(35)),
        specialName: "Inferno Combo", specialStyle: .rush, specialPower: 2.9,
        ultimateName: "Phoenix Meteor", ultimateStyle: .meteor, ultimatePower: 5.2)
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
