import XCTest
@testable import BattleCore

final class UniqueGaugeTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 3)

    private func engine(_ p: FighterDef, _ e: FighterDef) -> BattleEngine {
        var b = BattleEngine(player: [p, FighterRoster.sera, FighterRoster.lan], enemy: [e, FighterRoster.lan, FighterRoster.sera])
        b.sides[0].ki = 100
        b.sides[1].ki = 100
        b.rng = SplitMix64(seed: 5)
        b.timerPaused = true
        return b
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ seconds: Double) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < seconds - 1e-9 { out += e.advance(1.0 / 60); t += 1.0 / 60 }
        return out
    }

    func testAttackGaugeBurstsAfterFourAttackCards() {
        var b = engine(FighterRoster.kai, FighterRoster.lan)
        var ev: [BattleEvent] = []
        for _ in 0..<4 {
            b.sides[0].ki = 100
            b.setHand(side: 0, slot: 0, card: strike)
            XCTAssertTrue(b.apply(.play(0), side: 0, events: &ev))
            ev += run(&b, 1.4)
        }
        XCTAssertTrue(ev.contains(.gaugeTriggered(side: 0, type: .attack)))
        XCTAssertEqual(b.sides[0].current.gauge, 0)
        XCTAssertGreaterThan(b.sides[0].coverNullUntil, b.time + 5, "10 s cover nullification")
        XCTAssertTrue(b.sides[0].hand.contains { $0?.card.kind == .special }, "drew a special")
        XCTAssertEqual(b.gaugeDamageBonus(0), Tune.attackBurstDamage)
    }

    func testAutoEvadeNegatesCardAndCosts35() {
        var b = engine(FighterRoster.kai, FighterRoster.sephi)
        b.sides[1].current.gauge = 100
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        let ev = run(&b, 0.8)
        XCTAssertTrue(ev.contains(.autoEvaded(side: 1)))
        XCTAssertEqual(b.sides[1].current.hp, b.sides[1].current.maxHP)
        XCTAssertEqual(b.sides[1].current.gauge, 65, accuracy: 6, "35 % spent (plus a little regen)")
        XCTAssertEqual(b.sides[1].current.vanish, Tune.vanishMax, "vanish gauge untouched")
    }

    func testAutoEvadeRegeneratesFasterWhileMoving() {
        var b = engine(FighterRoster.kai, FighterRoster.sephi)
        run(&b, 1)
        let idle = b.sides[1].current.gauge
        XCTAssertEqual(idle, Tune.autoEvadeRegen, accuracy: 0.2)
    }

    func testCounterGaugeKnocksAttackerAwayAtMostThreeTimes() {
        var b = engine(FighterRoster.kai, FighterRoster.kross)
        b.sides[1].current.gauge = 100
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        let ev = run(&b, 0.6)
        XCTAssertTrue(ev.contains(.gaugeTriggered(side: 1, type: .counter)))
        XCTAssertEqual(b.sides[1].current.hp, b.sides[1].current.maxHP)
        XCTAssertEqual(b.sides[1].current.counterUses, 1)
        XCTAssertTrue(b.sides[1].hand.contains { $0?.card.kind == .special })
        // Out of uses: the hit lands.
        run(&b, 1.5)
        b.sides[1].current.counterUses = Tune.counterMaxUses
        b.sides[1].current.gauge = 100
        b.sides[0].ki = 100
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        let ev2 = run(&b, 0.8)
        XCTAssertFalse(ev2.contains(.gaugeTriggered(side: 1, type: .counter)))
        XCTAssertLessThan(b.sides[1].current.hp, b.sides[1].current.maxHP)
    }

    func testCounterGaugeChargesPerHitTaken() {
        var b = engine(FighterRoster.kai, FighterRoster.kross)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        run(&b, 0.8)
        XCTAssertGreaterThanOrEqual(b.sides[1].current.gauge, 3 * Tune.counterPerHit)
    }

    func testReleaseGaugeEntersPermanentOverload() {
        var b = engine(FighterRoster.nova, FighterRoster.lan)
        b.sides[0].current.gauge = 95
        b.setHand(side: 0, slot: 0, card: strike)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(0), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.gaugeTriggered(side: 0, type: .release)))
        XCTAssertTrue(b.sides[0].current.overload)
        XCTAssertEqual(b.gaugeDamageBonus(0), Tune.overloadDamage)
        run(&b, 30)
        XCTAssertTrue(b.sides[0].current.overload, "permanent")
    }

    func testFightersWithoutGaugeNeverCharge() {
        var b = engine(FighterRoster.lan, FighterRoster.sera)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        run(&b, 1)
        XCTAssertEqual(b.sides[0].current.gauge, 0)
        XCTAssertEqual(b.sides[1].current.gauge, 0)
    }
}
