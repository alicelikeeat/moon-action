import XCTest
import simd
@testable import MoonAction

@MainActor
final class AnimationTests: XCTestCase {
    private func angle(_ m: FighterModel, _ j: Joint) -> SIMD3<Float> { m.joints[j]!.simdEulerAngles }

    private func step(_ m: FighterModel, _ seconds: Double) {
        var t = 0.0
        while t < seconds { m.animatorTick(1.0 / 120); t += 1.0 / 120 }
    }

    func testStrikeReachesImpactPoseOnImpactFrame() {
        let m = FighterModel(def: Roster.kai)
        let clip = m.attack(0)                      // jab
        step(m, clip.impact)
        XCTAssertEqual(angle(m, .shoulderL).x, -1.62, accuracy: 0.08, "arm extended at impact")
        XCTAssertEqual(angle(m, .elbowL).x, -0.05, accuracy: 0.1)
    }

    func testStrikeSettlesBackToGuard() {
        let m = FighterModel(def: Roster.kai)
        let clip = m.attack(1)                      // cross
        step(m, clip.duration + clip.blendOut + 0.4)
        for j in [Joint.shoulderR, .elbowR, .shoulderL] {
            XCTAssertEqual(angle(m, j).x, FighterModel.stancePose[j]!.x, accuracy: 0.12, "\(j) back in guard")
        }
        XCTAssertLessThan(abs(m.body.simdEulerAngles.y), 0.05)
    }

    func testSpinKickDoesNotUnwind() {
        let m = FighterModel(def: Roster.kai)
        let clip = Moves.spinKick
        m.play(clip)
        step(m, clip.duration + clip.blendOut + 0.3)
        XCTAssertLessThan(abs(m.body.simdEulerAngles.y), 0.05, "spin normalised to a whole turn")
    }

    func testZeroRateFreezesAnimation() {
        let m = FighterModel(def: Roster.kai)
        _ = m.attack(0)
        step(m, 0.03)
        let before = angle(m, .shoulderL)
        m.animRate = 0
        FighterModel.tickAll(0.2)
        XCTAssertEqual(angle(m, .shoulderL), before)
    }
}
