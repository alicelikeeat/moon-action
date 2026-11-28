import UIKit
import BattleCore

/// Visual side of the six BattleCore fighters: which 3D model / look each one uses, element colors.
@MainActor
enum CoreVisuals {
    /// Visual roster entry (keeps the id so imported models and portraits resolve).
    private static let modelID: [String: String] = [
        "kai": "kai", "nova": "nova", "zero": "nyx", "lan": "luna", "aegis": "rook", "sera": "aria",
    ]

    static func color(_ e: BattleCore.Element) -> UIColor {
        switch e {
        case .red: return UIColor(hex: 0xFF5A4A)
        case .yel: return UIColor(hex: 0xF2C46D)
        case .pur: return UIColor(hex: 0xB18CFF)
        case .grn: return UIColor(hex: 0x7EE2A8)
        case .blu: return UIColor(hex: 0x6FC3FF)
        case .lgt: return UIColor(hex: 0xF4F1DE)
        }
    }

    static func elementName(_ e: BattleCore.Element) -> String { L10n.isZH ? e.nameZH : e.nameEN }

    static func name(_ d: BattleCore.FighterDef) -> String { L10n.isZH ? d.nameZH : d.nameEN }

    static func cardName(_ c: ArtsCard) -> String { L10n.isZH ? c.nameZH : c.nameEN }

    /// App-side FighterDef used by FighterModel / Portraits / Signatures for a core fighter.
    static func visual(_ d: BattleCore.FighterDef) -> FighterDef {
        let base = Roster.byID(modelID[d.id] ?? "kai")
        var look = base.look
        look.aura = color(d.element)
        return FighterDef(id: base.id, name: Text(d.nameEN, d.nameZH), title: Text(d.roleZH, d.roleZH), rarity: base.rarity,
                          speed: base.speed, look: look, hp: d.maxHP, atk: d.attack, defense: d.defense, cards: base.cards,
                          effectCard: base.effectCard, specialName: base.specialName, specialStyle: base.specialStyle,
                          specialPower: base.specialPower, ultimateName: base.ultimateName, ultimateStyle: base.ultimateStyle,
                          ultimatePower: base.ultimatePower)
    }

    static func kindColor(_ k: BattleCore.CardKind) -> UIColor {
        switch k {
        case .strike: return UIColor(hex: 0xFF5A4A)
        case .blast: return UIColor(hex: 0xF2C46D)
        case .special: return UIColor(hex: 0x6FC3FF)
        case .support: return UIColor(hex: 0x7EE2A8)
        case .ultimate: return UIColor(hex: 0xC49BFF)
        }
    }

    static func kindName(_ k: BattleCore.CardKind) -> String {
        switch k {
        case .strike: return L10n.isZH ? "打击" : "STRIKE"
        case .blast: return L10n.isZH ? "射击" : "BLAST"
        case .special: return L10n.isZH ? "必杀" : "SPECIAL"
        case .support: return L10n.isZH ? "特殊" : "ARTS"
        case .ultimate: return L10n.isZH ? "究极" : "ULTIMATE"
        }
    }

    static func kindSymbol(_ k: BattleCore.CardKind) -> String {
        switch k {
        case .strike: return "figure.boxing"
        case .blast: return "dot.radiowaves.right"
        case .special: return "sparkles"
        case .support: return "cross.case.fill"
        case .ultimate: return "flame.fill"
        }
    }
}
