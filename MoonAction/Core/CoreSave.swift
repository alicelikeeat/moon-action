import Foundation
import BattleCore

/// Loads / saves BattleCore's `UserSaveData` as Documents/UserSaveData.json.
@MainActor
final class CoreSave: ObservableObject {
    static let shared = CoreSave()

    @Published var data: UserSaveData {
        didSet { persist() }
    }

    private static var url: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? FileManager.default.temporaryDirectory
        return dir.appendingPathComponent("UserSaveData.json")
    }

    private init() {
        if let d = try? Data(contentsOf: Self.url), let s = try? UserSaveData.decode(d) {
            data = s
        } else {
            data = UserSaveData.newGame(seed: UInt64.random(in: 1...UInt64.max))
        }
        // Make sure every roster fighter has a progress entry (older saves / new fighters).
        for f in FighterRoster.all where data.fighters[f.id] == nil { data.fighters[f.id] = .init() }
    }

    private func persist() {
        guard let d = try? data.encoded() else { return }
        try? d.write(to: Self.url, options: .atomic)
    }

    var difficulty: Difficulty { Difficulty(rawValue: data.difficulty) ?? .standard }

    /// Enemy team scaled to the player's average level / stars.
    func enemyLoadouts(seed: UInt64) -> [FighterLoadout] {
        var rng = SplitMix64(seed: seed)
        let mine = data.teamLoadouts
        let lvl = mine.isEmpty ? 1 : mine.map(\.level).reduce(0, +) / mine.count
        let stars = mine.isEmpty ? 1 : max(1, mine.map(\.stars).reduce(0, +) / mine.count)
        var pool = FighterRoster.all
        var team: [FighterLoadout] = []
        for _ in 0..<3 where !pool.isEmpty {
            let d = pool.remove(at: rng.int(pool.count))
            team.append(FighterLoadout(def: d, level: lvl, stars: stars))
        }
        return team
    }
}
