import XCTest
import UIKit
import BattleCore
@testable import MoonAction

/// Runs the BattleCore-driven 3D battle screen with AI on both sides, exercising the renderer,
/// event handling, HUD sync, cameras and scheduling (catches runtime crashes).
@MainActor
final class CoreBattleSmokeTests: XCTestCase {
    func testAutoBattleRunsWithoutCrashing() {
        let b = CoreBattleScreen(seed: 3)
        b.ui.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        b.build()
        b.setAuto(true)
        var frames = 0
        while frames < 60 * 120 && !b.isFinished {
            b.update(dt: 1.0 / 60)
            frames += 1
        }
        XCTAssertGreaterThan(b.engineState.time, 10)
        XCTAssertGreaterThan(b.engineState.sides[0].damageDealt + b.engineState.sides[1].damageDealt, 0)
    }

    func testEveryRosterPairBuilds() {
        for p in FighterRoster.all {
            let b = CoreBattleScreen(player: [p.id], enemy: [FighterRoster.all.reversed().first!.id], seed: 1)
            b.ui.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
            b.build()
            for _ in 0..<30 { b.update(dt: 1.0 / 60) }
        }
    }
}
