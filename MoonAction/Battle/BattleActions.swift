import UIKit
import SceneKit
import simd

extension BattleScreen {
    // MARK: - Hand / deck

    func fillHand(_ s: Side) {
        s.handGen += 1
        for i in 0..<4 { s.hand[i] = s.current.drawCard() }
    }

    func refill(_ s: Side, slot: Int) {
        let gen = s.handGen
        timeline.after(0.55) { [weak self] in
            guard self != nil, s.handGen == gen, s.hand[slot] == nil else { return }
            s.hand[slot] = s.current.drawCard()
        }
    }

    /// Plays hand slot `idx` (0…3) or a power slot (-1 = ultimate, -2 = eclipse).
    @discardableResult
    func playCard(_ s: Side, _ idx: Int) -> Bool {
        let chaining = canChain(s)
        guard canAct(s) || chaining else { return false }
        let card: Card
        switch idx {
        case -1:
            guard s.ultimateReady else { return false }
            card = s.current.def.ultimateCard
        case -2:
            guard s.eclipseReady else { return false }
            card = Roster.eclipseCard
        default:
            guard idx >= 0, idx < 4, let c = s.hand[idx], s.energy >= Double(c.cost) else { return false }
            card = c
        }
        if chaining {
            timeline.cancel(tag: s.current)
            s.current.busy = false
            s.chain += 1
        } else {
            s.chain = 0
        }
        s.energy -= Double(card.cost)
        if idx >= 0 {
            s.hand[idx] = nil
            refill(s, slot: idx)
        }
        if s.isPlayer {
            Sound.play(.card)
            hud.cardPlayed(idx)
            if s.chain >= 1 { hud.chain(s.chain + 1) }
        }
        s.cardLanded = false
        var mul = 1 + min(0.5, Double(s.chain) * 0.1)
        if now < s.counterUntil && card.kind != .effect {
            mul *= 1.2
            s.counterUntil = 0
            popup(L("battle.counter"), at: s.current.chest + SIMD3(0, 0.9, 0), color: Theme.accent, size: 22)
        }
        switch card.kind {
        case .strike:
            let chase = now < opponent(of: s).current.launchedUntil
            doStrike(s, power: card.power * mul * (chase ? 1.15 : 1), hits: card.hits, style: .normal, chase: chase)
        case .blast: doBlast(s, power: card.power * mul, hits: card.hits)
        case .special: doSpecial(s, card: card, mul: mul)
        case .effect: doEffect(s, card)
        case .ultimate:
            s.soul = 0
            doUltimate(s)
        case .eclipse:
            s.shards = 0
            doEclipse(s)
        }
        return true
    }

    // MARK: - Basic actions (gestures)

    func doBasic(_ s: Side) {
        guard canAct(s) else { return }
        let a = s.current
        let t = opponent(of: s).current
        s.chain = 0
        if dist(a, t) < 3.4 {
            doStrike(s, power: 0.3, hits: 2, style: .basic)
        } else {
            doBlast(s, power: 0.22, hits: 1, small: true)
        }
    }

    func dashIn(_ s: Side) {
        guard canAct(s) else { return }
        let a = s.current
        let t = opponent(of: s).current
        let d = dist(a, t)
        guard d > 2.2 else { return }
        let dir = dirTo(a, t)
        a.model.afterimage(in: fxRoot)
        moveTo(a, t.pos - dir * 1.9, 0.22)
        a.model.dash()
        timeline.after(0.24, tag: a) { a.model.stance() }
        Sound.play(.dodge)
    }

    func stepBack(_ s: Side) {
        guard canAct(s) else { return }
        let a = s.current
        let t = opponent(of: s).current
        let dir = dirTo(a, t)
        moveTo(a, a.pos - dir * 3.2, 0.22)
        a.model.afterimage(in: fxRoot)
        Sound.play(.dodge)
    }

