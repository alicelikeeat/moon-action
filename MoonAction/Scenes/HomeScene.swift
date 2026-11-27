import SpriteKit
import UIKit

final class HomeScene: GameScene {
    private var coinLabel: UILabel?
    private var helpModal: UIView?

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let save = Save.shared
        Sound.shared.enabled = save.data.soundOn
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 170, theme: 0))

        // Logo (SpriteKit art)
        let logo = SKNode()
        logo.position = CGPoint(x: W * 0.32, y: H * 0.72)
        addChild(logo)
        let crescent = SKShapeNode(path: FighterNode.crescentPath(radius: 62))
        crescent.fillColor = UIColor(hex: 0xFFD45A)
        crescent.strokeColor = UIColor(hex: 0xFFF2C2)
        crescent.lineWidth = 4
        crescent.glowWidth = 6
        crescent.position = CGPoint(x: -230, y: 30)
        crescent.zRotation = 0.4
        logo.addChild(crescent)
        let title = ShadowLabel("MOON ACTION", size: 88)
        title.position = CGPoint(x: 10, y: 40)
        logo.addChild(title)
        let sub = ShadowLabel("ARENA CARD FIGHTER", size: 26, color: UIColor(hex: 0x8FE3FF), font: Fonts.bold)
        sub.position = CGPoint(x: 10, y: -22)
        logo.addChild(sub)
        logo.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 1.2), .moveBy(x: 0, y: -6, duration: 1.2)])))

        let team = save.data.team.filter { save.isUnlocked($0) }
        for (i, id) in team.prefix(2).enumerated() {
            let f = FighterNode(def: Roster.byID(id))
            f.setScale(1.5 * f.def.bodyScale)
            f.position = CGPoint(x: W * (0.70 + CGFloat(i) * 0.16), y: 150)
            f.setFacing(i == 0 ? 1 : -1)
            f.zPosition = CGFloat(5 - i)
            addChild(f)
            f.burstAura(0.8)
        }
        installUI(in: view)
    }

    override func buildUI() {
        let save = Save.shared

        let (record, _) = chip(symbol: "trophy.fill", text: "\(save.data.wins) W  ·  \(save.data.losses) L", tint: .maGold)
        ui.addSubview(record)
        let (coins, coinText) = chip(symbol: "moon.stars.fill", text: "\(save.data.coins)", tint: .maCoin)
        coinLabel = coinText
        ui.addSubview(coins)

        let sound = Glass.button(symbol: save.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill", fontSize: 16)
        sound.addAction(UIAction { [weak sound] _ in
            Save.shared.data.soundOn.toggle()
            Save.shared.persist()
            Sound.shared.enabled = Save.shared.data.soundOn
            sound?.configuration?.image = UIImage(systemName: Save.shared.data.soundOn ? "speaker.wave.2.fill" : "speaker.slash.fill",
                                                  withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold))
            Sound.play(.ui)
        }, for: .touchUpInside)
        ui.addSubview(sound)

        let battle = Glass.button("Battle", subtitle: "Stage \(save.data.stage)", symbol: "flame.fill",
                                  style: .prominent, tint: .maRed, fontSize: 24) { [weak self] in
            guard let self else { return }
            self.transition(to: TeamSelectScene(size: self.size))
        }
        let summon = Glass.button("Summon", symbol: "sparkles", style: .regular, fontSize: 18) { [weak self] in
            guard let self else { return }
            self.transition(to: SummonScene(size: self.size))
        }
        let help = Glass.button("How to Play", symbol: "questionmark.circle.fill", style: .regular, fontSize: 18) { [weak self] in
            self?.showHelp()
        }
        let row = UIStackView(arrangedSubviews: [summon, help])
        row.spacing = 12
        row.distribution = .fillEqually
        let menu = UIStackView(arrangedSubviews: [battle, row])
        menu.axis = .vertical
        menu.spacing = 12
        menu.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(menu)

        let footer = Glass.label("An original game · all characters and art are procedurally drawn originals",
                                 size: 11, weight: .medium, color: UIColor(white: 1, alpha: 0.5))
        ui.addSubview(footer)

        NSLayoutConstraint.activate([
            record.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            record.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            sound.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            sound.centerYAnchor.constraint(equalTo: record.centerYAnchor),
            sound.widthAnchor.constraint(equalToConstant: 44),
            sound.heightAnchor.constraint(equalToConstant: 44),
            coins.trailingAnchor.constraint(equalTo: sound.leadingAnchor, constant: -10),
            coins.centerYAnchor.constraint(equalTo: record.centerYAnchor),

            NSLayoutConstraint(item: menu, attribute: .centerX, relatedBy: .equal, toItem: ui, attribute: .centerX, multiplier: 0.64, constant: 0),
            menu.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -48),
            menu.widthAnchor.constraint(equalToConstant: 330),
            battle.heightAnchor.constraint(equalToConstant: 64),
            summon.heightAnchor.constraint(equalToConstant: 48),

            footer.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            footer.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            footer.widthAnchor.constraint(lessThanOrEqualTo: safe.widthAnchor, constant: -32),
        ])
    }

    private func showHelp() {
        helpModal = presentModal(width: 560) { stack in
            let title = Glass.label("How to Play", size: 26, weight: .heavy, color: .maCoin)
            stack.addArrangedSubview(title)
            let items: [(String, String)] = [
                ("person.3.fill", "3 vs 3 — knock out the whole enemy team before time runs out."),
                ("hand.raised.fill", "Red STRIKE cards dash in for combos. Blue BLAST cards fire projectiles."),
                ("bolt.fill", "Cards cost Energy. Hold CHARGE to refill faster."),
                ("arrow.triangle.2.circlepath", "A blast stops a strike dashing in; up close, strikes win."),
                ("wind", "Swipe the arena or tap EVADE to dodge — it also breaks enemy combos."),
                ("sparkles", "SPECIAL is your signature move. ULTIMATE unlocks at 100%."),
                ("arrow.left.arrow.right", "Tap a teammate portrait to tag them in."),
            ]
            for (sym, text) in items {
                let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
                icon.tintColor = UIColor(hex: 0x8FE3FF)
                icon.contentMode = .center
                icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
                let l = Glass.label(text, size: 14, weight: .semibold, align: .left)
                l.numberOfLines = 2
                let row = UIStackView(arrangedSubviews: [icon, l])
                row.spacing = 10
                row.alignment = .center
                stack.addArrangedSubview(row)
            }
            let ok = Glass.button("Got it", style: .prominent, tint: .maRed, fontSize: 18) { [weak self] in
                self?.dismissModal(self?.helpModal)
            }
            ok.heightAnchor.constraint(equalToConstant: 48).isActive = true
            stack.setCustomSpacing(18, after: stack.arrangedSubviews.last!)
            stack.addArrangedSubview(ok)
        }
    }
}
