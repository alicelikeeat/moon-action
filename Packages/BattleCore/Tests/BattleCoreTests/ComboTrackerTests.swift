import XCTest
@testable import BattleCore

final class ComboTrackerTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 3)
    private let blast = ArtsCard(id: "t.b", en: "B", zh: "B", kind: .blast, power: 1, hits: 3)

    private func engine() -> BattleEngine {
        var b = BattleEngine(player: [FighterRoster.kai, FighterRoster.sera, FighterRoster.lan],
                             enemy: [FighterRoster.lan, FighterRoster.sephi, FighterRoster.kross])
        b.sides[0].ki = 100
        b.sides[1].ki = 100
        b.rng = SplitMix64(seed: 11)
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

    /// Run until the last card's final hit has landed (route timer start).
    @discardableResult
    private func runToCardEnd(_ e: inout BattleEngine) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var guardFrames = 0
        while let end = e.sides[0].combo.lastCardEnd, e.time < end + 1.0 / 60, guardFrames < 300 {
            out += e.advance(1.0 / 60)
            guardFrames += 1
        }
        return out
    }

    private func played(_ ev: [BattleEvent]) -> [Int] {
        ev.compactMap { if case .cardPlayed(0, _, let i) = $0 { return i } else { return nil } }
    }

    func testInputBufferChainsSeamlessly() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        b.setHand(side: 0, slot: 1, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        let last = b.sides[0].current.action!.lastHitTime
        while b.time < last - 0.2 { b.advance(1.0 / 60) }
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(1), side: 0, events: &ev), "pressed 0.2 s early: buffered")
        XCTAssertEqual(ev, [.inputBuffered(side: 0, slot: 1)])
        ev = run(&b, 0.3)
        XCTAssertEqual(played(ev), [2], "fires on the recovery frame as the 2nd combo card")
        XCTAssertEqual(b.sides[1].current.phase, .stunned)
    }

    func testTooEarlyIsNotBuffered() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        b.setHand(side: 0, slot: 1, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        XCTAssertFalse(b.apply(.play(1), side: 0))
    }

    func testSideStepComboGivesKiVanishAndDraw() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        runToCardEnd(&b)
        b.sides[0].current.vanish = 50
        b.setHand(side: 0, slot: 1, card: strike)
        let refill = b.sides[0].refillAt[0]!
        XCTAssertTrue(b.apply(.moveForward, side: 0))
        run(&b, 0.1)
        XCTAssertTrue(b.apply(.sidestep(1), side: 0))
        run(&b, 0.1)
        let ki = b.sides[0].ki
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.comboRoute(side: 0, route: .sideStep)))
        XCTAssertEqual(played(ev), [2], "combo continues")
        XCTAssertEqual(b.sides[0].ki, ki - 20 + Tune.sideStepKi, accuracy: 0.01)
        XCTAssertEqual(b.sides[0].current.vanish, 60, accuracy: 1.5)
        XCTAssertEqual(b.sides[0].refillAt[0]!, refill - Tune.sideStepDraw, accuracy: 1e-9)
    }

    func testChargeStepAfterBlast() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: blast)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        runToCardEnd(&b)
        XCTAssertEqual(b.sides[1].current.phase, .stunned)
        b.setHand(side: 0, slot: 1, card: strike)
        XCTAssertTrue(b.apply(.moveForward, side: 0))
        XCTAssertTrue(b.apply(.chargeBegin, side: 0))
        run(&b, 0.3)
        let ki = b.sides[0].ki
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.play(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.comboRoute(side: 0, route: .chargeStep)))
        XCTAssertEqual(b.sides[0].ki, ki - 20 + Tune.chargeStepKi, accuracy: 0.01)
    }

    func testDropComboFreesDefenderAndResetsCount() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        runToCardEnd(&b)
        XCTAssertTrue(b.apply(.moveForward, side: 0))
        XCTAssertTrue(b.apply(.chargeBegin, side: 0))
        let ev = run(&b, 0.5)
        XCTAssertTrue(ev.contains(.comboDropped(side: 0)))
        XCTAssertEqual(b.sides[1].current.phase, .idle)
        XCTAssertEqual(b.sides[0].comboCards, 0)
        // Defender is free: a cover change now is a plain switch, not a cover.
        var sw: [BattleEvent] = []
        XCTAssertTrue(b.apply(.switchTo(1), side: 1, events: &sw))
        XCTAssertTrue(sw.contains { if case .tagged(1, 1, false, false) = $0 { return true }; return false })
    }
}
