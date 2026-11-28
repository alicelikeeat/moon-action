import UIKit
import SceneKit
import simd

/// Model gallery: orbit / pinch-zoom / pan any fighter, play every move, framing presets,
/// turntable, wireframe and aura toggles.
final class ViewerScreen: Screen {
    private var arena: Arena!
    private var model: FighterModel?
    private let fx = SCNNode()
    private let timeline = Timeline()
    private var ids: [String] = Roster.playable.map { $0.id }
    private var index = 0

    // Orbit camera (current values ease towards the targets)
    private var yaw: Float = 0, pitch: Float = 0.08, dist: Float = 4.4, lookY: Float = 1.1
    private var tYaw: Float = 0, tPitch: Float = 0.08, tDist: Float = 4.4, tLookY: Float = 1.1
    private var touches: [UITouch: CGPoint] = [:]
    private var pinchStart: (span: CGFloat, dist: Float, mid: CGPoint, lookY: Float)?

    private var turntable = false
    private var looping = false
    private var loopStep = 0
    private var nextLoop = 0.0
    private var clock = 0.0
    private var wireframe = false
    private var auraOn = true

    private let nameLabel = Glass.label("", size: 17, weight: .semibold)
    private let infoLabel = Glass.caption("", size: 10)
    private var toggleButtons: [String: UIButton] = [:]

    init(focus id: String? = nil) {
        super.init()
        if let id, let i = ids.firstIndex(of: id) { index = i }
    }

