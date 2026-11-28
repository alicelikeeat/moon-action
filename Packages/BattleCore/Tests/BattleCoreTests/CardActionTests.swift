import XCTest
@testable import BattleCore

final class CardActionTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 3)
    private let armored = ArtsCard(id: "t.sa", en: "SA", zh: "SA", kind: .strike, power: 1, hits: 3, superArmor: true)
    private let blast = ArtsCard(id: "t.b", en: "B", zh: "B", kind: .blast, power: 1, hits: 3)
    private let special = ArtsCard(id: "t.sp", en: "SP", zh: "SP", kind: .special, power: 2.5, hits: 6)

    private func engine(_ p: FighterDef = FighterRoster.kai, _ e: FighterDef = FighterRoster.lan, ki: Double = 100) -> BattleEngine {
        var b = BattleEngine(player: [p, FighterRoster.sera, FighterRoster.lan], enemy: [e, FighterRoster.sephi, FighterRoster.kross])
        b.sides[0].ki = ki
        b.sides[1].ki = ki
        b.rng = SplitMix64(seed: 99)
        return b
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ seconds: Double) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < seconds - 1e-9 {
            out += e.advance(1.0 / 60)
            t += 1.0 / 60
        }
        return out
    }

    private func hits(_ ev: [BattleEvent], by side: Int) -> [HitInfo] {
        ev.compactMap { if case .hit(let h) = $0, h.attacker == side { return h } else { return nil } }
    }

    // MARK: Hand & Ki

    func testPlayingCostsKiAndSlotRefillsAfterDrawSpeed() {
        var b = engine(ki: 50)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        XCTAssertEqual(b.sides[0].ki, 30, accuracy: 0.001)
        XCTAssertNil(b.sides[0].hand[0])
        run(&b, FighterRoster.kai.drawSpeed + 0.05)
        XCTAssertNotNil(b.sides[0].hand[0])
    }

    func testNotEnoughKiIsRejected() {
        var b = engine(ki: 10)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertFalse(b.canPlay(side: 0, slot: 0))
        XCTAssertFalse(b.apply(.play(0), side: 0))
        XCTAssertEqual(b.sides[0].ki, 10)
    }

    func testCardCosts() {
        let b = engine(FighterRoster.nova)
        XCTAssertEqual(b.cost(of: blast, side: 0), 30)
        XCTAssertEqual(b.cost(of: strike, side: 1), 20)
    }

    func testOrbCardsFillTheRushGauge() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike, orb: true)
        b.apply(.play(0), side: 0)
        XCTAssertEqual(b.sides[0].orbs, 1)
    }

    // MARK: Strike, lock, combo

    func testStrikeDashesInLandsEveryHitAndLocksTheDefender() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(0), side: 0, events: &ev))
        XCTAssertTrue(ev.contains { if case .dash = $0 { return true }; return false })
        ev = run(&b, 0.75)                             // dash in from mid range (6.5 m) then 3 hits
        XCTAssertTrue(ev.contains(.zoneChanged(.close)), "dashed in to close range (the last hit knocks back)")
        XCTAssertEqual(hits(ev, by: 0).count, 3)
        XCTAssertEqual(b.sides[1].current.phase, .stunned)
        // Locked: no vanish, cards or movement while being hit.
        b.sides[1].current.vanish = 100
        b.setHand(side: 1, slot: 0, card: strike)
        XCTAssertFalse(b.apply(.sidestep(1), side: 1))
        XCTAssertFalse(b.apply(.play(0), side: 1))
        XCTAssertFalse(b.apply(.moveBack, side: 1))
        XCTAssertLessThan(b.sides[1].current.hp, FighterRoster.lan.maxHP)
    }

    func testChainOnlyAfterLastHitAndComboCompensation() {
        var b = engine()
        for i in 0..<4 { b.setHand(side: 0, slot: i, card: strike) }
        b.apply(.play(0), side: 0)
        run(&b, 0.12)
        XCTAssertFalse(b.canPlay(side: 0, slot: 1), "not before the last hit")
        var damages: [Double] = []
        for slot in 1..<4 {
            var ev = run(&b, 0.6)
            damages.append(hits(ev, by: 0).map(\.damage).reduce(0, +))
            XCTAssertTrue(b.canPlay(side: 0, slot: slot) || b.sides[1].current.phase != .stunned)
            ev.removeAll()
            XCTAssertTrue(b.apply(.play(slot), side: 0), "chain card \(slot + 1)")
        }
        run(&b, 0.6)
        XCTAssertEqual(b.sides[0].comboCards, 4)
        XCTAssertEqual(b.sides[1].current.phase, .stunned, "locked through the whole chain")
    }

    func testComboEndsWhenDefenderRecovers() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        b.apply(.play(0), side: 0)
        run(&b, 0.5)
        XCTAssertGreaterThan(b.sides[0].comboHits, 0)
        let ev = run(&b, 1.5)
        XCTAssertTrue(ev.contains { if case .comboEnded(0, _) = $0 { return true }; return false })
        XCTAssertEqual(b.sides[0].comboHits, 0)
        XCTAssertNotEqual(b.sides[1].current.phase, .stunned)
    }

    // MARK: Warning & vanish

    func testWarningComesWithinWindowBeforeImpact() {
        var b = engine()
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        var warnedLead: Double?
        for _ in 0..<60 {
            for e in b.advance(1.0 / 60) { if case .warning(0, let lead) = e { warnedLead = lead } }
            if warnedLead != nil { break }
        }
        XCTAssertNotNil(warnedLead)
        XCTAssertLessThanOrEqual(warnedLead!, Tune.warningWindow.upperBound + 1e-9)
    }

    func testVanishInWindowCostsFullGaugeAndAttackerWhiffs() {
        var b = engine()
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        while (b.incomingThreat(on: 0) ?? 1) > 0.3 { b.advance(1.0 / 60) }
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.sidestep(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.vanished(side: 0)))
        XCTAssertTrue(ev.contains(.whiff(side: 1)))
        XCTAssertEqual(b.sides[0].current.vanish, 0, accuracy: 0.001)
        XCTAssertEqual(b.sides[1].current.phase, .stunned, "attacker left open")
        let after = run(&b, 0.8)
        XCTAssertTrue(hits(after, by: 1).isEmpty)
        XCTAssertEqual(b.sides[0].current.hp, FighterRoster.kai.maxHP)
    }

    func testSidestepWithoutThreatOrGaugeIsNotAVanish() {
        var b = engine()
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.sidestep(-1), side: 0, events: &ev))
        XCTAssertEqual(ev, [.sidestep(side: 0, dir: -1)])
        XCTAssertEqual(b.sides[0].current.vanish, Tune.vanishMax)
        // Empty gauge inside a window: just a sidestep, the hit lands.
        run(&b, 0.3)
        b.sides[0].current.vanish = 50
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        while (b.incomingThreat(on: 0) ?? 1) > 0.3 { b.advance(1.0 / 60) }
        ev.removeAll()
        b.apply(.sidestep(1), side: 0, events: &ev)
        XCTAssertFalse(ev.contains(.vanished(side: 0)))
        XCTAssertFalse(hits(run(&b, 0.8), by: 1).isEmpty)
    }

    func testVanishDodgesBlastShotsInFlight() {
        var b = engine()
        b.setHand(side: 1, slot: 0, card: blast)
        b.apply(.play(0), side: 1)
        while (b.incomingThreat(on: 0) ?? 1) > 0.3 { b.advance(1.0 / 60) }
        XCTAssertTrue(b.apply(.sidestep(1), side: 0))
        XCTAssertTrue(b.shots.filter { $0.target == 0 }.isEmpty)
    }

    // MARK: Blast vs strike

    func testBlastHitsLandAtRange() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: blast)
        b.apply(.play(0), side: 0)
        let ev = run(&b, 1.2)
        XCTAssertEqual(hits(ev, by: 0).count, 3)
    }

    func testArmoredStrikeBreaksThroughBlast() {
        var b = engine()
        b.moveGap(to: 11, over: 0.01)
        run(&b, 0.05)
        b.setHand(side: 1, slot: 0, card: blast)
        b.setHand(side: 0, slot: 0, card: armored)
        b.apply(.play(0), side: 1)
        run(&b, 0.25)                       // first shot out
        b.apply(.play(0), side: 0)          // armored dash through it
        let ev = run(&b, 0.6)
        XCTAssertTrue(ev.contains(.armorBreak(side: 0)) || hits(ev, by: 1).isEmpty)
        XCTAssertFalse(hits(ev, by: 0).isEmpty, "the armored strike still connects")
    }

    // MARK: Special / support

    func testSpecialPausesTimerDuringCinematic() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: special)
        let timer = b.timer
        b.apply(.play(0), side: 0)
        run(&b, 0.4)
        XCTAssertEqual(b.timer, timer, accuracy: 1e-9)
        run(&b, 1.0)
        XCTAssertLessThan(b.timer, timer)
    }

    func testSupportKiChargeShieldAndCounter() {
        var b = engine(ki: 20)
        b.setHand(side: 0, slot: 0, card: FighterRoster.kai.deck.first { $0.kind == .support }!)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        XCTAssertEqual(b.sides[0].ki, 20 - 15 + 35, accuracy: 0.01)
        XCTAssertEqual(b.sides[0].current.nextStrikeBonus, 0.3)

        var c = engine()
        c.setHand(side: 0, slot: 0, card: FighterRoster.nova.deck.first { $0.kind == .support }!)
        c.apply(.play(0), side: 0)
        run(&c, 0.4)
        c.setHand(side: 1, slot: 0, card: strike)
        c.apply(.play(0), side: 1)
        let ev = run(&c, 0.8)
        XCTAssertTrue(ev.contains(.countered(side: 0)))
        XCTAssertEqual(c.sides[0].current.hp, FighterRoster.kai.maxHP)
        XCTAssertEqual(c.sides[1].current.phase, .stunned)
    }

    // MARK: Edge cases

    func testKOMidComboSwitchesSafelyAndTheStringStopsHittingTheEntrant() {
        var b = engine()
        b.sides[1].current.hp = 1
        b.setHand(side: 0, slot: 0, card: strike)
        b.apply(.play(0), side: 0)
        let ev = run(&b, 1.0)
        XCTAssertTrue(ev.contains(.ko(side: 1, fighter: 0)))
        XCTAssertTrue(ev.contains(.switched(side: 1, to: 1)))
        XCTAssertEqual(b.sides[1].current.hp, FighterRoster.sephi.maxHP, "entrant protected")
        XCTAssertFalse(b.over)
    }

    func testAIvsAIPlaysWholeBattleWithoutStalling() {
        var b = engine(FighterRoster.kai, FighterRoster.nova, ki: 50)
        var p = AIController(side: 0, difficulty: .challenge)
        var e = AIController(side: 1, difficulty: .standard)
        var played = 0, hitsLanded = 0
        var steps = 0
        while !b.over && steps < 60 * 200 {
            var ev = b.advance(1.0 / 60)
            p.update(&b, &ev)
            e.update(&b, &ev)
            for x in ev {
                if case .cardPlayed = x { played += 1 }
                if case .hit = x { hitsLanded += 1 }
            }
            steps += 1
        }
        XCTAssertTrue(b.over, "battle resolves by KO or time-up")
        XCTAssertGreaterThan(played, 10)
        XCTAssertGreaterThan(hitsLanded, 20)
    }
}
