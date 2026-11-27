import SpriteKit

final class BattleScene: SKScene {
    let playerIDs: [String]
    let enemyIDs: [String]
    let enemyLevel: Int
    let stage: Int

    let world = SKNode()
    let hud = SKNode()
    let overlay = SKNode()

    var player: Side!
    var enemy: Side!
    let groundY: CGFloat = 235
    var now: TimeInterval = 0
    private var lastUpdate: TimeInterval = 0
    var projectiles: [Projectile] = []
    var battleOver = false
    var cinematic = false
    var started = false
    var pausedGame = false
    var timeLeft = Tune.battleTime

    // AI
    var aiNext: TimeInterval = 1.0
    var aiChargeUntil: TimeInterval = 0
    var aiThinkMin: Double { max(0.32, 0.95 - Double(stage) * 0.03) }
    var aiDodgeChance: Double { min(0.5, 0.16 + Double(stage) * 0.017) }

    // HUD
    var pHP: BarNode!
    var eHP: BarNode!
    var pName: ShadowLabel!
    var eName: ShadowLabel!
    var pSoulBar: BarNode!
    var eSoulBar: BarNode!
    var timerLabel: ShadowLabel!
    var energyBar: BarNode!
    var energyLabel: ShadowLabel!
    var cardButtons: [CardButton] = []
    var specialBtn: ButtonNode!
    var specialCD: SKLabelNode!
    var ultBtn: ButtonNode!
    var ultRing: SKShapeNode!
    var ultLabel: SKLabelNode!
    var chargeBtn: ButtonNode!
    var dodgeBtn: ButtonNode!
    var dodgePips: [SKShapeNode] = []
    var pPortraits: [PortraitButton] = []
    var ePortraits: [PortraitButton] = []
    var comboLabel: ShadowLabel!
    var lastUltPct = -1
    var pauseLayer: SKNode?
    private var touchStart: [UITouch: CGPoint] = [:]

    var minX: CGFloat { Layout.safeLeft + 60 }
    var maxX: CGFloat { size.width - Layout.safeRight - 60 }

    init(size: CGSize, playerIDs: [String], enemyIDs: [String], enemyLevel: Int, stage: Int) {
        self.playerIDs = playerIDs
        self.enemyIDs = enemyIDs
        self.enemyLevel = enemyLevel
        self.stage = stage
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        backgroundColor = .black
        anchorPoint = .zero
        addChild(BackgroundNode(size: size, groundY: groundY, theme: stage - 1))
        world.zPosition = 10
        addChild(world)
        hud.zPosition = 100
        addChild(hud)
        overlay.zPosition = 200
        addChild(overlay)

        let pt = playerIDs.map { Combatant(def: Roster.byID($0), level: Save.shared.level($0)) }
        let et = enemyIDs.map { Combatant(def: Roster.byID($0), level: enemyLevel) }
        player = Side(isPlayer: true, team: pt)
        enemy = Side(isPlayer: false, team: et)
        place(player.current, x: size.width * 0.3, z: 5)
        place(enemy.current, x: size.width * 0.7, z: 4)
        fillHand(player)
        fillHand(enemy)
        updateFacing(force: true)
        buildHUD()
        intro()
    }

    private func place(_ c: Combatant, x: CGFloat, z: CGFloat) {
        c.node.position = CGPoint(x: x.clamped(minX, maxX), y: groundY)
        c.node.zPosition = z
        world.addChild(c.node)
    }

    func opponent(of s: Side) -> Side { s === player ? enemy : player }

    // MARK: - Intro

