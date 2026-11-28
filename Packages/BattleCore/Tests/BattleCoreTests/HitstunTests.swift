import XCTest
@testable import BattleCore

final class HitstunTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 3)

    private func engine() -> BattleEngine {
        var b = BattleEngine(player: [FighterRoster.kai, FighterRoster.sera, FighterRoster.lan],
                             enemy: [FighterRoster.lan, FighterRoster.sephi, FighterRoster.kross])
        b.sides[0].ki = 100
        b.sides[1].ki = 100
        b.rng = SplitMix64(seed: 7)
        return b
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ seconds: Double) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < seconds - 1e-9 { out += e.advance(1.0 / 60); t += 1.0 / 60 }
        return out
    }

    func testFrameDurations() {
        XCTAssertEqual(Hitstun.light.duration, 0.30, accuracy: 1e-9)
        XCTAssertEqual(Hitstun.combo.duration, 28.0 / 60, accuracy: 1e-9)
        XCTAssertEqual(Hitstun.heavy.duration, 40.0 / 60, accuracy: 1e-9)
        XCTAssertTrue(Hitstun.stun.isAilment)
        XCTAssertFalse(Hitstun.heavy.isAilment)
    }

    func testOpeningJabIsLightThenComboThenHeavyWithRecovery() {
        var b = engine()
        b.moveGap(to: 2.2, over: 0.01)
        run(&b, 0.05)
        XCTAssertTrue(b.apply(.tap, side: 0))
        var ev = run(&b, 0.3)
        let first = ev.compactMap { if case .hit(let h) = $0 { return h } else { return nil } }.first
        XCTAssertEqual(first?.stun, .light)
        // A full card: inner hits are combo stun, the last is a heavy knockback.
        run(&b, 0.6)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0))
        ev = run(&b, 0.8)
        let hs = ev.compactMap { if case .hit(let h) = $0, h.attacker == 0 { return h } else { return nil } }
        XCTAssertEqual(hs.count, 3)
        XCTAssertEqual(hs.last?.stun, .heavy)
        XCTAssertTrue(hs.dropLast().allSatisfy { $0.stun == .combo || $0.stun == .light })
        ev += run(&b, 0.8)
        XCTAssertTrue(ev.contains(.recovered(side: 1)), "air recovery after heavy knockback")
        XCTAssertEqual(b.sides[1].current.phase, .idle)
    }

    func testStatusStunBlocksSwitchingButHitstunAllowsCover() {
        var b = engine()
        var ev: [BattleEvent] = []
        b.stun(side: 1, until: b.time + 0.4, type: .combo)
        XCTAssertTrue(b.canSwitch(side: 1, to: 1), "cover change allowed in hitstun")
        b.applyStun(side: 1, duration: 2.5, &ev)
        XCTAssertTrue(ev.contains(.stunApplied(side: 1, duration: 2.5)))
        XCTAssertFalse(b.canSwitch(side: 1, to: 1), "no switching while stunned")
        // A hit during the stun does not downgrade it.
        b.stun(side: 1, until: b.time + 0.3, type: .combo)
        XCTAssertEqual(b.sides[1].current.hitstun, .stun)
        run(&b, 2.6)
        XCTAssertEqual(b.sides[1].current.phase, .idle)
        XCTAssertTrue(b.canSwitch(side: 1, to: 1))
    }

    func testParalysisJoltsAboutAQuarterOfSeconds() {
        var b = engine()
        var ev: [BattleEvent] = []
        b.paralyze(side: 1, duration: 200, &ev)
        XCTAssertTrue(ev.contains(.paralyzed(side: 1, duration: 200)))
        b.timerPaused = true
        let out = run(&b, 160)
        let jolts = out.filter { $0 == .paralysisJolt(side: 1) }.count
        XCTAssertTrue((20...60).contains(jolts), "≈25 % of 160 checks, got \(jolts)")
    }

    func testForwardDashIsQuickAndBackDashHasRecovery() {
        var b = engine()
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.moveForward, side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.stepped(side: 0, forward: true, duration: 0.28)))
        run(&b, 0.3)
        XCTAssertTrue(b.sides[0].current.canAct)
        run(&b, 0.5)
        ev = []
        XCTAssertTrue(b.apply(.moveBack, side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.stepped(side: 0, forward: false, duration: Tune.moveTime)))
        run(&b, Tune.moveTime + 0.05)
        XCTAssertFalse(b.sides[0].current.canAct, "0.15 s recovery after a back dash")
        XCTAssertFalse(b.apply(.tap, side: 0))
        run(&b, 0.15)
        XCTAssertTrue(b.sides[0].current.canAct)
    }

    func testDashCancelIntoCard() {
        var b = engine()
        XCTAssertTrue(b.apply(.moveForward, side: 0))
        run(&b, 0.1)
        b.setHand(side: 0, slot: 0, card: strike)
        XCTAssertTrue(b.apply(.play(0), side: 0), "a forward dash can be cancelled by a card")
    }
}
