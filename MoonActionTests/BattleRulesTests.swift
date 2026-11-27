import XCTest
import UIKit
@testable import MoonAction

/// Deterministic rule tests. Randomness is injected: `rolls` are consumed in order, then `false`.
@MainActor
final class BattleRulesTests: XCTestCase {
    private var rolls: [Bool] = []

    private func makeBattle() -> BattleScreen {
        let b = BattleScreen(playerIDs: ["kai", "luna", "rook"], enemyIDs: ["nyx", "blaze", "ivy"], enemyLevel: 1, stage: 1)
        b.ui.frame = CGRect(x: 0, y: 0, width: 390, height: 844)
        b.build()
        b.started = true
        b.damageVariance = { 1 }
        b.roll = { [unowned self] _ in self.rolls.isEmpty ? false : self.rolls.removeFirst() }
        return b
    }

    // MARK: P0-1 evade must succeed to avoid damage

    /// Normal cost: AI evade intent with exactly the normal cost succeeds once and costs once.
    func testAIEvadeNormalCostSucceeds() {
        let b = makeBattle()
        let t = b.enemy.current
        let hp = t.hp
        b.enemy.dodge = Tune.dodgeCost
        rolls = [true, true, false] // evade intent, lateral, not-perfect
        let hit = b.applyHit(from: b.player, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1)
        XCTAssertFalse(hit)
        XCTAssertEqual(t.hp, hp)
        XCTAssertEqual(b.enemy.dodge, 0, accuracy: 0.0001)
        XCTAssertEqual(b.enemy.counterUntil, 0)
    }

    /// In hitstun the escape costs double. Just below the double cost → the hit lands normally.
    func testAIEscapeBelowDoubleCostTakesTheHit() {
        let b = makeBattle()
        let t = b.enemy.current
        t.stunUntil = b.now + 1
        let hp = t.hp
        let gauge = Tune.dodgeCost * 2 - 0.01
        b.enemy.dodge = gauge
        rolls = [true, true, true]
        let hit = b.applyHit(from: b.player, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1)
        XCTAssertTrue(hit)
        XCTAssertLessThan(t.hp, hp)
        XCTAssertEqual(b.enemy.dodge, gauge, accuracy: 0.0001)     // nothing deducted
        XCTAssertEqual(b.enemy.counterUntil, 0)                     // no perfect-evade reward
        XCTAssertGreaterThan(t.stunUntil, b.now)                    // hit reaction applied
        XCTAssertEqual(b.player.comboCount, 1)
    }

    /// In hitstun with exactly the double cost → escape succeeds, double cost deducted once.
    func testAIEscapeExactDoubleCostSucceeds() {
        let b = makeBattle()
        let t = b.enemy.current
        t.stunUntil = b.now + 1
        let hp = t.hp
        b.enemy.dodge = Tune.dodgeCost * 2
        rolls = [true, true, false]
        let hit = b.applyHit(from: b.player, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1)
        XCTAssertFalse(hit)
        XCTAssertEqual(t.hp, hp)
        XCTAssertEqual(b.enemy.dodge, 0, accuracy: 0.0001)
        XCTAssertEqual(b.player.comboCount, 0)
    }

    /// Player AUTO follows the same real-cost rules.
    func testAutoPlayerEscapeBelowDoubleCostTakesTheHit() {
        let b = makeBattle()
        b.player.auto = true
        let t = b.player.current
        t.stunUntil = b.now + 1
        let hp = t.hp
        b.player.dodge = Tune.dodgeCost * 2 - 0.01
        rolls = [true, true, true]
        XCTAssertTrue(b.applyHit(from: b.enemy, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1))
        XCTAssertLessThan(t.hp, hp)
        XCTAssertEqual(b.player.counterUntil, 0)
    }

    func testAutoPlayerEscapeExactDoubleCostSucceeds() {
        let b = makeBattle()
        b.player.auto = true
        let t = b.player.current
        t.stunUntil = b.now + 1
        let hp = t.hp
        b.player.dodge = Tune.dodgeCost * 2
        rolls = [true, true, false]
        XCTAssertFalse(b.applyHit(from: b.enemy, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1))
        XCTAssertEqual(t.hp, hp)
        XCTAssertEqual(b.player.dodge, 0, accuracy: 0.0001)
    }

    func testInvulnerabilityCheckIsIndependent() {
        let b = makeBattle()
        let t = b.enemy.current
        let hp = t.hp
        t.invulnUntil = b.now + 1
        b.enemy.dodge = 0
        XCTAssertFalse(b.applyHit(from: b.player, power: 1, stun: 0.4, knock: 1, heavy: false, aiDodge: 1))
        XCTAssertEqual(t.hp, hp)
    }

    func testFailedManualDodgeChangesNothing() {
        let b = makeBattle()
        b.player.dodge = Tune.dodgeCost - 0.01
        let pos = b.player.current.pos
        XCTAssertFalse(b.dodge(b.player, lateral: 1))
        XCTAssertEqual(b.player.dodge, Tune.dodgeCost - 0.01, accuracy: 0.0001)
        XCTAssertEqual(b.player.current.invulnUntil, 0)
        XCTAssertEqual(b.player.current.pos, pos)
    }

    // MARK: P1-3 card status

    func testRejectedCardIsNotChargedOrRemoved() {
        let b = makeBattle()
        b.player.energy = 0
        let before = b.player.hand.map { $0?.id }
        XCTAssertFalse(b.playCard(b.player, 0))
        XCTAssertEqual(b.player.hand.map { $0?.id }, before)
        XCTAssertEqual(b.player.energy, 0)
        XCTAssertFalse(b.cardStatus(b.player, 0).playable)
    }

