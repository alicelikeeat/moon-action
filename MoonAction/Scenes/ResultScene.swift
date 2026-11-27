import SpriteKit
import UIKit

final class ResultScene: GameScene {
    let won: Bool
    let teamIDs: [String]
    let stage: Int
    private var coins = 0
    private var xp = 0
    private var before: [Int] = []

    init(size: CGSize, won: Bool, teamIDs: [String], stage: Int) {
        self.won = won
        self.teamIDs = teamIDs
        self.stage = stage
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let W = size.width
        addChild(BackgroundNode(size: size, groundY: 120, theme: won ? 1 : 3))

        let save = Save.shared
        coins = won ? 120 + stage * 15 : 40
        xp = won ? 140 + stage * 10 : 50
        before = teamIDs.map { save.level($0) }
        save.data.coins += coins
        for id in teamIDs { save.addXP(id, xp) }
        if won {
            save.data.stage += 1
            save.data.wins += 1
        } else {
            save.data.losses += 1
        }
        save.persist()

        for (i, id) in teamIDs.enumerated() {
            let def = Roster.byID(id)
            let f = FighterNode(def: def)
            f.setScale(1.05 * def.bodyScale)
            f.position = CGPoint(x: W / 2 + (CGFloat(i) - 1) * 300, y: 290)
            f.setFacing(i == 2 ? -1 : 1)
            addChild(f)
            if won { f.burstAura(1.0) }
        }
        installUI(in: view)
    }

    override func buildUI() {
        let save = Save.shared
        let header = Glass.panel(radius: 28, tint: (won ? UIColor.maGold : UIColor.systemGray).withAlphaComponent(0.25))
        let title = Glass.label(won ? "Victory" : "Defeat", size: 40, weight: .black,
                                color: won ? .maCoin : UIColor(hex: 0xC4CBE6))
        let sub = Glass.label(won ? "Stage \(stage) cleared · next up: Stage \(stage + 1)" : "Train up and retry Stage \(stage)",
                              size: 15, weight: .semibold, color: UIColor(white: 1, alpha: 0.8))
        let reward = UIStackView()
        reward.spacing = 18
        for (sym, text, tint) in [("moon.stars.fill", "+\(coins)", UIColor.maCoin), ("star.fill", "+\(xp) XP", UIColor(hex: 0x8FE3FF))] {
            let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 16, weight: .bold)))
            icon.tintColor = tint
            let l = Glass.label(text, size: 20, weight: .heavy)
            let r = UIStackView(arrangedSubviews: [icon, l])
            r.spacing = 6
            r.alignment = .center
            reward.addArrangedSubview(r)
        }
        let hs = UIStackView(arrangedSubviews: [title, sub, reward])
        hs.axis = .vertical
        hs.alignment = .center
        hs.spacing = 4
        hs.setCustomSpacing(10, after: sub)
        hs.translatesAutoresizingMaskIntoConstraints = false
        header.contentView.addSubview(hs)
        ui.addSubview(header)

        // Per-fighter level cards
        let cards = UIStackView()
        cards.spacing = 14
        cards.distribution = .fillEqually
        cards.translatesAutoresizingMaskIntoConstraints = false
        for (i, id) in teamIDs.enumerated() {
            let def = Roster.byID(id)
            let info = save.levelInfo(id)
            let card = Glass.panel(radius: 18, tint: def.aura.withAlphaComponent(0.2))
            let name = Glass.label(def.name, size: 14, weight: .heavy)
            let leveled = info.level > before[i]
            let lvl = Glass.label(leveled ? "Lv \(info.level) · LEVEL UP!" : "Lv \(info.level)", size: 13, weight: .bold,
                                  color: leveled ? UIColor(hex: 0x7CFF8A) : def.aura.lighter(0.4))
            let meter = MeterView(color: def.aura)
            meter.heightAnchor.constraint(equalToConstant: 6).isActive = true
            meter.set(CGFloat(info.into) / CGFloat(info.need), immediate: true)
            let st = UIStackView(arrangedSubviews: [name, lvl, meter])
            st.axis = .vertical
            st.spacing = 4
            st.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(st)
            NSLayoutConstraint.activate([
                st.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 12),
                st.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -12),
                st.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 8),
                st.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -10),
            ])
            cards.addArrangedSubview(card)
        }
        ui.addSubview(cards)

        let cont = Glass.button("Continue", symbol: "arrow.right", style: .prominent, tint: .maRed, fontSize: 20) { [weak self] in
            guard let self else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        ui.addSubview(cont)

        NSLayoutConstraint.activate([
            header.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 10),
            hs.leadingAnchor.constraint(equalTo: header.contentView.leadingAnchor, constant: 30),
            hs.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -30),
            hs.topAnchor.constraint(equalTo: header.contentView.topAnchor, constant: 10),
            hs.bottomAnchor.constraint(equalTo: header.contentView.bottomAnchor, constant: -12),

            cards.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            cards.bottomAnchor.constraint(equalTo: cont.topAnchor, constant: -10),
            cards.widthAnchor.constraint(equalToConstant: 480),

            cont.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            cont.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -10),
            cont.widthAnchor.constraint(equalToConstant: 200),
            cont.heightAnchor.constraint(equalToConstant: 52),
        ])
    }
}
