import XCTest
@testable import BattleCore

final class ProgressionTests: XCTestCase {
    func testLevelAndStarFactors() {
        XCTAssertEqual(Progression.levelFactor(1), 1)
        XCTAssertEqual(Progression.levelFactor(5000), 10, accuracy: 1e-9)
        XCTAssertEqual(Progression.levelFactor(2500), 1 + 2499.0 / 4999 * 9, accuracy: 1e-9)
        XCTAssertEqual(Progression.starFactor(1), 1)
        XCTAssertEqual(Progression.starFactor(14), 1.39, accuracy: 1e-9)
    }

    func testBenchmarkIsLv5000SevenStars() {
        for f in FighterRoster.all {
            let s = Progression.baseStats(f, level: 5000, stars: 7)
            XCTAssertEqual(s.hp, f.benchmark.hp, accuracy: 0.5)
            XCTAssertEqual(s.strikeAtk, f.benchmark.strikeAtk, accuracy: 0.5)
            XCTAssertLessThan(Progression.baseStats(f, level: 1, stars: 1).hp, f.benchmark.hp / 11)
        }
    }

    func testZTiersAndLeaderRule() {
        XCTAssertEqual(ZAbility.tier(stars: 1), 0)
        XCTAssertEqual(ZAbility.tier(stars: 3), 1)
        XCTAssertEqual(ZAbility.tier(stars: 6), 2)
        XCTAssertEqual(ZAbility.tier(stars: 14), 3)
        // Leader Nova (mech warrior Z), then Lan (support Z) and Sera (star warrior Z).
        let team = [FighterLoadout(def: FighterRoster.nova, stars: 14), FighterLoadout(def: FighterRoster.lan, stars: 14),
                    FighterLoadout(def: FighterRoster.sera, stars: 14)]
        // Leader gets everyone's Z regardless of tags.
        XCTAssertEqual(TeamBuild.zBonus(for: 0, team: team), 0.28 + 0.22 + 0.22, accuracy: 1e-9)
        // Lan: leader's Z (always) + own Z (support) + Sera's Z (star warrior: Lan has the tag).
        XCTAssertEqual(TeamBuild.zBonus(for: 1, team: team), 0.28 + 0.22 + 0.22, accuracy: 1e-9)
        // Sera: leader's Z + own Z; Lan's support Z does not match Sera's tags.
        XCTAssertEqual(TeamBuild.zBonus(for: 2, team: team), 0.28 + 0.22, accuracy: 1e-9)
    }

    func testUltraAbility() {
        let ulLead = [FighterLoadout(def: FighterRoster.kross), FighterLoadout(def: FighterRoster.lan), FighterLoadout(def: FighterRoster.nova)]
        XCTAssertEqual(TeamBuild.ultraBonus(team: ulLead), 0.3)
        let stats = TeamBuild.finalStats(team: ulLead)
        XCTAssertTrue(stats.allSatisfy { $0.damageUp == 0.3 && $0.kiRecoveryUp >= 0.3 })
        // Not leader: +10 % per teammate sharing a tag (Lan shares Star Warrior with Kross, Nova does not).
        let ulBench = [FighterLoadout(def: FighterRoster.nova), FighterLoadout(def: FighterRoster.kross), FighterLoadout(def: FighterRoster.lan)]
        XCTAssertEqual(TeamBuild.ultraBonus(team: ulBench), 0.1, accuracy: 1e-9)
        XCTAssertEqual(TeamBuild.ultraBonus(team: [FighterLoadout(def: FighterRoster.lan)]), 0)
    }

    func testFinalAttackFormulaWithEquipment() {
        let item = EquipmentItem(id: 1, templateID: "eq.fist", rolls: [1, 1, 1])   // strike +16 %, +10 %, def +8 %
        let solo = [FighterLoadout(def: FighterRoster.sera, level: 5000, stars: 7, equipment: [item])]
        let f = TeamBuild.finalStats(team: solo)[0]
        let z = FighterRoster.sera.zAbility.value(stars: 7)
        XCTAssertEqual(f.strikeAtk, FighterRoster.sera.benchmark.strikeAtk * (1 + z + 0.26), accuracy: 1)
        XCTAssertEqual(f.defense, FighterRoster.sera.benchmark.defense * (1 + z + 0.08), accuracy: 1)
        // Low level: only the first slot is active.
        let low = TeamBuild.finalStats(team: [FighterLoadout(def: FighterRoster.sera, level: 10, stars: 1,
                                                             equipment: [item, EquipmentItem(id: 2, templateID: "eq.armor", rolls: [1, 1, 1])])])[0]
        XCTAssertEqual(low.damageCut, 0)
    }