    func testCardStatusMatchesPlayability() {
        let b = makeBattle()
        b.player.energy = 100
        for i in 0..<4 where b.player.hand[i]?.kind == .effect { b.player.hand[i] = b.player.current.def.cards[0] }
        XCTAssertTrue(b.cardStatus(b.player, 0).playable)
        XCTAssertFalse(b.cardStatus(b.player, 0).chain)
        XCTAssertFalse(b.cardStatus(b.player, 0).chase)
    }

    // MARK: P1-4 relay chase

    private func launch(_ b: BattleScreen) {
        rolls = []
        XCTAssertTrue(b.applyHit(from: b.player, power: 0.05, stun: 0.7, knock: 9, heavy: true, aiDodge: 0))
        b.player.current.busy = true // still in the launcher's recovery
    }

    func testFullRelayChase() {
        let b = makeBattle()
        b.player.energy = 60
        launch(b)
        XCTAssertNotNil(b.player.relay)
        XCTAssertTrue(b.relayEligible(b.player, 1))
        XCTAssertTrue(b.relayEligible(b.player, 2))
        let energy = b.player.energy

        XCTAssertTrue(b.doRelay(b.player, 1))
        XCTAssertEqual(b.player.active, 1)
        XCTAssertEqual(b.player.energy, energy)                    // tag-in and draw cost nothing
        XCTAssertGreaterThan(b.player.swapReadyAt, b.now)          // normal cooldown started
        // A payable strike is in hand and lit as a chase.
        let idx = (0..<4).first { b.cardStatus(b.player, $0).chase }
        XCTAssertNotNil(idx)
        // Double tap on the other bench portrait: only the first legal switch counts.
        XCTAssertFalse(b.doRelay(b.player, 2))
        XCTAssertFalse(b.swap(b.player, to: 2, forced: false))
        XCTAssertEqual(b.player.active, 1)

        // The chase window outlives the original launch window by the relay grace.
        b.timeline.tick(Tune.relayGrace - 0.05)
        XCTAssertTrue(b.chaseAvailable(b.player))
        let card = b.player.hand[idx!]!
        XCTAssertTrue(b.playCard(b.player, idx!))
        XCTAssertEqual(b.player.energy, energy - Double(card.cost), accuracy: 0.0001)   // paid once, on play
        XCTAssertTrue(b.player.relay?.closed ?? true)
        XCTAssertFalse(b.isRelayChase(b.player))
    }

    func testRelayWindowEndsAfterGrace() {
        let b = makeBattle()
        b.player.energy = 60
        launch(b)
        XCTAssertTrue(b.doRelay(b.player, 1))
        b.timeline.tick(max(Tune.launchWindow, Tune.relayGrace) + 0.05)
        XCTAssertFalse(b.isRelayChase(b.player))
    }

    func testRelayNotOfferedWhenBenchKOCooldownOrEnergy() {
        let b = makeBattle()
        b.player.energy = 60
        launch(b)
        b.player.team[1].hp = 0
        XCTAssertFalse(b.relayEligible(b.player, 1))
        XCTAssertTrue(b.relayEligible(b.player, 2))
        b.player.swapReadyAt = b.now + 3
        XCTAssertFalse(b.relayEligible(b.player, 2))
        b.player.swapReadyAt = 0
        b.player.energy = 5
        XCTAssertFalse(b.relayEligible(b.player, 2))
    }

    func testRelayClosedWhenTargetReplaced() {
        let b = makeBattle()
        b.player.energy = 60
        launch(b)
        b.enemy.current.hp = 0
        XCTAssertFalse(b.relayEligible(b.player, 1))
        _ = b.swap(b.enemy, to: 1, forced: true)
        XCTAssertNil(b.validRelay(b.player))
        XCTAssertEqual(b.enemy.current.launchedUntil, 0)             // new enemy carries no mark
    }

    func testOtherCardClosesRelayChase() {
        let b = makeBattle()
        b.player.energy = 100
        launch(b)
        XCTAssertTrue(b.doRelay(b.player, 1))
        // Replace a non-strike option and play it instead.
        b.player.hand[0] = b.player.current.def.cards.first { $0.kind == .blast }
        XCTAssertTrue(b.playCard(b.player, 0))
        XCTAssertFalse(b.isRelayChase(b.player))
    }

    func testStaleRefillDoesNotOverwriteNewHand() {
        let b = makeBattle()
        b.player.energy = 100
        b.player.hand[0] = b.player.current.def.cards[0]
        XCTAssertTrue(b.playCard(b.player, 0))                       // schedules a refill for slot 0
        b.timeline.cancel(tag: b.player.current)
        b.player.current.busy = false
        _ = b.swap(b.player, to: 1, forced: true)
        let hand = b.player.hand.map { $0?.id }
        b.timeline.tick(1.0)
        XCTAssertEqual(b.player.hand.map { $0?.id }, hand)
    }

    func testEntrantHitClosesRelay() {
        let b = makeBattle()
        b.player.energy = 60
        launch(b)
        XCTAssertTrue(b.doRelay(b.player, 1))
        b.player.current.invulnUntil = 0
        rolls = []
        XCTAssertTrue(b.applyHit(from: b.enemy, power: 0.05, stun: 0.3, knock: 1, heavy: false, aiDodge: 0))
        XCTAssertFalse(b.isRelayChase(b.player))
    }
}
