import XCTest
@testable import BattleCore

final class SwitchTests: XCTestCase {
    private let strike = ArtsCard(id: "t.s", en: "S", zh: "S", kind: .strike, power: 1, hits: 4)

    private func engine(_ team: [FighterDef] = [FighterRoster.lan, FighterRoster.kai, FighterRoster.kross]) -> BattleEngine {
        var b = BattleEngine(player: team, enemy: [FighterRoster.nova, FighterRoster.sephi, FighterRoster.sera], seed: 5)
        b.sides[0].ki = 50
        b.sides[1].ki = 100
        return b
    }

    @discardableResult
    private func run(_ e: inout BattleEngine, _ s: Double) -> [BattleEvent] {
        var out: [BattleEvent] = []
        var t = 0.0
        while t < s - 1e-9 { out += e.advance(1.0 / 60); t += 1.0 / 60 }
        return out
    }

    func testSwitchStartsCooldownAndRefreshesHand() {
        var b = engine()
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.switchTo(1), side: 0, events: &ev))
        XCTAssertEqual(b.sides[0].active, 1)
        XCTAssertTrue(ev.contains(.tagged(side: 0, to: 1, cover: false, special: false)))
        XCTAssertTrue(b.sides[0].hand.allSatisfy { $0 != nil })
        XCTAssertTrue(b.sides[0].hand.compactMap { $0?.card.id }.allSatisfy { $0.hasPrefix("kai.") })
        XCTAssertEqual(b.switchCooldown(side: 0), Tune.switchCooldown, accuracy: 0.01)
        XCTAssertFalse(b.apply(.switchTo(2), side: 0), "cooldown")
        run(&b, Tune.switchCooldown + 0.05)
        XCTAssertTrue(b.canSwitch(side: 0, to: 2))
    }

    func testCannotSwitchToKOOrSelf() {
        var b = engine()
        b.sides[0].team[1].hp = 0
        b.sides[0].team[1].phase = .ko
        XCTAssertFalse(b.canSwitch(side: 0, to: 1))
        XCTAssertFalse(b.canSwitch(side: 0, to: 0))
        XCTAssertTrue(b.canSwitch(side: 0, to: 2))
    }

    func testSwitchOutKiPassive() {
        var b = engine()
        XCTAssertTrue(b.apply(.switchTo(1), side: 0))       // Lan leaves: +30 Ki
        XCTAssertEqual(b.sides[0].ki, 80, accuracy: 0.01)
    }

    func testCoverChangeInterruptsTheCombo() {
        var b = engine([FighterRoster.lan, FighterRoster.nova, FighterRoster.sephi])     // Nova: blast cover only
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        run(&b, 0.35)                                       // first hits land
        XCTAssertEqual(b.sides[0].current.phase, .stunned)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.switchTo(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.tagged(side: 0, to: 1, cover: true, special: false)))
        XCTAssertNil(b.sides[1].current.action, "attacker's card interrupted")
        XCTAssertEqual(b.sides[1].comboHits, 0)
        let hp = b.sides[0].current.hp
        run(&b, 0.5)
        XCTAssertEqual(b.sides[0].current.hp, hp, "entrant not hit by the rest of the string")
    }

    func testSpecialCoverKnocksAttackerAwayOncePerCombo() {
        var b = engine([FighterRoster.lan, FighterRoster.kai, FighterRoster.kross])   // Kai: strike cover
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        run(&b, 0.35)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.switchTo(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.tagged(side: 0, to: 1, cover: true, special: true)))
        XCTAssertEqual(b.sides[1].current.phase, .stunned)
        run(&b, 0.4)
        XCTAssertEqual(b.zone, .long)
    }

    func testCoverNullificationBlocksSpecialCover() {
        var b = engine([FighterRoster.lan, FighterRoster.kai, FighterRoster.kross])
        b.setHand(side: 1, slot: 1, card: FighterRoster.kross.deck.first { $0.kind == .support }!)   // +30 Ki, 10 s cover null
        XCTAssertTrue(b.apply(.play(1), side: 1))
        run(&b, 0.4)
        b.setHand(side: 1, slot: 0, card: strike)
        b.apply(.play(0), side: 1)
        run(&b, 0.35)
        var ev: [BattleEvent] = []
        XCTAssertTrue(b.apply(.switchTo(1), side: 0, events: &ev))
        XCTAssertTrue(ev.contains(.tagged(side: 0, to: 1, cover: true, special: false)), "cover null: plain cover only")
    }

    func testStunnedCanCoverButActingCannotSwitch() {
        var b = engine()
        b.setHand(side: 0, slot: 0, card: strike)
        b.apply(.play(0), side: 0)
        XCTAssertFalse(b.canSwitch(side: 0, to: 1), "not in the middle of our own card")
        b.stun(side: 0, until: b.time + 1)
        XCTAssertTrue(b.canSwitch(side: 0, to: 1))
    }
}
