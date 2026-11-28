import UIKit
import SceneKit
import simd

/// Portrait 3D card battle. Over-the-shoulder camera behind the player's fighter.
final class BattleScreen: Screen {
    let playerIDs: [String]
    let enemyIDs: [String]
    let enemyLevel: Int
    let stage: Int

    var arena: Arena!
    var player: Side!
    var enemy: Side!
    let timeline = Timeline()
    var now: Double { timeline.now }
    var projectiles: [Projectile] = []
    var battleOver = false
    var cinematic = false
    var started = false
    var paused = false
    var timeLeft = Tune.battleTime
    var timeScale: Double = 1
    var hitStop: Double = 0
    /// Model roots frozen during hit stop (attacker + defender), and the defender that shakes.
    var frozenRoots: [SCNNode] = []
    var hitVictim: Combatant?
    var hitShakeAmp: Float = 0
    /// Directional camera kick (pushed along the hit direction, springs back).
    var camKick = SIMD3<Float>(repeating: 0)
    /// Jump the follow camera to its new spot next frame (after a teleport) instead of sweeping through fighters.
    var snapCamera = false
    var hud: BattleHUD!
    var startZone: RangeZone = .mid
    var fxRoot = SCNNode()

    // Camera
    var camPos = SIMD3<Float>(0, 3, -9)
    var camLook = SIMD3<Float>(0, 1.4, 0)
    var shot: (pos: SIMD3<Float>, look: SIMD3<Float>, until: Double, snap: Bool)?
    var shake: Float = 0
    var fovKick: Float = 0
    var victoryOrbit: Float?

    // AI
    var aiNext: [ObjectIdentifier: Double] = [:]
    var aiChargeUntil: [ObjectIdentifier: Double] = [:]
    var aiThinkMin: Double { max(0.35, 0.95 - Double(stage) * 0.03) }
    var aiDodgeChance: Double { min(0.5, 0.15 + Double(stage) * 0.017) }

    /// Randomness seams (tests replace these with deterministic sources).
    var roll: (Double) -> Bool = { chance($0) }
    var damageVariance: () -> Double = { Double.random(in: 0.94...1.06) }

    // Touch tracking
    var gesture = ArenaGesture()
    var liveTouches: [Int: UITouch] = [:]
    #if DEBUG
    var pendingGestureLog: (action: ArenaGesture.Action, cross: TimeInterval, accept: TimeInterval, accepted: Bool)?
    #endif

    init(playerIDs: [String], enemyIDs: [String], enemyLevel: Int, stage: Int) {
        self.playerIDs = playerIDs
        self.enemyIDs = enemyIDs
        self.enemyLevel = enemyLevel
        self.stage = stage
    }

    // MARK: - Setup

    override func build() {
        arena = Arena(theme: stage - 1)
        scene = arena.scene
        pointOfView = arena.camera
        // Battle camera: tighter, weaker bloom so additive hit/teleport FX stay crisp instead of white halos.
        if let cam = arena.camera.camera {
            cam.bloomIntensity = 0.45
            cam.bloomThreshold = 1.0
            cam.bloomBlurRadius = 7
        }
        arena.world.addChildNode(fxRoot)

        let pt = playerIDs.map { Combatant(def: Roster.byID($0), level: Save.shared.level($0)) }
        let et = enemyIDs.map { Combatant(def: Roster.byID($0), level: enemyLevel) }
        player = Side(isPlayer: true, team: pt)
        enemy = Side(isPlayer: false, team: et)
        startZone = Demo.mode != nil ? .mid : RangeZone(rawValue: Int.random(in: 0...2)) ?? .mid
        let d = Tune.startDistances[startZone.rawValue]
        place(player.current, at: SIMD2(0, -d / 2))
        place(enemy.current, at: SIMD2(0, d / 2))
        fillHand(player)
        fillHand(enemy)
        updateFacing()
        hud = BattleHUD(screen: self)
        // Intro camera: start in front of the enemy, sweep behind the player.
        let e = enemy.current
        // In front of the enemy (toward the player), three-quarter angle, whole upper body in frame.
        let toP = dirTo(e, player.current)
        let fwd = SIMD3(toP.x, 0, toP.y)
        let right = SIMD3(-toP.y, 0, toP.x)
        camPos = e.world3 + fwd * 4.6 + right * 1.4 + SIMD3(0, 1.9, 0)
        camLook = e.chest + SIMD3(0, 0.2, 0)
        shot = (pos: camPos, look: camLook, until: 1.0, snap: true)
        applyCamera(dt: 0)
    }

