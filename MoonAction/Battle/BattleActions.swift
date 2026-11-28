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
            guard idx >= 0, idx < 4, cardStatus(s, idx).playable, let c = s.hand[idx] else { return false }
            card = c
        }
        // Chase eligibility is decided before the relay window is consumed.
        let chase = card.kind == .strike && chaseAvailable(s)
        if let r = s.relay { r.closed = true }
        if chaining {
            timeline.cancel(tag: s.current)
            s.current.busy = false
            s.chain += 1
            // A chained card keeps the defender locked through its startup (dash-in / wind-up).
            let t = opponent(of: s).current
            if now < t.stunUntil { t.stunUntil = max(t.stunUntil, now + 0.6) }
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
            doStrike(s, power: card.power * mul * (chase ? 1.15 : 1), hits: card.hits, style: .normal, chase: chase,
                     sig: Signatures.of(card, s.current.def))
        case .blast: doBlast(s, power: card.power * mul, hits: card.hits, sig: Signatures.of(card, s.current.def))
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

    // MARK: - Card eligibility (single source of truth for logic + HUD)

    /// Strike chase is available: the opponent is airborne from a launch, or our tagged-in
    /// relay fighter still holds its chase window on the same target.
    func chaseAvailable(_ s: Side) -> Bool {
        let t = opponent(of: s).current
        guard !t.isKO else { return false }
        return now < t.launchedUntil || isRelayChase(s)
    }

    func isRelayChase(_ s: Side) -> Bool {
        guard let r = validRelay(s), let e = r.entrant else { return false }
        return e === s.current
    }

    func cardStatus(_ s: Side, _ idx: Int) -> CardStatus {
        guard idx >= 0, idx < 4, let card = s.hand[idx] else { return CardStatus() }
        let affordable = s.energy >= Double(card.cost)
        let chaining = canChain(s)
        let playable = affordable && (canAct(s) || chaining)
        return CardStatus(playable: playable,
                          chain: playable && chaining,
                          chase: playable && card.kind == .strike && chaseAvailable(s))
    }

    // MARK: - Tag-in relay chase

    /// The relay if it is still meaningful (same, living target; not timed out; battle running).
    func validRelay(_ s: Side) -> Relay? {
        guard let r = s.relay, !r.closed, !battleOver else { return nil }
        let t = opponent(of: s).current
        guard r.target === t, !t.isKO, now < r.deadline else { return nil }
        return r
    }

    /// Can bench fighter `i` tag in to continue the chase right now?
    func relayEligible(_ s: Side, _ i: Int) -> Bool {
        guard started, !cinematic, let r = validRelay(s), !r.used, r.launcher === s.current, now < r.launchUntil else { return false }
        guard i >= 0, i < s.team.count, i != s.active, !s.team[i].isKO, now >= s.swapReadyAt else { return false }
        let c = s.current
        guard !c.isKO, now >= c.stunUntil else { return false }
        return s.team[i].def.cards.contains { $0.kind == .strike && Double($0.cost) <= s.energy }
    }

    /// Tag bench fighter `i` in mid-launch. Cancels the launcher's recovery; the entrant
    /// gets a guaranteed affordable strike and a manual chase window.
    @discardableResult
    func doRelay(_ s: Side, _ i: Int) -> Bool {
        guard relayEligible(s, i), let r = s.relay else { return false }
        swapCore(s, to: i, banner: L10n.f("battle.relayIn", s.team[i].def.name.s))
        r.used = true
        r.entrant = s.current
        r.deadline = max(r.launchUntil, now + Tune.relayGrace)
        guaranteeStrike(s)
        if s.isPlayer { hud.relayStarted() }
        return true
    }

    /// Ensures the hand holds at least one strike the side can pay for (no energy is spent here).
    func guaranteeStrike(_ s: Side) {
        let ok: (Card) -> Bool = { $0.kind == .strike && Double($0.cost) <= s.energy }
        if s.hand.contains(where: { $0.map(ok) ?? false }) { return }
        let n = s.current
        let slot = 3
        var card: Card?
        if let k = n.deck.lastIndex(where: ok) {
            card = n.deck.remove(at: k)
        } else {
            card = n.def.cards.first(where: ok)
        }
        guard let c = card else { return }
        if let old = s.hand[slot] { n.deck.insert(old, at: 0) }
        s.hand[slot] = c
    }

    // MARK: - Basic actions (gestures)

    @discardableResult
    func doBasic(_ s: Side) -> Bool {
        guard canAct(s) else { return false }
        let a = s.current
        let t = opponent(of: s).current
        s.chain = 0
        if dist(a, t) < 3.4 {
            doStrike(s, power: 0.3, hits: 2, style: .basic)
        } else {
            doBlast(s, power: 0.22, hits: 1, small: true)
        }
        return true
    }

    @discardableResult
    func dashIn(_ s: Side) -> Bool {
        guard canAct(s) else { return false }
        let a = s.current
        let t = opponent(of: s).current
        let d = dist(a, t)
        guard d > 2.2 else { return false }
        let dir = dirTo(a, t)
        a.model.afterimage(in: fxRoot)
        moveTo(a, t.pos - dir * 1.9, 0.22)
        a.model.dash()
        timeline.after(0.24, tag: a) { a.model.stance() }
        Sound.play(.dodge)
        return true
    }

    @discardableResult
    func stepBack(_ s: Side) -> Bool {
        guard canAct(s) else { return false }
        let a = s.current
        let t = opponent(of: s).current
        let dir = dirTo(a, t)
        moveTo(a, a.pos - dir * 3.2, 0.22)
        a.model.stepBack()
        a.model.afterimage(in: fxRoot)
        Sound.play(.dodge)
        return true
    }

    /// Actual evade cost right now: double while escaping hitstun (combo escape).
    /// Shared by manual input, enemy AI and the player's AUTO mode.
    func dodgeCost(_ s: Side) -> Double { Tune.dodgeCost }

    /// Being hit: the fighter can neither act nor vanish until the attacker's combo ends
    /// (no energy / no follow-up) or this side switches fighters.
    func inHitstun(_ s: Side) -> Bool {
        let c = s.current
        return started && !battleOver && !cinematic && !c.isKO && now < c.stunUntil
    }

    /// After a card lands, the defender stays locked through the attacker's chain window.
    func extendLock(_ s: Side) {
        let t = opponent(of: s).current
        guard !t.isKO, now < t.stunUntil, now - s.lastHitTime < 0.8 else { return }
        t.stunUntil = max(t.stunUntil, s.chainOpenUntil + 0.05)
    }

    /// Evade: a sidestep around the opponent with brief invincibility. Also breaks combos.
    /// Returns false (and changes nothing) when the evade cannot be executed.
    @discardableResult
    func dodge(_ s: Side, lateral: Float) -> Bool {
        let c = s.current
        let cost = dodgeCost(s)
        guard started, !battleOver, !cinematic, !c.isKO, now >= c.stunUntil, s.dodge >= cost else { return false }
        s.dodge -= cost
        timeline.cancel(tag: c)
        c.busy = false
        c.stunUntil = 0
        c.invulnUntil = now + c.def.speed.invuln
        c.vanishStart = now
        c.perfectUsed = false
        c.model.afterimage(in: fxRoot)
        let t = opponent(of: s).current
        let rel = c.pos - t.pos
        let ang = lateral * 0.75
        let rot = SIMD2(rel.x * cos(ang) - rel.y * sin(ang), rel.x * sin(ang) + rel.y * cos(ang))
        var dest = t.pos + rot
        if simd_length(dest) > Tune.arenaRadius { dest = t.pos + SIMD2(rel.x * cos(-ang) - rel.y * sin(-ang), rel.x * sin(-ang) + rel.y * cos(-ang)) }
        let travel = c.def.speed.vanishTime
        moveTo(c, dest, travel)
        c.model.sidestep(lateral)
        c.model.setVisible(false)
        timeline.after(travel) { c.model.setVisible(true) }
        Sound.play(.dodge)
        if s.isPlayer { hud.flashEvade() }
        return true
    }

    // MARK: - Strikes

    enum StrikeStyle { case normal, basic, rush, eclipse }

    func doStrike(_ s: Side, power: Double, hits: Int, style: StrikeStyle, chase: Bool = false, sig given: CardSig? = nil) {
        let a = s.current
        let sig = given ?? (style == .basic ? Signatures.basic(a.def)
                            : Signatures.of(style == .eclipse ? Roster.eclipseCard : a.def.specialCard, a.def))
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
                VFX.dust(at: a.world3 + SIMD3(0, 0.1, 0), scale: 0.7, in: self.fxRoot)
                if d > 3 { a.model.afterimage(in: self.fxRoot) }
                Sound.play(.dodge)
            }))
            steps.append((dashT, {}))
        }
        let rushy = style == .rush || style == .eclipse
        let interval: Double = style == .basic ? 0.16 : (rushy ? 0.085 : 0.12)
        let speed: Double = rushy ? 1.4 : (style == .basic ? 1.1 : 1.0)
        let nearBonus = RangeZone.of(d) == .near ? 1.1 : 1.0
        let per = power / Double(hits) * nearBonus
        // Keyframed string from this card's signature: anticipation → impact → recovery per hit, heavy finisher last.
        let clips: [Clip] = (0..<hits).map { i in
            if i == hits - 1 && hits > 2 && style != .basic { return sig.finisher }
            return sig.strikes[i % sig.strikes.count]
        }
        for i in 0..<hits {
            let last = i == hits - 1
            let clip = clips[i]
            let delay = i == 0 ? 0.02 : max(interval, clips[i - 1].impact / speed + 0.03)
            steps.append((delay, { [weak self] in
                guard let self else { return }
                a.model.play(clip, speed: speed)
                Sound.play(.whoosh, pitch: sig.pitch * (last ? 0.85 : 1.1))
                // The hit lands on the clip's impact frame.
                self.timeline.after(clip.impact / speed, tag: a) { [weak self] in
                    guard let self else { return }
                    let target = o.current
                    guard !target.isKO, self.dist(a, target) < Tune.strikeRange else { return }
                    let aiChance = i == 0 ? self.aiDodgeChance : self.aiDodgeChance * 0.25
                    let heavy = last && style != .basic
                    self.applyHit(from: s, power: per * (last ? 1.4 : 1), stun: last ? 0.7 : 0.4,
                                  knock: heavy ? (style == .normal ? 9 : 13) : 1.5, heavy: heavy, aiDodge: aiChance,
                                  basic: style == .basic, sfx: heavy ? sig.heavyImpact : sig.impact, pitch: sig.pitch)
                    // Follow-up glide keeps combos connected.
                    if !last {
                        let dir = self.dirTo(a, target)
                        let gap = self.dist(a, target)
                        if gap > Tune.meleeStop + 0.2 { self.moveTo(a, target.pos - dir * Tune.meleeStop, 0.06) }
                    }
                }
            }))
        }
        steps.append(((clips.last?.impact ?? 0) / speed + 0.05, { [weak self] in
            guard let self else { return }
            s.chainOpenUntil = self.now + 0.55
            self.extendLock(s)
            self.awardShard(s)
        }))
        steps.append((style == .basic ? 0.16 : 0.14, {
            a.busy = false
        }))
        timeline.sequence(tag: a, steps)
    }

    // MARK: - Blasts

    func doBlast(_ s: Side, power: Double, hits: Int, small: Bool = false, big: Bool = false, sig given: CardSig? = nil) {
        let a = s.current
        let sig = given ?? Signatures.basic(a.def)
        let shot = big ? Moves.shotBig : sig.shot
        a.busy = true
        timeline.cancel(tag: a)
        let first = a.model.shoot(shot)
        // Hand glow while charging the shot; kept small when the hand is right in front of the camera.
        let near = Float(camScale(a.model.handWorld))
        let glow = Toon.glowSprite(a.def.aura, size: CGFloat(0.35 * near))
        a.model.fistR.addChildNode(glow)
        glow.runAction(.scale(to: CGFloat(1 + near), duration: 0.2))
        let interval = hits > 3 ? 0.1 : 0.14
        // Shots release on the clip's impact frame; volleys alternate hands.
        var steps: [(Double, () -> Void)] = [(first.impact + 0.06, {})]
        for i in 0..<hits {
            steps.append((i == 0 ? 0 : interval, { [weak self] in
                guard let self else { return }
                let fire = { [weak self] in
                    self?.spawnProjectile(s, power: power / Double(hits), radius: big ? 0.5 : (small ? 0.18 : (hits == 1 ? 0.32 : 0.22)),
                                          spread: hits > 1 ? Float(i % 2 == 0 ? 1 : -1) * Float(i) * 0.06 : 0,
                                          sfx: sig.fire, pitch: sig.pitch)
                }
                if i == 0 {
                    fire()
                } else {
                    let c = a.model.shoot(shot, speed: 1.4)
                    self.timeline.after(c.impact / 1.4, tag: a) { fire() }
                }
            }))
        }
        steps.append((0.05, { [weak self] in
            glow.removeFromParentNode()
            guard let self else { return }
            s.chainOpenUntil = self.now + 0.55
            self.extendLock(s)
        }))
        steps.append((small ? 0.2 : 0.16, {
            a.busy = false
        }))
        timeline.sequence(tag: a, steps)
    }

    func spawnProjectile(_ s: Side, power: Double, radius: Float, spread: Float, sfx: SFX = .blast, pitch: Float = 1) {
        let a = s.current
        let t = opponent(of: s).current
        let start = a.model.handWorld
        var dir = simd_normalize(t.chest - start)
        let right = simd_normalize(simd_cross(dir, SIMD3(0, 1, 0)))
        dir = simd_normalize(dir + right * spread)
        let n = VFX.projectile(color: a.def.aura, radius: radius)
        let near = camScale(start)
        VFX.muzzle(at: start, color: a.def.aura, size: CGFloat(radius * 6) * near * near, in: fxRoot)
        VFX.muzzleSparks(at: start, dir: dir, color: a.def.aura, in: fxRoot)
        // Recoil: the shooter is pushed back a little, camera nudges when the player fires.
        let back = SCNAction.moveBy(x: 0, y: 0, z: CGFloat(-0.12 - radius * 0.3), duration: 0.05)
        back.timingMode = .easeOut
        let ret = SCNAction.moveBy(x: 0, y: 0, z: CGFloat(0.12 + radius * 0.3), duration: 0.16)
        ret.timingMode = .easeInEaseOut
        a.model.body.runAction(.sequence([back, ret]), forKey: "recoil")
        if s.isPlayer { shake = max(shake, 0.02 + radius * 0.05) }
        n.simdPosition = start
        // Grow in as it leaves the hand so the shooter's own shot never floods the over-shoulder camera.
        n.scale = SCNVector3(0.25, 0.25, 0.25)
        n.runAction(.scale(to: 1, duration: 0.16))
        fxRoot.addChildNode(n)
        let farBonus = RangeZone.of(dist(a, t)) == .far ? 1.1 : 1.0
        projectiles.append(Projectile(node: n, owner: s, pos: start, vel: dir * Tune.blastSpeed, radius: radius, power: power * farBonus))
        Sound.play(sfx, pitch: pitch)
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
                    if canAIDodge(o) && roll(aiDodgeChance * 0.9) {
                        _ = dodge(o, lateral: roll(0.5) ? 1 : -1)
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
                        VFX.impact(at: p.pos, color: p.owner.current.def.aura, heavy: p.radius >= 0.3, in: fxRoot,
                                   dir: simd_normalize(p.vel), scale: camScale(p.pos))
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
        let orb = VFX.chargeIn(color: color, radius: CGFloat(1.0 + radius))
        a.model.fistR.addChildNode(orb)
        orb.childNode(withName: "orb", recursively: false)?.runAction(.scale(to: CGFloat(1 + radius * 4), duration: startup))
        if s.isPlayer || ultimate { hud.speedLines(startup) }
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
            let holder = VFX.beam(color: color, radius: radius, length: length)
            holder.simdPosition = start
            holder.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
            holder.simdScale = SIMD3(1, 0.01, 1)
            self.fxRoot.addChildNode(holder)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.16
            holder.simdScale = SIMD3(1, 1, 1)
            SCNTransaction.commit()
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
            if (!o.isPlayer || o.auto) && self.canAIDodge(o) && self.roll(self.aiDodgeChance * (ultimate ? 1.1 : 1)),
               self.dodge(o, lateral: self.roll(0.5) ? 1 : -1) {
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
                VFX.muzzle(at: t.chest, color: a.def.aura, size: CGFloat(radius * 7), in: self.fxRoot)
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
        let orb = VFX.projectile(color: color, radius: 1.5)
        orb.addParticleSystem(VFX.chargeSparks(color))
        orb.particleSystems?.last?.birthRate = 80
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
            if (!o.isPlayer || o.auto) && self.canAIDodge(o) && self.roll(self.aiDodgeChance),
               self.dodge(o, lateral: self.roll(0.5) ? 1 : -1) {
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
        hud.speedLines(duration)
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
        if roll(p) { perfectEvade(o, attacker: s) } else { showEvade(o.current) }
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
        snapCamera = true
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

    /// AI pre-check uses the same real cost as `dodge` (double while in hitstun).
    func canAIDodge(_ s: Side) -> Bool {
        (!s.isPlayer || s.auto) && !s.current.isKO && s.dodge >= dodgeCost(s) && !battleOver && now >= s.current.stunUntil
    }

    func awardShard(_ s: Side) {
        guard s.cardLanded else { return }
        s.cardLanded = false
        if s.chain >= 1 || roll(0.4) {
            s.shards = min(Tune.shardsNeeded, s.shards + 1)
        }
    }

    @discardableResult
    func applyHit(from s: Side, power: Double, stun: Double, knock: Float, heavy: Bool, aiDodge: Double,
                  ignoreInvuln: Bool = false, basic: Bool = false, source: SIMD2<Float>? = nil,
                  sfx: SFX? = nil, pitch: Float = 1) -> Bool {
        let o = opponent(of: s)
        let t = o.current
        let a = s.current
        guard !t.isKO, !battleOver else { return false }
        if !ignoreInvuln && now < t.invulnUntil {
            evaded(o, by: s)
            return false
        }
        if aiDodge > 0 && !(Cheats.freezeAI && !o.isPlayer) && canAIDodge(o) && roll(aiDodge) {
            // The evade must actually execute; otherwise this same hit lands normally.
            if dodge(o, lateral: roll(0.5) ? 1 : -1) {
                aiEvade(o, by: s)
                return false
            }
        }
        var dmg = power * a.atk * (1200 / (1000 + t.dfn * (now < t.cursedUntil ? 0.7 : 1))) * 1.25
        dmg *= damageVariance()
        let affinity = Element.multiplier(a.def.element, t.def.element)
        dmg *= affinity
        if now < a.powerUntil { dmg *= 1.3 }
        if now < t.barrierUntil { dmg *= 0.4 }
        dmg *= 1 + min(0.3, Double(max(0, s.comboCount - 4)) * 0.02)
        let crit = roll(0.08)
        if crit { dmg *= 1.5 }
        dmg = dmg.rounded()
        if s.isPlayer && Cheats.oneHit { dmg = max(dmg, t.hp) }
        if o.isPlayer && Cheats.god { dmg = 0 }
        t.hp = max(0, t.hp - dmg)
        timeline.cancel(tag: t)
        t.busy = false
        t.stunUntil = now + stun
        let src = source ?? a.pos
        var away = t.pos - src
        away = simd_length(away) > 0.001 ? simd_normalize(away) : SIMD2(0, 1)
        t.tween = nil
        t.knockVel = away * knock
        if let r = o.relay, r.entrant === t { r.closed = true }
        if heavy && knock >= 8 {
            t.launchedUntil = now + Tune.launchWindow
            s.relay = Relay(target: t, launcher: a, until: t.launchedUntil)
            VFX.dust(at: t.world3 + SIMD3(0, 0.1, 0), scale: 1.0, in: fxRoot)
        }
        t.model.hurt(heavy: heavy)
        if !basic { s.cardLanded = true }
        if basic { s.energy = min(Tune.energyMax, s.energy + 2) }

        let hitPoint = t.chest + SIMD3(0, 0.1, 0)
        let ranged = source != nil
        let hitDir = simd_normalize(SIMD3(away.x, 0.15, away.y))
        spark(at: hitPoint, color: a.def.aura, big: heavy || crit, dir: hitDir)
        popup(crit ? "\(Int(dmg))!" : "\(Int(dmg))", at: hitPoint + SIMD3(Float.random(in: -0.3...0.3), 0.5, 0),
              color: crit ? Theme.accent : (affinity > 1 ? UIColor(hex: 0xFF9A4A) : (affinity < 1 ? Theme.text2 : .white)),
              size: crit ? 26 : (heavy ? 21 : 16))
        if affinity > 1 && heavy {
            popup(L("battle.advantage"), at: hitPoint + SIMD3(0, 1.0, 0), color: UIColor(hex: 0xFF9A4A), size: 15)
        }
        // Hit stop scaled by hit weight (light jab → heavy launcher → critical), like arcade fighters.
        let stop: Double = (heavy ? 0.11 : (basic ? 0.045 : 0.065)) + (crit ? 0.035 : 0)
        beginHitStop(stop, attacker: ranged && dist(a, t) > 3 ? nil : a, victim: t, shake: heavy ? 0.07 : 0.035)
        kickCamera(from: a.world3, to: t.world3, strength: heavy ? 0.32 : (basic ? 0.07 : 0.12))
        shake = max(shake, heavy ? 0.1 : 0.025)
        if heavy || crit { fovKick = max(-6, fovKick - (heavy ? 4 : 2)) }
        if heavy && !o.isPlayer { hud.screenFlash(UIColor(white: 1, alpha: 0.5)) }
        Sound.play(sfx ?? (heavy || crit ? .heavy : .hit), pitch: pitch)
        if heavy && !basic { Sound.play(.crack, pitch: pitch * 0.8) }
        if s.isPlayer || o.isPlayer {
            if crit { Haptics.rigid.impactOccurred(intensity: 1) } else { Haptics.hit(heavy) }
        }

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
        // KO: long freeze-frame + flash before the slow-motion replay angle.
        beginHitStop(0.22, attacker: opponent(of: side).current, victim: c, shake: 0.09)
        hud.screenFlash(.white)
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

    @discardableResult
    func swap(_ s: Side, to index: Int, forced: Bool) -> Bool {
        guard index != s.active, index >= 0, index < s.team.count, !s.team[index].isKO else { return false }
        if !forced {
            // Switching is also the way out of a combo (DBL-style).
            guard canAct(s) || inHitstun(s), now >= s.swapReadyAt else { return false }
        }
        swapCore(s, to: index, banner: L10n.f("battle.tagin", s.team[index].def.name.s))
        return true
    }

    /// Shared tag-in: cancels the old fighter's pending events, starts the normal swap cooldown,
    /// resets the chain and deals a fresh hand (stale refill callbacks are invalidated by handGen).
    func swapCore(_ s: Side, to index: Int, banner: String) {
        let old = s.current
        let pos = old.pos
        let escaping = now < old.stunUntil && !old.isKO
        if escaping {
            // Breaking out of a combo interrupts the attacker's current card.
            let o = opponent(of: s)
            timeline.cancel(tag: o.current)
            o.current.busy = false
            o.chainOpenUntil = 0
            o.current.model.stance()
            popup(L("battle.breakout"), at: old.chest + SIMD3(0, 0.9, 0), color: Theme.energy, size: 20)
        }
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
        hud.moveBanner(banner, kind: .strike, side: s)
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

// MARK: - Main ability

extension BattleScreen {
    func abilityReady(_ s: Side) -> Bool {
        let c = s.current
        return !c.abilityUsed && now >= MainAbility.chargeTime && canAct(s)
    }

    /// Charge progress 0…1 for the HUD.
    var abilityCharge: Double { min(1, now / MainAbility.chargeTime) }

    @discardableResult
    func useAbility(_ s: Side) -> Bool {
        guard abilityReady(s) else { return false }
        let a = s.current
        let o = opponent(of: s)
        let ab = a.def.ability
        a.abilityUsed = true
        a.busy = true
        s.charging = false
        timeline.cancel(tag: a)
        a.model.apply(FighterModel.chargePose, duration: 0.12)
        a.model.setAura(3)
        a.auraBurstUntil = now + 1.2
        hud.moveBanner(ab.name, kind: .effect, side: s, symbol: ab.symbol)
        Sound.play(.charge)
        if s.isPlayer { Haptics.rigid.impactOccurred() }
        VFX.vanish(at: a.world3, height: 2.2, color: a.def.aura, in: fxRoot)
        switch ab {
        case .recover:
            let amount = a.maxHP * 0.3
            a.hp = min(a.maxHP, a.hp + amount)
            a.cursedUntil = 0
            popup("+\(Int(amount))", at: a.chest + SIMD3(0, 0.6, 0), color: Theme.effect, size: 26)
        case .guardian:
            a.barrierUntil = now + 8
            s.dodge = Tune.dodgeMax
        case .overdrive:
            a.powerUntil = now + 12
            s.energy = min(Tune.energyMax, s.energy + 40)
            popup(L("battle.atkup"), at: a.chest + SIMD3(0, 0.7, 0), color: UIColor(hex: 0xFF8A5E), size: 22)
        case .surge:
            s.energy = Tune.energyMax
            s.dodge = min(Tune.dodgeMax, s.dodge + 50)
            popup(L("ability.surge"), at: a.chest + SIMD3(0, 0.7, 0), color: Theme.energy, size: 22)
        case .hex:
            o.current.cursedUntil = now + 12
            o.energy = max(0, o.energy - 40)
            popup(L("ability.hex"), at: o.current.chest + SIMD3(0, 0.7, 0), color: Theme.ultimate, size: 22)
        }
        timeline.after(0.5, tag: a) {
            a.busy = false
            a.model.stance()
        }
        return true
    }
}