    /// Evade: a sidestep around the opponent with brief invincibility. Also breaks combos.
    @discardableResult
    func dodge(_ s: Side, lateral: Float) -> Bool {
        let c = s.current
        let escaping = now < c.stunUntil
        let cost = Tune.dodgeCost * (escaping ? 2 : 1)
        guard started, !battleOver, !cinematic, !c.isKO, s.dodge >= cost else { return false }
        s.dodge -= cost
        timeline.cancel(tag: c)
        c.busy = false
        c.stunUntil = 0
        c.invulnUntil = now + c.def.speed.invuln
        c.vanishStart = now
        c.perfectUsed = false
        if escaping { popup(L("battle.escape"), at: c.chest + SIMD3(0, 0.9, 0), color: Theme.energy, size: 18) }
        c.model.afterimage(in: fxRoot)
        let t = opponent(of: s).current
        let rel = c.pos - t.pos
        let ang = lateral * 0.75
        let rot = SIMD2(rel.x * cos(ang) - rel.y * sin(ang), rel.x * sin(ang) + rel.y * cos(ang))
        var dest = t.pos + rot
        if simd_length(dest) > Tune.arenaRadius { dest = t.pos + SIMD2(rel.x * cos(-ang) - rel.y * sin(-ang), rel.x * sin(-ang) + rel.y * cos(-ang)) }
        let travel = c.def.speed.vanishTime
        moveTo(c, dest, travel)
        c.model.stance()
        c.model.setVisible(false)
        timeline.after(travel) { c.model.setVisible(true) }
        Sound.play(.dodge)
        if s.isPlayer { hud.flashEvade() }
        return true
    }

    // MARK: - Strikes

    enum StrikeStyle { case normal, basic, rush, eclipse }

    func doStrike(_ s: Side, power: Double, hits: Int, style: StrikeStyle, chase: Bool = false) {
        let a = s.current
        let o = opponent(of: s)
        let t = o.current
        a.busy = true
        timeline.cancel(tag: a)
        let d = dist(a, t)
        var steps: [(Double, () -> Void)] = []
        if chase {
            // Teleport chase: blink to the far side of the launched opponent and keep the combo going.
            a.model.afterimage(in: fxRoot)
            var fly = t.knockVel
            if simd_length(fly) < 0.01 { fly = dirTo(a, t) }
            a.tween = nil
            a.knockVel = .zero
            a.pos = t.pos + simd_normalize(fly) * Tune.meleeStop
            t.knockVel *= 0.2
            popup(L("battle.chase"), at: a.chest + SIMD3(0, 0.9, 0), color: Theme.energy, size: 20)
            Sound.play(.dodge)
            if s.isPlayer { hud.flashEvade() }
        } else if d > Tune.meleeStop + 0.25 {
            let speed: Float = a.def.speed.dashSpeed * (style == .rush || style == .eclipse ? 1.25 : 1)
            let dashT = Double(max(0.07, (d - Tune.meleeStop) / speed))
            steps.append((0, { [weak self] in
                guard let self else { return }
                let dir = self.dirTo(a, o.current)
                self.moveTo(a, o.current.pos - dir * Tune.meleeStop, dashT)
                a.model.dash()
                if d > 3 { a.model.afterimage(in: self.fxRoot) }
                Sound.play(.dodge)
            }))
            steps.append((dashT, {}))
        }
        let interval: Double = style == .basic ? 0.16 : (style == .rush || style == .eclipse ? 0.085 : 0.12)
        let nearBonus = RangeZone.of(d) == .near ? 1.1 : 1.0
        let per = power / Double(hits) * nearBonus
        for i in 0..<hits {
            let last = i == hits - 1
            steps.append((i == 0 ? 0.02 : interval, { [weak self] in
                guard let self else { return }
                if last && hits > 2 { a.model.finisher() } else { a.model.attack(i) }
                let target = o.current
                guard !target.isKO, self.dist(a, target) < Tune.strikeRange else { return }
                let aiChance = i == 0 ? self.aiDodgeChance : self.aiDodgeChance * 0.25
                let heavy = last && style != .basic
                self.applyHit(from: s, power: per * (last ? 1.4 : 1), stun: last ? 0.7 : 0.4,
                              knock: heavy ? (style == .normal ? 9 : 13) : 1.5, heavy: heavy, aiDodge: aiChance,
                              basic: style == .basic)
                // Follow-up glide keeps combos connected.
                if !last {
                    let dir = self.dirTo(a, target)
                    let gap = self.dist(a, target)
                    if gap > Tune.meleeStop + 0.2 { self.moveTo(a, target.pos - dir * Tune.meleeStop, 0.06) }
                }
            }))
        }
        steps.append((0.05, { [weak self] in
            guard let self else { return }
            s.chainOpenUntil = self.now + 0.55
            self.awardShard(s)
        }))
        steps.append((style == .basic ? 0.22 : 0.18, {
            a.busy = false
            a.model.stance()
        }))
        timeline.sequence(tag: a, steps)
    }

