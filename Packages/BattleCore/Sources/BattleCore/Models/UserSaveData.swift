import Foundation

/// Local progression save (UserSaveData.json): levels, stars, equipment inventory, materials, team.
public struct UserSaveData: Codable, Sendable, Equatable {
    public struct FighterProgress: Codable, Sendable, Equatable {
        public var level = 1
        public var stars = 1
        /// Equipped item ids by slot (up to 3).
        public var equipped: [Int] = []

        public init(level: Int = 1, stars: Int = 1, equipped: [Int] = []) {
            self.level = level
            self.stars = stars
            self.equipped = equipped
        }
    }

    public struct Materials: Codable, Sendable, Equatable {
        public var expBooks = 0         // 1 book = +1 level
        public var starSouls = 0
        public var reforgeStones = 0
    }

    public var version = 1
    public var fighters: [String: FighterProgress] = [:]
    public var inventory: [EquipmentItem] = []
    public var materials = Materials()
    /// Leader first, then two members.
    public var team: [String] = ["sera", "kai", "lan"]
    /// Up to three bench / support members.
    public var bench: [String] = ["kross", "sephi", "nova"]
    public var difficulty = "standard"
    public var nextItemID = 1
    public var wins = 0
    public var losses = 0

    public init() {}

    /// Fresh save: every roster fighter at Lv.1 / 1★, starter materials and two starter items.
    public static func newGame(seed: UInt64 = 0xC0FFEE) -> UserSaveData {
        var s = UserSaveData()
        for f in FighterRoster.all { s.fighters[f.id] = FighterProgress() }
        s.materials = Materials(expBooks: 2000, starSouls: 120, reforgeStones: 20)
        var rng = SplitMix64(seed: seed)
        s.grant(templateID: "eq.fist", rng: &rng)
        s.grant(templateID: "eq.core", rng: &rng)
        return s
    }

    // MARK: Persistence

    public func encoded() throws -> Data {
        let e = JSONEncoder()
        e.outputFormatting = [.sortedKeys]
        return try e.encode(self)
    }

    public static func decode(_ data: Data) throws -> UserSaveData { try JSONDecoder().decode(UserSaveData.self, from: data) }

    // MARK: Progression actions

    public func progress(_ id: String) -> FighterProgress { fighters[id] ?? FighterProgress() }

    /// Spend experience books to gain levels (clamped at Lv.5000). Returns levels gained.
    @discardableResult
    public mutating func levelUp(_ id: String, by n: Int) -> Int {
        var p = progress(id)
        let gain = max(0, min(n, materials.expBooks, Progression.maxLevel - p.level))
        p.level += gain
        materials.expBooks -= gain
        fighters[id] = p
        return gain
    }

    /// Testing convenience from the brief: jump straight to Lv.5000 (no cost).
    public mutating func maxLevel(_ id: String) {
        var p = progress(id)
        p.level = Progression.maxLevel
        fighters[id] = p
    }

    /// Limit break +1★ for star souls. Returns false if maxed or not enough souls.
    @discardableResult
    public mutating func starUp(_ id: String) -> Bool {
        var p = progress(id)
        let cost = Progression.starCost(from: p.stars)
        guard p.stars < Progression.maxStars, materials.starSouls >= cost else { return false }
        materials.starSouls -= cost
        p.stars += 1
        fighters[id] = p
        return true
    }

    @discardableResult
    public mutating func grant(templateID: String, rng: inout SplitMix64) -> EquipmentItem {
        let item = EquipmentItem.roll(templateID: templateID, id: nextItemID, rng: &rng)
        nextItemID += 1
        inventory.append(item)
        return item
    }

    /// Equip an item in a slot if the slot is unlocked, the restriction matches, and nobody else wears it.
    @discardableResult
    public mutating func equip(itemID: Int, to fighterID: String, slot: Int) -> Bool {
        guard let def = FighterRoster.byID(fighterID), let item = inventory.first(where: { $0.id == itemID }),
              let t = item.template, t.canEquip(def) else { return false }
        var p = progress(fighterID)
        guard slot >= 0, slot < Progression.equipmentSlots(level: p.level) else { return false }
        // Take it off anyone else first.
        for (k, var other) in fighters where k != fighterID { other.equipped.removeAll { $0 == itemID }; fighters[k] = other }
        p.equipped.removeAll { $0 == itemID }
        while p.equipped.count <= slot { p.equipped.append(-1) }
        p.equipped[slot] = itemID
        fighters[fighterID] = p
        return true
    }

    /// Reroll slot 2 / 3 of an item for one reforge stone (secure upgrade costs 3).
    @discardableResult
    public mutating func reforge(itemID: Int, slot: Int, secure: Bool, rng: inout SplitMix64) -> Bool {
        let cost = secure ? 3 : 1
        guard materials.reforgeStones >= cost, let i = inventory.firstIndex(where: { $0.id == itemID }), slot == 1 || slot == 2 else { return false }
        materials.reforgeStones -= cost
        inventory[i].reforge(slot: slot, secure: secure, rng: &rng)
        return true
    }

    /// Battle loadout for a fighter from this save.
    public func loadout(_ id: String) -> FighterLoadout? {
        guard let def = FighterRoster.byID(id) else { return nil }
        let p = progress(id)
        let items = p.equipped.compactMap { eid in inventory.first { $0.id == eid } }
        return FighterLoadout(def: def, level: p.level, stars: p.stars, equipment: items)
    }

    public var teamLoadouts: [FighterLoadout] { team.compactMap(loadout) }

    /// Rewards after a battle.
    public mutating func reward(won: Bool, rng: inout SplitMix64) -> (books: Int, souls: Int, stones: Int, item: EquipmentItem?) {
        let books = won ? 300 : 80, souls = won ? 12 : 3, stones = won ? 2 : 0
        materials.expBooks += books
        materials.starSouls += souls
        materials.reforgeStones += stones
        if won { wins += 1 } else { losses += 1 }
        var item: EquipmentItem?
        if won && rng.chance(0.5) {
            let t = EquipmentCatalog.all[rng.int(EquipmentCatalog.all.count)]
            item = grant(templateID: t.id, rng: &rng)
        }
        return (books, souls, stones, item)
    }
}
