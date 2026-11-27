import Foundation

/// Cheat toggles (player side only). Stored separately from the save so old saves keep decoding.
@MainActor
enum Cheats {
    enum Key: String, CaseIterable {
        case god, energy, dodge, oneHit, freezeAI

        var title: String { L("cheat.\(rawValue)") }
        var detail: String { L("cheat.\(rawValue).d") }
        var symbol: String {
            switch self {
            case .god: return "shield.fill"
            case .energy: return "bolt.fill"
            case .dodge: return "wind"
            case .oneHit: return "burst.fill"
            case .freezeAI: return "pause.circle.fill"
            }
        }
    }

    private static func k(_ key: Key) -> String { "moonaction.cheat.\(key.rawValue)" }

    static func isOn(_ key: Key) -> Bool { UserDefaults.standard.bool(forKey: k(key)) }
    static func set(_ key: Key, _ on: Bool) { UserDefaults.standard.set(on, forKey: k(key)) }
    static var anyOn: Bool { Key.allCases.contains { isOn($0) } }

    static var god: Bool { isOn(.god) }
    static var infiniteEnergy: Bool { isOn(.energy) }
    static var infiniteDodge: Bool { isOn(.dodge) }
    static var oneHit: Bool { isOn(.oneHit) }
    static var freezeAI: Bool { isOn(.freezeAI) }

    // One-shot save edits

    static func unlockAll() {
        let s = Save.shared
        for d in Roster.all where !s.data.unlocked.contains(d.id) { s.data.unlocked.append(d.id) }
        s.persist()
    }

    static func addCoins(_ n: Int = 100_000) {
        Save.shared.data.coins += n
        Save.shared.persist()
    }

    static func maxLevels() {
        let s = Save.shared
        let total = (1..<Save.maxLevel).reduce(0) { $0 + Save.xpNeeded(forLevel: $1) }
        for id in s.data.unlocked { s.data.xp[id] = max(s.data.xp[id] ?? 0, total) }
        s.persist()
    }
}
