import UIKit

/// Everything the character creator edits. Colors are stored as hex so the spec is Codable.
struct CharacterSpec: Codable, Equatable {
    var name = ""
    var style = "kai"           // fighting style: moves, stats and speed come from this roster fighter
    var height: Float = 1
    var bulk: Float = 1
    var skin: UInt32 = 0xF1C7A1
    var hair: UInt32 = 0x2B2D3A
    var eyes: UInt32 = 0x1E6B8F
    var primary: UInt32 = 0xF2F4F8
    var secondary: UInt32 = 0x2E3A5C
    var accent: UInt32 = 0xF2C46D
    var aura: UInt32 = 0x7FD8FF
    var hairStyle = 0
    var sleeves = 1
    var coat = false
    var scarf = false
    var shoulderPads = false
    var gloves = false
    var cape = false
    var headband = false
    var eyeScale: Float = 1
    var eyeGap: Float = 1
    var eyeShape = 0
    var browTilt: Float = 0
    var jaw: Float = 1

    var look: Look {
        var l = Look(primary: UIColor(hex: primary), secondary: UIColor(hex: secondary), accent: UIColor(hex: accent),
                     hair: UIColor(hex: hair), skin: UIColor(hex: skin), eyes: UIColor(hex: eyes), aura: UIColor(hex: aura),
                     hairStyle: hairStyle, height: height, bulk: bulk, sleeves: sleeves, coat: coat, scarf: scarf,
                     shoulderPads: shoulderPads, gloves: gloves, cape: cape, headband: headband)
        l.eyeScale = eyeScale
        l.eyeGap = eyeGap
        l.eyeShape = eyeShape
        l.browTilt = browTilt
        l.jaw = jaw
        return l
    }

    static func random() -> CharacterSpec {
        var s = CharacterSpec()
        s.style = Roster.all.randomElement()?.id ?? "kai"
        s.height = Float.random(in: 0.92...1.08)
        s.bulk = Float.random(in: 0.88...1.15)
        s.skin = Palette.skin.randomElement()!
        s.hair = Palette.hair.randomElement()!
        s.eyes = Palette.eyes.randomElement()!
        let cloth = Palette.cloth.shuffled()
        s.primary = cloth[0]
        s.secondary = cloth[1]
        s.accent = cloth[2]
        s.aura = Palette.aura.randomElement()!
        s.hairStyle = Int.random(in: 0..<CharacterSpec.hairStyles)
        s.sleeves = Int.random(in: 0...2)
        s.coat = Bool.random()
        s.scarf = Int.random(in: 0..<3) == 0
        s.shoulderPads = Int.random(in: 0..<4) == 0
        s.gloves = Bool.random()
        s.cape = Int.random(in: 0..<4) == 0
        s.headband = Int.random(in: 0..<4) == 0
        s.eyeScale = Float.random(in: 0.92...1.2)
        s.eyeGap = Float.random(in: 0.92...1.08)
        s.eyeShape = Int.random(in: 0...1)
        s.browTilt = Float.random(in: -0.6...0.8)
        s.jaw = Float.random(in: 0.8...1.25)
        return s
    }

    static let hairStyles = 12
}

enum Palette {
    static let skin: [UInt32] = [0xFBE3D0, 0xF6D7C3, 0xF1C7A1, 0xE8B48E, 0xD49A72, 0xB87A55, 0x8E5A3C, 0x6A4029]
    static let hair: [UInt32] = [0x1C1C24, 0x2B2D3A, 0x5A3A28, 0x9A5B32, 0xC93A2C, 0xE8C26A, 0xF2EEE6, 0xDAD4F5,
                                 0x8FA0B8, 0x3A6FD8, 0x2FA88A, 0xE07AB0]
    static let eyes: [UInt32] = [0x1E6B8F, 0x2A4FA8, 0x7A4FD6, 0x2E8A5A, 0xC9A23A, 0xC93A2C, 0x5A3A28, 0x1C1C24, 0x3FC0D8, 0xE07AB0]
    static let cloth: [UInt32] = [0xF2F4F8, 0xB8C0D8, 0x2B2D3A, 0x14161F, 0x2E3A5C, 0x3A2D7A, 0x1F8A8A, 0x2E6B3A,
                                  0x8A2A2A, 0xC93A2C, 0xE07A3A, 0xF2C46D, 0xD9C27A, 0x6FC3FF, 0xC49BFF, 0xE07AB0]
    static let aura: [UInt32] = [0xFFB347, 0xF2C46D, 0xFF6B5B, 0xFF4FA0, 0xB18CFF, 0x6FC3FF, 0x7FD8FF, 0x7EE2A8, 0x3FE0B0, 0xF4F1DE]
}

/// The player's created character ("me"). Stored apart from the save so old saves keep decoding.
enum CustomFighter {
    static let id = "me"
    private static let key = "moonaction.custom.v1"
    private static var cached: FighterDef?
    private static var loaded = false

    static var spec: CharacterSpec? {
        guard let d = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(CharacterSpec.self, from: d)
    }

    static var def: FighterDef? {
        if !loaded {
            loaded = true
            cached = spec.map(makeDef)
        }
        return cached
    }

    @MainActor static func save(_ s: CharacterSpec) {
        if let d = try? JSONEncoder().encode(s) { UserDefaults.standard.set(d, forKey: key) }
        cached = makeDef(s)
        loaded = true
        Portraits.invalidate(id)
        let save = Save.shared
        if !save.data.unlocked.contains(id) { save.data.unlocked.insert(id, at: 0) }
        save.persist()
    }

    @MainActor static func delete() {
        UserDefaults.standard.removeObject(forKey: key)
        cached = nil
        loaded = true
        Portraits.invalidate(id)
        let save = Save.shared
        save.data.unlocked.removeAll { $0 == id }
        save.data.team.removeAll { $0 == id }
        if save.data.team.isEmpty { save.data.team = ["kai", "luna", "rook"] }
        save.persist()
    }

    static func displayName(_ s: CharacterSpec) -> String {
        let n = s.name.trimmingCharacters(in: .whitespaces)
        return n.isEmpty ? L("creator.defaultName") : n
    }

    /// Build a fighter from the spec: own look and name, moves/stats/speed borrowed from the chosen style.
    static func makeDef(_ s: CharacterSpec) -> FighterDef {
        let base = Roster.all.first { $0.id == s.style } ?? Roster.kai
        let name = displayName(s)
        func remap(_ c: Card, _ i: String) -> Card {
            Card(id: "\(id).\(i)", name: c.name, kind: c.kind, cost: c.cost, power: c.power, hits: c.hits, effect: c.effect)
        }
        return FighterDef(
            id: id, name: Text(name, name), title: Text("Original · " + base.title.en, "原创 · " + base.title.zh),
            rarity: base.rarity, speed: base.speed, look: s.look,
            hp: base.hp, atk: base.atk, defense: base.defense,
            cards: base.cards.enumerated().map { remap($0.element, "\($0.offset)") },
            effectCard: remap(base.effectCard, "fx"),
            specialName: base.specialName, specialStyle: base.specialStyle, specialPower: base.specialPower,
            ultimateName: base.ultimateName, ultimateStyle: base.ultimateStyle, ultimatePower: base.ultimatePower)
    }
}
