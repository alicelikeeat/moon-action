import SpriteKit
import UIKit

final class SummonScene: GameScene {
    private var coinLabel: UILabel?
    private var summonBtn: UIButton?
    private var backBtn: UIButton?
    private var resultPanel: UIView?
    private let stageNode = SKNode()
    private var busy = false

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        addChild(BackgroundNode(size: size, groundY: 140, theme: 3))
        addChild(stageNode)
        showIdleOrb()
        installUI(in: view)
        refresh()
    }

    override func buildUI() {
        let back = Glass.button(symbol: "chevron.left", fontSize: 17) { [weak self] in
            guard let self, !self.busy else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        backBtn = back
        ui.addSubview(back)

        let header = Glass.panel(radius: 24)
        let title = Glass.label("Summon", size: 22, weight: .heavy, color: UIColor(hex: 0xE3CCFF))
        let rates = Glass.label("★★ 75%  ·  ★★★ 25%  ·  duplicates give \(Save.duplicateXP) XP", size: 13, weight: .semibold,
                                color: UIColor(white: 1, alpha: 0.7))
        let hs = UIStackView(arrangedSubviews: [title, rates])
        hs.axis = .vertical
        hs.spacing = 2
        hs.translatesAutoresizingMaskIntoConstraints = false
        header.contentView.addSubview(hs)
        ui.addSubview(header)

        let (coins, coinText) = chip(symbol: "moon.stars.fill", text: "", tint: .maCoin)
        coinLabel = coinText
        ui.addSubview(coins)

        let summon = Glass.button("Summon ×1", subtitle: "\(Save.summonCost) moon coins", symbol: "sparkles",
                                  style: .prominent, tint: .maPurple, fontSize: 22) { [weak self] in
            self?.summon()
        }
        summonBtn = summon
        ui.addSubview(summon)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            back.widthAnchor.constraint(equalToConstant: 48),
            back.heightAnchor.constraint(equalToConstant: 48),
            header.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            hs.leadingAnchor.constraint(equalTo: header.contentView.leadingAnchor, constant: 24),
            hs.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -24),
            hs.topAnchor.constraint(equalTo: header.contentView.topAnchor, constant: 8),
            hs.bottomAnchor.constraint(equalTo: header.contentView.bottomAnchor, constant: -8),
            coins.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            coins.centerYAnchor.constraint(equalTo: back.centerYAnchor),
            summon.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            summon.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -14),
            summon.widthAnchor.constraint(equalToConstant: 260),
            summon.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    private func refresh() {
        coinLabel?.text = "\(Save.shared.data.coins)"
        let ok = Save.shared.data.coins >= Save.summonCost && !busy
        summonBtn?.isEnabled = ok
        summonBtn?.alpha = ok ? 1 : 0.5
        backBtn?.alpha = busy ? 0.5 : 1
    }

    private func showIdleOrb() {
        stageNode.removeAllChildren()
        let orb = SKShapeNode(circleOfRadius: 90)
        orb.fillColor = UIColor(hex: 0x3A2D7A)
        orb.strokeColor = UIColor(hex: 0xD9B8FF)
        orb.lineWidth = 5
        orb.glowWidth = 10
        orb.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        let moon = SKShapeNode(path: FighterNode.crescentPath(radius: 46))
        moon.fillColor = UIColor(hex: 0xFFD45A)
        moon.strokeColor = .clear
        orb.addChild(moon)
        stageNode.addChild(orb)
        orb.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.8), .scale(to: 1, duration: 0.8)])))
    }

    private func roll() -> FighterDef {
        let rarity = chance(0.25) ? 3 : 2
        return Roster.all.filter { $0.rarity == rarity }.randomElement() ?? Roster.kai
    }

    private func summon() {
        let save = Save.shared
        guard !busy, save.data.coins >= Save.summonCost else { return }
        busy = true
        save.data.coins -= Save.summonCost
        let def = roll()
        let isNew = !save.isUnlocked(def.id)
        if isNew {
            save.data.unlocked.append(def.id)
        } else {
            save.addXP(def.id, Save.duplicateXP)
        }
        save.persist()
        refresh()
        resultPanel?.removeFromSuperview()
        resultPanel = nil

        stageNode.removeAllChildren()
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        let orb = SKShapeNode(circleOfRadius: 70)
        orb.fillColor = .white
        orb.strokeColor = def.rarity == 3 ? UIColor(hex: 0xFFD45A) : UIColor(hex: 0x8FE3FF)
        orb.lineWidth = 8
        orb.glowWidth = 14
        orb.position = center
        stageNode.addChild(orb)
        Sound.play(.charge)
        orb.run(.sequence([
            .repeat(.sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 0.9, duration: 0.12)]), count: 4),
            .run { [weak self] in self?.reveal(def, isNew: isNew, at: center) },
            .removeFromParent(),
        ]))
    }

    private func reveal(_ def: FighterDef, isNew: Bool, at center: CGPoint) {
        Sound.play(def.rarity == 3 ? .ultimate : .explode)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = def.aura
        flash.strokeColor = .clear
        flash.alpha = 0.8
        stageNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))

        for i in 0..<12 {
            let ray = SKShapeNode(rect: CGRect(x: 0, y: -6, width: 600, height: 12))
            ray.fillColor = def.aura.withAlphaComponent(0.35)
            ray.strokeColor = .clear
            ray.zRotation = CGFloat(i) / 12 * 2 * .pi
            ray.position = CGPoint(x: size.width * 0.33, y: center.y)
            ray.zPosition = -1
            stageNode.addChild(ray)
            ray.run(.repeatForever(.rotate(byAngle: 0.6, duration: 2)))
        }
        let f = FighterNode(def: def)
        f.setScale(1.6 * def.bodyScale)
        f.position = CGPoint(x: size.width * 0.33, y: 150)
        stageNode.addChild(f)
        f.burstAura(1.2)
        f.enterEffect()

        // Native glass result card
        let panel = Glass.panel(radius: 28, tint: def.aura.withAlphaComponent(0.3))
        let stars = Glass.label(String(repeating: "★", count: def.rarity), size: 26, weight: .heavy,
                                color: def.rarity == 3 ? .maCoin : UIColor(hex: 0x8FE3FF), align: .left)
        let name = Glass.label(def.name, size: 32, weight: .heavy, align: .left)
        let title = Glass.label(def.title, size: 17, weight: .bold, color: def.aura.lighter(0.4), align: .left)
        let result = Glass.label(isNew ? "New fighter unlocked!" : "+\(Save.duplicateXP) XP", size: 19, weight: .heavy,
                                 color: isNew ? UIColor(hex: 0x7CFF8A) : .maCoin, align: .left)
        let sp = Glass.label("Special · \(def.specialName)", size: 14, weight: .semibold, color: UIColor(white: 1, alpha: 0.8), align: .left)
        let ul = Glass.label("Ultimate · \(def.ultimateName)", size: 14, weight: .semibold, color: UIColor(white: 1, alpha: 0.8), align: .left)
        let st = UIStackView(arrangedSubviews: [stars, name, title, result, sp, ul])
        st.axis = .vertical
        st.spacing = 4
        st.setCustomSpacing(12, after: title)
        st.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(st)
        ui.addSubview(panel)
        NSLayoutConstraint.activate([
            NSLayoutConstraint(item: panel, attribute: .centerX, relatedBy: .equal, toItem: ui, attribute: .centerX, multiplier: 1.4, constant: 0),
            panel.centerYAnchor.constraint(equalTo: ui.centerYAnchor, constant: -10),
            panel.widthAnchor.constraint(equalToConstant: 320),
            st.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 22),
            st.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -22),
            st.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 18),
            st.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -18),
        ])
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 40, y: 0)
        UIView.animate(withDuration: 0.4, delay: 0.1, usingSpringWithDamping: 0.75, initialSpringVelocity: 0) {
            panel.alpha = 1
            panel.transform = .identity
        }
        resultPanel = panel
        busy = false
        refresh()
    }
}
