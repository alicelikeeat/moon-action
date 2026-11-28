import UIKit
import SceneKit
import simd

/// Character creator: edit body, face, hair, outfit, colors and fighting style of the player's own fighter
/// on top of the procedural MeshKit body, so every result keeps clean topology, outlines and all moves.
final class CreatorScreen: Screen {
    private var arena: Arena!
    private var model: FighterModel?
    private var spec: CharacterSpec
    private let isNew: Bool
    private var tab = 0
    private var dirty = true
    private var lastBuild = -1.0
    private var clock = 0.0

    // Orbit preview
    private var yaw: Float = 0.25, tYaw: Float = 0.25
    private var zoom: Float = 0, tZoom: Float = 0       // 0 full body … 1 face close-up
    private var touches: [UITouch: CGPoint] = [:]
    private var pinch: (span: CGFloat, zoom: Float)?

    private let content = UIStackView()
    private var tabControl: UISegmentedControl!

    init(spec: CharacterSpec? = nil) {
        let existing = CustomFighter.spec
        isNew = existing == nil
        self.spec = spec ?? existing ?? CharacterSpec()
        super.init()
    }

    override func build() {
        arena = Arena(theme: 2)
        scene = arena.scene
        pointOfView = arena.camera
        let ped = Toon.part(SCNCylinder(radius: 0.9, height: 0.06), UIColor(hex: 0x1A2030), outline: 0.012, rim: false)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.9, pipeRadius: 0.01))
        ring.geometry?.materials = [Toon.energy(Theme.accent)]
        ring.simdPosition = SIMD3(0, 0.03, 0)
        ped.addChildNode(ring)
        ped.simdPosition = SIMD3(0, 0.03, 0)
        arena.world.addChildNode(ped)
        buildUI()
        if Demo.mode == "creator" {
            self.spec = CharacterSpec.random()
            self.spec.name = "Demo"
            tab = 1
            tabControl.selectedSegmentIndex = 1
            tZoom = 0.85
            tYaw = 0.3
            showTab()
        }
        rebuild()
        applyCamera(snap: true)
    }

    // MARK: - Model

    private func rebuild() {
        dirty = false
        lastBuild = clock
        model?.root.removeFromParentNode()
        let m = FighterModel(def: CustomFighter.makeDef(spec))
        m.root.simdPosition = SIMD3(0, 0.06, 0)
        m.setAura(1)
        arena.world.addChildNode(m.root)
        model = m
    }

    private func changed() { dirty = true }

    override func update(dt: Double) {
        clock += dt
        if dirty && clock - lastBuild > 0.08 { rebuild() }
        applyCamera(snap: false, dt: Float(dt))
    }

    private func applyCamera(snap: Bool, dt: Float = 1) {
        let k: Float = snap ? 1 : min(1, dt * 10)
        yaw += (tYaw - yaw) * k
        zoom += (tZoom - zoom) * k
        // Focus point: body center (zoom 0) up to the face (zoom 1). The aim is pushed below the focus so
        // the focus lands in the open area above the editing panel (upper ~58% of the screen).
        let h = 2.21 * spec.height
        let focus = h * (0.5 + 0.42 * zoom)
        let dist: Float = 4.3 - 3.45 * zoom
        let halfH = dist * tan(29 * Float.pi / 180)
        let target = SIMD3<Float>(0, focus - halfH * 0.42, 0)
        arena.camera.simdPosition = target + SIMD3(sin(yaw) * dist, 0.15 * (1 - zoom), cos(yaw) * dist)
        arena.camera.simdLook(at: target, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
    }

    // Preview gestures: drag to turn, pinch to zoom (touches over the panel never reach here).
    override func touchesBegan(_ set: Set<UITouch>, in view: UIView) {
        for t in set { touches[t] = t.location(in: view) }
        if touches.count >= 2 {
            let p = Array(touches.values.prefix(2))
            pinch = (max(10, hypot(p[0].x - p[1].x, p[0].y - p[1].y)), tZoom)
        }
    }

    override func touchesMoved(_ set: Set<UITouch>, in view: UIView) {
        if touches.count >= 2, let p0 = pinch {
            let p = Array(touches.keys.prefix(2)).map { $0.location(in: view) }
            let span = max(10, hypot(p[0].x - p[1].x, p[0].y - p[1].y))
            tZoom = max(0, min(1, p0.zoom + Float((span - p0.span) / 260)))
        } else if let t = set.first, let last = touches[t] {
            tYaw -= Float(t.location(in: view).x - last.x) * 0.012
        }
        for t in set { touches[t] = t.location(in: view) }
    }

    override func touchesEnded(_ set: Set<UITouch>, in view: UIView) {
        for t in set { touches[t] = nil }
        if touches.count < 2 { pinch = nil }
    }

    // MARK: - UI shell

    private func buildUI() {
        let back = Glass.button(symbol: "xmark", style: .secondary, fontSize: 13) { [weak self] in self?.go(HomeScreen()) }
        let title = Glass.label(L("creator.title"), size: 17, weight: .semibold)
        title.translatesAutoresizingMaskIntoConstraints = false
        let dice = Glass.button(symbol: "dice.fill", style: .secondary, fontSize: 14) { [weak self] in
            guard let self else { return }
            let name = self.spec.name
            self.spec = CharacterSpec.random()
            self.spec.name = name
            self.changed()
            self.showTab()
        }
        let save = Glass.button(L("creator.save"), symbol: "checkmark", style: .primary, fontSize: 14) { [weak self] in self?.commit() }
        for v in [back, title, dice, save] as [UIView] { ui.addSubview(v) }

        let zoomRow = UIStackView()
        zoomRow.spacing = 6
        zoomRow.translatesAutoresizingMaskIntoConstraints = false
        for (sym, z) in [("figure.stand", Float(0)), ("person.bust", Float(0.55)), ("face.smiling", Float(1))] {
            let b = Glass.button(symbol: sym, style: .secondary, fontSize: 12) { [weak self] in self?.tZoom = z }
            Glass.size(b, 36, 36)
            zoomRow.addArrangedSubview(b)
        }
        ui.addSubview(zoomRow)

        let panel = Glass.panel(radius: 26)
        ui.addSubview(panel)
        tabControl = UISegmentedControl(items: ["creator.tab.body", "creator.tab.face", "creator.tab.hair", "creator.tab.outfit", "creator.tab.style"].map { L($0) })
        tabControl.selectedSegmentIndex = 0
        tabControl.selectedSegmentTintColor = Theme.accent
        tabControl.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: Glass.font(12, .semibold)], for: .normal)
        tabControl.setTitleTextAttributes([.foregroundColor: Theme.ink, .font: Glass.font(12, .semibold)], for: .selected)
        tabControl.addAction(UIAction { [weak self] _ in
            guard let self else { return }
            self.tab = self.tabControl.selectedSegmentIndex
            self.showTab()
        }, for: .valueChanged)
        tabControl.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(tabControl)
        let scroll = UIScrollView()
        scroll.showsVerticalScrollIndicator = false
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.keyboardDismissMode = .onDrag
        panel.contentView.addSubview(scroll)
        content.axis = .vertical
        content.spacing = 14
        content.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(content)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            back.widthAnchor.constraint(equalToConstant: 40), back.heightAnchor.constraint(equalToConstant: 40),
            title.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            title.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            save.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            save.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            save.heightAnchor.constraint(equalToConstant: 40),
            dice.trailingAnchor.constraint(equalTo: save.leadingAnchor, constant: -8),
            dice.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            dice.widthAnchor.constraint(equalToConstant: 40), dice.heightAnchor.constraint(equalToConstant: 40),

            zoomRow.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            zoomRow.bottomAnchor.constraint(equalTo: panel.topAnchor, constant: -10),

            panel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 10),
            panel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -10),
            panel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -6),
            panel.heightAnchor.constraint(equalTo: ui.heightAnchor, multiplier: 0.42),
            tabControl.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 14),
            tabControl.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -14),
            tabControl.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
            tabControl.heightAnchor.constraint(equalToConstant: 32),
            scroll.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: tabControl.bottomAnchor, constant: 12),
            scroll.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -8),
            content.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 16),
            content.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -16),
            content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            content.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -8),
            content.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -32),
        ])
        showTab()
    }

    private func showTab() {
        content.arrangedSubviews.forEach { $0.removeFromSuperview() }
        switch tab {
        case 0: bodyTab()
        case 1: faceTab()
        case 2: hairTab()
        case 3: outfitTab()
        default: styleTab()
        }
    }

    // MARK: - Tabs

    private func bodyTab() {
        add(slider("creator.height", spec.height, 0.86...1.14) { [weak self] v in self?.spec.height = v })
        add(slider("creator.bulk", spec.bulk, 0.8...1.28) { [weak self] v in self?.spec.bulk = v })
        add(swatches("creator.skin", Palette.skin, spec.skin) { [weak self] c in self?.spec.skin = c })
        add(swatches("creator.aura", Palette.aura, spec.aura) { [weak self] c in self?.spec.aura = c })
    }

    private func faceTab() {
        add(segments("creator.eyeShape", ["creator.eye.round", "creator.eye.sharp"], spec.eyeShape) { [weak self] i in self?.spec.eyeShape = i })
        add(slider("creator.eyeSize", spec.eyeScale, 0.8...1.3) { [weak self] v in self?.spec.eyeScale = v })
        add(slider("creator.eyeGap", spec.eyeGap, 0.86...1.14) { [weak self] v in self?.spec.eyeGap = v })
        add(slider("creator.brow", spec.browTilt, -1...1) { [weak self] v in self?.spec.browTilt = v })
        add(slider("creator.jaw", spec.jaw, 0.55...1.45) { [weak self] v in self?.spec.jaw = v })
        add(swatches("creator.eyeColor", Palette.eyes, spec.eyes) { [weak self] c in self?.spec.eyes = c })
    }

    private func hairTab() {
        let names = (0..<CharacterSpec.hairStyles).map { L("creator.hair.\($0)") }
        add(header("creator.hairStyle"))
        add(grid(names, columns: 4, selected: [spec.hairStyle]) { [weak self] i in
            self?.spec.hairStyle = i
            return [i]
        })
        add(swatches("creator.hairColor", Palette.hair, spec.hair) { [weak self] c in self?.spec.hair = c })
    }

    private func outfitTab() {
        add(segments("creator.sleeves", ["creator.sleeve.0", "creator.sleeve.1", "creator.sleeve.2"], spec.sleeves) { [weak self] i in
            self?.spec.sleeves = i
        })
        add(header("creator.parts"))
        let keys = ["creator.coat", "creator.scarf", "creator.pads", "creator.gloves", "creator.cape", "creator.headband"]
        let paths: [WritableKeyPath<CharacterSpec, Bool>] = [\.coat, \.scarf, \.shoulderPads, \.gloves, \.cape, \.headband]
        let on = Set(paths.indices.filter { spec[keyPath: paths[$0]] })
        add(grid(keys.map { L($0) }, columns: 3, selected: on) { [weak self] i in
            guard let self else { return [] }
            self.spec[keyPath: paths[i]].toggle()
            return Set(paths.indices.filter { self.spec[keyPath: paths[$0]] })
        })
        add(swatches("creator.primary", Palette.cloth, spec.primary) { [weak self] c in self?.spec.primary = c })
        add(swatches("creator.secondary", Palette.cloth, spec.secondary) { [weak self] c in self?.spec.secondary = c })
        add(swatches("creator.accent", Palette.cloth, spec.accent) { [weak self] c in self?.spec.accent = c })
    }

    private func styleTab() {
        add(header("creator.name"))
        let field = UITextField()
        field.text = spec.name
        field.placeholder = L("creator.defaultName")
        field.textColor = .white
        field.font = Glass.font(15, .semibold)
        field.backgroundColor = UIColor(white: 1, alpha: 0.08)
        field.layer.cornerRadius = 12
        field.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        field.leftViewMode = .always
        field.returnKeyType = .done
        field.heightAnchor.constraint(equalToConstant: 40).isActive = true
        field.addAction(UIAction { [weak self, weak field] _ in
            self?.spec.name = String((field?.text ?? "").prefix(12))
        }, for: .editingChanged)
        field.addAction(UIAction { [weak field] _ in field?.resignFirstResponder() }, for: .editingDidEndOnExit)
        add(field)

        add(header("creator.styleHint"))
        let fighters = Roster.all
        let summary = Glass.label("", size: 11, weight: .regular, color: Theme.text2, align: .left)
        summary.numberOfLines = 3
        func describe() {
            let b = fighters.first { $0.id == spec.style } ?? Roster.kai
            summary.text = L10n.f("creator.styleInfo", b.name.s, b.speed.label, b.specialName.s, b.ultimateName.s)
        }
        add(grid(fighters.map { $0.shortName }, columns: 4, selected: Set(fighters.indices.filter { fighters[$0].id == spec.style })) { [weak self] i in
            self?.spec.style = fighters[i].id
            describe()
            return [i]
        })
        describe()
        add(summary)
        if !isNew {
            let del = Glass.button(L("creator.delete"), symbol: "trash", style: .secondary, tint: Theme.hpEnemy.withAlphaComponent(0.5), fontSize: 13) { [weak self] in
                CustomFighter.delete()
                self?.go(HomeScreen())
            }
            del.heightAnchor.constraint(equalToConstant: 38).isActive = true
            add(del)
        }
    }

    private func commit() {
        host?.view.endEditing(true)
        CustomFighter.save(spec)
        let s = Save.shared
        if !s.data.team.contains(CustomFighter.id) {
            s.data.team.insert(CustomFighter.id, at: 0)
            s.data.team = Array(s.data.team.prefix(3))
            s.persist()
        }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        model?.victory()
        realDelay(0.7) { [weak self] in self?.go(TeamScreen()) }
    }

    // MARK: - Control builders

    private func add(_ v: UIView) { content.addArrangedSubview(v) }

    private func header(_ key: String) -> UILabel {
        Glass.label(L(key), size: 12, weight: .semibold, color: Theme.text2, align: .left)
    }

    private func slider(_ key: String, _ value: Float, _ range: ClosedRange<Float>, set: @escaping (Float) -> Void) -> UIView {
        let l = header(key)
        let s = UISlider()
        s.minimumValue = range.lowerBound
        s.maximumValue = range.upperBound
        s.value = value
        s.minimumTrackTintColor = Theme.accent
        s.maximumTrackTintColor = UIColor(white: 1, alpha: 0.15)
        s.addAction(UIAction { [weak self, weak s] _ in
            guard let s else { return }
            set(s.value)
            self?.changed()
        }, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [l, s])
        row.spacing = 12
        row.alignment = .center
        l.widthAnchor.constraint(equalToConstant: 72).isActive = true
        return row
    }

    private func segments(_ key: String, _ items: [String], _ selected: Int, set: @escaping (Int) -> Void) -> UIView {
        let l = header(key)
        let c = UISegmentedControl(items: items.map { L($0) })
        c.selectedSegmentIndex = selected
        c.selectedSegmentTintColor = Theme.accent
        c.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: Glass.font(12, .medium)], for: .normal)
        c.setTitleTextAttributes([.foregroundColor: Theme.ink, .font: Glass.font(12, .semibold)], for: .selected)
        c.addAction(UIAction { [weak self, weak c] _ in
            guard let c else { return }
            set(c.selectedSegmentIndex)
            self?.changed()
        }, for: .valueChanged)
        let row = UIStackView(arrangedSubviews: [l, c])
        row.spacing = 12
        row.alignment = .center
        l.widthAnchor.constraint(equalToConstant: 72).isActive = true
        return row
    }

    private func swatches(_ key: String, _ colors: [UInt32], _ selected: UInt32, set: @escaping (UInt32) -> Void) -> UIView {
        let col = UIStackView()
        col.axis = .vertical
        col.spacing = 8
        col.addArrangedSubview(header(key))
        let scroll = UIScrollView()
        scroll.showsHorizontalScrollIndicator = false
        scroll.heightAnchor.constraint(equalToConstant: 34).isActive = true
        let row = UIStackView()
        row.spacing = 9
        row.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(row)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: 2),
            row.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -2),
            row.centerYAnchor.constraint(equalTo: scroll.frameLayoutGuide.centerYAnchor),
        ])
        var dots: [UIButton] = []
        func mark(_ hex: UInt32) {
            for (i, d) in dots.enumerated() {
                let on = colors[i] == hex
                d.layer.borderColor = (on ? Theme.accent : UIColor(white: 1, alpha: 0.25)).cgColor
                d.layer.borderWidth = on ? 3 : 1
                d.transform = on ? CGAffineTransform(scaleX: 1.12, y: 1.12) : .identity
            }
        }
        for hex in colors {
            let d = UIButton(type: .custom)
            d.backgroundColor = UIColor(hex: hex)
            d.layer.cornerRadius = 14
            Glass.size(d, 28, 28)
            d.addAction(UIAction { [weak self] _ in
                set(hex)
                mark(hex)
                UISelectionFeedbackGenerator().selectionChanged()
                self?.changed()
            }, for: .touchUpInside)
            dots.append(d)
            row.addArrangedSubview(d)
        }
        mark(selected)
        col.addArrangedSubview(scroll)
        return col
    }

    /// Grid of choice chips. `pick` returns the new selected set.
    private func grid(_ titles: [String], columns: Int, selected: Set<Int>, pick: @escaping (Int) -> Set<Int>) -> UIView {
        let col = UIStackView()
        col.axis = .vertical
        col.spacing = 8
        var buttons: [UIButton] = []
        func paint(_ on: Set<Int>) {
            for (i, b) in buttons.enumerated() {
                b.tintColor = on.contains(i) ? Theme.accent : Theme.smoke
                b.configuration?.baseForegroundColor = on.contains(i) ? Theme.ink : .white
            }
        }
        var row: UIStackView?
        for (i, t) in titles.enumerated() {
            if i % columns == 0 {
                let r = UIStackView()
                r.spacing = 8
                r.distribution = .fillEqually
                col.addArrangedSubview(r)
                row = r
            }
            let b = Glass.button(t, style: .secondary, fontSize: 12) { [weak self] in
                paint(pick(i))
                self?.changed()
            }
            b.heightAnchor.constraint(equalToConstant: 36).isActive = true
            b.titleLabel?.adjustsFontSizeToFitWidth = true
            buttons.append(b)
            row?.addArrangedSubview(b)
        }
        if let r = row {
            for _ in 0..<((columns - titles.count % columns) % columns) { r.addArrangedSubview(UIView()) }
        }
        paint(selected)
        return col
    }
}