    // MARK: - Blasts

    func doBlast(_ s: Side, power: Double, hits: Int, small: Bool = false, big: Bool = false) {
        let a = s.current
        a.busy = true
        timeline.cancel(tag: a)
        a.model.blast()
        let glow = Toon.glowSprite(a.def.aura, size: 0.5)
        a.model.fistR.addChildNode(glow)
        glow.runAction(.scale(to: 2.2, duration: 0.2))
        let interval = hits > 3 ? 0.085 : 0.12
        var steps: [(Double, () -> Void)] = [(0.2, {})]
        for i in 0..<hits {
            steps.append((i == 0 ? 0 : interval, { [weak self] in
                guard let self else { return }
                if i > 0 { a.model.blast() }
                self.spawnProjectile(s, power: power / Double(hits), radius: big ? 0.5 : (small ? 0.18 : (hits == 1 ? 0.32 : 0.22)),
                                     spread: hits > 1 ? Float(i % 2 == 0 ? 1 : -1) * Float(i) * 0.06 : 0)
            }))
        }
        steps.append((0.05, { [weak self] in
            glow.removeFromParentNode()
            guard let self else { return }
            s.chainOpenUntil = self.now + 0.55
        }))
        steps.append((small ? 0.25 : 0.2, {
            a.busy = false
            a.model.stance()
        }))
        timeline.sequence(tag: a, steps)
    }

    func spawnProjectile(_ s: Side, power: Double, radius: Float, spread: Float) {
        let a = s.current
        let t = opponent(of: s).current
        let start = a.model.handWorld
        var dir = simd_normalize(t.chest - start)
        let right = simd_normalize(simd_cross(dir, SIMD3(0, 1, 0)))
        dir = simd_normalize(dir + right * spread)
        let n = SCNNode()
        let core = SCNNode(geometry: SCNSphere(radius: CGFloat(radius * 0.55)))
        core.geometry?.materials = [Toon.energy(.white)]
        n.addChildNode(core)
        let shell = SCNNode(geometry: SCNSphere(radius: CGFloat(radius)))
        shell.geometry?.materials = [Toon.energy(a.def.aura, alpha: 0.6)]
        n.addChildNode(shell)
        let g = Toon.glowSprite(a.def.aura, size: CGFloat(radius * 5))
        n.addChildNode(g)
        n.addParticleSystem(Toon.trail(a.def.aura, size: CGFloat(radius * 2.2)))
        n.simdPosition = start
        fxRoot.addChildNode(n)
        let farBonus = RangeZone.of(dist(a, t)) == .far ? 1.1 : 1.0
        projectiles.append(Projectile(node: n, owner: s, pos: start, vel: dir * Tune.blastSpeed, radius: radius, power: power * farBonus))
        Sound.play(.blast)
    }

    func updateProjectiles(_ dt: Double) {
        let fdt = Float(dt)
        for p in projectiles where p.alive {
            p.pos += p.vel * fdt
            p.age += fdt
            p.node.simdPosition = p.pos
            let o = opponent(of: p.owner)
            let t = o.current
            if !t.isKO {
                let d = simd_length(t.chest - p.pos)
                if !p.aiRolled && (!o.isPlayer || o.auto) && d < 6 {
                    p.aiRolled = true
                    if canAIDodge(o) && chance(aiDodgeChance * 0.9) {
                        dodge(o, lateral: chance(0.5) ? 1 : -1)
                    }
                }
                if d < 0.75 + p.radius {
                    if now < t.invulnUntil {
                        if !p.evadeShown {
                            p.evadeShown = true
                            evaded(o, by: p.owner)
                        }
                    } else {
                        p.alive = false
                        applyHit(from: p.owner, power: p.power, stun: 0.45, knock: 2.5, heavy: false, aiDodge: 0,
                                 source: SIMD2(p.pos.x - p.vel.x, p.pos.z - p.vel.z))
                        burst(at: p.pos, color: p.owner.current.def.aura, scale: p.radius * 3)
                    }
                }
            }
            if p.age > 2.5 { p.alive = false }
        }
        // Clash: opposing projectiles cancel out.
        let live = projectiles.filter { $0.alive }
        if live.count > 1 {
            for i in 0..<(live.count - 1) {
                for j in (i + 1)..<live.count where live[i].alive && live[j].alive && live[i].owner !== live[j].owner {
                    if simd_length(live[i].pos - live[j].pos) < live[i].radius + live[j].radius + 0.2 {
                        live[i].alive = false
                        live[j].alive = false
                        burst(at: live[i].pos, color: .white, scale: 1.5)
                        Sound.play(.hit)
                    }
                }
            }
        }
        for p in projectiles where !p.alive { p.node.removeFromParentNode() }
        projectiles.removeAll { !$0.alive }
    }