    private func intro() {
        let stageLabel = ShadowLabel("STAGE \(stage)", size: 40, color: UIColor(hex: 0xFFC94A))
        stageLabel.position = CGPoint(x: size.width / 2, y: size.height / 2 + 70)
        overlay.addChild(stageLabel)
        let big = ShadowLabel("READY", size: 96)
        big.position = CGPoint(x: size.width / 2, y: size.height / 2 - 10)
        big.setScale(0.3)
        overlay.addChild(big)
        big.run(.sequence([
            .scale(to: 1, duration: 0.2),
            .wait(forDuration: 0.9),
            .run { big.text = "FIGHT!"; big.color = UIColor(hex: 0xFF7A45); big.setScale(1.6); Sound.play(.heavy) },
            .scale(to: 1, duration: 0.12),
            .wait(forDuration: 0.5),
            .group([.fadeOut(withDuration: 0.25), .scale(to: 1.4, duration: 0.25)]),
            .removeFromParent(),
        ]))
        stageLabel.run(.sequence([.wait(forDuration: 1.1), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        run(.sequence([.wait(forDuration: 1.25), .run { [weak self] in
            guard let self else { return }
            self.started = true
            self.aiNext = self.now + 1.0
        }]))
    }

    // MARK: - Loop

    override func update(_ currentTime: TimeInterval) {
        let rawDT = lastUpdate == 0 ? 1.0 / 60 : currentTime - lastUpdate
        lastUpdate = currentTime
        let dt = min(1.0 / 30, max(0, rawDT))
        if pausedGame { return }
        now += dt
        if started && !battleOver && !cinematic {
            timeLeft -= dt
            if timeLeft <= 0 {
                timeLeft = 0
                timeUp()
            }
        }
        if started {
            tickSide(player, dt)
            tickSide(enemy, dt)
            if !cinematic { updateProjectiles(dt) }
            if !battleOver { aiUpdate() }
        }
        updateFacing(force: false)
        updateHUD(CGFloat(dt))
    }

    func canAct(_ s: Side) -> Bool {
        let c = s.current
        return started && !battleOver && !cinematic && !c.isKO && !c.busy && now >= c.stunUntil
            && !opponent(of: s).current.isKO
    }

    private func tickSide(_ s: Side, _ dt: Double) {
        let c = s.current
        let free = canAct(s)
        let charging = s.charging && free
        if !battleOver && !cinematic {
            s.energy = min(Tune.energyMax, s.energy + (charging ? Tune.chargeRate : Tune.energyRegen) * dt)
            s.dodge = min(Tune.dodgeMax, s.dodge + Tune.dodgeRegen * dt)
        }
        c.node.setCharging(charging)
        if free && !charging && s.moveDir != 0 {
            c.node.position.x = (c.node.position.x + s.moveDir * Tune.moveSpeed * CGFloat(dt)).clamped(minX, maxX)
        }
        if now - s.lastHitTime > 1.3 { s.comboCount = 0 }
    }

    private func updateFacing(force: Bool) {
        for s in [player!, enemy!] {
            let c = s.current
            if c.isKO || (c.busy && !force) { continue }
            let t = opponent(of: s).current
            let dx = t.node.position.x - c.node.position.x
            if abs(dx) > 4 { c.node.setFacing(dx > 0 ? 1 : -1) }
        }
    }

    // MARK: - Hand

    func draw(for s: Side) -> Card {
        let cards = s.current.def.cards
        let held = s.hand.compactMap { $0?.name }
        let fresh = cards.filter { c in held.filter { $0 == c.name }.count < 2 }
        return (fresh.isEmpty ? cards : fresh).randomElement()!
    }

    func fillHand(_ s: Side) {
        s.handGen += 1
        s.hand = [nil, nil, nil, nil]
        for i in 0..<4 { s.hand[i] = draw(for: s) }
    }

    @discardableResult
    func useCard(_ s: Side, _ idx: Int) -> Bool {
        guard canAct(s), idx >= 0, idx < 4, let card = s.hand[idx], s.energy >= Double(card.cost) else { return false }
        s.energy -= Double(card.cost)
        s.charging = s.isPlayer ? s.charging : false
        s.hand[idx] = nil
        let gen = s.handGen
        world.run(.sequence([.wait(forDuration: 0.75), .run { [weak self] in
            guard let self, s.handGen == gen, s.hand[idx] == nil else { return }
            s.hand[idx] = self.draw(for: s)
        }]))
        if s.isPlayer { Sound.play(.card) }
        switch card.kind {
        case .strike: doStrike(s, power: card.power, hits: card.hits, rush: false)
        case .blast: doBlast(s, power: card.power, hits: card.hits)
        }
        return true
    }

    // MARK: - Actions

    func doStrike(_ s: Side, power: Double, hits: Int, rush: Bool) {
        let a = s.current
        let o = opponent(of: s)
        let t = o.current
        a.busy = true
        let dir: CGFloat = t.node.position.x >= a.node.position.x ? 1 : -1
        a.node.setFacing(dir)
        let destX = (t.node.position.x - dir * 78).clamped(minX, maxX)
        let dist = abs(destX - a.node.position.x)
        let dashT = max(0.07, Double(dist) / (rush ? 2400 : 1700))
        var seq: [SKAction] = []
        seq.append(.run { [weak self] in
            a.node.dashPose()
            Sound.play(.dodge)
            if let self, dist > 120 { a.node.spawnAfterimage(in: self.world) }
        })
        seq.append(.moveTo(x: destX, duration: dashT))
        let per = power / Double(hits)
        for i in 0..<hits {
            let last = i == hits - 1
            seq.append(.run { [weak self] in
                guard let self else { return }
                a.node.strikePose(i)
                let target = o.current
                guard !target.isKO, abs(target.node.position.x - a.node.position.x) < Tune.strikeRange else { return }
                let aiChance = i == 0 ? self.aiDodgeChance : self.aiDodgeChance * 0.3
                self.applyHit(from: s, power: per * (last ? 1.4 : 1), stun: last ? 0.65 : 0.38,
                              knock: last ? (rush ? 190 : 140) : 16, heavy: last, aiDodge: aiChance)
                if !last && abs(target.node.position.x - a.node.position.x) > 90 {
                    // Follow the target a little so combos connect.
                    let follow = (target.node.position.x - dir * 78).clamped(self.minX, self.maxX)
                    a.node.run(.moveTo(x: follow, duration: 0.05))
                }
            })
            seq.append(.wait(forDuration: rush ? 0.1 : 0.13))
        }
        seq.append(.wait(forDuration: 0.16))
        seq.append(.run {
            a.busy = false
            a.node.stance()
        })
        a.node.run(.sequence(seq), withKey: "act")
    }

    func doBlast(_ s: Side, power: Double, hits: Int, big: Bool = false) {
        let a = s.current
        a.busy = true
        let interval = hits > 3 ? 0.09 : 0.13
        a.node.blastPose(hold: 0.2 + Double(hits) * interval)
        let charge = SKSpriteNode(texture: Tex.glow)
        charge.name = "fx"
        charge.color = a.def.aura
        charge.colorBlendFactor = 1
        charge.blendMode = .add
        charge.size = CGSize(width: 30, height: 30)
        a.node.attachFront(charge, at: CGPoint(x: 62, y: 118 + FighterNode.hoverY))
        charge.run(.scale(to: 2.2, duration: 0.2))
        var seq: [SKAction] = [.wait(forDuration: 0.22)]
        for _ in 0..<hits {
            seq.append(.run { [weak self] in
                self?.spawnProjectile(s, power: power / Double(hits), radius: big ? 26 : (hits == 1 ? 22 : 14))
            })
            seq.append(.wait(forDuration: interval))
        }
        seq.append(.run { charge.removeFromParent() })
        seq.append(.wait(forDuration: 0.18))
        seq.append(.run { a.busy = false; a.node.stance() })
        a.node.run(.sequence(seq), withKey: "act")
    }

    func spawnProjectile(_ s: Side, power: Double, radius: CGFloat) {
        let a = s.current
        let n = SKNode()
        let glow = SKSpriteNode(texture: Tex.glow)
        glow.size = CGSize(width: radius * 4, height: radius * 4)
        glow.color = a.def.aura
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        n.addChild(glow)
        let core = SKShapeNode(circleOfRadius: radius * 0.6)
        core.fillColor = .white
        core.strokeColor = a.def.aura
        core.lineWidth = 3
        n.addChild(core)
        let trail = SKEmitterNode()
        trail.particleTexture = Tex.glow
        trail.particleBirthRate = 120
        trail.particleLifetime = 0.25
        trail.particleScale = radius / 40
        trail.particleScaleSpeed = -radius / 30
        trail.particleAlpha = 0.7
        trail.particleAlphaSpeed = -2.5
        trail.particleColor = a.def.aura
        trail.particleColorBlendFactor = 1
        trail.particleBlendMode = .add
        trail.particlePositionRange = CGVector(dx: 4, dy: radius * 0.6)
        n.addChild(trail)
        let hp = a.node.handPoint
        n.position = CGPoint(x: hp.x, y: hp.y + CGFloat.random(in: -10...10))
        n.zPosition = 20
        world.addChild(n)
        trail.targetNode = world
        let p = Projectile(node: n, owner: s, vx: a.node.facing * 980, radius: radius, power: power)
        projectiles.append(p)
        Sound.play(.blast)
    }

    private func updateProjectiles(_ dt: Double) {
        for p in projectiles where p.alive {
            p.node.position.x += p.vx * CGFloat(dt)
            let o = opponent(of: p.owner)
            let t = o.current
            if !t.isKO {
                let dx = t.node.position.x - p.node.position.x
                let approaching = (dx > 0) == (p.vx > 0)
                if !o.isPlayer && !p.aiRolled && approaching && abs(dx) < 240 {
                    p.aiRolled = true
                    if canAIDodge(o) && chance(aiDodgeChance * 0.9) {
                        let dir: CGFloat = chance(0.5) ? 1 : -1
                        dodge(o, dir: dir)
                    }
                }
                if abs(dx) < 30 + p.radius {
                    if now < t.invulnUntil {
                        if !p.evadeShown {
                            p.evadeShown = true
                            showEvade(t)
                        }
                    } else {
                        p.alive = false
                        applyHit(from: p.owner, power: p.power, stun: 0.42, knock: 40, heavy: false, aiDodge: 0,
                                 sourceX: p.node.position.x)
                        burst(at: p.node.position, color: p.owner.current.def.aura, scale: p.radius / 18)
                    }
                }
            }
            if p.node.position.x < -100 || p.node.position.x > size.width + 100 { p.alive = false }
        }
        // Clash: opposing projectiles cancel each other out.
        let live = projectiles.filter { $0.alive }
        for i in 0..<live.count {
            for j in (i + 1)..<live.count where live[i].alive && live[j].alive && live[i].owner !== live[j].owner {
                if abs(live[i].node.position.x - live[j].node.position.x) < live[i].radius + live[j].radius
                    && abs(live[i].node.position.y - live[j].node.position.y) < 50 {
                    live[i].alive = false
                    live[j].alive = false
                    burst(at: live[i].node.position, color: .white, scale: 1.2)
                    Sound.play(.hit)
                }
            }
        }
        for p in projectiles where !p.alive { p.node.removeFromParent() }
        projectiles.removeAll { !$0.alive }
    }

    func doSpecial(_ s: Side) {
        guard canAct(s), now >= s.specialReadyAt, s.energy >= Tune.specialCost else { return }
        s.energy -= Tune.specialCost
        s.specialReadyAt = now + Tune.specialCooldown
        s.charging = s.isPlayer ? s.charging : false
        let a = s.current
        showMoveBanner(a.def.specialName, side: s, ultimate: false)
        Sound.play(.charge)
        switch a.def.specialStyle {
        case .beam:
            fireBeam(s, power: a.def.specialPower, thickness: 44, startup: 0.45, ticks: 6)
        case .rush:
            a.busy = true
            a.node.powerUpPose(0.35)
            a.node.run(.sequence([.wait(forDuration: 0.3), .run { [weak self] in
                self?.doStrike(s, power: a.def.specialPower, hits: 7, rush: true)
            }]), withKey: "act")
        case .volley:
            a.busy = true
            a.node.powerUpPose(0.3)
            a.node.run(.sequence([.wait(forDuration: 0.25), .run { [weak self] in
                self?.doBlast(s, power: a.def.specialPower, hits: 7)
            }]), withKey: "act")
        }
    }

    func fireBeam(_ s: Side, power: Double, thickness: CGFloat, startup: Double, ticks: Int, ultimate: Bool = false) {
        let a = s.current
        a.busy = true
        a.node.powerUpPose(startup)
        let color = a.def.aura
        let origin = CGPoint(x: 62, y: 118 + FighterNode.hoverY)

        let orb = SKSpriteNode(texture: Tex.glow)
        orb.name = "fx"
        orb.color = color
        orb.colorBlendFactor = 1
        orb.blendMode = .add
        orb.size = CGSize(width: 20, height: 20)
        a.node.attachFront(orb, at: origin)
        orb.run(.scale(to: thickness / 8, duration: startup))

        var locked = false
        let length = size.width * 1.4
        var seq: [SKAction] = [.wait(forDuration: startup)]
        seq.append(.run { [weak self] in
            guard let self else { return }
            a.node.blastPose(hold: 0.2 + Double(ticks) * 0.12)
            let beam = SKNode()
            beam.name = "fx"
            let outer = SKShapeNode(rect: CGRect(x: 0, y: -thickness / 2, width: length, height: thickness), cornerRadius: thickness / 2)
            outer.fillColor = color.withAlphaComponent(0.75)
            outer.strokeColor = .clear
            outer.blendMode = .add
            let core = SKShapeNode(rect: CGRect(x: 0, y: -thickness * 0.22, width: length, height: thickness * 0.44), cornerRadius: thickness * 0.22)
            core.fillColor = .white
            core.strokeColor = .clear
            beam.addChild(outer)
            beam.addChild(core)
            beam.xScale = 0.01
            a.node.attachFront(beam, at: origin)
            beam.run(.scaleX(to: 1, duration: 0.18))
            beam.run(.repeatForever(.sequence([.scaleY(to: 1.15, duration: 0.05), .scaleY(to: 0.9, duration: 0.05)])))
            Sound.play(.beam)
            self.shake(ultimate ? 14 : 7, duration: 0.4)
        })
        // Contact check when the beam front reaches the target.
        seq.append(.wait(forDuration: 0.1))
        seq.append(.run { [weak self] in
            guard let self else { return }
            let o = self.opponent(of: s)
            let t = o.current
            let inFront = (t.node.position.x - a.node.position.x) * a.node.facing > 0
            guard inFront, !t.isKO else { return }
            if self.now < t.invulnUntil {
                self.showEvade(t)
                return
            }
            if !o.isPlayer && self.canAIDodge(o) && chance(self.aiDodgeChance * (ultimate ? 1.1 : 1)) {
                self.dodge(o, dir: -a.node.facing)
                self.showEvade(t)
                return
            }
            locked = true
        })
        for k in 0..<ticks {
            let last = k == ticks - 1
            seq.append(.run { [weak self] in
                guard let self, locked else { return }
                let t = self.opponent(of: s).current
                if self.now < t.invulnUntil { locked = false; return }
                self.applyHit(from: s, power: power / Double(ticks) * (last ? 1.3 : 1), stun: last ? 0.8 : 0.5,
                              knock: last ? 200 : 12, heavy: last, aiDodge: 0, ignoreInvuln: true)
            })
            seq.append(.wait(forDuration: 0.12))
        }
        seq.append(.run { a.node.removeAttachments() })
        seq.append(.wait(forDuration: 0.2))
        seq.append(.run { a.busy = false; a.node.stance() })
        a.node.run(.sequence(seq), withKey: "act")
    }

    func doUltimate(_ s: Side) {
        guard canAct(s), s.soul >= 100 else { return }
        s.soul = 0
        let a = s.current
        let o = opponent(of: s)
        a.busy = true
        cinematic = true
        s.charging = s.isPlayer ? s.charging : false
        // Freeze the defender's current move.
        if !o.current.isKO {
            o.current.node.cancelAction()
            o.current.busy = false
        }
        Sound.play(.ultimate)
        Haptics.hit(true)
        let cutDuration = ultimateCutIn(a.def, side: s)
        a.node.run(.sequence([.wait(forDuration: cutDuration), .run { [weak self] in
            guard let self else { return }
            self.cinematic = false
            switch a.def.ultimateStyle {
            case .beam:
                self.fireBeam(s, power: a.def.ultimatePower, thickness: 120, startup: 0.3, ticks: 8, ultimate: true)
            case .meteor:
                self.fireMeteor(s, power: a.def.ultimatePower)
            }
        }]), withKey: "act")
    }

    func fireMeteor(_ s: Side, power: Double) {
        let a = s.current
        a.busy = true
        a.node.powerUpPose(1.0)
        let color = a.def.aura
        let o = opponent(of: s)
        let targetX = o.current.node.position.x
        let impact = CGPoint(x: targetX, y: groundY + 70)

        let orb = SKNode()
        let glow = SKSpriteNode(texture: Tex.glow)
        glow.size = CGSize(width: 360, height: 360)
        glow.color = color
        glow.colorBlendFactor = 1
        glow.blendMode = .add
        orb.addChild(glow)
        let core = SKShapeNode(circleOfRadius: 55)
        core.fillColor = color.lighter(0.6)
        core.strokeColor = .white
        core.lineWidth = 6
        core.glowWidth = 8
        orb.addChild(core)
        orb.position = CGPoint(x: targetX - a.node.facing * 260, y: size.height + 160)
        orb.zPosition = 30
        world.addChild(orb)
        orb.run(.repeatForever(.rotate(byAngle: 3, duration: 0.5)))

        let fall = SKAction.move(to: impact, duration: 0.75)
        fall.timingMode = .easeIn
        orb.run(.sequence([fall, .run { [weak self] in
            guard let self else { return }
            orb.removeFromParent()
            self.explosion(at: impact, color: color)
            let t = o.current
            guard !t.isKO else { return }
            let near = abs(t.node.position.x - impact.x) < 190
            if !near || self.now < t.invulnUntil {
                self.showEvade(t)
                return
            }
            if !o.isPlayer && self.canAIDodge(o) && chance(self.aiDodgeChance) {
                self.dodge(o, dir: t.node.position.x < impact.x ? -1 : 1)
                self.showEvade(t)
                return
            }
            let ticks = 5
            for k in 0..<ticks {
                let last = k == ticks - 1
                self.world.run(.sequence([.wait(forDuration: Double(k) * 0.1), .run { [weak self] in
                    _ = self?.applyHit(from: s, power: power / Double(ticks) * (last ? 1.3 : 1), stun: last ? 0.9 : 0.5,
                                   knock: last ? 220 : 8, heavy: last, aiDodge: 0, ignoreInvuln: true, sourceX: impact.x)
                }]))
            }
        }]))
        Sound.play(.beam)
        a.node.run(.sequence([.wait(forDuration: 1.1), .run { a.busy = false; a.node.stance() }]), withKey: "act")
    }

    func canAIDodge(_ s: Side) -> Bool {
        !s.isPlayer && !s.current.isKO && s.dodge >= Tune.dodgeCost && !battleOver
    }

    @discardableResult
    func dodge(_ s: Side, dir: CGFloat) -> Bool {
        let c = s.current
        guard started, !battleOver, !cinematic, !c.isKO, s.dodge >= Tune.dodgeCost else { return false }
        s.dodge -= Tune.dodgeCost
        c.node.cancelAction()
        c.node.removeAction(forKey: "knock")
        c.busy = false
        c.stunUntil = 0
        c.invulnUntil = now + Tune.dodgeInvuln
        c.node.spawnAfterimage(in: world)
        var d = dir == 0 ? -c.node.facing : dir
        var dest = (c.node.position.x + d * 200).clamped(minX, maxX)
        if abs(dest - c.node.position.x) < 60 {
            d = -d
            dest = (c.node.position.x + d * 200).clamped(minX, maxX)
        }
        c.node.run(.moveTo(x: dest, duration: 0.1))
        c.node.dodgeFlicker()
        Sound.play(.dodge)
        return true
    }

    func swap(_ s: Side, to index: Int, forced: Bool) {
        guard index != s.active, index >= 0, index < s.team.count, !s.team[index].isKO else { return }
        if !forced {
            guard canAct(s), now >= s.swapReadyAt else { return }
        }
        let old = s.current
        var pos = old.node.position
        if forced { pos.x = s.isPlayer ? size.width * 0.28 : size.width * 0.72 }
        old.node.cancelAction()
        old.node.removeFromParent()
        s.active = index
        s.swapReadyAt = now + Tune.swapCooldown
        s.charging = s.isPlayer ? s.charging : false
        let n = s.current
        n.busy = false
        n.stunUntil = 0
        n.invulnUntil = now + 0.6
        place(n, x: pos.x, z: s.isPlayer ? 5 : 4)
        n.node.enterEffect()
        fillHand(s)
        updateFacing(force: true)
        showTagBanner(n.def, side: s)
        Sound.play(.charge)
    }

    // MARK: - Hits

    @discardableResult
    func applyHit(from s: Side, power: Double, stun: Double, knock: CGFloat, heavy: Bool, aiDodge: Double,
                  ignoreInvuln: Bool = false, sourceX: CGFloat? = nil) -> Bool {
        let o = opponent(of: s)
        let t = o.current
        let a = s.current
        guard !t.isKO, !battleOver else { return false }
        if !ignoreInvuln && now < t.invulnUntil {
            showEvade(t)
            return false
        }
        if aiDodge > 0 && canAIDodge(o) && chance(aiDodge) {
            let away: CGFloat = t.node.position.x >= a.node.position.x ? 1 : -1
            dodge(o, dir: chance(0.6) ? away : -away)
            showEvade(t)
            return false
        }
        var dmg = power * a.atk * (1000 / (1000 + t.dfn)) * Double.random(in: 0.92...1.08)
        let crit = chance(0.08)
        if crit { dmg *= 1.5 }
        if s.comboCount >= 8 { dmg *= 1.1 }
        t.hp = max(0, t.hp - dmg)
        t.node.cancelAction()
        t.busy = false
        t.stunUntil = now + stun
        let src = sourceX ?? a.node.position.x
        let away: CGFloat = t.node.position.x >= src ? 1 : -1
        let dest = (t.node.position.x + away * knock).clamped(minX, maxX)
        t.node.removeAction(forKey: "knock")
        let kb = SKAction.moveTo(x: dest, duration: heavy ? 0.28 : 0.08)
        kb.timingMode = .easeOut
        t.node.run(kb, withKey: "knock")
        t.node.hurt(heavy: heavy)

        let hitPoint = CGPoint(x: t.node.position.x - away * 14, y: t.node.position.y + 105)
        spark(at: hitPoint, color: a.def.aura, big: heavy || crit)
        damageNumber(Int(dmg), at: hitPoint, crit: crit)
        shake(heavy ? 9 : 3, duration: heavy ? 0.22 : 0.08)
        Sound.play(heavy ? .heavy : .hit)
        if s.isPlayer || o.isPlayer { Haptics.hit(heavy) }

        s.addSoul(heavy ? 5 : 2.5)
        o.addSoul(heavy ? 4 : 2)
        o.energy = min(Tune.energyMax, o.energy + 1.5)
        s.comboCount = now - s.lastHitTime < 1.3 ? s.comboCount + 1 : 1
        s.lastHitTime = now
        if s.isPlayer { showCombo(s.comboCount) }

        if t.isKO { handleKO(o) }
        return true
    }

    private func handleKO(_ side: Side) {
        let c = side.current
        c.node.cancelAction()
        c.busy = true
        if !side.isPlayer { side.charging = false }
        c.node.koAnim()
        Sound.play(.ko)
        shake(16, duration: 0.35)
        let ko = ShadowLabel("K.O.", size: 70, color: UIColor(hex: 0xFF5A5A))
        ko.position = CGPoint(x: c.node.position.x, y: c.node.position.y + 230)
        ko.setScale(0.4)
        world.addChild(ko)
        ko.run(.sequence([.scale(to: 1, duration: 0.15), .wait(forDuration: 0.8), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        world.speed = 0.35
        run(.sequence([.wait(forDuration: 0.5), .run { [weak self] in self?.world.speed = 1 }]))
        if side.allKO {
            endBattle(playerWon: !side.isPlayer)
            return
        }
        world.run(.sequence([.wait(forDuration: 0.6), .run { [weak self] in
            guard let self, !self.battleOver else { return }
            if let next = side.team.firstIndex(where: { !$0.isKO }) {
                self.swap(side, to: next, forced: true)
            }
        }]))
    }

    private func timeUp() {
        let pf = player.team.reduce(0.0) { $0 + $1.hp / $1.maxHP }
        let ef = enemy.team.reduce(0.0) { $0 + $1.hp / $1.maxHP }
        endBattle(playerWon: pf > ef, banner: "TIME UP")
    }

    func endBattle(playerWon: Bool, banner: String? = nil) {
        guard !battleOver else { return }
        battleOver = true
        player.charging = false
        player.moveDir = 0
        enemy.charging = false
        enemy.moveDir = 0
        var y = size.height / 2 + 20
        if let banner {
            let b = ShadowLabel(banner, size: 44, color: UIColor(hex: 0xFFC94A))
            b.position = CGPoint(x: size.width / 2, y: y + 90)
            overlay.addChild(b)
            y -= 10
        }
        let text = ShadowLabel(playerWon ? "VICTORY" : "DEFEAT", size: 110,
                               color: playerWon ? UIColor(hex: 0xFFD45A) : UIColor(hex: 0x9AA4C8))
        text.position = CGPoint(x: size.width / 2, y: y)
        text.setScale(2.2)
        text.alpha = 0
        overlay.addChild(text)
        text.run(.sequence([.wait(forDuration: 0.7), .group([.fadeIn(withDuration: 0.2), .scale(to: 1, duration: 0.2)])]))
        run(.sequence([.wait(forDuration: 3.0), .run { [weak self] in
            guard let self else { return }
            self.transition(to: ResultScene(size: self.size, won: playerWon, teamIDs: self.playerIDs, stage: self.stage))
        }]))
    }

    // MARK: - AI

    private func aiUpdate() {
        let s = enemy!
        let p = player!
        let c = s.current
        if c.isKO { s.charging = false; return }
        if s.charging && (now >= aiChargeUntil || s.energy >= 95) { s.charging = false }
        guard now >= aiNext, canAct(s) else { return }
        aiNext = now + Double.random(in: aiThinkMin...(aiThinkMin + 0.55))
        let dist = abs(c.node.position.x - p.current.node.position.x)

        // Movement intent
        if dist > 620 {
            s.moveDir = p.current.node.position.x > c.node.position.x ? 1 : -1
        } else if dist < 160 && chance(0.4) {
            s.moveDir = p.current.node.position.x > c.node.position.x ? -1 : 1
        } else {
            s.moveDir = chance(0.25) ? (chance(0.5) ? 1 : -1) : 0
        }

        if c.hpFraction < 0.25, now >= s.swapReadyAt, chance(0.35),
           let idx = s.team.indices.first(where: { $0 != s.active && s.team[$0].hpFraction > 0.5 }) {
            swap(s, to: idx, forced: false)
            return
        }
        if s.soul >= 100 && chance(0.7) {
            s.moveDir = 0
            doUltimate(s)
            return
        }
        if now >= s.specialReadyAt && s.energy >= Tune.specialCost && chance(0.45) {
            s.moveDir = 0
            doSpecial(s)
            return
        }
        let playable = s.hand.indices.filter { i in
            if let card = s.hand[i] { return s.energy >= Double(card.cost) }
            return false
        }
        if playable.isEmpty || (s.energy < 30 && chance(0.55)) {
            s.charging = true
            s.moveDir = 0
            aiChargeUntil = now + Double.random(in: 0.8...1.6)
            return
        }
        let preferStrike = dist < 450 ? chance(0.72) : chance(0.3)
        let wantKind: CardKind = preferStrike ? .strike : .blast
        let wanted = playable.filter { s.hand[$0]?.kind == wantKind }
        let pick = (wanted.isEmpty ? playable : wanted).randomElement()!
        s.moveDir = 0
        useCard(s, pick)
    }

    // MARK: - Touch (swipe to evade)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchStart[t] = t.location(in: self) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches {
            guard let start = touchStart.removeValue(forKey: t) else { continue }
            let end = t.location(in: self)
            let dx = end.x - start.x
            let dy = end.y - start.y
            guard hypot(dx, dy) > 45, !pausedGame else { continue }
            let dir: CGFloat = abs(dx) >= abs(dy) * 0.6 ? (dx > 0 ? 1 : -1) : -player.current.node.facing
            dodge(player, dir: dir)
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        for t in touches { touchStart.removeValue(forKey: t) }
    }

    // MARK: - Pause

    func setPaused(_ p: Bool) {
        guard !battleOver else { return }
        pausedGame = p
        world.isPaused = p
        player.charging = false
        player.moveDir = 0
        pauseLayer?.removeFromParent()
        pauseLayer = nil
        guard p else { return }
        let layer = SKNode()
        layer.zPosition = 300
        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = UIColor(white: 0, alpha: 0.7)
        dim.strokeColor = .clear
        layer.addChild(dim)
        let title = ShadowLabel("PAUSED", size: 64)
        title.position = CGPoint(x: size.width / 2, y: size.height / 2 + 120)
        layer.addChild(title)
        let resume = ButtonNode(text: "RESUME", size: CGSize(width: 300, height: 76), color: UIColor(hex: 0x2F8FE8))
        resume.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        resume.action = { [weak self] in self?.setPaused(false) }
        layer.addChild(resume)
        let quit = ButtonNode(text: "RETREAT", size: CGSize(width: 300, height: 76), color: UIColor(hex: 0x8A2C3A))
        quit.position = CGPoint(x: size.width / 2, y: size.height / 2 - 90)
        quit.action = { [weak self] in
            guard let self else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        layer.addChild(quit)
        addChild(layer)
        pauseLayer = layer
    }
}
