import XCTest
@testable import BattleCore

final class BattleEngineTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 3)

    private func engine() -> BattleEngine {
        var b = BattleEngine(player: [FighterRoster.sera, FighterRoster.kai, FighterRoster.lan],
                             enemy: [FighterRoster.lan, FighterRoster.sera, FighterRoster.kai])
        b.sides[0].ki = 100
        b.sides[1].ki = 100
        b.rng = SplitMix64(seed: 21)
        return b
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ seconds: Double) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < seconds - 1e-9 { out += e.advance(1.0 / 60); t += 1.0 / 60 }
        return out
    }

    private func startClash(_ b: inout BattleEngine) -> [BattleEvent] {
        b.setHand(side: 0, slot: 0, card: strike)
        b.setHand(side: 1, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        XCTAssertTrue(b.apply(.play(0), side: 1))
        return run(&b, 1.0 / 60)
    }

    func testSimultaneousStrikesClashAndPauseTheTimer() {
        var b = engine()
        let ev = startClash(&b)
        XCTAssertTrue(ev.contains { if case .clashStarted = $0 { return true }; return false })
        XCTAssertNotNil(b.clash)
        let timer = b.timer
        XCTAssertFalse(b.apply(.play(1), side: 0), "inputs locked during the clash")
        XCTAssertFalse(b.canSwitch(side: 0, to: 1))
        run(&b, 0.5)
        XCTAssertEqual(b.timer, timer, "timer paused")
    }

    func testClashBarSweepsZeroTo999() {
        let c = ClashState(start: 0, end: 3)
        XCTAssertEqual(c.bar(at: 0), 0)
        XCTAssertEqual(c.bar(at: 0.6), 999)
        XCTAssertEqual(c.bar(at: 1.2), 0)
        XCTAssertEqual(c.bar(at: 0.3), 500, accuracy: 1)
    }

    func testHigherClashScoreWinsAFreeHit() {
        var b = engine()
        _ = startClash(&b)
        // Lock side 0 near the top of the sweep, side 1 near the bottom.
        let start = b.clash!.start
        while b.time < start + 0.58 { b.advance(1.0 / 60) }
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.clashTap, side: 0, events: &ev))
        XCTAssertFalse(b.apply(.clashTap, side: 0), "locks once")
        while b.time < start + 1.2 { b.advance(1.0 / 60) }
        XCTAssertTrue(b.apply(.clashTap, side: 1, events: &ev))
        XCTAssertNil(b.clash)
        guard let resolved = ev.first(where: { if case .clashResolved = $0 { return true }; return false }),
              case .clashResolved(let w, let scores) = resolved else { return XCTFail("no resolution") }
        XCTAssertEqual(w, 0)
        XCTAssertGreaterThan(scores[0], scores[1])
        XCTAssertLessThan(b.sides[1].current.hp, b.sides[1].current.maxHP, "winner's free follow-up")
        XCTAssertEqual(b.sides[1].current.phase, .stunned)
    }

    func testClashWithoutTapsEndsInADraw() {
        var b = engine()
        _ = startClash(&b)
        let ev = run(&b, Tune.clashDuration + 0.1)
        XCTAssertTrue(ev.contains(.clashResolved(winner: nil, scores: [0, 0])))
        XCTAssertEqual(b.sides[0].current.hp, b.sides[0].current.maxHP)
    }

    func testStaggeredStrikesDoNotClash() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        run(&b, 0.4)
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        run(&b, 0.1)
        XCTAssertNil(b.clash)
    }

    func testRisingRushNeedsSevenOrbs() {
        var b = engine()
        b.sides[0].orbs = 6
        XCTAssertFalse(b.apply(.risingRush, side: 0))
        b.sides[0].orbs = 7
        XCTAssertTrue(b.apply(.risingRush, side: 0))
        XCTAssertEqual(b.sides[0].orbs, 0)
    }

    private func landRush(_ b: inout BattleEngine, pick: Int) -> [BattleEvent] {
        b.sides[0].orbs = 7
        XCTAssertTrue(b.apply(.risingRush, side: 0))
        XCTAssertTrue(b.apply(.rushPick(pick), side: 0))
        return run(&b, Tune.rushStartup + 0.05)
    }

    func testRushWrongGuessFinishes() {
        var b = engine()
        let ev = landRush(&b, pick: 2)
        XCTAssertTrue(ev.contains { if case .rushGuessing(1, _) = $0 { return true }; return false })
        XCTAssertFalse(b.canSwitch(side: 1, to: 1))
        var out: [BattleEvent] = []
        XCTAssertTrue(b.apply(.rushGuess(0), side: 1, events: &out))
        XCTAssertTrue(out.contains(.rushFinish(side: 0)))
        XCTAssertLessThan(b.sides[1].current.hp, b.sides[1].current.maxHP * 0.8, "massive damage")
    }

    func testRushRightGuessParries() {
        var b = engine()
        _ = landRush(&b, pick: 3)
        var out: [BattleEvent] = []
        XCTAssertTrue(b.apply(.rushGuess(3), side: 1, events: &out))
        XCTAssertTrue(out.contains(.rushParried(side: 1)))
        XCTAssertEqual(b.sides[1].current.hp, b.sides[1].current.maxHP)
        XCTAssertEqual(b.sides[0].current.phase, .stunned)
    }

    func testRushTimesOutIntoFinish() {
        var b = engine()
        _ = landRush(&b, pick: 1)
        let ev = run(&b, Tune.rushGuessTime + 0.1)
        XCTAssertTrue(ev.contains(.rushFinish(side: 0)))
    }

    func testVanishedRushMisses() {
        var b = engine()
        b.sides[0].orbs = 7
        XCTAssertTrue(b.apply(.risingRush, side: 0))
        b.sides[1].current.invulnUntil = b.time + 2
        let ev = run(&b, Tune.rushStartup + 0.05)
        XCTAssertTrue(ev.contains(.rushMissed(side: 0)))
        XCTAssertNil(b.rush)
    }
}