    // MARK: - Special arts

    func doSpecial(_ s: Side, card: Card, mul: Double) {
        let a = s.current
        a.busy = true
        timeline.cancel(tag: a)
        hud.moveBanner(card.name.s, kind: .special, side: s)
        Sound.play(.charge)
        a.auraBurstUntil = now + 0.6
        let (pos, look) = frontShot(a, distance: 2.6, height: 1.5, side: s.isPlayer ? 1.0 : -1.0)
        cut(to: pos, look: look, for: 0.55)
        switch a.def.specialStyle {
        case .beam:
            fireBeam(s, power: card.power * mul, radius: 0.42, startup: 0.5, ticks: 6, ultimate: false)
        case .rush:
            a.model.apply(FighterModel.chargePose, duration: 0.12)
            timeline.after(0.45, tag: a) { [weak self] in
                guard let self else { return }
                let (p2, l2) = self.sideShot(a, self.opponent(of: s).current, distance: 6)
                self.cut(to: p2, look: l2, for: 1.0, snap: false)
                self.doStrike(s, power: card.power * mul, hits: card.hits, style: .rush)
            }
        case .volley:
            a.model.apply(FighterModel.chargePose, duration: 0.12)
            timeline.after(0.45, tag: a) { [weak self] in
                self?.doBlast(s, power: card.power * mul, hits: card.hits)
            }
        }
    }

