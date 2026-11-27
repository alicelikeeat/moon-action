import UIKit
import SceneKit
import simd

final class TeamScreen: Screen {
    private var arena: Arena!
    private var preview: FighterModel?
    private var pedestal = SCNNode()
    private var selected: [String] = []
    private var focused: String = "kai"
    private var tiles: [String: UIButton] = [:]
    private var badges: [String: UILabel] = [:]
    private var fightBtn: UIButton!
    private let infoName = Glass.label("", size: 20, weight: .black, align: .left)
    private let infoTitle = Glass.label("", size: 12, weight: .bold, color: UIColor(white: 1, alpha: 0.75), align: .left)
    private let infoStats = Glass.label("", size: 12, weight: .semibold, color: UIColor(white: 1, alpha: 0.85), align: .left)
    private let deckRow = UIStackView()
    private var enemyIDs: [String] = []
    private var t: Double = 0

    override func build() {
        arena = Arena(theme: 2)
        scene = arena.scene
        pointOfView = arena.camera
        let save = Save.shared
        selected = save.data.team.filter { save.isUnlocked($0) }
        focused = selected.first ?? "kai"
        enemyIDs = Array(Roster.all.map { $0.id }.shuffled().prefix(3))

        let ped = Toon.part(SCNCylinder(radius: 1.1, height: 0.25), UIColor(hex: 0x2A3550), outline: 0.02)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 1.1, pipeRadius: 0.04))
        ring.geometry?.materials = [Toon.energy(UIColor(hex: 0x7FE8FF))]
        ring.simdPosition = SIMD3(0, 0.13, 0)
        ped.addChildNode(ring)
        pedestal.addChildNode(ped)
        pedestal.simdPosition = SIMD3(0, 0.12, 0)
        arena.world.addChildNode(pedestal)
        arena.camera.simdPosition = SIMD3(0, 1.9, 7.0)
        arena.camera.simdLook(at: SIMD3(0, 0.35, 0))
        showPreview(focused)
        buildUI()
        refresh()
    }

    override func update(dt: Double) {
        t += dt
        preview?.root.simdEulerAngles = SIMD3(0, Float(sin(t * 0.6) * 0.6), 0)
    }

    private func showPreview(_ id: String) {
        preview?.root.removeFromParentNode()
        let m = FighterModel(def: Roster.byID(id))
        m.root.simdPosition = SIMD3(0, 0.25, 0)
        m.setAura(2)
        arena.world.addChildNode(m.root)
        preview = m
        let d = m.def
        infoName.text = d.name
        infoTitle.text = "\(d.title)  ·  " + String(repeating: "★", count: d.rarity) +
            (Save.shared.isUnlocked(id) ? "  ·  Lv \(Save.shared.level(id))" : "  ·  LOCKED")
        infoStats.text = "HP \(Int(d.hp))   ATK \(Int(d.atk))   DEF \(Int(d.defense))"
        deckRow.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for card in d.cards + [d.specialCard, d.effectCard, d.ultimateCard] {
            let iv = UIImageView(image: CardArt.image(card))
            iv.contentMode = .scaleAspectFill
            iv.layer.cornerRadius = 5
            iv.clipsToBounds = true
            Glass.size(iv, 30, 42)
            deckRow.addArrangedSubview(iv)
        }
    }

    private func buildUI() {
        let back = Glass.button(symbol: "chevron.left", fontSize: 16) { [weak self] in self?.go(HomeScreen()) }
        ui.addSubview(back)
        let head = header("Choose Your Team", "Pick 3 · the first one starts")
        ui.addSubview(head)

        // Info card
        let info = Glass.panel(radius: 22)
        deckRow.spacing = 4
        let infoStack = UIStackView(arrangedSubviews: [infoName, infoTitle, infoStats, deckRow])
        infoStack.axis = .vertical
        infoStack.spacing = 4
        infoStack.setCustomSpacing(8, after: infoStats)
        infoStack.alignment = .leading
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        info.contentView.addSubview(infoStack)
        ui.addSubview(info)

        // Roster grid
        let grid = UIStackView()
        grid.axis = .vertical
        grid.spacing = 8
        grid.distribution = .fillEqually
        grid.translatesAutoresizingMaskIntoConstraints = false
        var row: UIStackView?
        for (i, def) in Roster.all.enumerated() {
            if i % 3 == 0 {
                row = UIStackView()
                row?.spacing = 8
                row?.distribution = .fillEqually
                grid.addArrangedSubview(row!)
            }
            let unlocked = Save.shared.isUnlocked(def.id)
            let b = Glass.button(unlocked ? def.name.components(separatedBy: " ").first : "Locked", style: .regular, fontSize: 12)
            b.configuration?.image = Portraits.image(def, .bust, size: CGSize(width: 54, height: 54))?
                .withRenderingMode(.alwaysOriginal)
            b.configuration?.imagePlacement = .top
            b.configuration?.imagePadding = 2
            b.configuration?.cornerStyle = .large
            b.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
            b.alpha = unlocked ? 1 : 0.45
            b.addAction(UIAction { [weak self] _ in self?.toggle(def.id) }, for: .touchUpInside)
            let badge = Glass.label("", size: 12, weight: .black, color: .black)
            badge.backgroundColor = .maCoin
            badge.layer.cornerRadius = 11
            badge.clipsToBounds = true
            badge.isHidden = true
            b.addSubview(badge)
            NSLayoutConstraint.activate([
                badge.widthAnchor.constraint(equalToConstant: 22),
                badge.heightAnchor.constraint(equalToConstant: 22),
                badge.topAnchor.constraint(equalTo: b.topAnchor, constant: 4),
                badge.trailingAnchor.constraint(equalTo: b.trailingAnchor, constant: -4),
            ])
            tiles[def.id] = b
            badges[def.id] = badge
            row?.addArrangedSubview(b)
        }
        ui.addSubview(grid)

        let stage = Save.shared.data.stage
        let foe = Glass.label("Stage \(stage) foes · Lv \(Save.enemyLevel(stage: stage)): " +
                              enemyIDs.map { Roster.byID($0).name.components(separatedBy: " ").first ?? "" }.joined(separator: ", "),
                              size: 12, weight: .bold, color: UIColor(hex: 0xFFB3AA))
        ui.addSubview(foe)
        fightBtn = Glass.button("Fight!", symbol: "bolt.fill", style: .prominent, tint: .maRed, fontSize: 22) { [weak self] in self?.start() }
        ui.addSubview(fightBtn)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            back.widthAnchor.constraint(equalToConstant: 44),
            back.heightAnchor.constraint(equalToConstant: 44),
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.centerYAnchor.constraint(equalTo: back.centerYAnchor),

            info.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            info.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            info.bottomAnchor.constraint(equalTo: grid.topAnchor, constant: -10),
            infoStack.leadingAnchor.constraint(equalTo: info.contentView.leadingAnchor, constant: 16),
            infoStack.trailingAnchor.constraint(equalTo: info.contentView.trailingAnchor, constant: -16),
            infoStack.topAnchor.constraint(equalTo: info.contentView.topAnchor, constant: 10),
            infoStack.bottomAnchor.constraint(equalTo: info.contentView.bottomAnchor, constant: -12),

            grid.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            grid.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            grid.bottomAnchor.constraint(equalTo: foe.topAnchor, constant: -10),
            grid.heightAnchor.constraint(equalToConstant: 196),

            foe.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            foe.bottomAnchor.constraint(equalTo: fightBtn.topAnchor, constant: -8),
            foe.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -28),

            fightBtn.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            fightBtn.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            fightBtn.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            fightBtn.heightAnchor.constraint(equalToConstant: 58),
        ])
    }

    private func toggle(_ id: String) {
        focused = id
        showPreview(id)
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
        for (id, badge) in badges {
            if let i = selected.firstIndex(of: id) {
                badge.isHidden = false
                badge.text = "\(i + 1)"
                tiles[id]?.tintColor = .maGold
            } else {
                badge.isHidden = true
                tiles[id]?.tintColor = nil
            }
        }
        fightBtn.isEnabled = selected.count == 3
        fightBtn.alpha = selected.count == 3 ? 1 : 0.5
    }

    private func start() {
        guard selected.count == 3 else { return }
        Save.shared.data.team = selected
        Save.shared.persist()
        let stage = Save.shared.data.stage
        go(BattleScreen(playerIDs: selected, enemyIDs: enemyIDs, enemyLevel: Save.enemyLevel(stage: stage), stage: stage))
    }
}
