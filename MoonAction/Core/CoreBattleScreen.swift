import UIKit
import SceneKit
import SwiftUI
import simd
import BattleCore

/// Battle driven by the pure BattleCore engine. This screen only renders (SceneKit 3D models,
/// keyframe moves, effects, camera), plays sound / haptics, maps gestures to engine inputs and
/// shows the SwiftUI HUD. All rules live in BattleCore.
final class CoreBattleScreen: Screen {
    private var engine: BattleEngine
    private var ai: AIController
    private var autoAI: AIController
    private let difficulty: Difficulty
    private let hud = CoreHUDModel()
    private var hosts: [UIViewController] = []
    private var pauseHost: UIViewController?

    private var arena: Arena!
    private let fx = SCNNode()
    private var models: [[FighterModel]] = [[], []]
    private var visuals: [[FighterDef]] = [[], []]
    private var shown = [0, 0]
    private var lateral: [Float] = [0, 0]
    private var wasCharging = [false, false]
    private var seenAction: [Double] = [-1, -1]
    private var hitClips: [[Int: Clip]] = [[:], [:]]
    private var currentSig: [CardSig?] = [nil, nil]
    private struct Pending { let at: Double; let side: Int; let start: Double?; let fn: () -> Void }
    private var pending: [Pending] = []

    private var realTime: Double = 0
    private var hitStop: Double = 0
    private var slowUntil: Double = 0
    private var shake: Float = 0
    private var camKick = SIMD3<Float>(repeating: 0)
    private var camPos = SIMD3<Float>(0, 3, -9)
    private var camLook = SIMD3<Float>(0, 1.2, 0)
    private var comboW: Float = 0
    private var guardW: Float = 0
    private var finished = false
    private var gesture = ArenaGesture()
    private var liveTouches: [Int: UITouch] = [:]
    private var warnUntil: Double = 0
    private let warnLabel = UILabel()
    private let comboLabel = UILabel()
    private var shownCombo = 0
    private let callouts = UIStackView()
    private var resignObserver: NSObjectProtocol?

    init(player: [String] = ["sera", "kai", "lan"], enemy: [String] = ["nova", "zero", "aegis"],
         difficulty: Difficulty = .standard, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        let p = player.compactMap { FighterRoster.byID($0) }
        let e = enemy.compactMap { FighterRoster.byID($0) }
        engine = BattleEngine(player: p.isEmpty ? [FighterRoster.sera] : p, enemy: e.isEmpty ? [FighterRoster.nova] : e,
                              startZone: .mid, seed: seed)
        self.difficulty = difficulty
        ai = AIController(side: 1, difficulty: difficulty)
        autoAI = AIController(side: 0, difficulty: .standard)
        super.init()
    }

    // MARK: - Build

    override func build() {
        arena = Arena(theme: 0)
        scene = arena.scene
        pointOfView = arena.camera
        if let cam = arena.camera.camera {
            cam.bloomIntensity = 0.25
            cam.bloomThreshold = 1.2
            cam.bloomBlurRadius = 5
        }
        arena.world.addChildNode(fx)
        for s in 0..<2 {
            for f in engine.sides[s].team {
                let v = CoreVisuals.visual(f.def)
                visuals[s].append(v)
                models[s].append(FighterModel(def: v))
            }
            arena.world.addChildNode(models[s][0].root)
        }
        placeModels(dt: 1)
        snapCamera()

        hud.onPlay = { [weak self] slot in self?.input(.play(slot)) }
        hud.onPause = { [weak self] in self?.setPaused(true) }
        hud.onResume = { [weak self] in self?.setPaused(false) }
        hud.onQuit = { [weak self] in self?.go(HomeScreen()) }
        hud.onAuto = { [weak self] in
            guard let self else { return }
            self.hud.auto.toggle()
            self.gesture.reset()
        }
        if Demo.mode == "core" { hud.auto = true }
        hud.sync(engine)
        addHUD(CoreTopHUD(m: hud), top: true)
        addHUD(CoreBottomHUD(m: hud), top: false)

        comboLabel.textAlignment = .right
        comboLabel.alpha = 0
        comboLabel.isUserInteractionEnabled = false
        comboLabel.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(comboLabel)
        callouts.axis = .vertical
        callouts.spacing = 4
        callouts.alignment = .leading
        callouts.isUserInteractionEnabled = false
        callouts.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(callouts)
        NSLayoutConstraint.activate([
            comboLabel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            comboLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -70),
            callouts.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            callouts.topAnchor.constraint(equalTo: safe.topAnchor, constant: 132),
        ])