    override func didAppear() {
        intro()
        switch Demo.mode {
        case "battle":
            player.auto = true
        case "ultimate":
            player.auto = true
            timeline.after(4.0) { [weak self] in self?.player.soul = 100 }
        case "special":
            player.auto = true
            timeline.after(2.5) { [weak self] in
                guard let self else { return }
                self.player.energy = 100
                self.player.hand[0] = self.player.current.def.specialCard
            }
        default: break
        }
    }

    func place(_ c: Combatant, at p: SIMD2<Float>) {
        c.pos = p
        c.tween = nil
        c.knockVel = .zero
        c.model.root.simdPosition = c.world3
        arena.world.addChildNode(c.model.root)
        c.model.setAura(1)
    }

    func opponent(of s: Side) -> Side { s === player ? enemy : player }

    private func intro() {
        Sound.play(.charge)
        hud.banner(L("battle.ready"), color: .white, big: true, duration: 0.9)
        hud.rangeStart(startZone)
        timeline.after(1.0) { [weak self] in
            guard let self else { return }
            self.hud.banner(L("battle.fight"), color: Theme.accent, big: true, duration: 0.7)
            Sound.play(.heavy)
            Haptics.hit(true)
            self.started = true
            self.shot = nil
        }
    }

    // MARK: - Loop

