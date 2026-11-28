import XCTest
@testable import BattleCore

/// Full AI-vs-AI battles as edge-case / soak tests (KO mid-combo, clash, rush, gauges, timer).
final class AIBattleTests: XCTestCase {
    private func simulate(_ d0: Difficulty, _ d1: Difficulty, seed: UInt64) -> (BattleEngine, [BattleEvent]) {
        let p = [FighterLoadout(def: FighterRoster.kross), FighterLoadout(def: FighterRoster.kai), FighterLoadout(def: FighterRoster.lan)]
        let e = [FighterLoadout(def: FighterRoster.sephi), FighterLoadout(def: FighterRoster.nova), FighterLoadout(def: FighterRoster.sera)]
        var b = BattleEngine(player: p, enemy: e, seed: seed)
        var a0 = AIController(side: 0, difficulty: d0), a1 = AIController(side: 1, difficulty: d1)
        var all: [BattleEvent] = []
        var frames = 0
        while !b.over && frames < 60 * 400 {
            var ev = b.advance(1.0 / 60)
            a0.update(&b, &ev)
            a1.update(&b, &ev)
            all += ev
            frames += 1
            // Invariants every frame.
            for s in 0..<2 {
                XCTAssertGreaterThanOrEqual(b.sides[s].ki, 0)
                XCTAssertLessThanOrEqual(b.sides[s].ki, Tune.kiMax + 1e-9)
                XCTAssertTrue((0...7).contains(b.sides[s].orbs))
                for f in b.sides[s].team { XCTAssertGreaterThanOrEqual(f.hp, 0); XCTAssertLessThanOrEqual(f.hp, f.maxHP + 1e-6) }
                if !b.over { XCTAssertFalse(b.sides[s].current.isKO, "active fighter is never KO'd while the battle runs") }
            }
        }
        return (b, all)
    }

    func testBattlesFinishForEveryDifficulty() {
        for (i, d) in Difficulty.allCases.enumerated() {
            let (b, ev) = simulate(d, .standard, seed: UInt64(100 + i))
            XCTAssertTrue(b.over, "\(d) battle ended")
            XCTAssertTrue(ev.contains { if case .battleOver = $0 { return true }; return false })
            XCTAssertTrue(ev.contains { if case .hit = $0 { return true }; return false })
        }
    }

    func testChallengeAIUsesAdvancedSystems() {
        var seen = Set<String>()
        for seed in 1...4 {
            let (_, ev) = simulate(.challenge, .challenge, seed: UInt64(seed))
            for e in ev {
                switch e {
                case .comboRoute: seen.insert("route")
                case .vanished: seen.insert("vanish")
                case .tagged: seen.insert("switch")
                case .mainAbility: seen.insert("ability")
                case .gaugeTriggered, .autoEvaded: seen.insert("gauge")
                default: break
                }
            }
        }
        for k in ["route", "vanish", "ability", "gauge"] { XCTAssertTrue(seen.contains(k), "challenge AI used \(k)") }
    }
}