        warnLabel.text = "!"
        warnLabel.font = .systemFont(ofSize: 40, weight: .black)
        warnLabel.textColor = UIColor(hex: 0xFF5A4A)
        warnLabel.layer.shadowColor = UIColor.black.cgColor
        warnLabel.layer.shadowOpacity = 0.8
        warnLabel.layer.shadowRadius = 3
        warnLabel.sizeToFit()
        warnLabel.isHidden = true
        warnLabel.isUserInteractionEnabled = false
        ui.addSubview(warnLabel)

        resignObserver = NotificationCenter.default.addObserver(forName: UIApplication.willResignActiveNotification,
                                                                object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.setPaused(true) }
        }
        banner(L10n.isZH ? "中距离开局" : "MID RANGE", size: 16)
    }

    private func addHUD<V: View>(_ view: V, top: Bool) {
        let hc = UIHostingController(rootView: view)
        hc.view.backgroundColor = .clear
        hc.sizingOptions = .intrinsicContentSize
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        host?.addChild(hc)
        ui.addSubview(hc.view)
        hc.didMove(toParent: host)
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            top ? hc.view.topAnchor.constraint(equalTo: safe.topAnchor, constant: 4)
                : hc.view.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -4),
        ])
        hosts.append(hc)
    }

    override func willDisappear() {
        for h in hosts + [pauseHost].compactMap({ $0 }) {
            h.willMove(toParent: nil)
            h.view.removeFromSuperview()
            h.removeFromParent()
        }
        hosts = []
        if let o = resignObserver { NotificationCenter.default.removeObserver(o) }
    }

    private func setPaused(_ p: Bool) {
        guard hud.paused != p, !finished else { return }
        hud.paused = p
        gesture.reset()
        if p {
            let hc = UIHostingController(rootView: CorePauseOverlay(m: hud))
            hc.view.backgroundColor = .clear
            hc.view.frame = ui.bounds
            hc.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            host?.addChild(hc)
            ui.addSubview(hc.view)
            hc.didMove(toParent: host)
            pauseHost = hc
        } else if let hc = pauseHost {
            hc.willMove(toParent: nil)
            hc.view.removeFromSuperview()
            hc.removeFromParent()
            pauseHost = nil
        }
        setRates(p ? 0 : 1)
    }

    // MARK: - Loop

    override func update(dt: Double) {
        if hud.paused { return }
        realTime += dt
        if hitStop > 0 {
            hitStop -= dt
            setRates(0)
            updateCamera(dt: Float(dt))
            return
        }
        let scale = realTime < slowUntil ? 0.35 : 1.0
        setRates(scale)
        var ev = engine.advance(dt * scale)
        ai.update(&engine, &ev)
        if hud.auto { autoAI.update(&engine, &ev) }
        if !hud.auto, let a = gesture.tick(time: realTime, location: { [weak self] id in self?.liveTouches[id]?.location(in: self?.ui) }) {
            perform(a)
        }
        handle(ev)
        scheduleNewActions()
        runPending()
        syncCharging()
        placeModels(dt: Float(dt))
        updateCamera(dt: Float(dt))
        updateWarning()
        updateCombo()
        hud.sync(engine)
    }

    /// Big right-edge combo counter (DBL style): pops on every hit, fades when the combo ends.
    private func updateCombo() {
        let mine = engine.sides[0].comboHits, theirs = engine.sides[1].comboHits
        let n = max(mine, theirs)
        guard n != shownCombo else { return }
        let grew = n > shownCombo
        shownCombo = n
        if n < 2 {
            UIView.animate(withDuration: 0.35, delay: 0.25) { self.comboLabel.alpha = 0 }
            return
        }
        let color = mine >= theirs ? Theme.accent : Theme.hpEnemy
        let t = NSMutableAttributedString(string: "\(n)", attributes: [
            .font: UIFont.italic(46, .black), .foregroundColor: color,
            .strokeColor: UIColor.black, .strokeWidth: -3,
        ])
        t.append(NSAttributedString(string: " " + (L10n.isZH ? "连击" : "Combo"), attributes: [
            .font: UIFont.italic(15, .heavy), .foregroundColor: UIColor.white,
            .strokeColor: UIColor.black, .strokeWidth: -3,
        ]))
        comboLabel.attributedText = t
        comboLabel.alpha = 1
        if grew {
            comboLabel.transform = CGAffineTransform(scaleX: 1.35, y: 1.35)
            UIView.animate(withDuration: 0.16) { self.comboLabel.transform = .identity }
        }
    }

    /// Stacked status callouts on the upper left (Ki recovery, BLOCK, cover change, …).
    private func callout(_ text: String, color: UIColor, symbol: String? = nil) {
        let l = UILabel()
        let t = NSMutableAttributedString()
        if let symbol, let img = UIImage(systemName: symbol)?.withTintColor(color, renderingMode: .alwaysOriginal) {
            let a = NSTextAttachment(image: img)
            a.bounds = CGRect(x: 0, y: -2, width: 13, height: 13)
            t.append(NSAttributedString(attachment: a))
            t.append(NSAttributedString(string: " "))
        }
        t.append(NSAttributedString(string: text, attributes: [.font: UIFont.systemFont(ofSize: 12, weight: .bold), .foregroundColor: UIColor.white]))
        l.attributedText = t
        let box = UIView()
        box.backgroundColor = UIColor.black.withAlphaComponent(0.45)
        box.layer.cornerRadius = 4
        box.layer.borderColor = color.withAlphaComponent(0.8).cgColor
        box.layer.borderWidth = 1
        l.translatesAutoresizingMaskIntoConstraints = false
        box.addSubview(l)
        NSLayoutConstraint.activate([
            l.leadingAnchor.constraint(equalTo: box.leadingAnchor, constant: 8),
            l.trailingAnchor.constraint(equalTo: box.trailingAnchor, constant: -8),
            l.topAnchor.constraint(equalTo: box.topAnchor, constant: 3),
            l.bottomAnchor.constraint(equalTo: box.bottomAnchor, constant: -3),
        ])
        if callouts.arrangedSubviews.count >= 4 { callouts.arrangedSubviews.first?.removeFromSuperview() }
        callouts.addArrangedSubview(box)
        box.alpha = 0
        box.transform = CGAffineTransform(translationX: -20, y: 0)
        UIView.animate(withDuration: 0.15) {
            box.alpha = 1
            box.transform = .identity
        }
        UIView.animate(withDuration: 0.3, delay: 1.6, options: [], animations: { box.alpha = 0 }) { _ in box.removeFromSuperview() }
    }

    /// Tests / demos: let the AI play the player's side.
    func setAuto(_ on: Bool) { hud.auto = on }
    var isFinished: Bool { finished }
    var engineState: BattleEngine { engine }

    private func setRates(_ r: Double) {
        for side in models { for m in side { m.animRate = r } }
    }

    private func input(_ i: BattleCore.Input) {
        guard !hud.paused, !finished else { return }
        var ev: [BattleEvent] = []
        if engine.apply(i, side: 0, events: &ev) {
            if case .play = i { Haptics.light.impactOccurred() }
        }
        handle(ev)
        scheduleNewActions()
        hud.sync(engine)
    }

    // MARK: - Scheduling animations from engine actions

    private func model(_ s: Int) -> FighterModel { models[s][shown[s]] }
    private func visual(_ s: Int) -> FighterDef { visuals[s][engine.sides[s].active] }

    private func scheduleNewActions() {
        for s in 0..<2 {
            guard let act = engine.sides[s].current.action, act.start != seenAction[s] else { continue }
            seenAction[s] = act.start
            let m = model(s)
            let def = visual(s)
            let sig = act.card.map { Signatures.of(cardID: $0.id, def) } ?? Signatures.basic(def)
            currentSig[s] = sig
            hitClips[s] = [:]
            switch act.kind {
            case .special, .ultimate:
                m.play(Moves.beamCharge)
                m.setAura(3)
                let orb = VFX.chargeIn(color: def.aura, radius: 1.3)
                m.fistR.addChildNode(orb)
                let first = act.times.first ?? engine.time
                let duration = (act.times.last ?? first) - first + 0.3
                pending.append(Pending(at: first - 0.06, side: s, start: act.start) { [weak self] in
                    orb.removeFromParentNode()
                    self?.fireBeam(s, duration: duration)
                })
                pending.append(Pending(at: first + duration + 0.2, side: s, start: nil) { orb.removeFromParentNode() })
            default:
                if act.isProjectile {
                    for t in act.times {
                        pending.append(Pending(at: t - 0.11, side: s, start: act.start) { _ = m.shoot(sig.shot) })
                    }
                } else {
                    let n = act.times.count
                    for (i, t) in act.times.enumerated() {
                        let clip = (i == n - 1 && n > 2 && act.kind == .strike) ? sig.finisher : sig.strikes[i % sig.strikes.count]
                        hitClips[s][i] = clip
                        let last = i == n - 1
                        pending.append(Pending(at: t - clip.impact, side: s, start: act.start) {
                            m.play(clip)
                            Sound.play(.whoosh, pitch: sig.pitch * (last ? 0.85 : 1.1))
                        })
                    }
                }
            }
        }
    }

    private func runPending() {
        guard !pending.isEmpty else { return }
        let now = engine.time
        var keep: [Pending] = []
        for p in pending {
            if p.at > now { keep.append(p); continue }
            if let start = p.start, engine.sides[p.side].current.action?.start != start { continue }   // interrupted
            p.fn()
        }
        pending = keep
    }

    private func fireBeam(_ s: Int, duration: Double) {
        let m = model(s)
        let t = model(1 - s)
        m.play(Moves.beamFire)
        let start = m.handWorld
        let target = t.chestWorld
        let dir = simd_normalize(target - start)
        let len = simd_length(target - start) + 2
        let beam = VFX.beam(color: visual(s).aura, radius: 0.32, length: len)
        beam.simdPosition = start
        beam.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
        beam.simdScale = SIMD3(1, 0.01, 1)
        fx.addChildNode(beam)
        SCNTransaction.begin()
        SCNTransaction.animationDuration = 0.12
        beam.simdScale = SIMD3(1, 1, 1)
        SCNTransaction.commit()
        beam.runAction(.sequence([.wait(duration: duration), .fadeOut(duration: 0.2), .removeFromParentNode()]))
        Sound.play(.beam)
        shake = max(shake, 0.06)
    }

    // MARK: - Engine events → presentation

    private func handle(_ events: [BattleEvent]) {
        for e in events { handle(e) }
    }

    private func handle(_ e: BattleEvent) {
        switch e {
        case .cardPlayed(let s, let card, _):
            if s == 0 { Sound.play(.card) } else {
                callout((L10n.isZH ? "对手 · " : "Foe · ") + CoreVisuals.cardName(card), color: CoreVisuals.kindColor(card.kind),
                        symbol: CoreVisuals.kindSymbol(card.kind))
            }
        case .dash(let s, _):
            let m = model(s)
            m.dash()
            m.afterimage(in: fx)
            VFX.dust(at: m.root.simdWorldPosition + SIMD3(0, 0.1, 0), scale: 0.7, in: fx)
            Sound.play(.dodge)
        case .shotFired(let s, let travel, let big):
            shot(from: s, travel: travel, big: big)
        case .hit(let h):
            hit(h)
        case .warning(let s, let lead):
            if s == 0 {
                warnUntil = engine.time + lead + 0.1
                Sound.play(.ui, pitch: 1.8)
                Haptics.light.impactOccurred()
            }
        case .vanished(let s):
            let m = model(s)
            m.afterimage(in: fx)
            // Cyan vanish vortex around the fighter.
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.7, pipeRadius: 0.035))
            ring.geometry?.materials = [Toon.energy(UIColor(hex: 0x7FE8FF), alpha: 0.85)]
            ring.simdPosition = m.root.simdWorldPosition + SIMD3(0, 1.1, 0)
            ring.simdEulerAngles = SIMD3(0.35, 0, 0)
            fx.addChildNode(ring)
            ring.runAction(.sequence([.group([.scale(to: 2.0, duration: 0.28), .rotateBy(x: 0, y: 3, z: 0, duration: 0.28),
                                              .fadeOut(duration: 0.28)]), .removeFromParentNode()]))
            lateral[s] = (lateral[s] >= 0 ? -1 : 1) * 1.5
            m.setVisible(false)
            realDelay(0.16) { m.setVisible(true) }
            popup(L10n.isZH ? "瞬身！" : "VANISH!", over: s, color: Theme.energy, size: 20)
            Sound.play(.dodge)
            if s == 0 { Haptics.heavy.impactOccurred(intensity: 0.6) }
        case .whiff(let s):
            model(s).play(Moves.stepBack)
            popup(L10n.isZH ? "落空" : "MISS", over: s, color: Theme.text2, size: 15)
        case .sidestep(let s, let dir):
            lateral[s] += Float(dir) * 0.9
            model(s).sidestep(Float(dir))
            Sound.play(.dodge, pitch: 1.3)
        case .support(let s, let effect):
            let m = model(s)
            m.apply(FighterModel.chargePose, duration: 0.12)
            realDelay(0.4) { m.stance() }
            m.setAura(3)
            realDelay(0.9) { m.setAura(0) }
            callout((s == 0 ? "" : (L10n.isZH ? "对手 · " : "Foe · ")) + supportText(effect), color: Theme.effect, symbol: "arrow.up.circle.fill")
            Sound.play(.charge)
        case .armorBreak(let s):
            callout(L10n.isZH ? "霸体 · 无视气弹" : "SUPER ARMOR", color: Theme.accent, symbol: "shield.fill")
            Sound.play(.crack, pitch: 0.7)
        case .countered(let s):
            popup(L10n.isZH ? "防反！" : "COUNTER!", over: s, color: Theme.special, size: 22)
            callout(L10n.isZH ? "防反成功 · 对手冻结" : "COUNTER · FROZEN", color: Theme.special, symbol: "snowflake")
            model(1 - s).react(.head, heavy: false)
            Sound.play(.heavy, pitch: 1.2)
            hitStop = 0.12
        case .shieldBlocked(let s):
            callout(s == 0 ? "BLOCK" : (L10n.isZH ? "对手护盾 BLOCK" : "Foe BLOCK"), color: UIColor(hex: 0x6FC3FF), symbol: "shield.lefthalf.filled")
        case .cinematic(let s, let card):
            banner(CoreVisuals.cardName(card), size: 22, color: CoreVisuals.kindColor(card.kind))
            Sound.play(.charge)
            if s == 0 { Haptics.rigid.impactOccurred() }
        case .ko(let s, _):
            model(s).ko()
            Sound.play(.ko)
            hitStop = 0.2
            slowUntil = realTime + 0.9
            banner(L10n.isZH ? "击倒！" : "K.O.", size: 34, color: Theme.hpEnemy)
        case .tenacity(let s):
            popup(L10n.isZH ? "坚韧！" : "TENACITY!", over: s, color: Theme.accent, size: 20)
        case .switched(let s, let to):
            realDelay(1.0) { [weak self] in self?.showMember(s, to) }
        case .battleOver(let w):
            finish(winner: w)
        case .comboEnded(let s, let hits):
            if s == 0 && hits >= 4 { popup(L10n.f("core.comboTotal", hits), over: 1, color: Theme.accent, size: 18, rise: 1.6) }
        case .zoneChanged, .handChanged, .swing:
            break
        }
    }

    private static let grouped: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        return f
    }()

    private func supportText(_ e: SupportEffect) -> String {
        switch e {
        case .kiCharge: return L10n.isZH ? "火焰充能" : "KI CHARGE"
        case .shield: return L10n.isZH ? "护盾" : "SHIELD"
        case .vanishRefill: return L10n.isZH ? "闪避回复" : "VANISH UP"
        case .teamHeal: return L10n.isZH ? "全队回复" : "TEAM HEAL"
        case .freezeCounter: return L10n.isZH ? "防反架势" : "COUNTER STANCE"
        case .kiBurst: return L10n.isZH ? "气功爆发" : "KI BURST"
        }
    }

    private func hit(_ h: HitInfo) {
        let a = h.attacker, d = 1 - a
        let dm = model(d)
        let react: HitReact
        switch h.kind {
        case .strike, .basic: react = hitClips[a][h.hitIndex].map { HitReact.of($0) } ?? .head
        case .blast: react = .blast
        case .special, .ultimate: react = .launch
        }
        dm.react(react, heavy: h.heavy)
        let p = dm.chestWorld + SIMD3(0, 0.1, 0)
        let am = model(a)
        var dir = p - am.chestWorld
        dir.y = 0
        dir = simd_length(dir) > 1e-3 ? simd_normalize(dir) + SIMD3(0, 0.15, 0) : SIMD3(0, 0.15, 1)
        VFX.impact(at: p, color: visual(a).aura, heavy: h.heavy || h.crit, in: fx, dir: dir, scale: camScale(p))
        let sig = currentSig[a]
        switch h.kind {
        case .strike, .basic: Sound.play(h.heavy ? (sig?.heavyImpact ?? .heavy) : (sig?.impact ?? .hit), pitch: sig?.pitch ?? 1)
        default: Sound.play(h.heavy ? .heavy : .hit)
        }
        // Damage number: ADV (orange-gold, large) / RES (grey-blue, small) / CRIT!
        var text = Self.grouped.string(from: NSNumber(value: Int(h.damage))) ?? "\(Int(h.damage))"
        var color = UIColor.white
        var size: CGFloat = h.heavy ? 20 : 16
        switch h.matchup {
        case .advantage:
            color = UIColor(hex: 0xFFB347)
            size += 4
            if h.heavy { text += " ADV" }
        case .disadvantage:
            color = UIColor(hex: 0x9FB4D0)
            size -= 2
            if h.heavy { text += " RES" }
        case .neutral: break
        }
        if h.crit {
            text += " CRIT!"
            color = Theme.accent
        }
        popup(text, at: p + SIMD3(Float.random(in: -0.3...0.3), 0.5, 0), color: color, size: size)
        hitStop = max(hitStop, min(0.14, (h.heavy ? 0.1 : (h.kind == .basic ? 0.04 : 0.06)) + (h.crit ? 0.03 : 0)))
        shake = max(shake, h.heavy ? 0.09 : 0.025)
        camKick += SIMD3(dir.x, -0.1, dir.z) * (h.heavy ? 0.3 : 0.1)
        if a == 0 || d == 0 {
            if h.heavy { Haptics.heavy.impactOccurred() } else { Haptics.light.impactOccurred() }
        }
    }

    private func shot(from s: Int, travel: Double, big: Bool) {
        let m = model(s)
        let t = model(1 - s)
        let start = m.handWorld
        let n = VFX.projectile(color: visual(s).aura, radius: big ? 0.32 : 0.2)
        n.simdPosition = start
        n.scale = SCNVector3(0.3, 0.3, 0.3)
        fx.addChildNode(n)
        VFX.muzzle(at: start, color: visual(s).aura, size: 0.8 * camScale(start), in: fx)
        let end = t.chestWorld + SIMD3(0, 0.1, 0)
        n.runAction(.group([.scale(to: 1, duration: 0.12), .move(to: SCNVector3(end.x, end.y, end.z), duration: max(0.05, travel))]))
        n.runAction(.sequence([.wait(duration: max(0.05, travel) + 0.02), .removeFromParentNode()]))
        if let sig = currentSig[s] { Sound.play(sig.fire, pitch: sig.pitch) } else { Sound.play(.blast) }
    }

    private func showMember(_ s: Int, _ i: Int) {
        guard i != shown[s], i < models[s].count else { return }
        let old = models[s][shown[s]]
        old.root.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode(), .run { $0.opacity = 1 }]))
        shown[s] = i
        let n = models[s][i]
        n.revive()
        arena.world.addChildNode(n.root)
        n.play(Moves.tagDrop)
        seenAction[s] = -1
        placeModels(dt: 1)
        realDelay(0.2) { [weak self] in
            guard let self else { return }
            VFX.dust(at: n.root.simdWorldPosition + SIMD3(0, 0.1, 0), scale: 0.8, in: self.fx)
            Sound.play(.thud, pitch: 1.1)
        }
        banner(CoreVisuals.name(engine.sides[s].current.def), size: 18)
    }

    private func finish(winner: Int?) {
        guard !finished else { return }
        finished = true
        let won = winner == 0
        banner(won ? (L10n.isZH ? "胜利" : "VICTORY") : (winner == nil ? (L10n.isZH ? "平局" : "DRAW") : (L10n.isZH ? "战败" : "DEFEAT")),
               size: 40, color: won ? Theme.accent : Theme.hpEnemy)
        if won { model(0).victory() }
        let ids = visuals[0].map(\.id)
        realDelay(2.6) { [weak self] in self?.go(ResultScreen(won: won, teamIDs: ids, stage: Save.shared.data.stage)) }
    }

    // MARK: - Placement / charging / camera

    private func syncCharging() {
        for s in 0..<2 {
            let charging = engine.sides[s].current.phase == .charging
            guard charging != wasCharging[s] else { continue }
            wasCharging[s] = charging
            let m = model(s)
            if charging {
                m.charge()
                m.setAura(2)
            } else {
                m.stance()
                m.setAura(0)
            }
        }
    }

    private func worldPos(_ s: Int) -> SIMD3<Float> {
        let half = Float(engine.gap) / 2
        return SIMD3(lateral[s], 0, s == 0 ? -half : half)
    }

    private func placeModels(dt: Float) {
        for s in 0..<2 {
            lateral[s] *= max(0, 1 - dt * 3)
            let m = model(s)
            let p = worldPos(s)
            let o = worldPos(1 - s)
            m.root.simdPosition = p
            m.root.simdEulerAngles = SIMD3(0, atan2(o.x - p.x, o.z - p.z), 0)
        }
    }

    private func camScale(_ p: SIMD3<Float>) -> CGFloat {
        CGFloat(max(0.35, min(1, simd_length(p - camPos) / 9)))
    }

    private func cameraTarget() -> (SIMD3<Float>, SIMD3<Float>) {
        let p = worldPos(0), e = worldPos(1)
        var f = e - p
        f.y = 0
        f = simd_length(f) > 1e-3 ? simd_normalize(f) : SIMD3(0, 0, 1)
        let right = SIMD3<Float>(f.z, 0, -f.x) * -1
        let gap = Float(engine.gap)
        // Special / ultimate startup: front close-up of the attacker.
        for s in 0..<2 where engine.inCinematic {
            if let k = engine.sides[s].current.action?.kind, k == .special || k == .ultimate {
                let a = worldPos(s)
                let fw = s == 0 ? f : -f
                return (a + fw * 3.4 + right * (s == 0 ? 1 : -1) * 0.9 + SIMD3(0, 1.85, 0), model(s).chestWorld + SIMD3(0, 0.45, 0))
            }
        }
        // DBL framing in neutral: behind the player, a little to the left, chest height — the player stands
        // large right of center with the opponent ahead. Combos switch to the 3/4 side view below.
        let mid = (p + e) / 2
        var pos = p - f * (2.7 + gap * 0.08) - right * 1.15 + SIMD3(0, 1.8, 0)
        var look = p + f * max(2.8, gap * 0.75) - right * 0.35 + SIMD3(0, 1.2, 0)
        // Comboing: swing further to the side and close in on the exchange.
        pos = simd_mix(pos, mid - f * 1.0 + right * (3.0 + gap * 0.1) + SIMD3(0, 1.35, 0), SIMD3(repeating: comboW))
        look = simd_mix(look, mid + f * 0.3 + SIMD3(0, 1.2, 0), SIMD3(repeating: comboW))
        // Being comboed: pull back a little to show both.
        let g = guardW * (1 - comboW)
        pos = simd_mix(pos, p - f * 4.2 + right * 2.6 + SIMD3(0, 2.2, 0), SIMD3(repeating: g))
        look = simd_mix(look, mid + SIMD3(0, 1.1, 0), SIMD3(repeating: g))
        return (pos, look)
    }

    private func snapCamera() {
        (camPos, camLook) = cameraTarget()
        arena.camera.simdPosition = camPos
        arena.camera.simdLook(at: camLook, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
    }

    private func updateCamera(dt: Float) {
        let comboing = engine.sides[0].comboHits >= 2
        let comboed = engine.sides[1].comboHits >= 2
        comboW += ((comboing ? 1 : 0) - comboW) * min(1, dt * 5)
        guardW += ((comboed ? 1 : 0) - guardW) * min(1, dt * 5)
        let (tp, tl) = cameraTarget()
        let k = engine.inCinematic ? 1 - exp(-dt * 10) : 1 - exp(-dt * 6)
        camPos += (tp - camPos) * k
        camLook += (tl - camLook) * k
        var p = camPos + camKick
        camKick *= max(0, 1 - dt * 14)
        if shake > 0.001 {
            p += SIMD3(Float.random(in: -shake...shake), Float.random(in: -shake...shake), Float.random(in: -shake...shake))
            shake *= max(0, 1 - dt * 9)
        }
        arena.camera.simdPosition = p
        arena.camera.simdLook(at: camLook, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
    }

    private func updateWarning() {
        guard engine.time < warnUntil, let v = host?.scnView else {
            warnLabel.isHidden = true
            return
        }
        let head = model(0).root.simdWorldPosition + SIMD3(0, 2.6, 0)
        let sp = v.projectPoint(SCNVector3(head.x, head.y, head.z))
        warnLabel.isHidden = false
        warnLabel.center = CGPoint(x: CGFloat(sp.x), y: CGFloat(sp.y))
        let pulse = 1 + 0.15 * CGFloat(sin(realTime * 30))
        warnLabel.transform = CGAffineTransform(scaleX: pulse, y: pulse)
    }

    // MARK: - Text

    private func popup(_ text: String, over s: Int, color: UIColor, size: CGFloat, rise: Float = 0.9) {
        popup(text, at: model(s).chestWorld + SIMD3(0, rise, 0), color: color, size: size)
    }

    private func popup(_ text: String, at p: SIMD3<Float>, color: UIColor, size: CGFloat) {
        guard let v = host?.scnView else { return }
        let sp = v.projectPoint(SCNVector3(p.x, p.y, p.z))
        guard sp.z > 0 && sp.z < 1 else { return }
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: UIFont.italic(size * 1.25, .black), .foregroundColor: color,
            .strokeColor: UIColor.black.withAlphaComponent(0.85), .strokeWidth: -3.5,
        ])
        l.sizeToFit()
        l.center = CGPoint(x: CGFloat(sp.x), y: CGFloat(sp.y))
        l.isUserInteractionEnabled = false
        ui.insertSubview(l, at: 0)
        l.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        UIView.animate(withDuration: 0.12, animations: { l.transform = .identity }) { _ in
            UIView.animate(withDuration: 0.5, delay: 0.15, options: [.curveEaseIn], animations: {
                l.center.y -= 36
                l.alpha = 0
            }, completion: { _ in l.removeFromSuperview() })
        }
    }

    private func banner(_ text: String, size: CGFloat, color: UIColor = .white) {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: Glass.font(size, .bold), .foregroundColor: color, .kern: L10n.isZH ? 3 : 6,
        ])
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.7
        l.layer.shadowRadius = 6
        l.sizeToFit()
        l.center = CGPoint(x: ui.bounds.midX, y: ui.bounds.height * 0.36)
        l.isUserInteractionEnabled = false
        ui.insertSubview(l, at: 0)
        l.alpha = 0
        l.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        UIView.animate(withDuration: 0.18, animations: {
            l.alpha = 1
            l.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.8, options: [], animations: { l.alpha = 0 }, completion: { _ in l.removeFromSuperview() })
        }
    }

    // MARK: - Gestures (swipe ↑ forward, ↓ back, ←/→ sidestep / vanish, tap attack, hold charge)

    private func touchID(_ t: UITouch) -> Int { ObjectIdentifier(t).hashValue }
    private var acceptsGestures: Bool { !hud.paused && !hud.auto && !finished }

    override func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        guard acceptsGestures else { return }
        for t in touches {
            liveTouches[touchID(t)] = t
            gesture.began(id: touchID(t), at: t.location(in: view), time: realTime)
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        guard acceptsGestures else { return }
        for t in touches {
            if let a = gesture.moved(id: touchID(t), to: t.location(in: view)) { perform(a) }
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches {
            let id = touchID(t)
            liveTouches[id] = nil
            if acceptsGestures, let a = gesture.ended(id: id, at: t.location(in: view)) { perform(a) }
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
        for t in touches {
            let id = touchID(t)
            liveTouches[id] = nil
            if let a = gesture.cancelled(id: id) { perform(a) }
        }
    }

    private func perform(_ a: ArenaGesture.Action) {
        switch a {
        case .evade(let lateral): input(.sidestep(lateral > 0 ? 1 : -1))
        case .dash: input(.moveForward)
        case .stepBack: input(.moveBack)
        case .basic: input(.tap)
        case .chargeStart: input(.chargeBegin)
        case .chargeEnd: input(.chargeEnd)
        }
    }
}

extension UIFont {
    /// Heavy italic system font (fighting-game numbers / combo counter).
    static func italic(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        guard let d = base.fontDescriptor.withSymbolicTraits(base.fontDescriptor.symbolicTraits.union(.traitItalic)) else { return base }
        return UIFont(descriptor: d, size: size)
    }
}
