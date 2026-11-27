import UIKit
import SceneKit
import simd

final class HomeScreen: Screen {
    private var arena: Arena!
    private var models: [FighterModel] = []
    private var t: Double = 0
    private var nextMove: Double = 2
    private var moveIndex = 0
    private var helpModal: UIView?

    override func build() {
        arena = Arena(theme: 0)
        scene = arena.scene
        pointOfView = arena.camera
        let save = Save.shared
        let team = save.data.team.filter { save.isUnlocked($0) }
        let spots: [SIMD3<Float>] = [SIMD3(0, 0, 0), SIMD3(-1.7, 0, -1.6), SIMD3(1.8, 0, -1.9)]
        for (i, id) in team.prefix(3).enumerated() {
            let m = FighterModel(def: Roster.byID(id))
            m.root.simdPosition = spots[i]
            m.root.simdEulerAngles = SIMD3(0, i == 0 ? 0.15 : (i == 1 ? 0.35 : -0.35), 0)
            m.setAura(i == 0 ? 2 : 1)
            arena.world.addChildNode(m.root)
            models.append(m)
        }
        buildUI()
    }

    override func update(dt: Double) {
        t += dt
        let a = Float(sin(t * 0.18) * 0.45)
        arena.camera.simdPosition = SIMD3(sin(a) * 5.4, 1.75, cos(a) * 5.4)
        arena.camera.simdLook(at: SIMD3(0, 1.55, 0))
        if t > nextMove, let lead = models.first {
            nextMove = t + 2.6
            moveIndex += 1
            switch moveIndex % 3 {
            case 0: lead.attack(moveIndex)
            case 1: lead.blast()
            default: lead.finisher()
            }
        }
    }

    private func buildUI() {
        let save = Save.shared
        let (record, _) = chip(symbol: "trophy.fill", text: "\(save.data.wins)W · \(save.data.losses)L", tint: .maGold)
        let (coins, _) = chip(symbol: "moon.stars.fill", text: "\(save.data.coins)", tint: .maCoin)
        let sound = Glass.button(symbol: save.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", fontSize: 15)
        sound.addAction(UIAction { [weak sound] _ in
            Save.shared.data.soundOn.toggle()
            Save.shared.persist()
            Sound.shared.enabled = Save.shared.data.soundOn
            sound?.configuration?.image = UIImage(systemName: Save.shared.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold))
        }, for: .touchUpInside)
        for v in [record, coins, sound] as [UIView] { ui.addSubview(v) }

        let titlePanel = Glass.panel(radius: 28)
        let moon = UIImageView(image: UIImage(systemName: "moon.stars.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 26, weight: .bold)))
        moon.tintColor = .maCoin
        let title = Glass.label("MOON ACTION", size: 34, weight: .black)
        let sub = Glass.label("3D CARD BATTLE", size: 13, weight: .heavy, color: UIColor(hex: 0x8FE3FF))
        let ts = UIStackView(arrangedSubviews: [moon, title, sub])
        ts.axis = .vertical
        ts.alignment = .center
        ts.spacing = 2
        ts.translatesAutoresizingMaskIntoConstraints = false
        titlePanel.contentView.addSubview(ts)
        ui.addSubview(titlePanel)

        let battle = Glass.button("Battle", subtitle: "Stage \(save.data.stage)", symbol: "flame.fill",
                                  style: .prominent, tint: .maRed, fontSize: 24) { [weak self] in self?.go(TeamScreen()) }
        let summon = Glass.button("Summon", symbol: "sparkles", fontSize: 17) { [weak self] in self?.go(SummonScreen()) }
        let team = Glass.button("Fighters", symbol: "person.3.fill", fontSize: 17) { [weak self] in self?.go(TeamScreen()) }
        let help = Glass.button("How to Play", symbol: "questionmark.circle.fill", fontSize: 17) { [weak self] in self?.showHelp() }
        let row = UIStackView(arrangedSubviews: [summon, team])
        row.spacing = 10
        row.distribution = .fillEqually
        let menu = UIStackView(arrangedSubviews: [battle, row, help])
        menu.axis = .vertical
        menu.spacing = 10
        menu.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(menu)

        let footer = Glass.label("Original game · all characters are procedurally generated 3D models",
                                 size: 10, weight: .medium, color: UIColor(white: 1, alpha: 0.5))
        ui.addSubview(footer)

        NSLayoutConstraint.activate([
            record.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            record.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            sound.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            sound.centerYAnchor.constraint(equalTo: record.centerYAnchor),
            sound.widthAnchor.constraint(equalToConstant: 40),
            sound.heightAnchor.constraint(equalToConstant: 40),
            coins.trailingAnchor.constraint(equalTo: sound.leadingAnchor, constant: -8),
            coins.centerYAnchor.constraint(equalTo: record.centerYAnchor),

            titlePanel.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            titlePanel.topAnchor.constraint(equalTo: record.bottomAnchor, constant: 18),
            ts.leadingAnchor.constraint(equalTo: titlePanel.contentView.leadingAnchor, constant: 28),
            ts.trailingAnchor.constraint(equalTo: titlePanel.contentView.trailingAnchor, constant: -28),
            ts.topAnchor.constraint(equalTo: titlePanel.contentView.topAnchor, constant: 12),
            ts.bottomAnchor.constraint(equalTo: titlePanel.contentView.bottomAnchor, constant: -12),

            menu.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 24),
            menu.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -24),
            menu.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -12),
            battle.heightAnchor.constraint(equalToConstant: 66),
            summon.heightAnchor.constraint(equalToConstant: 50),
            help.heightAnchor.constraint(equalToConstant: 46),

            footer.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            footer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -6),
            footer.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -24),
        ])
    }

    private func showHelp() {
        helpModal = presentModal(width: 350) { stack in
            stack.addArrangedSubview(Glass.label("How to Play", size: 24, weight: .heavy, color: .maCoin))
            let items: [(String, String)] = [
                ("rectangle.portrait.on.rectangle.portrait.fill", "Tap cards to fight. Each card costs Energy; used cards are replaced from your deck."),
                ("hand.raised.fill", "STRIKE (red) — dash in for melee combos."),
                ("circle.hexagongrid.fill", "BLAST (gold) — fire energy shots. Blasts stop strikers dashing in."),
                ("sparkles", "SPECIAL (blue) — signature art with a cinematic camera."),
                ("cross.fill", "EFFECT cards — heal, barrier, power-up, energy or curse."),
                ("flame.fill", "ULTIMATE — appears when the gold gauge fills."),
                ("moon.fill", "Collect 7 moon shards by chaining cards to unlock ECLIPSE RUSH."),
                ("hand.tap.fill", "Tap arena: basic attack · Swipe ←/→: evade · ↑: dash · ↓: step back · Hold: charge"),
            ]
            for (sym, text) in items {
                let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)))
                icon.tintColor = UIColor(hex: 0x8FE3FF)
                icon.contentMode = .center
                icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
                let l = Glass.label(text, size: 13, weight: .semibold, align: .left)
                l.numberOfLines = 3
                l.adjustsFontSizeToFitWidth = false
                let row = UIStackView(arrangedSubviews: [icon, l])
                row.spacing = 10
                row.alignment = .center
                stack.addArrangedSubview(row)
            }
            let ok = Glass.button("Got it", style: .prominent, tint: .maRed, fontSize: 17) { [weak self] in
                self?.dismissModal(self?.helpModal)
            }
            ok.heightAnchor.constraint(equalToConstant: 46).isActive = true
            stack.addArrangedSubview(ok)
        }
    }
}
