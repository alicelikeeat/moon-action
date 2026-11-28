import XCTest
@testable import BattleCore

final class MainAbilityTests: XCTestCase {
    private func engine(_ p: FighterDef, _ e: FighterDef = FighterRoster.lan) -> BattleEngine {
        var b = BattleEngine(player: [p, FighterRoster.sera, FighterRoster.lan], enemy: [e, FighterRoster.sera, FighterRoster.lan])
        b.rng = SplitMix64(seed: 3)
        return b
    }

    private func run(_ e: inout BattleEngine, _ seconds: Double) {
        var t = 0.0
        while t < seconds - 1e-9 { e.advance(1.0 / 60); t += 1.0 / 60 }
    }

    func testUnlocksAfterTimeAndOnlyOnce() {
        var b = engine(FighterRoster.kai)
        XCTAssertFalse(b.apply(.mainAbility, side: 0), "locked before 20 s")
        run(&b, 20.1)
        b.sides[0].current.hp = b.sides[0].current.maxHP * 0.5
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.mainAbility, side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.mainAbility(side: 0)))
        XCTAssertTrue(b.sides[0].hand.contains { $0?.card == FighterRoster.kai.ultimate }, "draws the ultimate")
        XCTAssertEqual(b.sides[0].current.hp, b.sides[0].current.maxHP * 0.75, accuracy: 1)
        XCTAssertEqual(b.sides[0].fastDrawUntil, .infinity)
        XCTAssertFalse(b.apply(.mainAbility, side: 0), "once per fighter")
    }

    func testSephiFillsGaugeAndDelaysEnemySwitch() {
        var b = engine(FighterRoster.sephi)
        run(&b, 25.1)
        let before = b.sides[1].switchReadyAt
        XCTAssertTrue(b.apply(.mainAbility, side: 0))
        XCTAssertEqual(b.sides[0].current.gauge, 100)
        XCTAssertGreaterThanOrEqual(b.sides[1].switchReadyAt, max(before, b.time) + 3 - 1e-9)
    }

    func testNovaTurnsHandIntoBlastsAndKrossPurges() {
        var b = engine(FighterRoster.nova)
        run(&b, 20.1)
        XCTAssertTrue(b.apply(.mainAbility, side: 0))
        XCTAssertEqual(b.sides[0].hand.compactMap { $0 }.filter { $0.card.kind == .blast }.count, 3)
        XCTAssertTrue(b.sides[0].hand.contains { $0?.card.kind == .ultimate })

        var k = engine(FighterRoster.kross, FighterRoster.lan)
        run(&k, 25.1)
        k.sides[1].current.statBonus = 0.2
        XCTAssertTrue(k.apply(.mainAbility, side: 0))
        XCTAssertEqual(k.sides[1].current.statBonus, 0)
    }

    func testLanTeamDamageAndSeraTransform() {
        var b = engine(FighterRoster.lan)
        run(&b, 15.1)
        XCTAssertTrue(b.apply(.mainAbility, side: 0))
        XCTAssertEqual(b.sides[0].teamDamageBonus(at: b.time + 19), 0.25)
        XCTAssertEqual(b.sides[0].teamDamageBonus(at: b.time + 21), 0)

        var s = engine(FighterRoster.sera)
        run(&s, 15.1)
        XCTAssertTrue(s.apply(.mainAbility, side: 0))
        XCTAssertEqual(s.sides[0].current.statBonus, 0.2, accuracy: 1e-9)
    }

    private func finishWithUltimate(_ p: FighterDef) -> [BattleEvent] {
        var b = BattleEngine(player: [p], enemy: [FighterRoster.lan])
        b.rng = SplitMix64(seed: 9)
        b.sides[0].ki = 100
        b.sides[1].current.hp = 1000
        b.setHand(side: 0, slot: 0, card: p.ultimate)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(0), side: 0, events: &ev))
        var t = 0.0
        while t < 3 && !b.over { ev += b.advance(1.0 / 60); t += 1.0 / 60 }
        XCTAssertEqual(b.winner, 0)
        return ev
    }

    func testLegendaryFinishOnlyForLLAndUL() {
        XCTAssertTrue(finishWithUltimate(FighterRoster.kai).contains(.legendaryFinish(side: 0)))
        XCTAssertTrue(finishWithUltimate(FighterRoster.kross).contains(.legendaryFinish(side: 0)))
        XCTAssertFalse(finishWithUltimate(FighterRoster.sera).contains(.legendaryFinish(side: 0)))
    }
}
