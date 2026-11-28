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
    private var cheatModal: UIView?

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

    override func didAppear() {
        if Demo.mode == "cheats" { showCheats() }
    }

    override func update(dt: Double) {
        t += dt
        let a = Float(sin(t * 0.18) * 0.45)
        arena.camera.simdPosition = SIMD3(sin(a) * 5.6, 1.7, cos(a) * 5.6)
        arena.camera.simdLook(at: SIMD3(0, 1.45, 0), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
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
        let (record, _) = chip(symbol: "trophy.fill", text: L10n.f("home.record", save.data.wins, save.data.losses), tint: Theme.accent)
        let (coins, _) = chip(symbol: "moon.stars.fill", text: "\(save.data.coins)", tint: Theme.accent)
        let lang = Glass.button(L("lang"), style: .secondary, fontSize: 12) { [weak self] in
            L10n.toggle()
            self?.go(HomeScreen())
        }
        let sound = Glass.button(symbol: save.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", style: .secondary, fontSize: 13)
        sound.addAction(UIAction { [weak sound] _ in
            Save.shared.data.soundOn.toggle()
            Save.shared.persist()
            Sound.shared.enabled = Save.shared.data.soundOn
            sound?.configuration?.image = UIImage(systemName: Save.shared.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold))
        }, for: .touchUpInside)
        for v in [record, coins, lang, sound] as [UIView] { ui.addSubview(v) }

        // Title: quiet, wide-tracked typography
        let title = UILabel()
        title.attributedText = NSAttributedString(string: "MOON ACTION", attributes: [
            .font: Glass.font(30, .bold), .foregroundColor: UIColor.white, .kern: 9,
        ])
        title.textAlignment = .center
        title.layer.shadowColor = UIColor.black.cgColor
        title.layer.shadowOpacity = 0.35
        title.layer.shadowRadius = 12
        title.translatesAutoresizingMaskIntoConstraints = false
        let rule = UIView()
        rule.backgroundColor = Theme.accent
        rule.translatesAutoresizingMaskIntoConstraints = false
        let sub = Glass.caption(L("app.subtitle"), size: 11, color: Theme.text2)
        for v in [title, rule, sub] as [UIView] { ui.addSubview(v) }

        let battle = Glass.button(L("home.battle"), subtitle: L10n.f("home.stage", save.data.stage), symbol: "play.fill",
                                  style: .primary, fontSize: 19) { [weak self] in self?.go(CoreBattleScreen()) }
        let fighters = Glass.button(L("home.fighters"), symbol: "person.2.fill", style: .secondary, fontSize: 15) { [weak self] in
            self?.go(TeamScreen())
        }
        let summon = Glass.button(L("home.summon"), symbol: "sparkles", style: .secondary, fontSize: 15) { [weak self] in
            self?.go(SummonScreen())
        }
        let row = UIStackView(arrangedSubviews: [fighters, summon])
        row.spacing = 10
        row.distribution = .fillEqually
        let viewer = Glass.button(L("home.viewer"), symbol: "cube.transparent", style: .secondary, fontSize: 15) { [weak self] in
            self?.go(ViewerScreen())
        }
        let cheats = Glass.button(L("home.cheats"), symbol: "wand.and.stars", style: Cheats.anyOn ? .secondary : .regular,
                                  tint: Cheats.anyOn ? Theme.ultimate.withAlphaComponent(0.55) : nil, fontSize: 13) { [weak self] in
            self?.showCheats()
        }
        let creator = Glass.button(L("home.creator"), symbol: "paintpalette.fill", style: .secondary, fontSize: 15) { [weak self] in
            self?.go(CreatorScreen())
        }
        let row2 = UIStackView(arrangedSubviews: [viewer, creator])
        row2.spacing = 10
        row2.distribution = .fillEqually
        let help = Glass.button(L("home.help"), symbol: "questionmark.circle", style: .regular, fontSize: 13) { [weak self] in
            self?.showHelp()
        }
        let row3 = UIStackView(arrangedSubviews: [cheats, help])
        row3.spacing = 10
        row3.distribution = .fillEqually
        let menu = UIStackView(arrangedSubviews: [battle, row, row2, row3])
        menu.axis = .vertical
        menu.spacing = 10
        menu.setCustomSpacing(16, after: row2)
        menu.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(menu)

        let footer = Glass.label(L("home.footer") + "  ·  " + AppInfo.display, size: 9, weight: .regular, color: Theme.text3)
        ui.addSubview(footer)

        NSLayoutConstraint.activate([
            record.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            record.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            sound.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            sound.centerYAnchor.constraint(equalTo: record.centerYAnchor),
            sound.widthAnchor.constraint(equalToConstant: 36),
            sound.heightAnchor.constraint(equalToConstant: 36),
            lang.trailingAnchor.constraint(equalTo: sound.leadingAnchor, constant: -8),
            lang.centerYAnchor.constraint(equalTo: record.centerYAnchor),
            lang.heightAnchor.constraint(equalToConstant: 36),
            coins.leadingAnchor.constraint(equalTo: record.trailingAnchor, constant: 8),
            coins.centerYAnchor.constraint(equalTo: record.centerYAnchor),

            title.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            title.topAnchor.constraint(equalTo: record.bottomAnchor, constant: 30),
            rule.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            rule.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 10),
            rule.widthAnchor.constraint(equalToConstant: 28),
            rule.heightAnchor.constraint(equalToConstant: 2),
            sub.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            sub.topAnchor.constraint(equalTo: rule.bottomAnchor, constant: 10),

            menu.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 28),
            menu.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -28),
            menu.bottomAnchor.constraint(equalTo: footer.topAnchor, constant: -14),
            battle.heightAnchor.constraint(equalToConstant: 60),
            fighters.heightAnchor.constraint(equalToConstant: 48),
            viewer.heightAnchor.constraint(equalToConstant: 48),
            cheats.heightAnchor.constraint(equalToConstant: 38),
            help.heightAnchor.constraint(equalToConstant: 38),

            footer.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            footer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -6),
            footer.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),
        ])
    }

    private func showHelp() {
        helpModal = presentModal(width: 350) { stack in
            stack.addArrangedSubview(Glass.label(L("help.title"), size: 19, weight: .semibold))
            let items: [(String, String)] = [
                ("rectangle.portrait.on.rectangle.portrait", "help.1"), ("figure.boxing", "help.2"),
                ("dot.radiowaves.right", "help.3"), ("sparkles", "help.4"), ("cross", "help.5"), ("flame", "help.6"),
                ("link", "help.7"), ("wind", "help.8"), ("hand.tap", "help.9"), ("moon", "help.10"),
                ("circle.hexagongrid.fill", "help.11"), ("sparkles", "help.12"), ("lock.fill", "help.13"), ("burst", "help.14"),
            ]
            for (sym, key) in items {
                let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .medium))
                                        ?? UIImage(systemName: "circle"))
                icon.tintColor = Theme.accent
                icon.contentMode = .center
                icon.widthAnchor.constraint(equalToConstant: 22).isActive = true
                let l = Glass.label(L(key), size: 12, weight: .regular, color: Theme.text, align: .left)
                l.numberOfLines = 3
                l.adjustsFontSizeToFitWidth = false
                let row = UIStackView(arrangedSubviews: [icon, l])
                row.spacing = 10
                row.alignment = .center
                stack.addArrangedSubview(row)
            }
            let ok = Glass.button(L("ok"), style: .primary, fontSize: 15) { [weak self] in
                self?.dismissModal(self?.helpModal)
            }
            ok.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(ok)
        }
    }

    private func showCheats() {
        cheatModal = presentModal(width: 350) { stack in
            stack.addArrangedSubview(Glass.label(L("cheat.title"), size: 19, weight: .semibold))
            let note = Glass.label(L("cheat.note"), size: 11, weight: .regular, color: Theme.text2)
            note.numberOfLines = 2
            stack.addArrangedSubview(note)
            for key in Cheats.Key.allCases {
                let icon = UIImageView(image: UIImage(systemName: key.symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .medium)))
                icon.tintColor = Theme.ultimate
                icon.contentMode = .center
                icon.widthAnchor.constraint(equalToConstant: 24).isActive = true
                let t = Glass.label(key.title, size: 14, weight: .semibold, align: .left)
                let d = Glass.label(key.detail, size: 10, weight: .regular, color: Theme.text2, align: .left)
                let text = UIStackView(arrangedSubviews: [t, d])
                text.axis = .vertical
                text.spacing = 1
                let sw = UISwitch()
                sw.isOn = Cheats.isOn(key)
                sw.onTintColor = Theme.ultimate
                sw.accessibilityLabel = key.title
                sw.addAction(UIAction { [weak sw] _ in
                    Cheats.set(key, sw?.isOn ?? false)
                    Haptics.select()
                }, for: .valueChanged)
                let row = UIStackView(arrangedSubviews: [icon, text, sw])
                row.spacing = 10
                row.alignment = .center
                stack.addArrangedSubview(row)
            }
            let actions: [(String, String, () -> Void)] = [
                ("person.3.fill", "cheat.unlock", { Cheats.unlockAll() }),
                ("moon.stars.fill", "cheat.coins", { Cheats.addCoins() }),
                ("arrow.up.circle.fill", "cheat.maxlv", { Cheats.maxLevels() }),
            ]
            let grid = UIStackView()
            grid.axis = .vertical
            grid.spacing = 8
            for (sym, key, fn) in actions {
                var b: UIButton!
                b = Glass.button(L(key), symbol: sym, style: .secondary, fontSize: 13) {
                    fn()
                    Glass.setTitle(b, L(key) + " · " + L("cheat.applied"))
                    Haptics.success()
                }
                b.heightAnchor.constraint(equalToConstant: 38).isActive = true
                grid.addArrangedSubview(b)
            }
            stack.setCustomSpacing(16, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(grid)
            let done = Glass.button(L("cheat.done"), style: .primary, fontSize: 15) { [weak self] in
                self?.go(HomeScreen())
            }
            done.heightAnchor.constraint(equalToConstant: 44).isActive = true
            stack.setCustomSpacing(16, after: grid)
            stack.addArrangedSubview(done)
        }
    }
}
