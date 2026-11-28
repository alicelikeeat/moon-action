import XCTest
@testable import BattleCore

final class CombatMathTests: XCTestCase {
    func testElementWheelIsOneCycleAndLightIsNeutral() {
        let wheel: [Element] = [.red, .yel, .pur, .grn, .blu]
        for (i, e) in wheel.enumerated() { XCTAssertEqual(e.beats, wheel[(i + 1) % wheel.count]) }
        XCTAssertNil(Element.lgt.beats)
        for e in Element.allCases where e != .lgt {
            XCTAssertEqual(Element.damageMultiplier(attacker: .lgt, defender: e), 1)
            XCTAssertEqual(Element.damageMultiplier(attacker: e, defender: .lgt), 1)
        }
        XCTAssertEqual(Element.damageMultiplier(attacker: .red, defender: .yel), 1.5)
        XCTAssertEqual(Element.damageMultiplier(attacker: .yel, defender: .red), 0.7)
    }

    func testComboCompensationTable() {
        let expected: [Double] = [1, 0.95, 0.85, 0.75, 0.65, 0.5, 0.5, 0.5]
        for (i, v) in expected.enumerated() {
            XCTAssertEqual(CombatMath.comboScale(cardIndex: i + 1), v, accuracy: 1e-12, "card \(i + 1)")
        }
    }

    func testLayeredFormulaExactly() {
        // Raw = 200000 × 1.2 − 100000 × 0.55 = 185000
        let base = CombatMath.damage(attack: 200_000, cardMultiplier: 1.2, defense: 100_000, attacker: .lgt, defender: .lgt)
        XCTAssertEqual(base, 185_000)
        // Buff = (1 + 0.3) × max(0.2, 1 − max(0, 0.4 − 0.1)) = 1.3 × 0.7 = 0.91
        let buffed = CombatMath.damage(attack: 200_000, cardMultiplier: 1.2, defense: 100_000, damageUp: 0.3, damageCut: 0.4,
                                       cutPenetration: 0.1, attacker: .lgt, defender: .lgt)
        XCTAssertEqual(buffed, 185_000 * 1.3 * 0.7, accuracy: 1)
        // Cut floor 0.2
        let floored = CombatMath.damage(attack: 200_000, cardMultiplier: 1.2, defense: 100_000, damageCut: 2, attacker: .lgt, defender: .lgt)
        XCTAssertEqual(floored, Double(Int(185_000 * 0.2)))
        // Element × combo × crit × variance
        let all = CombatMath.damage(attack: 200_000, cardMultiplier: 1.2, defense: 100_000, attacker: .red, defender: .yel,
                                    cardIndex: 3, crit: true, variance: 1.03)
        XCTAssertEqual(all, Double(Int(185_000 * 1.5 * 0.85 * 1.25 * 1.03)))
        // Raw never below 1
        XCTAssertEqual(CombatMath.damage(attack: 10, cardMultiplier: 1, defense: 1_000_000, attacker: .lgt, defender: .lgt), 1)
    }

    func testZones() {
        XCTAssertEqual(Zone.of(2.2), .close)
        XCTAssertEqual(Zone.of(6.5), .mid)
        XCTAssertEqual(Zone.of(12), .long)
        XCTAssertEqual(Zone.mid.closer, .close)
        XCTAssertEqual(Zone.long.farther, .long)
    }

    func testRosterTwoULTwoLLTwoSPEveryElementAndCardCosts() {
        let r = FighterRoster.all
        XCTAssertEqual(r.count, 6)
        XCTAssertEqual(r.filter { $0.rarity == .ul }.map(\.id), ["kross", "sephi"])
        XCTAssertEqual(r.filter { $0.rarity == .ll }.map(\.id), ["kai", "nova"])
        XCTAssertEqual(r.filter { $0.rarity == .sp }.map(\.id), ["lan", "sera"])
        XCTAssertEqual(Set(r.map(\.element)), Set(Element.allCases))
        XCTAssertEqual(FighterRoster.kai.element, .pur)
        for f in r {
            for c in f.deck {
                switch c.kind {
                case .strike: XCTAssertEqual(c.cost, 20); XCTAssertEqual(c.hits, 4)
                case .blast: XCTAssertEqual(c.cost, 30); XCTAssertEqual(c.hits, 6)
                case .special: XCTAssertEqual(c.cost, 50)
                case .support: XCTAssertTrue((15...20).contains(c.cost)); XCTAssertNotNil(c.support)
                case .ultimate: XCTFail("ultimates are not in decks")
                }
            }
            XCTAssertEqual(f.ultimate.cost, 20)
        }
        XCTAssertEqual(FighterRoster.kross.gauge, .counter)
        XCTAssertEqual(FighterRoster.sephi.gauge, .autoEvade)
        XCTAssertEqual(FighterRoster.kai.gauge, .attack)
        XCTAssertEqual(FighterRoster.nova.gauge, .release)
        XCTAssertNil(FighterRoster.lan.gauge)
        XCTAssertTrue(FighterRoster.kai.deck.contains { $0.superArmor })
    }
}
