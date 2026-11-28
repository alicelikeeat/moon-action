import XCTest
@testable import BattleCore

final class CombatMathTests: XCTestCase {
    func testElementWheelIsOneCycleAndLightIsNeutral() {
        let wheel: [Element] = [.red, .yel, .pur, .grn, .blu]
        for (i, e) in wheel.enumerated() {
            XCTAssertEqual(e.beats, wheel[(i + 1) % wheel.count])
        }
        XCTAssertNil(Element.lgt.beats)
        for e in Element.allCases where e != .lgt {
            XCTAssertEqual(Element.damageMultiplier(attacker: .lgt, defender: e), 1)
            XCTAssertEqual(Element.damageMultiplier(attacker: e, defender: .lgt), 1)
        }
    }

    func testElementMultipliers() {
        XCTAssertEqual(Element.damageMultiplier(attacker: .red, defender: .yel), 1.5)   // advantage +50%
        XCTAssertEqual(Element.damageMultiplier(attacker: .yel, defender: .red), 0.7)   // into advantage -30%
        XCTAssertEqual(Element.damageMultiplier(attacker: .red, defender: .pur), 1)
        XCTAssertEqual(Element.matchup(attacker: .blu, defender: .red), .advantage)
        XCTAssertEqual(Element.matchup(attacker: .red, defender: .blu), .disadvantage)
    }

    func testComboCompensation() {
        let expected: [Double] = [1, 1, 1, 0.9, 0.8, 0.7, 0.6, 0.6, 0.6]
        for (i, v) in expected.enumerated() {
            XCTAssertEqual(CombatMath.comboScale(cardIndex: i + 1), v, accuracy: 1e-9, "card \(i + 1)")
        }
    }

    func testDamageScalesWithElementComboCritAndShield() {
        func d(_ a: Element = .lgt, _ b: Element = .lgt, card: Int = 1, crit: Bool = false, red: Double = 0) -> Double {
            CombatMath.damage(power: 1, attack: 2500, defense: 1000, attacker: a, defender: b, cardIndex: card, crit: crit, reduction: red)
        }
        let base = d()
        XCTAssertGreaterThan(base, 0)
        XCTAssertEqual(d(.red, .yel), (base * 1.5).rounded(), accuracy: 1)
        XCTAssertEqual(d(.yel, .red), (base * 0.7).rounded(), accuracy: 1)
        XCTAssertEqual(d(card: 5), (base * 0.8).rounded(), accuracy: 1)
        XCTAssertEqual(d(crit: true), (base * 1.5).rounded(), accuracy: 1)
        XCTAssertEqual(d(red: 0.4), (base * 0.6).rounded(), accuracy: 1)
        XCTAssertEqual(d(red: 2), 0)
    }

    func testZones() {
        XCTAssertEqual(Zone.of(2.6), .close)
        XCTAssertEqual(Zone.of(6.2), .mid)
        XCTAssertEqual(Zone.of(11), .long)
        XCTAssertEqual(Zone.mid.closer, .close)
        XCTAssertEqual(Zone.close.closer, .close)
        XCTAssertEqual(Zone.long.farther, .long)
    }

    func testRosterCoversEveryElementAndCardCosts() {
        XCTAssertEqual(FighterRoster.all.count, 6)
        XCTAssertEqual(Set(FighterRoster.all.map(\.element)), Set(Element.allCases))
        XCTAssertEqual(Set(FighterRoster.all.map(\.id)).count, 6)
        for f in FighterRoster.all {
            for c in f.deck {
                switch c.kind {
                case .strike: XCTAssertEqual(c.cost, 20)
                case .blast: XCTAssertEqual(c.cost, 30)
                case .special: XCTAssertEqual(c.cost, 50)
                case .support: XCTAssertTrue((15...20).contains(c.cost)); XCTAssertNotNil(c.support)
                case .ultimate: XCTFail("ultimates are not in decks")
                }
            }
            XCTAssertEqual(f.ultimate.kind, .ultimate)
            XCTAssertEqual(f.ultimate.cost, 20)
        }
        XCTAssertEqual(FighterRoster.nova.blastDiscount, 5)
    }
}
