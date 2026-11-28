import XCTest
import UIKit
@testable import MoonAction

@MainActor
final class ElementAbilityTests: XCTestCase {
    func testCycleEachElementBeatsExactlyOneAndIsBeatenByOne() {
        for e in Element.allCases {
            XCTAssertNotEqual(e.beats, e)
            XCTAssertEqual(Element.allCases.filter { $0.beats == e }.count, 1)
        }
        // The five arrows form a single cycle.
        var seen: Set<Element> = []
        var e = Element.wood
        for _ in 0..<5 { seen.insert(e); e = e.beats }
        XCTAssertEqual(seen.count, 5)
        XCTAssertEqual(e, .wood)
    }

    func testMultipliers() {
        XCTAssertEqual(Element.multiplier(.water, .fire), Element.advantage)
        XCTAssertEqual(Element.multiplier(.fire, .water), Element.disadvantage)
        XCTAssertEqual(Element.multiplier(.fire, .wood), 1)
        XCTAssertEqual(Element.multiplier(.metal, .metal), 1)
    }

    func testAuraColorMapping() {
        XCTAssertEqual(Element.of(UIColor(hex: 0xFF6B5B)), .fire)
        XCTAssertEqual(Element.of(UIColor(hex: 0xF2C46D)), .earth)
        XCTAssertEqual(Element.of(UIColor(hex: 0x7EE2A8)), .wood)
        XCTAssertEqual(Element.of(UIColor(hex: 0x6FC3FF)), .water)
        XCTAssertEqual(Element.of(UIColor(hex: 0xF4F1DE)), .metal)
    }

    private func makeBattle() -> BattleScreen {
        let b = BattleScreen(playerIDs: ["kai", "luna", "rook"], enemyIDs: ["nyx", "blaze", "ivy"], enemyLevel: 1, stage: 1)
        b.ui.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        b.build()
        b.started = true
        b.damageVariance = { 1 }
        b.roll = { _ in false }
        return b
    }

    func testAbilityNeedsChargeAndIsSingleUse() {
        let b = makeBattle()
        XCTAssertFalse(b.useAbility(b.player), "not charged at battle start")
        b.timeline.tick(MainAbility.chargeTime + 0.1)
        b.player.current.busy = false
        b.player.current.stunUntil = 0
        XCTAssertTrue(b.useAbility(b.player))
        XCTAssertTrue(b.player.current.abilityUsed)
        b.timeline.tick(1)
        b.player.current.busy = false
        XCTAssertFalse(b.useAbility(b.player), "single use per fighter")
    }
}
