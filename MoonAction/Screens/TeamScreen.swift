import UIKit
import SceneKit
import simd

/// Team select: live 3D preview of the focused fighter, info card, scrollable roster of 20.
final class TeamScreen: Screen {
    private var arena: Arena!
    private var preview: FighterModel?
    private let pedestal = SCNNode()
    private var selected: [String] = []
    private var tiles: [String: RosterTile] = [:]
    private var fightBtn: UIButton!
    private let infoName = Glass.label("", size: 19, weight: .semibold, align: .left)
    private let infoTitle = Glass.label("", size: 12, weight: .medium, color: Theme.text2, align: .left)
    private let infoSpeed = Glass.label("", size: 11, weight: .medium, color: Theme.energy, align: .left)
    private let infoStats = Glass.label("", size: 11, weight: .medium, color: Theme.text2, align: .left, mono: true)
    private let deckRow = UIStackView()
    private let modelInfo = Glass.label("", size: 10, weight: .medium, color: Theme.text3, align: .left)
    private var importBtn: UIButton!
    private var removeBtn: UIButton!
    private var focusedID = "kai"
    private var enemyIDs: [String] = []
    private var t: Double = 0

    override func build() {
        arena = Arena(theme: 2)
        scene = arena.scene
        pointOfView = arena.camera
        let save = Save.shared
        selected = save.data.team.filter { save.isUnlocked($0) }
        enemyIDs = Array(Roster.all.map { $0.id }.shuffled().prefix(3))

        let ped = Toon.part(SCNCylinder(radius: 1.0, height: 0.18), UIColor(hex: 0x1A2030), outline: 0.015, rim: false)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.0, pipeRadius: 0.012))
        ring.geometry?.materials = [Toon.energy(Theme.accent)]
        ring.simdPosition = SIMD3(0, 0.095, 0)
        ped.addChildNode(ring)
        pedestal.addChildNode(ped)
        pedestal.simdPosition = SIMD3(0, 0.09, 0)
        arena.world.addChildNode(pedestal)
        arena.camera.simdPosition = SIMD3(0, 1.75, 7.4)
        arena.camera.simdLook(at: SIMD3(0, 0.15, 0), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
        buildUI()
        focus(Demo.mode == "team" ? "aria" : (selected.first ?? "kai"))
        refresh()
    }

    override func update(dt: Double) {
        t += dt
        preview?.root.simdEulerAngles = SIMD3(0, Float(sin(t * 0.6) * 0.55), 0)
    }

    private func focus(_ id: String) {
        focusedID = id
        preview?.root.removeFromParentNode()
        let m = FighterModel(def: Roster.byID(id))
        m.root.simdPosition = SIMD3(0, 0.18, 0)
        m.setAura(1)
        arena.world.addChildNode(m.root)
        preview = m
        let d = m.def
        let unlocked = Save.shared.isUnlocked(id)
        infoName.text = d.name.s
        infoTitle.text = d.title.s + "  ·  " + String(repeating: "★", count: d.rarity) +
            (unlocked ? "  ·  Lv \(Save.shared.level(id))" : "  ·  " + L("team.locked"))
        infoSpeed.text = d.speed.label
        infoStats.text = L10n.f("team.stats", Int(d.hp), Int(d.atk), Int(d.defense))
        deckRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for card in d.cards + [d.specialCard, d.effectCard, d.ultimateCard] {
            let iv = UIImageView(image: CardArt.image(card))
            iv.contentMode = .scaleAspectFill
            iv.layer.cornerRadius = 4
            iv.clipsToBounds = true
            Glass.size(iv, 24, 34)
            deckRow.addArrangedSubview(iv)
        }
        for (k, tile) in tiles { tile.setFocused(k == id) }
        let has = ModelLibrary.hasModel(id)
        if let n = m.importedBones {
            modelInfo.text = L10n.f(ModelLibrary.isUserImported(id) ? "model.custom" : "model.bundled", n)
        } else {
            modelInfo.text = has ? L("model.failed") : L("model.procedural") + " · " + L("model.hint")
        }
        importBtn?.configuration?.title = L(ModelLibrary.isUserImported(id) ? "model.replace" : "model.import")
        removeBtn?.isHidden = !ModelLibrary.isUserImported(id)
    }

    private func importModel() {
        guard let vc = host else { return }
        let id = focusedID
        ModelPicker.present(from: vc, for: id) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                Sound.play(.ultimate)
                self.tiles[id]?.refreshImage()
                self.focus(id)
            case .failure(let e):
                self.modelInfo.text = L("model.failed") + ": " + e.localizedDescription
            }
        }
    }

    private func buildUI() {
        let back = Glass.button(symbol: "chevron.left", style: .secondary, fontSize: 14) { [weak self] in self?.go(HomeScreen()) }
        ui.addSubview(back)
        let head = header(L("team.title"), L("team.sub"))
        ui.addSubview(head)

        let info = Glass.panel(radius: 20)
        deckRow.spacing = 4
        let speedRow = UIStackView(arrangedSubviews: [infoSpeed, infoStats])
        speedRow.spacing = 12
        importBtn = Glass.button(L("model.import"), symbol: "cube.transparent", style: .secondary, fontSize: 11) { [weak self] in
            self?.importModel()
        }
        importBtn.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        removeBtn = Glass.button(L("model.remove"), symbol: "trash", style: .secondary, fontSize: 11) { [weak self] in
            guard let self else { return }
            ModelLibrary.remove(self.focusedID)
            self.tiles[self.focusedID]?.refreshImage()
            self.focus(self.focusedID)
        }
        removeBtn.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        let modelRow = UIStackView(arrangedSubviews: [importBtn, removeBtn])
        modelRow.spacing = 6
        let infoStack = UIStackView(arrangedSubviews: [infoName, infoTitle, speedRow, deckRow, modelRow, modelInfo])
        infoStack.axis = .vertical
        infoStack.spacing = 3
        infoStack.setCustomSpacing(10, after: speedRow)
        infoStack.setCustomSpacing(10, after: deckRow)
        importBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        removeBtn.heightAnchor.constraint(equalToConstant: 28).isActive = true
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        info.contentView.addSubview(infoStack)
        ui.addSubview(info)

        // Roster grid (5 columns, scrolls)
        let gridPanel = Glass.panel(radius: 20)
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        gridPanel.contentView.addSubview(scroll)
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 10
        grid.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(grid)
        var row: UIStackView?
        let roster = Roster.playable
        for (i, def) in roster.enumerated() {
            if i % 5 == 0 {
                let r = UIStackView()
                r.spacing = 6
                r.distribution = .fillEqually
                grid.addArrangedSubview(r)
                row = r
            }
            let tile = RosterTile(def: def, unlocked: Save.shared.isUnlocked(def.id))
            tile.onTap = { [weak self] in self?.toggle(def.id) }
            tiles[def.id] = tile
            row?.addArrangedSubview(tile)
        }
        if let r = row {
            for _ in 0..<((5 - roster.count % 5) % 5) { r.addArrangedSubview(UIView()) }
        }
        ui.addSubview(gridPanel)

        let stage = Save.shared.data.stage
        let foeNames = enemyIDs.map { Roster.byID($0).shortName }.joined(separator: " · ")
        let foe = Glass.label(L10n.f("team.foes", stage, Save.enemyLevel(stage: stage), foeNames), size: 11, weight: .medium, color: Theme.text2)
        ui.addSubview(foe)
        fightBtn = Glass.button(L("team.fight"), symbol: "play.fill", style: .primary, fontSize: 18) { [weak self] in self?.start() }
        ui.addSubview(fightBtn)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            back.widthAnchor.constraint(equalToConstant: 40),
            back.heightAnchor.constraint(equalToConstant: 40),
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.centerYAnchor.constraint(equalTo: back.centerYAnchor),

            info.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            info.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            info.bottomAnchor.constraint(equalTo: gridPanel.topAnchor, constant: -10),
            infoStack.leadingAnchor.constraint(equalTo: info.contentView.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(lessThanOrEqualTo: info.contentView.trailingAnchor, constant: -16),
            infoStack.topAnchor.constraint(equalTo: info.contentView.topAnchor, constant: 12),
            infoStack.bottomAnchor.constraint(equalTo: info.contentView.bottomAnchor, constant: -12),

            gridPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            gridPanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            gridPanel.bottomAnchor.constraint(equalTo: foe.topAnchor, constant: -10),
            gridPanel.heightAnchor.constraint(equalToConstant: 176),
            scroll.leadingAnchor.constraint(equalTo: gridPanel.contentView.leadingAnchor, constant: 10),
            scroll.trailingAnchor.constraint(equalTo: gridPanel.contentView.trailingAnchor, constant: -10),
            scroll.topAnchor.constraint(equalTo: gridPanel.contentView.topAnchor, constant: 10),
            scroll.bottomAnchor.constraint(equalTo: gridPanel.contentView.bottomAnchor, constant: -10),
            grid.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            grid.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            grid.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            grid.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),

            foe.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            foe.bottomAnchor.constraint(equalTo: fightBtn.topAnchor, constant: -10),
            foe.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),

            fightBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 28),
            fightBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -28),
            fightBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            fightBtn.heightAnchor.constraint(equalToConstant: 54),
        ])
    }

    private func toggle(_ id: String) {
        focus(id)
        guard Save.shared.isUnlocked(id) else {
            Sound.play(.ui)
            return
        }
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
        } else if selected.count < 3 {
            selected.append(id)
        } else {
            selected[2] = id
        }
        Sound.play(.card)
        UISelectionFeedbackGenerator().selectionChanged()
        refresh()
    }

    private func refresh() {
        for (id, tile) in tiles { tile.setOrder(selected.firstIndex(of: id).map { $0 + 1 }) }
        fightBtn.isEnabled = selected.count == 3
        fightBtn.alpha = selected.count == 3 ? 1 : 0.45
    }

    private func start() {
        guard selected.count == 3 else { return }
        Save.shared.data.team = selected
        Save.shared.persist()
        let stage = Save.shared.data.stage
        go(BattleScreen(playerIDs: selected, enemyIDs: enemyIDs, enemyLevel: Save.enemyLevel(stage: stage), stage: stage))
    }
}