    func testEquipmentBeadsGradesRestrictionsAndReforge() {
        XCTAssertEqual(EquipmentCatalog.all.count, 10)
        XCTAssertEqual(EquipmentItem.bead(0.5), .green)
        XCTAssertEqual(EquipmentItem.bead(0.8), .gold)
        XCTAssertEqual(EquipmentItem.bead(0.95), .red)
        XCTAssertEqual(EquipmentItem(id: 1, templateID: "eq.fist", rolls: [0.95, 0.96, 0.99]).grade, .godly)
        XCTAssertEqual(EquipmentItem(id: 1, templateID: "eq.fist", rolls: [1, 1, 0.5]).grade, .z)
        XCTAssertEqual(EquipmentItem(id: 1, templateID: "eq.fist", rolls: [0.1, 0.2, 0.3]).grade, .b)
        XCTAssertFalse(EquipmentCatalog.byID("eq.crown")!.canEquip(FighterRoster.lan))
        XCTAssertTrue(EquipmentCatalog.byID("eq.crown")!.canEquip(FighterRoster.kai))
        XCTAssertTrue(EquipmentCatalog.byID("eq.flame")!.canEquip(FighterRoster.kross))
        XCTAssertFalse(EquipmentCatalog.byID("eq.flame")!.canEquip(FighterRoster.sephi))
        var rng = SplitMix64(seed: 42)
        var item = EquipmentItem(id: 9, templateID: "eq.core", rolls: [0.5, 0.6, 0.7])
        for _ in 0..<50 {
            let before = item.rolls[2]
            item.reforge(slot: 2, secure: true, rng: &rng)
            XCTAssertGreaterThanOrEqual(item.rolls[2], before, "secure upgrade never rolls lower")
        }
        item.reforge(slot: 0, secure: false, rng: &rng)
        XCTAssertEqual(item.rolls[0], 0.5, "slot 1 cannot be reforged")
    }

    func testSaveRoundTripAndProgressionActions() throws {
        var s = UserSaveData.newGame()
        XCTAssertEqual(s.fighters.count, 6)
        XCTAssertEqual(s.levelUp("kai", by: 999), 999)
        XCTAssertEqual(s.progress("kai").level, 1000)
        XCTAssertTrue(s.starUp("kai"))
        XCTAssertEqual(s.progress("kai").stars, 2)
        s.maxLevel("sera")
        XCTAssertEqual(s.progress("sera").level, 5000)
        XCTAssertEqual(s.levelUp("sera", by: 10), 0, "clamped at Lv.5000")
        let fist = s.inventory[0].id
        XCTAssertTrue(s.equip(itemID: fist, to: "kai", slot: 1), "slot 2 unlocked at Lv.1000")
        XCTAssertFalse(s.equip(itemID: fist, to: "kai", slot: 2), "slot 3 needs Lv.3000")
        XCTAssertTrue(s.equip(itemID: fist, to: "sera", slot: 0))
        XCTAssertFalse(s.progress("kai").equipped.contains(fist), "moved, not duplicated")
        var rng = SplitMix64(seed: 3)
        XCTAssertTrue(s.reforge(itemID: fist, slot: 2, secure: false, rng: &rng))
        let data = try s.encoded()
        XCTAssertEqual(try UserSaveData.decode(data), s)
        XCTAssertEqual(s.teamLoadouts.count, 3)
    }

    func testLoadoutBattleUsesFinalStats() {
        let p = [FighterLoadout(def: FighterRoster.kross), FighterLoadout(def: FighterRoster.lan)]
        let e = [FighterLoadout(def: FighterRoster.nova, level: 1, stars: 1)]
        let b = BattleEngine(player: p, enemy: e)
        XCTAssertGreaterThan(b.sides[0].current.maxHP, FighterRoster.kross.benchmark.hp, "Z + leader bonuses apply")
        XCTAssertLessThan(b.sides[1].current.maxHP, FighterRoster.nova.benchmark.hp / 10)
    }
}
