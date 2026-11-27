import UIKit
import SceneKit
import simd

final class ResultScreen: Screen {
    let won: Bool
    let teamIDs: [String]
    let stage: Int
    private var arena: Arena!
    private var coins = 0
    private var xp = 0
    private var before: [Int] = []
    private var t: Double = 0

    init(won: Bool, teamIDs: [String], stage: Int) {
        self.won = won
        self.teamIDs = teamIDs
        self.stage = stage
    }

    override func build() {
        arena = Arena(theme: won ? 1 : 3)
        scene = arena.scene
        pointOfView = arena.camera
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

        let spots: [SIMD3<Float>] = [SIMD3(0, 0, 0.4), SIMD3(-1.5, 0, -0.8), SIMD3(1.5, 0, -0.8)]
        for (i, id) in teamIDs.enumerated() {
            let m = FighterModel(def: Roster.byID(id))
            m.root.simdPosition = spots[i % 3]
            m.root.simdEulerAngles = SIMD3(0, i == 1 ? 0.3 : (i == 2 ? -0.3 : 0), 0)
            if won {
                m.victory()
            } else {
                m.apply(FighterModel.chargePose, duration: 0)
                m.setAura(0)
            }
            arena.world.addChildNode(m.root)
        }
        buildUI()
    }

    override func update(dt: Double) {
        t += dt
        let a = Float(sin(t * 0.25) * 0.3)
        arena.camera.simdPosition = SIMD3(sin(a) * 6.2, 1.9, cos(a) * 6.2)
        arena.camera.simdLook(at: SIMD3(0, 0.95, 0))
    }

    private func buildUI() {
        let save = Save.shared
        let head = Glass.panel(radius: 28, tint: (won ? UIColor.maGold : UIColor.gray).withAlphaComponent(0.25))
        let title = Glass.label(won ? "Victory" : "Defeat", size: 40, weight: .black, color: won ? .maCoin : UIColor(hex: 0xC4CBE6))
        let sub = Glass.label(won ? "Stage \(stage) cleared · next: Stage \(stage + 1)" : "Train up and retry Stage \(stage)",
                              size: 14, weight: .semibold, color: UIColor(white: 1, alpha: 0.8))
        let reward = UIStackView()
        reward.spacing = 18
        for (sym, text, tint) in [("moon.stars.fill", "+\(coins)", UIColor.maCoin), ("star.fill", "+\(xp) XP", UIColor(hex: 0x8FE3FF))] {
            let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 15, weight: .bold)))
            icon.tintColor = tint
            let l = Glass.label(text, size: 19, weight: .heavy)
            let r = UIStackView(arrangedSubviews: [icon, l])
            r.spacing = 6
            r.alignment = .center
            reward.addArrangedSubview(r)
        }
        let hs = UIStackView(arrangedSubviews: [title, sub, reward])
        hs.axis = .vertical
        hs.alignment = .center
        hs.spacing = 4
        hs.translatesAutoresizingMaskIntoConstraints = false
        head.contentView.addSubview(hs)
        ui.addSubview(head)

        let cards = UIStackView()
        cards.spacing = 8
        cards.distribution = .fillEqually
        cards.translatesAutoresizingMaskIntoConstraints = false
        for (i, id) in teamIDs.enumerated() {
            let def = Roster.byID(id)
            let info = save.levelInfo(id)
            let card = Glass.panel(radius: 16, tint: def.look.aura.withAlphaComponent(0.2))
            let name = Glass.label(def.name.components(separatedBy: " ").first ?? def.name, size: 13, weight: .heavy)
            let leveled = info.level > before[i]
            let lvl = Glass.label(leveled ? "Lv \(info.level) ▲" : "Lv \(info.level)", size: 12, weight: .bold,
                                  color: leveled ? UIColor(hex: 0x7CFF8A) : def.look.aura.lighter(0.4))
            let meter = MeterView(color: def.look.aura)
            meter.heightAnchor.constraint(equalToConstant: 5).isActive = true
            meter.set(CGFloat(info.into) / CGFloat(info.need), immediate: true)
            let st = UIStackView(arrangedSubviews: [name, lvl, meter])
            st.axis = .vertical
            st.spacing = 3
            st.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(st)
            NSLayoutConstraint.activate([
                st.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 10),
                st.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -10),
                st.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 8),
                st.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -9),
            ])
            cards.addArrangedSubview(card)
        }
        ui.addSubview(cards)
        let cont = Glass.button("Continue", symbol: "arrow.right", style: .prominent, tint: .maRed, fontSize: 20) { [weak self] in
            self?.go(HomeScreen())
        }
        ui.addSubview(cont)
        NSLayoutConstraint.activate([
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            hs.leadingAnchor.constraint(equalTo: head.contentView.leadingAnchor, constant: 26),
            hs.trailingAnchor.constraint(equalTo: head.contentView.trailingAnchor, constant: -26),
            hs.topAnchor.constraint(equalTo: head.contentView.topAnchor, constant: 10),
            hs.bottomAnchor.constraint(equalTo: head.contentView.bottomAnchor, constant: -12),
            cards.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            cards.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            cards.bottomAnchor.constraint(equalTo: cont.topAnchor, constant: -12),
            cont.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 30),
            cont.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -30),
            cont.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -10),
            cont.heightAnchor.constraint(equalToConstant: 56),
        ])
    }
}