/// Roster cell: round 3D-rendered bust, short name, selection order.
final class RosterTile: UIControl {
    var onTap: (() -> Void)?
    private let face = UIImageView()
    private let ring = UIView()
    private let name = Glass.label("", size: 10, weight: .medium, color: Theme.text2)
    private let order = Glass.label("", size: 10, weight: .bold, color: Theme.ink, mono: true)

    private let def: FighterDef

    func refreshImage() {
        face.image = Portraits.image(def, .bust, size: CGSize(width: 56, height: 56))
    }

    init(def: FighterDef, unlocked: Bool) {
        self.def = def
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        face.image = Portraits.image(def, .bust, size: CGSize(width: 56, height: 56))
        face.contentMode = .scaleAspectFill
        face.clipsToBounds = true
        face.layer.cornerRadius = 24
        face.backgroundColor = def.look.aura.withAlphaComponent(0.25)
        face.alpha = unlocked ? 1 : 0.3
        ring.layer.cornerRadius = 27
        ring.layer.borderWidth = 1.5
        ring.layer.borderColor = UIColor.clear.cgColor
        name.text = unlocked ? def.shortName : "—"
        order.backgroundColor = Theme.accent
        order.layer.cornerRadius = 8
        order.clipsToBounds = true
        order.isHidden = true
        for v in [ring, face, name, order] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            v.isUserInteractionEnabled = false
            addSubview(v)
        }
        if !unlocked {
            let lock = UIImageView(image: UIImage(systemName: "lock.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 11, weight: .semibold)))
            lock.tintColor = Theme.text2
            lock.translatesAutoresizingMaskIntoConstraints = false
            addSubview(lock)
            lock.centerXAnchor.constraint(equalTo: face.centerXAnchor).isActive = true
            lock.centerYAnchor.constraint(equalTo: face.centerYAnchor).isActive = true
        }
        NSLayoutConstraint.activate([
            heightAnchor.constraint(equalToConstant: 74),
            ring.centerXAnchor.constraint(equalTo: centerXAnchor),
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.widthAnchor.constraint(equalToConstant: 54),
            ring.heightAnchor.constraint(equalToConstant: 54),
            face.centerXAnchor.constraint(equalTo: ring.centerXAnchor),
            face.centerYAnchor.constraint(equalTo: ring.centerYAnchor),
            face.widthAnchor.constraint(equalToConstant: 48),
            face.heightAnchor.constraint(equalToConstant: 48),
            name.topAnchor.constraint(equalTo: ring.bottomAnchor, constant: 4),
            name.leadingAnchor.constraint(equalTo: leadingAnchor),
            name.trailingAnchor.constraint(equalTo: trailingAnchor),
            order.widthAnchor.constraint(equalToConstant: 16),
            order.heightAnchor.constraint(equalToConstant: 16),
            order.trailingAnchor.constraint(equalTo: ring.trailingAnchor, constant: 2),
            order.topAnchor.constraint(equalTo: ring.topAnchor, constant: -2),
        ])
        addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchUpInside)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setOrder(_ n: Int?) {
        order.isHidden = n == nil
        order.text = n.map { "\($0)" }
        ring.layer.borderColor = (n != nil ? Theme.accent : UIColor.clear).cgColor
    }

    func setFocused(_ f: Bool) {
        name.textColor = f ? .white : Theme.text2
        if ring.layer.borderColor == UIColor.clear.cgColor || ring.layer.borderColor == UIColor(white: 1, alpha: 0.5).cgColor {
            ring.layer.borderColor = (f ? UIColor(white: 1, alpha: 0.5) : UIColor.clear).cgColor
        }
    }
}
