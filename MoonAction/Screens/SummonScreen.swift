import UIKit
import SceneKit
import simd

final class SummonScreen: Screen {
    private var arena: Arena!
    private let portal = SCNNode()
    private var revealed: FighterModel?
    private var coinLabel: UILabel!
    private var summonBtn: UIButton!
    private var backBtn: UIButton!
    private var resultPanel: UIView?
    private var busy = false
    private var t: Double = 0

    override func build() {
        arena = Arena(theme: 3)
        scene = arena.scene
        pointOfView = arena.camera
        arena.camera.simdPosition = SIMD3(0, 1.8, 7.5)
        arena.camera.simdLook(at: SIMD3(0, 1.1, 0), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))

        let color = Theme.accent
        for (r, w) in [(Float(1.6), Float(0.035)), (Float(1.85), Float(0.012))] {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: CGFloat(r), pipeRadius: CGFloat(w)))
            ring.geometry?.materials = [Toon.energy(color)]
            ring.simdEulerAngles = SIMD3(.pi / 2, 0, 0)
            ring.runAction(.repeatForever(.rotateBy(x: 0, y: r > 1.7 ? -2 : 2, z: 0, duration: 3)))
            portal.addChildNode(ring)
        }
        let disc = SCNNode(geometry: SCNCylinder(radius: 1.55, height: 0.01))
        disc.geometry?.materials = [Toon.energy(color.darker(0.75), alpha: 0.25)]
        disc.simdEulerAngles = SIMD3(.pi / 2, 0, 0)
        portal.addChildNode(disc)
        let halo = Toon.glowSprite(color, size: 2.6)
        halo.opacity = 0.35
        portal.addChildNode(halo)
        let ps = Toon.aura(color, height: 0.2)
        ps.birthRate = 25
        ps.emitterShape = SCNTorus(ringRadius: 1.6, pipeRadius: 0.1)
        ps.emittingDirection = SCNVector3(0, 0, 1)
        portal.addParticleSystem(ps)
        portal.simdPosition = SIMD3(0, 1.6, 0)
        arena.world.addChildNode(portal)
        buildUI()
        refresh()
    }

    override func update(dt: Double) {
        t += dt
        portal.simdScale = SIMD3(repeating: 1 + Float(sin(t * 2)) * 0.03)
        if let m = revealed {
            m.root.simdEulerAngles = SIMD3(0, Float(sin(t * 0.5) * 0.35), 0)
        }
    }

    private func buildUI() {
        backBtn = Glass.button(symbol: "chevron.left", style: .secondary, fontSize: 14) { [weak self] in
            guard let self, !self.busy else { return }
            self.go(HomeScreen())
        }
        ui.addSubview(backBtn)
        let head = header(L("summon.title"), L10n.f("summon.rates", Save.duplicateXP))
        ui.addSubview(head)
        let (coins, label) = chip(symbol: "moon.stars.fill", text: "", tint: Theme.accent)
        coinLabel = label
        ui.addSubview(coins)
        summonBtn = Glass.button(L("summon.button"), subtitle: L10n.f("summon.cost", Save.summonCost), symbol: "sparkles",
                                 style: .primary, fontSize: 18) { [weak self] in self?.summon() }
        ui.addSubview(summonBtn)
        NSLayoutConstraint.activate([
            backBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            backBtn.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            backBtn.widthAnchor.constraint(equalToConstant: 40),
            backBtn.heightAnchor.constraint(equalToConstant: 40),
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.topAnchor.constraint(equalTo: backBtn.bottomAnchor, constant: 12),
            coins.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            coins.centerYAnchor.constraint(equalTo: backBtn.centerYAnchor),
            summonBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 30),
            summonBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -30),
            summonBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            summonBtn.heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    private func refresh() {
        coinLabel.text = "\(Save.shared.data.coins)"
        let ok = Save.shared.data.coins >= Save.summonCost && !busy
        summonBtn.isEnabled = ok
        summonBtn.alpha = ok ? 1 : 0.5
        backBtn.alpha = busy ? 0.5 : 1
    }

    private func summon() {
        let save = Save.shared
        guard !busy, save.data.coins >= Save.summonCost else { return }
        busy = true
        save.data.coins -= Save.summonCost
        let rarity = chance(0.25) ? 3 : 2
        let def = Roster.all.filter { $0.rarity == rarity }.randomElement() ?? Roster.kai
        let isNew = !save.isUnlocked(def.id)
        if isNew { save.data.unlocked.append(def.id) } else { save.addXP(def.id, Save.duplicateXP) }
        save.persist()
        refresh()
        resultPanel?.removeFromSuperview()
        revealed?.root.removeFromParentNode()
        revealed = nil

        Sound.play(.charge)
        let spin = SCNAction.rotateBy(x: 0, y: 0, z: 12, duration: 1.2)
        spin.timingMode = .easeIn
        portal.runAction(.group([spin, .sequence([.scale(to: 1.4, duration: 1.1), .scale(to: 1, duration: 0.1)])]))
        realDelay(1.2) { [weak self] in self?.reveal(def, isNew: isNew) }
    }

    private func reveal(_ def: FighterDef, isNew: Bool) {
        Sound.play(def.rarity == 3 ? .ultimate : .explode)
        Haptics.success()
        SCNNode.emit(Toon.burst(def.look.aura, count: 120, speed: 8, size: 0.35, life: 0.6), at: SIMD3(0, 1.6, 0), in: arena.world)
        let flash = UIView(frame: ui.bounds)
        flash.backgroundColor = UIColor.white.withAlphaComponent(0.7)
        flash.isUserInteractionEnabled = false
        ui.addSubview(flash)
        UIView.animate(withDuration: 0.6, animations: { flash.alpha = 0 }) { _ in flash.removeFromSuperview() }

        let m = FighterModel(def: def)
        m.root.simdPosition = SIMD3(0, 0, 0.6)
        m.setAura(3)
        m.victory()
        arena.world.addChildNode(m.root)
        revealed = m
        realDelay(1.5) { m.setAura(1) }

        let panel = Glass.panel(radius: 22)
        let stars = Glass.label(String(repeating: "★", count: def.rarity), size: 14, weight: .semibold,
                                color: def.rarity == 3 ? Theme.accent : Theme.text2)
        let name = Glass.label(def.name.s, size: 24, weight: .bold)
        let title = Glass.label(def.title.s + "  ·  " + def.speed.label, size: 12, weight: .medium, color: Theme.text2)
        let result = Glass.caption(isNew ? L("summon.new") : L10n.f("summon.dup", Save.duplicateXP), size: 11,
                                   color: isNew ? Theme.hp : Theme.accent)
        let moves = Glass.label(L10n.f("summon.moves", def.specialName.s, def.ultimateName.s), size: 11, weight: .regular,
                                color: Theme.text2)
        let st = UIStackView(arrangedSubviews: [stars, name, title, result, moves])
        st.axis = .vertical
        st.spacing = 3
        st.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(st)
        ui.addSubview(panel)
        NSLayoutConstraint.activate([
            panel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 18),
            panel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -18),
            panel.bottomAnchor.constraint(equalTo: summonBtn.topAnchor, constant: -14),
            st.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 18),
            st.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -18),
            st.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
            st.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -14),
        ])
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: 30)
        UIView.animate(withDuration: 0.4, delay: 0.2, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            panel.alpha = 1
            panel.transform = .identity
        }
        resultPanel = panel
        busy = false
        refresh()
    }
}
