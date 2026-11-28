import UIKit

/// Five-element affinity (原创五行属性). Each element overcomes exactly one other:
/// wood → earth → water → fire → metal → wood. Advantage: ×1.3 damage dealt; disadvantage: ×0.8.
enum Element: Int, CaseIterable {
    case wood, fire, earth, metal, water

    /// The element this one overcomes.
    var beats: Element {
        switch self {
        case .wood: return .earth
        case .earth: return .water
        case .water: return .fire
        case .fire: return .metal
        case .metal: return .wood
        }
    }

    var name: String { L("element.\(self)") }

    var symbol: String {
        switch self {
        case .wood: return "leaf.fill"
        case .fire: return "flame.fill"
        case .earth: return "mountain.2.fill"
        case .metal: return "diamond.fill"
        case .water: return "drop.fill"
        }
    }

    var color: UIColor {
        switch self {
        case .wood: return UIColor(hex: 0x7EE2A8)
        case .fire: return UIColor(hex: 0xFF6B5B)
        case .earth: return UIColor(hex: 0xE8B35A)
        case .metal: return UIColor(hex: 0xD8DCF0)
        case .water: return UIColor(hex: 0x6FC3FF)
        }
    }

    static let advantage = 1.3
    static let disadvantage = 0.8

    /// Damage multiplier when `attacker` hits `defender`.
    static func multiplier(_ attacker: Element, _ defender: Element) -> Double {
        if attacker.beats == defender { return advantage }
        if defender.beats == attacker { return disadvantage }
        return 1
    }

    /// Element follows the fighter's aura color (so a created character picks it with the aura swatch).
    static func of(_ c: UIColor) -> Element {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        if s < 0.22 { return .metal }
        let deg = h * 360
        switch deg {
        case 25..<70: return .earth
        case 70..<170: return .wood
        case 170..<250: return .water
        case 250..<325: return .metal
        default: return .fire
        }
    }
}

extension FighterDef {
    var element: Element { Element.of(look.aura) }
}

/// Main ability (主动技能): one powerful action per fighter per battle, ready after a charge time.
enum MainAbility {
    case recover, guardian, overdrive, surge, hex

    static let chargeTime = 25.0

    var name: String { L("ability.\(self)") }
    var detail: String { L("ability.\(self).d") }
    var symbol: String {
        switch self {
        case .recover: return "cross.fill"
        case .guardian: return "shield.lefthalf.filled"
        case .overdrive: return "flame.fill"
        case .surge: return "bolt.fill"
        case .hex: return "moon.haze.fill"
        }
    }

    /// Derived from the fighter's effect card, so every fighter keeps a consistent identity.
    static func of(_ d: FighterDef) -> MainAbility {
        switch d.effectCard.effect {
        case .heal?: return .recover
        case .barrier?: return .guardian
        case .powerUp?: return .overdrive
        case .energy?: return .surge
        case .curse?: return .hex
        case nil: return .overdrive
        }
    }
}

extension FighterDef {
    var ability: MainAbility { MainAbility.of(self) }
}