    override func update(dt rawDT: Double) {
        if paused { return }
        var dt = rawDT * timeScale
        if hitStop > 0 {
            hitStop -= rawDT
            dt = 0
            if hitStop <= 0 { endHitStop() }
        }
        timeline.tick(dt)
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
            if !battleOver {
                if !Cheats.freezeAI { aiUpdate(enemy) }
                if player.auto { aiUpdate(player) }
            }
            checkChargeTouch()
        }
        for s in [player!, enemy!] { moveCombatant(s.current, dt) }
        separate()
        // Fighting-game hit shake: the defender vibrates in place while frozen.
        if hitStop > 0, let v = hitVictim {
            let a = hitShakeAmp * Float(min(1, hitStop * 12))
            v.model.root.simdPosition += SIMD3(Float.random(in: -a...a), 0, Float.random(in: -a...a))
        }
        updateFacing()
        applyCamera(dt: Float(rawDT))
        hud.update(dt: rawDT)
        #if DEBUG
        flushGestureLog()
        #endif
    }

    func canAct(_ s: Side) -> Bool {
        let c = s.current
        return started && !battleOver && !cinematic && !c.isKO && !c.busy && now >= c.stunUntil
            && !opponent(of: s).current.isKO
    }

    /// Can play a card now, either freely or by chaining off the previous card.
    func canChain(_ s: Side) -> Bool {
        let c = s.current
        return started && !battleOver && !cinematic && !c.isKO && now >= c.stunUntil
            && !opponent(of: s).current.isKO && c.busy && now < s.chainOpenUntil
    }

    private func tickSide(_ s: Side, _ dt: Double) {
        let c = s.current
        let free = canAct(s)
        let charging = s.charging && free
        if !battleOver && !cinematic {
            s.energy = min(Tune.energyMax, s.energy + (charging ? Tune.chargeRate : Tune.energyRegen) * dt)
            s.dodge = min(Tune.dodgeMax, s.dodge + Tune.dodgeRegen * dt)
            if s.isPlayer {
                if Cheats.infiniteEnergy { s.energy = Tune.energyMax }
                if Cheats.infiniteDodge { s.dodge = Tune.dodgeMax }
            }
        }
        if !c.isKO {
            if charging != c.wasCharging {
                c.wasCharging = charging
                if charging {
                    c.model.apply(FighterModel.chargePose, duration: 0.2)
                } else if !c.busy {
                    c.model.stance()
                }
            }
            c.model.setAura(charging ? 2 : (now < c.auraBurstUntil ? 3 : 1))
        }
        let barrier = now < c.barrierUntil
        c.model.setBarrier(barrier && !c.isKO)
        c.model.setPowered(now < c.powerUntil && !c.isKO)
        if now - s.lastHitTime > 1.4 { s.comboCount = 0 }
        if s.relay != nil && validRelay(s) == nil { s.relay = nil }
        if now > s.chainOpenUntil + 0.6 && !c.busy { s.chain = 0 }
    }

    private func moveCombatant(_ c: Combatant, _ dt: Double) {
        if let tw = c.tween {
            let t = Float(min(1, (now - tw.t0) / max(0.001, tw.dur)))
            c.pos = tw.from + (tw.to - tw.from) * easeOut(t)
            if t >= 1 { c.tween = nil }
        }
        if simd_length(c.knockVel) > 0.01 {
            c.pos += c.knockVel * Float(dt)
            c.knockVel *= Float(max(0, 1 - 7 * dt))
        }
        let r = simd_length(c.pos)
        if r > Tune.arenaRadius { c.pos *= Tune.arenaRadius / r }
        c.model.root.simdPosition = c.world3
    }

    private func separate() {
        let a = player.current, b = enemy.current
        let d = b.pos - a.pos
        let len = simd_length(d)
        if len < 0.95 && len > 0.001 && a.tween == nil && b.tween == nil {
            let push = (0.95 - len) / 2 * simd_normalize(d)
            a.pos -= push
            b.pos += push
        }
    }

    func updateFacing() {
        for s in [player!, enemy!] {
            let c = s.current
            if c.isKO { continue }
            let t = opponent(of: s).current
            let d = t.pos - c.pos
            if simd_length(d) > 0.05 {
                let yaw = atan2(d.x, d.y)
                c.model.root.simdEulerAngles = SIMD3(0, yaw, 0)
            }
        }
    }

    func dirTo(_ from: Combatant, _ to: Combatant) -> SIMD2<Float> {
        let d = to.pos - from.pos
        return simd_length(d) > 0.001 ? simd_normalize(d) : SIMD2(0, 1)
    }

    func dist(_ a: Combatant, _ b: Combatant) -> Float { simd_length(b.pos - a.pos) }

    func moveTo(_ c: Combatant, _ p: SIMD2<Float>, _ dur: Double) {
        c.knockVel = .zero
        c.tween = (from: c.pos, to: p, t0: now, dur: dur)
    }

    // MARK: - Camera

    func applyCamera(dt: Float) {
        guard let cam = pointOfView else { return }
        var targetPos: SIMD3<Float>
        var targetLook: SIMD3<Float>
        var k: Float = 1 - exp(-dt * 6)
        if let o = victoryOrbit, let w = winnerModel {
            victoryOrbit = o + dt * 0.35
            let base = w.root.simdWorldPosition
            targetPos = base + SIMD3(sin(o) * 4.2, 1.7, cos(o) * 4.2)
            targetLook = base + SIMD3(0, 1.4, 0)
        } else if let s = shot, now < s.until || !started {
            targetPos = s.pos
            targetLook = s.look
            if s.snap { k = 1 }
        } else {
            shot = nil
            if snapCamera {
                k = 1
                snapCamera = false
            }
            let p = player.current
            let e = enemy.current
            let f2 = dirTo(p, e)
            let f = SIMD3(f2.x, 0, f2.y)
            let right = SIMD3(-f2.y, 0, f2.x)
            let d = dist(p, e)
            let back: Float = 4.4 + max(0, (3 - d)) * 0.35
            targetPos = p.world3 - f * back + right * 0.75 + SIMD3(0, 2.45, 0)
            targetLook = p.world3 + f * max(3.2, d * 0.7) + SIMD3(0, 1.15, 0)
        }
        camPos += (targetPos - camPos) * k
        camLook += (targetLook - camLook) * k
        var p = camPos + camKick
        camKick *= max(0, 1 - dt * 14)
        if shake > 0.001 {
            p += SIMD3(Float.random(in: -shake...shake), Float.random(in: -shake...shake), Float.random(in: -shake...shake))
            shake *= max(0, 1 - dt * 9)
        }
        cam.simdPosition = p
        // Never look (almost) straight down/up: keep some horizontal offset.
        var flat = SIMD2<Float>(camLook.x - p.x, camLook.z - p.z)
        if simd_length(flat) < 0.6 {
            flat = simd_length(flat) > 1e-4 ? simd_normalize(flat) * 0.6 : SIMD2(0, 0.6)
            camLook = SIMD3(p.x + flat.x, camLook.y, p.z + flat.y)
        }
        cam.simdLook(at: camLook, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
        fovKick *= max(0, 1 - dt * 8)
        cam.camera?.fieldOfView = CGFloat(54 + fovKick)
    }

    var winnerModel: FighterModel?

    func cut(to pos: SIMD3<Float>, look: SIMD3<Float>, for duration: Double, snap: Bool = true) {
        shot = (pos: pos, look: look, until: now + duration, snap: snap)
    }

    /// Camera in front of a fighter (for special / ultimate cut scenes).
    func frontShot(_ c: Combatant, distance: Float = 2.4, height: Float = 1.6, side: Float = 0.9) -> (SIMD3<Float>, SIMD3<Float>) {
        let t = opponent(of: c === player.current ? player! : enemy!).current
        let f2 = dirTo(c, t)
        let f = SIMD3(f2.x, 0, f2.y)
        let right = SIMD3(-f2.y, 0, f2.x)
        // Frame head to waist (the face, not the chest), far enough for tall imported models.
        let d = max(distance, 3.2)
        let pos = c.world3 + f * d + right * side + SIMD3(0, height + 0.25, 0)
        return (pos, c.chest + SIMD3(0, 0.45, 0))
    }

    func sideShot(_ a: Combatant, _ b: Combatant, distance: Float = 7) -> (SIMD3<Float>, SIMD3<Float>) {
        let mid = (a.world3 + b.world3) / 2
        let f2 = dirTo(a, b)
        let right = SIMD3(-f2.y, 0, f2.x)
        return (mid + right * distance + SIMD3(0, 2.2, 0), mid + SIMD3(0, 1.2, 0))
    }

    // MARK: - Input

    private func touchID(_ t: UITouch) -> Int { ObjectIdentifier(t).hashValue }

    private var acceptsGestures: Bool { started && !paused && !player.auto && !battleOver }

    override func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        guard acceptsGestures else { return }
        for t in touches {
            liveTouches[touchID(t)] = t
            gesture.began(id: touchID(t), at: t.location(in: view), time: now)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches {
            if let a = gesture.moved(id: touchID(t), to: t.location(in: view)) {
                perform(a, crossedAt: t.timestamp)
            }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches {
            let id = touchID(t)
            liveTouches.removeValue(forKey: id)
            if let a = gesture.ended(id: id, at: t.location(in: view)) {
                perform(a, crossedAt: t.timestamp)
            }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches {
            let id = touchID(t)
            liveTouches.removeValue(forKey: id)
            if let a = gesture.cancelled(id: id) { perform(a, crossedAt: t.timestamp) }
        }
    }

    private func checkChargeTouch() {
        guard acceptsGestures, let view = host?.view else { return }
        if let a = gesture.tick(time: now, location: { [weak self] id in self?.liveTouches[id]?.location(in: view) }) {
            perform(a, crossedAt: CACurrentMediaTime())
        }
    }

    /// Clears all touch state (pause, AUTO toggle, system cancel, leaving the screen).
    func resetTouches() {
        gesture.reset()
        liveTouches.removeAll()
        if player != nil { player.charging = false }
    }

    private func perform(_ a: ArenaGesture.Action, crossedAt stamp: TimeInterval) {
        guard acceptsGestures || a == .chargeEnd else { return }
        var accepted = false
        switch a {
        case .evade(let lateral): accepted = dodge(player, lateral: lateral)
        case .dash: accepted = dashIn(player)
        case .stepBack: accepted = stepBack(player)
        case .basic: accepted = doBasic(player)
        case .chargeStart:
            player.charging = true
            Sound.play(.charge)
            accepted = true
        case .chargeEnd:
            player.charging = false
            accepted = true
        }
        #if DEBUG
        let acceptT = CACurrentMediaTime()
        pendingGestureLog = (a, stamp, acceptT, accepted)
        #endif
    }

    #if DEBUG
    /// Logged on the next frame: threshold crossing → accepted → first visible frame.
    func flushGestureLog() {
        guard let g = pendingGestureLog else { return }
        pendingGestureLog = nil
        let frameT = CACurrentMediaTime()
        print(String(format: "[gesture] %@ accepted=%@ cross→accept %.1fms, accept→frame %.1fms",
                     String(describing: g.action), g.accepted ? "Y" : "N",
                     (g.accept - g.cross) * 1000, (frameT - g.accept) * 1000))
    }
    #endif

    // MARK: - Pause

    func setPaused(_ p: Bool) {
        guard !battleOver, p != paused else { return }
        paused = p
        scene.isPaused = p
        resetTouches()
        if !p {
            hud.closePause()
            return
        }
        hud.openPause()
    }

    override func willDisappear() {
        resetTouches()
    }

    func retreat() {
        go(HomeScreen())
    }
}

extension BattleScreen {
    /// Freeze-frame hit stop: logic time stops and both fighters' animations pause, the defender shakes.
    func beginHitStop(_ duration: Double, attacker: Combatant?, victim: Combatant, shake amp: Float) {
        guard duration > 0 else { return }
        if hitStop <= 0 { frozenRoots.forEach { $0.isPaused = false }; frozenRoots = [] }
        hitStop = max(hitStop, duration)
        for n in [attacker?.model.root, victim.model.root].compactMap({ $0 }) where !frozenRoots.contains(n) {
            n.isPaused = true
            frozenRoots.append(n)
        }
        hitVictim = victim
        hitShakeAmp = amp
    }

    func endHitStop() {
        frozenRoots.forEach { $0.isPaused = false }
        frozenRoots = []
        hitVictim = nil
        hitStop = 0
    }

    /// Push the camera along the hit direction (world space); it springs back in a few frames.
    func kickCamera(from a: SIMD3<Float>, to b: SIMD3<Float>, strength: Float) {
        var d = b - a
        d.y = 0
        guard simd_length(d) > 1e-3 else { return }
        camKick += simd_normalize(d) * strength + SIMD3(0, -strength * 0.3, 0)
    }
}
