import XCTest
@testable import MoonAction

final class GestureTests: XCTestCase {
    private let o = CGPoint(x: 100, y: 400)

    func testHorizontalSwipeFiresOnThresholdCrossingOnce() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertNil(g.moved(id: 1, to: CGPoint(x: 120, y: 402)))           // 20 pt: below threshold
        XCTAssertEqual(g.moved(id: 1, to: CGPoint(x: 131, y: 403)), .evade(lateral: 1)) // crosses 30 pt
        XCTAssertNil(g.moved(id: 1, to: CGPoint(x: 200, y: 403)))           // never twice
        XCTAssertNil(g.ended(id: 1, at: CGPoint(x: 200, y: 403)))           // no basic attack on lift
    }

    func testHoldAfterCommitNeverBecomesCharge() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertEqual(g.moved(id: 1, to: CGPoint(x: 60, y: 400)), .evade(lateral: -1))
        XCTAssertNil(g.tick(time: 1.0) { _ in CGPoint(x: 60, y: 400) })
        XCTAssertFalse(g.isCharging)
    }

    func testSlowCrossStillCommitsOnCrossing() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        // Moved 25 pt before the charge delay: not a charge (slop is 22) and not yet a swipe.
        XCTAssertNil(g.moved(id: 1, to: CGPoint(x: 100, y: 375)))
        XCTAssertNil(g.tick(time: 0.5) { _ in CGPoint(x: 100, y: 375) })
        XCTAssertEqual(g.moved(id: 1, to: CGPoint(x: 100, y: 368)), .dash)  // dy -32: up = dash in
    }

    func testDominantAxisLocksDirection() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertEqual(g.moved(id: 1, to: CGPoint(x: 112, y: 430)), .stepBack) // dy dominant, down
    }

    func testFastFlickWithoutMoveEventResolvesOnLift() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertEqual(g.ended(id: 1, at: CGPoint(x: 150, y: 405)), .evade(lateral: 1))
    }

    func testTapIsBasicAttack() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertEqual(g.ended(id: 1, at: CGPoint(x: 104, y: 402)), .basic)
    }

    func testLongPressChargesAndEndsWithoutAttack() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertNil(g.tick(time: 0.1) { _ in self.o })
        XCTAssertEqual(g.tick(time: 0.25) { _ in self.o }, .chargeStart)
        XCTAssertNil(g.moved(id: 1, to: CGPoint(x: 200, y: 400)))          // charge stays locked
        XCTAssertEqual(g.ended(id: 1, at: CGPoint(x: 200, y: 400)), .chargeEnd)
    }

    func testCancelNeverFiresAttack() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        XCTAssertNil(g.cancelled(id: 1))
        g.began(id: 2, at: o, time: 0)
        _ = g.tick(time: 0.3) { _ in self.o }
        XCTAssertEqual(g.cancelled(id: 2), .chargeEnd)
    }

    func testResetDropsOldTouches() {
        var g = ArenaGesture()
        g.began(id: 1, at: o, time: 0)
        g.reset()
        XCTAssertNil(g.moved(id: 1, to: CGPoint(x: 200, y: 400)))
        XCTAssertNil(g.ended(id: 1, at: CGPoint(x: 200, y: 400)))
        XCTAssertEqual(g.activeCount, 0)
    }
}
