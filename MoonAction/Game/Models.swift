import UIKit

enum CardKind {
    case strike, blast
}

struct Card {
    let name: String
    let kind: CardKind
    let cost: Int
    let power: Double
    let hits: Int
}

enum SpecialStyle { case beam, rush, volley }
enum UltimateStyle { case beam, meteor }

/// All fighters, names and designs in Moon Action are original creations.
struct FighterDef {
    let id: String
    let name: String
    let title: String
    let rarity: Int
    let primary: UIColor
    let secondary: UIColor
    let hair: UIColor
    let skin: UIColor
    let aura: UIColor
    let hairStyle: Int
    let bodyScale: CGFloat
    let hp: Double
    let atk: Double
    let defense: Double
    let cards: [Card]
    let specialName: String
    let specialStyle: SpecialStyle
    let specialPower: Double
    let ultimateName: String
    let ultimateStyle: UltimateStyle
    let ultimatePower: Double
}

enum Roster {
    static let all: [FighterDef] = [kai, luna, rook, ivy, nyx, blaze]

    static func byID(_ id: String) -> FighterDef {
        all.first { $0.id == id } ?? kai
    }

    static let kai = FighterDef(
        id: "kai", name: "Kai Solaris", title: "Dawn Brawler", rarity: 2,
        primary: UIColor(hex: 0xECEFF4), secondary: UIColor(hex: 0x1F8A8A), hair: UIColor(hex: 0xC0392B),
        skin: UIColor(hex: 0xF1C7A1), aura: UIColor(hex: 0xFFB347), hairStyle: 0, bodyScale: 1.0,
        hp: 6200, atk: 900, defense: 420,
        cards: [
            Card(name: "Sunrise Jab", kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(name: "Solar Knee", kind: .strike, cost: 25, power: 1.3, hits: 2),
            Card(name: "Flare Shot", kind: .blast, cost: 25, power: 1.1, hits: 1),
            Card(name: "Corona Spread", kind: .blast, cost: 35, power: 1.5, hits: 3),
        ],
        specialName: "Daybreak Cannon", specialStyle: .beam, specialPower: 2.8,
        ultimateName: "Zenith Sunburst", ultimateStyle: .beam, ultimatePower: 5.2)

    static let luna = FighterDef(
        id: "luna", name: "Luna Vey", title: "Moonblade Dancer", rarity: 2,
        primary: UIColor(hex: 0x3A2D7A), secondary: UIColor(hex: 0xB8C0D8), hair: UIColor(hex: 0xD9D4F2),
        skin: UIColor(hex: 0xF6D7C3), aura: UIColor(hex: 0xB18CFF), hairStyle: 1, bodyScale: 0.96,
        hp: 5800, atk: 940, defense: 400,
        cards: [
            Card(name: "Crescent Cut", kind: .strike, cost: 20, power: 1.05, hits: 3),
            Card(name: "Tidal Step", kind: .strike, cost: 25, power: 1.35, hits: 4),
            Card(name: "Silver Needle", kind: .blast, cost: 25, power: 1.15, hits: 2),
            Card(name: "Night Petals", kind: .blast, cost: 30, power: 1.35, hits: 3),
        ],
        specialName: "Eclipse Waltz", specialStyle: .rush, specialPower: 2.9,
        ultimateName: "Silver Tide", ultimateStyle: .meteor, ultimatePower: 5.0)

    static let rook = FighterDef(
        id: "rook", name: "Rook Thunderhart", title: "Storm Knuckle", rarity: 2,
        primary: UIColor(hex: 0xE5B93C), secondary: UIColor(hex: 0x23252E), hair: UIColor(hex: 0x24418F),
        skin: UIColor(hex: 0xC98E62), aura: UIColor(hex: 0x5CE1FF), hairStyle: 2, bodyScale: 1.12,
        hp: 7200, atk: 860, defense: 520,
        cards: [
            Card(name: "Iron Hook", kind: .strike, cost: 20, power: 1.1, hits: 2),
            Card(name: "Quake Stomp", kind: .strike, cost: 30, power: 1.6, hits: 3),
            Card(name: "Spark Toss", kind: .blast, cost: 25, power: 1.0, hits: 1),
            Card(name: "Static Hail", kind: .blast, cost: 35, power: 1.45, hits: 4),
        ],
        specialName: "Thunderclap Rush", specialStyle: .rush, specialPower: 3.0,
        ultimateName: "Skybreaker Bolt", ultimateStyle: .meteor, ultimatePower: 5.0)

    static let ivy = FighterDef(
        id: "ivy", name: "Ivy Thorne", title: "Verdant Warden", rarity: 2,
        primary: UIColor(hex: 0x2E7D4F), secondary: UIColor(hex: 0x6B4F2A), hair: UIColor(hex: 0x7FD35B),
        skin: UIColor(hex: 0xEBC2A0), aura: UIColor(hex: 0x9BFF6A), hairStyle: 3, bodyScale: 0.97,
        hp: 6000, atk: 880, defense: 460,
        cards: [
            Card(name: "Bramble Kick", kind: .strike, cost: 20, power: 1.0, hits: 3),
            Card(name: "Oak Palm", kind: .strike, cost: 25, power: 1.3, hits: 2),
            Card(name: "Seed Burst", kind: .blast, cost: 25, power: 1.15, hits: 3),
            Card(name: "Pollen Comet", kind: .blast, cost: 30, power: 1.4, hits: 1),
        ],
        specialName: "Thorn Storm", specialStyle: .volley, specialPower: 2.8,
        ultimateName: "World Root Bloom", ultimateStyle: .meteor, ultimatePower: 5.1)

    static let nyx = FighterDef(
        id: "nyx", name: "Nyx Obsidian", title: "Void Walker", rarity: 3,
        primary: UIColor(hex: 0x1C1B26), secondary: UIColor(hex: 0x8E1B3A), hair: UIColor(hex: 0xF0F0F5),
        skin: UIColor(hex: 0xD9B8A5), aura: UIColor(hex: 0xD04CFF), hairStyle: 4, bodyScale: 1.02,
        hp: 5600, atk: 1020, defense: 400,
        cards: [
            Card(name: "Shade Fang", kind: .strike, cost: 20, power: 1.1, hits: 3),
            Card(name: "Rift Lunge", kind: .strike, cost: 25, power: 1.4, hits: 2),
            Card(name: "Null Orb", kind: .blast, cost: 25, power: 1.2, hits: 1),
            Card(name: "Gravity Rain", kind: .blast, cost: 35, power: 1.6, hits: 4),
        ],
        specialName: "Abyss Lance", specialStyle: .beam, specialPower: 3.1,
        ultimateName: "Event Horizon", ultimateStyle: .beam, ultimatePower: 5.6)

    static let blaze = FighterDef(
        id: "blaze", name: "Blaze Ardent", title: "Ember Fist", rarity: 3,
        primary: UIColor(hex: 0xB22222), secondary: UIColor(hex: 0x30302F), hair: UIColor(hex: 0xFF8C1A),
        skin: UIColor(hex: 0xE3B08A), aura: UIColor(hex: 0xFF5A1F), hairStyle: 5, bodyScale: 1.05,
        hp: 6400, atk: 980, defense: 430,
        cards: [
            Card(name: "Cinder Combo", kind: .strike, cost: 20, power: 1.05, hits: 4),
            Card(name: "Magma Uppercut", kind: .strike, cost: 30, power: 1.6, hits: 2),
            Card(name: "Ember Dart", kind: .blast, cost: 25, power: 1.1, hits: 2),
            Card(name: "Wildfire", kind: .blast, cost: 35, power: 1.55, hits: 3),
        ],
        specialName: "Inferno Combo", specialStyle: .rush, specialPower: 3.0,
        ultimateName: "Phoenix Meteor", ultimateStyle: .meteor, ultimatePower: 5.4)
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
    private let key = "moonaction.save.v1"
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
        if let d = try? JSONEncoder().encode(data) {
            UserDefaults.standard.set(d, forKey: key)
        }
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

    func addXP(_ id: String, _ amount: Int) {
        data.xp[id, default: 0] += amount
    }

    func isUnlocked(_ id: String) -> Bool { data.unlocked.contains(id) }
}