    func fireBeam(_ s: Side, power: Double, radius: Float, startup: Double, ticks: Int, ultimate: Bool) {
        let a = s.current
        a.busy = true
        a.model.apply(FighterModel.beamChargePose, duration: 0.15)
        a.auraBurstUntil = now + startup + 0.3
        let color = a.def.aura
        let orb = Toon.glowSprite(color, size: 0.4)
        a.model.fistR.addChildNode(orb)
        orb.runAction(.scale(to: CGFloat(radius * 6), duration: startup))
        var locked = false
        var beamNode: SCNNode?
        var steps: [(Double, () -> Void)] = [(startup, { [weak self] in
            guard let self else { return }
            orb.removeFromParentNode()
            a.model.apply(FighterModel.beamFirePose, duration: 0.06)
            let t = self.opponent(of: s).current
            let start = a.model.handWorld
            let dir = simd_normalize(t.chest - start)
            let length: Float = 60
            let holder = SCNNode()
            holder.simdPosition = start
            holder.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
            let outer = SCNNode(geometry: SCNCylinder(radius: CGFloat(radius), height: CGFloat(length)))
            outer.geometry?.materials = [Toon.energy(color, alpha: 0.55)]
            outer.simdPosition = SIMD3(0, length / 2, 0)
            let core = SCNNode(geometry: SCNCylinder(radius: CGFloat(radius * 0.45), height: CGFloat(length)))
            core.geometry?.materials = [Toon.energy(.white)]
            core.simdPosition = SIMD3(0, length / 2, 0)
            let head = Toon.glowSprite(color, size: CGFloat(radius * 8))
            holder.addChildNode(outer)
            holder.addChildNode(core)
            holder.addChildNode(head)
            holder.simdScale = SIMD3(1, 0.01, 1)
            self.fxRoot.addChildNode(holder)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.16
            holder.simdScale = SIMD3(1, 1, 1)
            SCNTransaction.commit()
            outer.runAction(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.05), .scale(to: 0.92, duration: 0.05)])))
            beamNode = holder
            Sound.play(.beam)
            self.shake = ultimate ? 0.28 : 0.14
            self.fovKick = ultimate ? 10 : 5
            let (p2, l2) = self.sideShot(a, t, distance: ultimate ? 9 : 7)
            self.cut(to: p2, look: l2, for: 0.3 + Double(ticks) * 0.12, snap: false)
        })]
        steps.append((0.12, { [weak self] in
            guard let self else { return }
            let o = self.opponent(of: s)
            let t = o.current
            guard !t.isKO else { return }
            if self.now < t.invulnUntil {
                self.evaded(o, by: s)
                return
            }
            if (!o.isPlayer || o.auto) && self.canAIDodge(o) && chance(self.aiDodgeChance * (ultimate ? 1.1 : 1)) {
                self.dodge(o, lateral: chance(0.5) ? 1 : -1)
                self.aiEvade(o, by: s)
                return
            }
            locked = true
        }))
        for k in 0..<ticks {
            let last = k == ticks - 1
            steps.append((0.12, { [weak self] in
                guard let self, locked else { return }
                let t = self.opponent(of: s).current
                if self.now < t.invulnUntil {
                    locked = false
                    return
                }
                self.applyHit(from: s, power: power / Double(ticks) * (last ? 1.3 : 1), stun: last ? 0.9 : 0.5,
                              knock: last ? 14 : 0.8, heavy: last, aiDodge: 0, ignoreInvuln: true)
            }))
        }
        steps.append((0.1, { [weak self] in
            if let b = beamNode {
                b.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
            }
            guard let self else { return }
            s.chainOpenUntil = self.now + 0.4
            self.awardShard(s)
        }))
        steps.append((0.25, {
            a.busy = false
            a.model.stance()
        }))
        timeline.sequence(tag: a, steps)
    }

    func fireMeteor(_ s: Side, power: Double) {
        let a = s.current
        a.busy = true
        a.model.apply(FighterModel.victoryPose, duration: 0.2)
        a.auraBurstUntil = now + 1.2
        let o = opponent(of: s)
        let color = a.def.aura
        let impact = o.current.world3
        let orb = SCNNode()
        let core = SCNNode(geometry: SCNSphere(radius: 1.4))
        core.geometry?.materials = [Toon.energy(color.lighter(0.5))]
        orb.addChildNode(core)
        let shell = SCNNode(geometry: SCNSphere(radius: 2.0))
        shell.geometry?.materials = [Toon.energy(color, alpha: 0.45)]
        orb.addChildNode(shell)
        orb.addChildNode(Toon.glowSprite(color, size: 9))
        orb.addParticleSystem(Toon.trail(color, size: 2.5))
        orb.simdPosition = a.world3 + SIMD3(0, 9, 0)
        fxRoot.addChildNode(orb)
        orb.runAction(.sequence([.scale(to: 0.2, duration: 0), .scale(to: 1, duration: 0.5)]))
        let fall = SCNAction.move(to: SCNVector3(impact.x, impact.y + 1, impact.z), duration: 0.6)
        fall.timingMode = .easeIn
        orb.runAction(.sequence([.wait(duration: 0.55), fall, .removeFromParentNode()]))
        Sound.play(.beam)
        let wide = sideShot(a, o.current, distance: 12)
        cut(to: wide.0 + SIMD3(0, 3, 0), look: wide.1, for: 2.0, snap: false)

        var steps: [(Double, () -> Void)] = [(1.15, { [weak self] in
            guard let self else { return }
            self.explosion(at: impact + SIMD3(0, 1, 0), color: color)
            let t = o.current
            guard !t.isKO else { return }
            let near = simd_length(t.world3 - impact) < 3.6
            if !near || self.now < t.invulnUntil {
                if near { self.evaded(o, by: s) } else { self.showEvade(t) }
                return
            }
            if (!o.isPlayer || o.auto) && self.canAIDodge(o) && chance(self.aiDodgeChance) {
                self.dodge(o, lateral: chance(0.5) ? 1 : -1)
                self.aiEvade(o, by: s)
                return
            }
            let ticks = 5
            for k in 0..<ticks {
                let last = k == ticks - 1
                self.timeline.after(Double(k) * 0.1) { [weak self] in
                    self?.applyHit(from: s, power: power / Double(ticks) * (last ? 1.3 : 1), stun: last ? 1.0 : 0.5,
                                   knock: last ? 16 : 0.5, heavy: last, aiDodge: 0, ignoreInvuln: true,
                                   source: SIMD2(impact.x, impact.z) - SIMD2(0.01, 0.01))
                }
            }
        })]
        steps.append((0.8, { [weak self] in
            a.busy = false
            a.model.stance()
            guard let self else { return }
            self.awardShard(s)
        }))
        timeline.sequence(tag: a, steps)
    }

    // MARK: - Ultimate / Eclipse

    func doUltimate(_ s: Side) {
        let a = s.current
        let o = opponent(of: s)
        a.busy = true
        timeline.cancel(tag: a)
        cinematic = true
        if !o.current.isKO {
            timeline.cancel(tag: o.current)
            o.current.busy = false
            o.current.model.stance()
        }
        Sound.play(.ultimate)
        Haptics.hit(true)
        a.model.apply(FighterModel.chargePose, duration: 0.2)
        a.auraBurstUntil = now + 1.8
        let (pos, look) = frontShot(a, distance: 2.0, height: 1.7, side: s.isPlayer ? 0.7 : -0.7)
        cut(to: pos, look: look, for: 1.6)
        let duration = hud.ultimateCutIn(a.def, side: s)
        SCNNode.emit(Toon.burst(a.def.aura, count: 80, speed: 6, size: 0.3, life: 0.6), at: a.chest, in: fxRoot)
        timeline.after(duration, tag: a) { [weak self] in
            guard let self else { return }
            self.cinematic = false
            switch a.def.ultimateStyle {
            case .beam:
                self.fireBeam(s, power: a.def.ultimatePower, radius: 1.1, startup: 0.3, ticks: 8, ultimate: true)
            case .meteor:
                self.fireMeteor(s, power: a.def.ultimatePower)
            }
        }
    }

    func doEclipse(_ s: Side) {
        let a = s.current
        a.busy = true
        timeline.cancel(tag: a)
        cinematic = true
        Sound.play(.ultimate)
        let duration = hud.eclipseCutIn(s)
        let (pos, look) = frontShot(a, distance: 3.0, height: 1.4, side: s.isPlayer ? 1.2 : -1.2)
        cut(to: pos, look: look, for: duration)
        timeline.after(duration, tag: a) { [weak self] in
            guard let self else { return }
            self.cinematic = false
            let (p2, l2) = self.sideShot(a, self.opponent(of: s).current, distance: 6)
            self.cut(to: p2, look: l2, for: 1.3, snap: false)
            self.doStrike(s, power: Roster.eclipseCard.power, hits: 9, style: .eclipse)
        }
    }

    // MARK: - Effect cards

    func doEffect(_ s: Side, _ card: Card) {
        let a = s.current
        let o = opponent(of: s)
        a.busy = true
        timeline.cancel(tag: a)
        a.model.apply(FighterModel.chargePose, duration: 0.12)
        a.auraBurstUntil = now + 0.5
        hud.moveBanner(card.name.s, kind: .effect, side: s)
        Sound.play(.charge)
        let st = CardArt.style(card)
        switch card.effect {
        case .heal(let f)?:
            let amount = a.maxHP * f
            a.hp = min(a.maxHP, a.hp + amount)
            popup("+\(Int(amount))", at: a.chest + SIMD3(0, 0.6, 0), color: Theme.effect, size: 26)
            SCNNode.emit(Toon.burst(Theme.effect, count: 60, speed: 2.5, size: 0.25, life: 0.8, streaks: false), at: a.chest, in: fxRoot)
        case .barrier(let t)?:
            a.barrierUntil = now + t
        case .powerUp(let t)?:
            a.powerUntil = now + t
            popup(L("battle.atkup"), at: a.chest + SIMD3(0, 0.7, 0), color: UIColor(hex: 0xFF8A5E), size: 22)
        case .energy(let v)?:
            s.energy = min(Tune.energyMax, s.energy + v)
            popup(L10n.f("battle.en", Int(v)), at: a.chest + SIMD3(0, 0.7, 0), color: UIColor(hex: 0x7FE8FF), size: 22)
        case .curse(let t)?:
            o.current.cursedUntil = now + t
            popup(L("battle.defdown"), at: o.current.chest + SIMD3(0, 0.7, 0), color: UIColor(hex: 0xD58CFF), size: 22)
            SCNNode.emit(Toon.burst(UIColor(hex: 0xB04CFF), count: 50, speed: 2, size: 0.3, life: 0.7, streaks: false),
                         at: o.current.chest, in: fxRoot)
        case nil:
            break
        }
        SCNNode.emit(Toon.burst(st.color, count: 40, speed: 3, size: 0.2, life: 0.5), at: a.chest, in: fxRoot)
        timeline.sequence(tag: a, [
            (0.35, { [weak self] in
                guard let self else { return }
                s.chainOpenUntil = self.now + 0.3
            }),
            (0.1, {
                a.busy = false
                a.model.stance()
            }),
        ])
    }

    // MARK: - Evasion

    /// Called when an attack from `s` misses `o` because of evade invulnerability.
    func evaded(_ o: Side, by s: Side) {
        let t = o.current
        if !t.perfectUsed && now - t.vanishStart <= t.def.speed.perfectWindow {
            perfectEvade(o, attacker: s)
        } else {
            showEvade(t)
        }
    }

    /// AI evades happen at the last instant; some of them count as perfect.
    func aiEvade(_ o: Side, by s: Side) {
        let p = o.isPlayer ? 0.4 : min(0.55, 0.25 + Double(stage) * 0.015)
        if chance(p) { perfectEvade(o, attacker: s) } else { showEvade(o.current) }
    }

    /// Perfect evade: slow-mo, teleport behind the attacker, attacker is left open, counter window.
    func perfectEvade(_ o: Side, attacker s: Side) {
        let t = o.current
        let a = s.current
        t.perfectUsed = true
        popup(L("battle.perfect"), at: t.chest + SIMD3(0, 1.0, 0), color: Theme.accent, size: 22)
        timeScale = 0.3
        realDelay(0.45) { [weak self] in self?.timeScale = 1 }
        t.model.afterimage(in: fxRoot)
        let dir = dirTo(t, a)
        t.tween = nil
        t.knockVel = .zero
        t.pos = a.pos + dir * 1.35
        t.invulnUntil = max(t.invulnUntil, now + 0.35)
        if !a.isKO {
            timeline.cancel(tag: a)
            a.busy = false
            a.stunUntil = now + 0.75
            a.model.stance()
        }
        o.dodge = min(Tune.dodgeMax, o.dodge + 15)
        o.counterUntil = now + 1.6
        Sound.play(.dodge)
        if o.isPlayer {
            hud.flashEvade()
            Haptics.rigid.impactOccurred()
        }
        fovKick = 6
    }

    // MARK: - Hits

    func canAIDodge(_ s: Side) -> Bool {
        (!s.isPlayer || s.auto) && !s.current.isKO && s.dodge >= Tune.dodgeCost && !battleOver
    }

    func awardShard(_ s: Side) {
        guard s.cardLanded else { return }
        s.cardLanded = false
        if s.chain >= 1 || chance(0.4) {
            s.shards = min(Tune.shardsNeeded, s.shards + 1)
        }
    }

    @discardableResult
    func applyHit(from s: Side, power: Double, stun: Double, knock: Float, heavy: Bool, aiDodge: Double,
                  ignoreInvuln: Bool = false, basic: Bool = false, source: SIMD2<Float>? = nil) -> Bool {
        let o = opponent(of: s)
        let t = o.current
        let a = s.current
        guard !t.isKO, !battleOver else { return false }
        if !ignoreInvuln && now < t.invulnUntil {
            evaded(o, by: s)
            return false
        }
        if aiDodge > 0 && canAIDodge(o) && chance(aiDodge) {
            dodge(o, lateral: chance(0.5) ? 1 : -1)
            aiEvade(o, by: s)
            return false
        }
        var dmg = power * a.atk * (1200 / (1000 + t.dfn * (now < t.cursedUntil ? 0.7 : 1))) * 1.25
        dmg *= Double.random(in: 0.94...1.06)
        if now < a.powerUntil { dmg *= 1.3 }
        if now < t.barrierUntil { dmg *= 0.4 }
        dmg *= 1 + min(0.3, Double(max(0, s.comboCount - 4)) * 0.02)
        let crit = chance(0.08)
        if crit { dmg *= 1.5 }
        dmg = dmg.rounded()
        t.hp = max(0, t.hp - dmg)
        timeline.cancel(tag: t)
        t.busy = false
        t.stunUntil = now + stun
        let src = source ?? a.pos
        var away = t.pos - src
        away = simd_length(away) > 0.001 ? simd_normalize(away) : SIMD2(0, 1)
        t.tween = nil
        t.knockVel = away * knock
        if heavy && knock >= 8 { t.launchedUntil = now + 0.75 }
        t.model.hurt(heavy: heavy)
        if !basic { s.cardLanded = true }
        if basic { s.energy = min(Tune.energyMax, s.energy + 2) }

        let hitPoint = t.chest + SIMD3(0, 0.1, 0)
        spark(at: hitPoint, color: a.def.aura, big: heavy || crit)
        popup(crit ? "\(Int(dmg))!" : "\(Int(dmg))", at: hitPoint + SIMD3(Float.random(in: -0.3...0.3), 0.5, 0),
              color: crit ? Theme.accent : .white, size: crit ? 24 : (heavy ? 20 : 16))
        shake = max(shake, heavy ? 0.16 : 0.04)
        if heavy {
            hitStop = 0.07
            fovKick = max(fovKick, 4)
        }
        Sound.play(heavy ? .heavy : .hit)
        if s.isPlayer || o.isPlayer { Haptics.hit(heavy) }

        s.addSoul(heavy ? 4 : 2)
        o.addSoul(heavy ? 3.5 : 1.8)
        o.energy = min(Tune.energyMax, o.energy + 1.2)
        s.comboCount = now - s.lastHitTime < 1.4 ? s.comboCount + 1 : 1
        s.lastHitTime = now
        if s.isPlayer { hud.combo(s.comboCount) }

        if t.isKO { handleKO(o) }
        return true
    }

    func handleKO(_ side: Side) {
        let c = side.current
        timeline.cancel(tag: c)
        c.busy = true
        side.charging = false
        c.model.ko()
        Sound.play(.ko)
        shake = 0.3
        hud.banner(L("battle.ko"), color: Theme.hpEnemy, big: true, duration: 0.9)
        timeScale = 0.3
        realDelay(0.7) { [weak self] in self?.timeScale = 1 }
        let attacker = opponent(of: side).current
        let (p, l) = sideShot(attacker, c, distance: 5)
        cut(to: p, look: l, for: 0.6, snap: false)
        if side.allKO {
            endBattle(playerWon: !side.isPlayer)
            return
        }
        timeline.after(1.0) { [weak self] in
            guard let self, !self.battleOver else { return }
            if let next = side.team.firstIndex(where: { !$0.isKO }) {
                self.swap(side, to: next, forced: true)
            }
        }
    }

    func swap(_ s: Side, to index: Int, forced: Bool) {
        guard index != s.active, index >= 0, index < s.team.count, !s.team[index].isKO else { return }
        if !forced {
            guard canAct(s), now >= s.swapReadyAt else { return }
        }
        let old = s.current
        let pos = old.pos
        timeline.cancel(tag: old)
        old.model.root.removeFromParentNode()
        old.charging(false)
        s.active = index
        s.swapReadyAt = now + Tune.swapCooldown
        s.chain = 0
        let n = s.current
        n.busy = false
        n.stunUntil = 0
        n.invulnUntil = now + 0.6
        n.model.revive()
        place(n, at: pos)
        n.auraBurstUntil = now + 0.6
        SCNNode.emit(Toon.burst(n.def.aura, count: 70, speed: 5, size: 0.3, life: 0.5), at: n.chest, in: fxRoot)
        fillHand(s)
        updateFacing()
        hud.moveBanner(L10n.f("battle.tagin", n.def.name.s), kind: .strike, side: s)
        Sound.play(.charge)
        if s.isPlayer { hud.teamChanged() }
    }

    func timeUp() {
        let pf = player.team.reduce(0.0) { $0 + max(0, $1.hp) / $1.maxHP }
        let ef = enemy.team.reduce(0.0) { $0 + max(0, $1.hp) / $1.maxHP }
        hud.banner(L("battle.timeup"), color: Theme.accent, big: true, duration: 1.2)
        endBattle(playerWon: pf > ef)
    }

    func endBattle(playerWon: Bool) {
        guard !battleOver else { return }
        battleOver = true
        player.charging = false
        enemy.charging = false
        let winner = playerWon ? player! : enemy!
        timeline.after(1.4) { [weak self] in
            guard let self else { return }
            if !winner.current.isKO {
                self.winnerModel = winner.current.model
                winner.current.model.victory()
                self.victoryOrbit = 0
            }
            self.hud.finalBanner(won: playerWon)
        }
        realDelay(4.6) { [weak self] in
            guard let self else { return }
            self.go(ResultScreen(won: playerWon, teamIDs: self.playerIDs, stage: self.stage))
        }
    }
}

extension Combatant {
    func charging(_ on: Bool) {
        wasCharging = on
    }
}
