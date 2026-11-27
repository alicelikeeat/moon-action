import Foundation
import simd

extension BattleScreen {
    func strafe(_ s: Side, lateral: Float) {
        guard canAct(s) else { return }
        let c = s.current
        let t = opponent(of: s).current
        let rel = c.pos - t.pos
        let ang = lateral * 0.35
        let dest = t.pos + SIMD2(rel.x * cos(ang) - rel.y * sin(ang), rel.x * sin(ang) + rel.y * cos(ang))
        moveTo(c, dest, 0.45)
    }

    /// Card-playing AI used by the enemy and by the player's AUTO mode.
    func aiUpdate(_ s: Side) {
        let id = ObjectIdentifier(s)
        let c = s.current
        let o = opponent(of: s)
        if c.isKO {
            s.charging = false
            return
        }
        if s.charging && (now >= aiChargeUntil[id] ?? 0 || s.energy >= 95) { s.charging = false }
        guard now >= aiNext[id] ?? 0 else { return }

        let affordable: [Int] = (0..<4).filter { i in
            guard let card = s.hand[i] else { return false }
            return s.energy >= Double(card.cost)
        }

        // Chain a follow-up card off the previous one.
        if canChain(s) {
            let launched = now < o.current.launchedUntil
            let attacks = affordable.filter { s.hand[$0]?.kind == .strike || (!launched && s.hand[$0]?.kind == .blast) }
            if let pick = attacks.randomElement(), chance(s.isPlayer ? 0.6 : 0.35 + Double(stage) * 0.02) {
                playCard(s, pick)
                aiNext[id] = now + 0.25
            }
            return
        }
        guard canAct(s) else { return }
        let thinkMin = s.isPlayer ? 0.4 : aiThinkMin
        aiNext[id] = now + Double.random(in: thinkMin...(thinkMin + 0.5))
        let d = dist(c, o.current)

        if s.eclipseReady && chance(0.6) {
            s.charging = false
            playCard(s, -2)
            return
        }
        if s.ultimateReady && chance(0.65) {
            s.charging = false
            playCard(s, -1)
            return
        }
        if c.hpFraction < 0.25, now >= s.swapReadyAt, chance(0.3),
           let idx = s.team.indices.first(where: { $0 != s.active && s.team[$0].hpFraction > 0.5 }) {
            swap(s, to: idx, forced: false)
            return
        }
        // Effect cards
        for i in affordable {
            guard let card = s.hand[i], card.kind == .effect else { continue }
            var use = false
            switch card.effect {
            case .heal?: use = c.hpFraction < 0.6
            case .barrier?: use = o.ultimateReady || o.eclipseReady || chance(0.25)
            case .powerUp?, .curse?: use = chance(0.5)
            case .energy?: use = s.energy < 50
            case nil: use = false
            }
            if use {
                s.charging = false
                playCard(s, i)
                return
            }
        }
        if let i = affordable.first(where: { s.hand[$0]?.kind == .special }), chance(0.6) {
            s.charging = false
            playCard(s, i)
            return
        }
        let preferStrike = d < 6 ? chance(0.7) : chance(0.3)
        let want: CardKind = preferStrike ? .strike : .blast
        let attacks = affordable.filter { s.hand[$0]?.kind == .strike || s.hand[$0]?.kind == .blast }
        if !attacks.isEmpty && !(s.energy < 30 && chance(0.4)) {
            let pool = attacks.filter { s.hand[$0]?.kind == want }
            s.charging = false
            playCard(s, (pool.isEmpty ? attacks : pool).randomElement()!)
            return
        }
        // Nothing affordable: basic attack, reposition or charge.
        let r = Double.random(in: 0..<1)
        if r < 0.3 {
            doBasic(s)
        } else if r < 0.45 && d > 7 {
            dashIn(s)
        } else if r < 0.55 {
            strafe(s, lateral: chance(0.5) ? 1 : -1)
        } else {
            s.charging = true
            aiChargeUntil[id] = now + Double.random(in: 0.8...1.6)
        }
    }
}