    override func build() {
        arena = Arena(theme: 3)
        scene = arena.scene
        pointOfView = arena.camera
        arena.world.addChildNode(fx)
        let ped = Toon.part(SCNCylinder(radius: 1.1, height: 0.06), UIColor(hex: 0x1A1D28), outline: 0.012, rim: false)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.1, pipeRadius: 0.01))
        ring.geometry?.materials = [Toon.energy(Theme.accent)]
        ring.simdPosition = SIMD3(0, 0.03, 0)
        ped.addChildNode(ring)
        ped.simdPosition = SIMD3(0, 0.03, 0)
        arena.world.addChildNode(ped)
        buildUI()
        load()
        if Demo.mode == "viewer" {
            tYaw = 0.5
            looping = true
            refreshToggles()
        }
        applyCamera(snap: true)
    }

    override func willDisappear() {
        host?.scnView.debugOptions = []
    }

    // MARK: - Model

    private func load() {
        timeline.cancelAll()
        fx.childNodes.forEach { $0.removeFromParentNode() }
        model?.root.removeFromParentNode()
        let def = Roster.byID(ids[index])
        let m = FighterModel(def: def)
        m.root.simdPosition = SIMD3(0, 0.06, 0)
        m.setAura(auraOn ? 1 : 0)
        m.idle()
        arena.world.addChildNode(m.root)
        model = m
        nameLabel.text = def.name.s
        var info = def.title.s + "  ·  " + String(repeating: "★", count: def.rarity)
        if m.isImported {
            let tris = ViewerScreen.triangleCount(m.root)
            info += "  ·  " + L10n.f("viewer.tris", tris)
            if let b = m.importedBones { info += "  ·  " + L10n.f("viewer.bones", b) }
        } else {
            info += "  ·  " + L("viewer.procedural")
        }
        infoLabel.text = info
        frame(.full, snap: false)
    }

    static func triangleCount(_ node: SCNNode) -> Int {
        var n = 0
        node.enumerateHierarchy { c, _ in
            for e in c.geometry?.elements ?? [] where e.primitiveType == .triangles { n += e.primitiveCount }
        }
        return n
    }

    private var height: Float { 2.15 * (model?.def.look.height ?? 1) }

    private enum Framing { case full, upper, face }

    private func frame(_ f: Framing, snap: Bool = false) {
        switch f {
        case .full: tLookY = height * 0.5; tDist = 4.4
        case .upper: tLookY = height * 0.74; tDist = 2.1
        case .face: tLookY = height * 0.9; tDist = 0.95
        }
        tPitch = f == .face ? 0.02 : 0.08
        if snap { applyCamera(snap: true) }
    }

    // MARK: - Moves

    private func play(_ move: String) {
        guard let m = model else { return }
        let color = m.def.look.aura
        switch move {
        case "stance": m.stance()
        case "jab": m.attack(0)
        case "cross": m.attack(1)
        case "kick": m.attack(2)
        case "upper": m.attack(3)
        case "spin": m.attack(4)
        case "combo":
            for i in 0..<5 { timeline.after(Double(i) * 0.3) { [weak m] in m?.attack(i) } }
            timeline.after(1.6) { [weak m] in m?.finisher() }
        case "dash":
            m.dash()
            m.afterimage(in: fx)
            timeline.after(0.45) { [weak m] in m?.stance() }
        case "blast":
            m.blast()
            timeline.after(0.06) { [weak self] in self?.shoot(color) }
        case "charge":
            m.apply(FighterModel.chargePose, duration: 0.2)
            m.setAura(2)
            timeline.after(1.6) { [weak self, weak m] in
                m?.setAura(3)
                m?.stance()
                self?.timeline.after(0.5) { [weak self] in m?.setAura(self?.auraOn == true ? 1 : 0) }
            }
        case "beam": beam(color)
        case "hurt": m.hurt(heavy: false)
        case "heavy": m.hurt(heavy: true)
        case "ko":
            m.ko()
            timeline.after(2.2) { [weak self, weak m] in
                m?.revive()
                m?.setAura(self?.auraOn == true ? 1 : 0)
            }
        case "victory":
            m.victory()
            timeline.after(2.4) { [weak m] in m?.stance() }
        default: break
        }
    }

    private func forward() -> SIMD3<Float> {
        guard let m = model else { return SIMD3(0, 0, 1) }
        return simd_normalize(m.root.simdWorldFront * -1)
    }

    private func shoot(_ color: UIColor) {
        guard let m = model else { return }
        let start = m.handWorld
        let dir = forward()
        let p = VFX.projectile(color: color, radius: 0.22)
        p.simdPosition = start
        fx.addChildNode(p)
        VFX.muzzle(at: start, color: color, size: 1.1, in: fx)
        Sound.play(.blast)
        let end = start + dir * 9
        p.runAction(.sequence([.move(to: SCNVector3(end), duration: 0.45), .removeFromParentNode()]))
    }

    private func beam(_ color: UIColor) {
        guard let m = model else { return }
        m.apply(FighterModel.beamChargePose, duration: 0.15)
        let orb = VFX.chargeIn(color: color, radius: 1.2)
        m.fistR.addChildNode(orb)
        orb.childNode(withName: "orb", recursively: false)?.runAction(.scale(to: 2.2, duration: 0.9))
        timeline.after(0.9) { [weak self, weak m] in
            guard let self, let m else { return }
            orb.removeFromParentNode()
            m.apply(FighterModel.beamFirePose, duration: 0.08)
            let start = m.handWorld
            let dir = self.forward()
            let holder = VFX.beam(color: color, radius: 0.32, length: 12)
            holder.simdPosition = start
            holder.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: dir)
            holder.simdScale = SIMD3(1, 0.01, 1)
            self.fx.addChildNode(holder)
            SCNTransaction.begin()
            SCNTransaction.animationDuration = 0.16
            holder.simdScale = SIMD3(1, 1, 1)
            SCNTransaction.commit()
            Sound.play(.beam)
            self.timeline.after(1.1) { [weak m] in
                holder.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
                m?.stance()
            }
        }
    }

    private static let loopMoves = ["jab", "cross", "kick", "upper", "spin", "blast", "dash", "charge", "beam", "heavy", "victory"]

    // MARK: - Loop

    override func update(dt: Double) {
        clock += dt
        timeline.tick(dt)
        if turntable && touches.isEmpty { tYaw += Float(dt) * 0.45 }
        if looping && clock >= nextLoop {
            let mv = ViewerScreen.loopMoves[loopStep % ViewerScreen.loopMoves.count]
            loopStep += 1
            nextLoop = clock + (["charge", "beam", "victory"].contains(mv) ? 3.0 : 1.3)
            play(mv)
        }
        applyCamera(snap: false, dt: Float(dt))
    }

    private func applyCamera(snap: Bool, dt: Float = 1) {
        let k: Float = snap ? 1 : min(1, dt * 10)
        yaw += (tYaw - yaw) * k
        pitch += (tPitch - pitch) * k
        dist += (tDist - dist) * k
        lookY += (tLookY - lookY) * k
        let target = SIMD3<Float>(0, lookY, 0)
        let off = SIMD3<Float>(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * dist
        var pos = target + off
        pos.y = max(0.12, pos.y)
        arena.camera.simdPosition = pos
        arena.camera.simdLook(at: target, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
    }

    // MARK: - Touch: 1 finger orbit, 2 fingers pinch zoom + vertical pan, double tap resets

    override func touchesBegan(_ set: Set<UITouch>, in view: UIView) {
        for t in set { touches[t] = t.location(in: view) }
        startPinchIfNeeded()
    }

    override func touchesMoved(_ set: Set<UITouch>, in view: UIView) {
        if touches.count >= 2, let p = pinchStart {
            let pts = Array(touches.keys.prefix(2)).map { $0.location(in: view) }
            let span = max(10, hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y))
            tDist = max(0.45, min(10, p.dist * Float(p.span / span)))
            let midY = (pts[0].y + pts[1].y) / 2
            tLookY = max(0, min(height * 1.1, p.lookY + Float(midY - p.mid.y) * 0.003 * max(1, tDist)))
        } else if let t = set.first, let last = touches[t] {
            let now = t.location(in: view)
            tYaw -= Float(now.x - last.x) * 0.012
            tPitch = max(-0.5, min(1.3, tPitch + Float(now.y - last.y) * 0.007))
        }
        for t in set { touches[t] = t.location(in: view) }
    }

    override func touchesEnded(_ set: Set<UITouch>, in view: UIView) {
        if set.count == 1, touches.count == 1, set.first?.tapCount == 2 {
            tYaw = 0
            frame(.full)
        }
        for t in set { touches[t] = nil }
        pinchStart = nil
        startPinchIfNeeded()
    }

    private func startPinchIfNeeded() {
        guard touches.count >= 2 else { return }
        let pts = Array(touches.values.prefix(2))
        pinchStart = (max(10, hypot(pts[0].x - pts[1].x, pts[0].y - pts[1].y)), tDist,
                      CGPoint(x: (pts[0].x + pts[1].x) / 2, y: (pts[0].y + pts[1].y) / 2), tLookY)
    }

    // MARK: - UI

    private func buildUI() {
        let back = Glass.button(symbol: "chevron.left", style: .secondary, fontSize: 14) { [weak self] in self?.go(HomeScreen()) }
        let prev = Glass.button(symbol: "chevron.backward", style: .secondary, fontSize: 13) { [weak self] in self?.step(-1) }
        let next = Glass.button(symbol: "chevron.forward", style: .secondary, fontSize: 13) { [weak self] in self?.step(1) }
        let head = UIStackView(arrangedSubviews: [nameLabel, infoLabel])
        head.axis = .vertical
        head.alignment = .center
        head.spacing = 3
        head.translatesAutoresizingMaskIntoConstraints = false
        infoLabel.numberOfLines = 2
        infoLabel.textAlignment = .center
        for v in [back, prev, next, head] as [UIView] { ui.addSubview(v) }

        // Right rail: framing + view toggles
        let rail = UIStackView()
        rail.axis = .vertical
        rail.spacing = 8
        rail.translatesAutoresizingMaskIntoConstraints = false
        let railItems: [(String, String, () -> Void)] = [
            ("figure.stand", "viewer.full", { [weak self] in self?.frame(.full) }),
            ("person.bust", "viewer.upper", { [weak self] in self?.frame(.upper) }),
            ("face.smiling", "viewer.face", { [weak self] in self?.frame(.face) }),
        ]
        for (sym, key, fn) in railItems {
            let b = Glass.button(L(key), symbol: sym, style: .secondary, fontSize: 11, action: fn)
            b.configuration?.imagePlacement = .top
            b.configuration?.imagePadding = 3
            Glass.size(b, 58, 50)
            rail.addArrangedSubview(b)
        }
        let toggles: [(String, String, String)] = [
            ("turn", "arrow.triangle.2.circlepath", "viewer.turn"),
            ("loop", "play.circle", "viewer.loop"),
            ("wire", "square.grid.3x3", "viewer.wire"),
            ("aura", "sparkle", "viewer.aura"),
        ]
        for (id, sym, key) in toggles {
            let b = Glass.button(L(key), symbol: sym, style: .secondary, fontSize: 11) { [weak self] in self?.toggle(id) }
            b.configuration?.imagePlacement = .top
            b.configuration?.imagePadding = 3
            Glass.size(b, 58, 50)
            rail.addArrangedSubview(b)
            toggleButtons[id] = b
        }
        ui.addSubview(rail)

        // Bottom: scrolling move list
        let moves: [(String, String)] = [
            ("stance", "viewer.m.stance"), ("jab", "viewer.m.jab"), ("cross", "viewer.m.cross"), ("kick", "viewer.m.kick"),
            ("upper", "viewer.m.upper"), ("spin", "viewer.m.spin"), ("combo", "viewer.m.combo"), ("dash", "viewer.m.dash"),
            ("blast", "viewer.m.blast"), ("charge", "viewer.m.charge"), ("beam", "viewer.m.beam"), ("hurt", "viewer.m.hurt"),
            ("heavy", "viewer.m.heavy"), ("ko", "viewer.m.ko"), ("victory", "viewer.m.victory"),
        ]
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        let row = UIStackView()
        row.spacing = 8
        row.translatesAutoresizingMaskIntoConstraints = false
        for (id, key) in moves {
            let b = Glass.button(L(key), style: id == "beam" || id == "combo" ? .primary : .secondary, fontSize: 13) { [weak self] in
                self?.looping = false
                self?.refreshToggles()
                self?.play(id)
            }
            b.heightAnchor.constraint(equalToConstant: 40).isActive = true
            row.addArrangedSubview(b)
        }
        scroll.addSubview(row)
        ui.addSubview(scroll)
        let hint = Glass.caption(L("viewer.hint"), size: 9, color: Theme.text3)
        ui.addSubview(hint)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            back.widthAnchor.constraint(equalToConstant: 40), back.heightAnchor.constraint(equalToConstant: 40),
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.centerYAnchor.constraint(equalTo: back.centerYAnchor, constant: 6),
            head.leadingAnchor.constraint(greaterThanOrEqualTo: prev.trailingAnchor, constant: 6),
            head.trailingAnchor.constraint(lessThanOrEqualTo: next.leadingAnchor, constant: -6),
            prev.leadingAnchor.constraint(equalTo: back.trailingAnchor, constant: 8),
            prev.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            prev.widthAnchor.constraint(equalToConstant: 40), prev.heightAnchor.constraint(equalToConstant: 40),
            next.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            next.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            next.widthAnchor.constraint(equalToConstant: 40), next.heightAnchor.constraint(equalToConstant: 40),

            rail.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            rail.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -10),

            scroll.leadingAnchor.constraint(equalTo: ui.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: ui.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: hint.topAnchor, constant: -8),
            scroll.heightAnchor.constraint(equalToConstant: 44),
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 2),
            row.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -2),
            hint.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            hint.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -6),
        ])
        refreshToggles()
    }

    private func step(_ d: Int) {
        index = (index + d + ids.count) % ids.count
        load()
    }

    private func toggle(_ id: String) {
        switch id {
        case "turn": turntable.toggle()
        case "loop":
            looping.toggle()
            nextLoop = clock
        case "wire":
            wireframe.toggle()
            host?.scnView.debugOptions = wireframe ? [.showWireframe] : []
        case "aura":
            auraOn.toggle()
            model?.setAura(auraOn ? 1 : 0)
        default: break
        }
        refreshToggles()
    }

    private func refreshToggles() {
        let state = ["turn": turntable, "loop": looping, "wire": wireframe, "aura": auraOn]
        for (id, b) in toggleButtons {
            let on = state[id] ?? false
            b.tintColor = on ? Theme.accent : Theme.smoke
            b.configuration?.baseForegroundColor = on ? Theme.ink : .white
        }
    }
}
