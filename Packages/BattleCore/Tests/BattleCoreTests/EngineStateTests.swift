import XCTest
@testable import BattleCore

final class EngineStateTests: XCTestCase {
    private func engine() -> BattleEngine {
        BattleEngine(player: [FighterRoster.kai, FighterRoster.lan, FighterRoster.sera],
                     enemy: [FighterRoster.nova, FighterRoster.zero, FighterRoster.aegis])
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ seconds: Double, frame: Double = 1.0 / 60) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < seconds - 1e-9 {
            out += e.advance(frame)
            t += frame
        }
        return out
    }

    func testStartsAtMidRange() {
        let e = engine()
        XCTAssertEqual(e.zone, .mid)
        XCTAssertEqual(e.timer, 180)
    }

    func testFixedStepIsFrameRateIndependent() {
        var a = engine(), b = engine()
        run(&a, 2, frame: 1.0 / 60)
        run(&b, 2, frame: 1.0 / 120)
        XCTAssertEqual(a.time, b.time, accuracy: 1.0 / 60 + 1e-9)
        XCTAssertEqual(a.sides[0].ki, b.sides[0].ki, accuracy: 0.2)
    }

    func testLargeFrameIsClamped() {
        var e = engine()
        e.advance(5)                                   // e.g. app returning from background
        XCTAssertLessThanOrEqual(e.time, Tune.maxFrameDT + 1e-9)
    }

    func testKiRegeneratesAndChargingIsFaster() {
        var idle = engine(), charging = engine()
        let start = idle.sides[0].ki
        XCTAssertTrue(charging.apply(.chargeBegin, side: 0))
        run(&idle, 1)
        run(&charging, 1)
        XCTAssertEqual(idle.sides[0].ki - start, Tune.kiRegen, accuracy: 0.2)
        XCTAssertEqual(charging.sides[0].ki - start, Tune.chargeRate, accuracy: 0.6)
        XCTAssertTrue(charging.apply(.chargeEnd, side: 0))
        XCTAssertEqual(charging.sides[0].current.phase, .idle)
    }

    func testKiCapsAtMax() {
        var e = engine()
        e.apply(.chargeBegin, side: 0)
        run(&e, 5)
        XCTAssertEqual(e.sides[0].ki, Tune.kiMax)
    }

    func testSwipeUpAndDownChangeZones() {
        var e = engine()
        XCTAssertTrue(e.apply(.moveForward, side: 0))
        XCTAssertEqual(e.sides[0].current.phase, .moving)
        let ev = run(&e, 0.4)
        XCTAssertEqual(e.zone, .close)
        XCTAssertTrue(ev.contains(.zoneChanged(.close)))
        XCTAssertEqual(e.sides[0].current.phase, .idle)
        // Swipe up at close range dashes into the opponent's face.
        XCTAssertTrue(e.apply(.moveForward, side: 0))
        run(&e, 0.4)
        XCTAssertEqual(e.gap, Tune.dashGap, accuracy: 0.01)
        XCTAssertTrue(e.apply(.moveBack, side: 0))
        run(&e, 0.4)
        XCTAssertEqual(e.zone, .mid)
        e.apply(.moveBack, side: 0)
        run(&e, 0.4)
        XCTAssertEqual(e.zone, .long)
        XCTAssertFalse(e.apply(.moveBack, side: 0), "already at the farthest zone")
    }

    func testStunnedFighterCannotMoveOrCharge() {
        var e = engine()
        e.stun(side: 0, until: e.time + 0.5)
        XCTAssertFalse(e.apply(.moveForward, side: 0))
        XCTAssertFalse(e.apply(.chargeBegin, side: 0))
        let ki = e.sides[0].ki
        run(&e, 0.3)
        XCTAssertEqual(e.sides[0].ki, ki, "no Ki regen while stunned")
        run(&e, 0.3)
        XCTAssertEqual(e.sides[0].current.phase, .idle)
        XCTAssertTrue(e.apply(.chargeBegin, side: 0))
    }

    func testKOSwitchesToNextLivingTeammateAndEndsBattle() {
        var e = engine()
        var ev = e.damage(1e9, to: 1)
        XCTAssertTrue(ev.contains(.ko(side: 1, fighter: 0)))
        XCTAssertTrue(ev.contains(.switched(side: 1, to: 1)))
        XCTAssertEqual(e.sides[1].active, 1)
        XCTAssertEqual(e.sides[1].current.phase, .idle)
        _ = e.damage(1e9, to: 1)
        ev = e.damage(1e9, to: 1)
        XCTAssertTrue(ev.contains(.battleOver(winner: 0)))
        XCTAssertTrue(e.over)
        XCTAssertEqual(e.winner, 0)
        XCTAssertFalse(e.apply(.chargeBegin, side: 0), "no input after the battle ends")
    }

    func testTenacityKeepsOneHPOnce() {
        var e = BattleEngine(player: [FighterRoster.sera], enemy: [FighterRoster.kai])
        let ev = e.damage(1e9, to: 0)
        XCTAssertEqual(ev, [.tenacity(side: 0)])
        XCTAssertEqual(e.sides[0].current.hp, 1)
        _ = e.damage(1e9, to: 0)
        XCTAssertTrue(e.sides[0].current.isKO)
    }

    func testTimerPausesAndTimeUpPicksHigherDamage() {
        var e = engine()
        e.timerPaused = true
        run(&e, 1)
        XCTAssertEqual(e.timer, 180)
        e.timerPaused = false
        _ = e.damage(500, to: 1)
        var guardSteps = 0
        while !e.over && guardSteps < 20000 {
            e.advance(Tune.maxFrameDT)
            guardSteps += 1
        }
        XCTAssertTrue(e.over)
        XCTAssertEqual(e.winner, 0)
    }
}
