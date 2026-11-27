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
        let head = Glass.panel(radius: 24)
        let title = UILabel()
        title.attributedText = NSAttributedString(string: L(won ? "result.victory" : "result.defeat").uppercased(), attributes: [
            .font: Glass.font(28, .bold), .foregroundColor: won ? Theme.accent : Theme.text2, .kern: L10n.isZH ? 6 : 9,
        ])
        let sub = Glass.label(won ? L10n.f("result.cleared", stage, stage + 1) : L10n.f("result.retry", stage),
                              size: 12, weight: .medium, color: Theme.text2)
        let reward = UIStackView()
        reward.spacing = 18
        for (sym, text) in [("moon.stars.fill", "+\(coins)"), ("star.fill", "+\(xp) XP")] {
            let icon = UIImageView(image: UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
            icon.tintColor = Theme.accent
            let l = Glass.label(text, size: 15, weight: .semibold, mono: true)
            let r = UIStackView(arrangedSubviews: [icon, l])
            r.spacing = 6
            r.alignment = .center
            reward.addArrangedSubview(r)
        }
        let hs = UIStackView(arrangedSubviews: [title, sub, reward])
        hs.axis = .vertical
        hs.alignment = .center
        hs.spacing = 6
        hs.setCustomSpacing(12, after: sub)
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
            let card = Glass.panel(radius: 16)
            let name = Glass.label(def.shortName, size: 12, weight: .semibold)
            let leveled = info.level > before[i]
            let lvl = Glass.label(leveled ? "Lv \(info.level) ↑" : "Lv \(info.level)", size: 11, weight: .medium,
                                  color: leveled ? Theme.hp : Theme.text2, mono: true)
            let meter = MeterView(color: Theme.accent)
            meter.heightAnchor.constraint(equalToConstant: 3).isActive = true
            meter.set(CGFloat(info.into) / CGFloat(info.need), immediate: true)
            let st = UIStackView(arrangedSubviews: [name, lvl, meter])
            st.axis = .vertical
            st.spacing = 4
            st.translatesAutoresizingMaskIntoConstraints = false
            card.contentView.addSubview(st)
            NSLayoutConstraint.activate([
                st.leadingAnchor.constraint(equalTo: card.contentView.leadingAnchor, constant: 12),
                st.trailingAnchor.constraint(equalTo: card.contentView.trailingAnchor, constant: -12),
                st.topAnchor.constraint(equalTo: card.contentView.topAnchor, constant: 10),
                st.bottomAnchor.constraint(equalTo: card.contentView.bottomAnchor, constant: -11),
            ])
            cards.addArrangedSubview(card)
        }
        ui.addSubview(cards)
        let cont = Glass.button(L("result.continue"), symbol: "arrow.right", style: .primary, fontSize: 17) { [weak self] in
            self?.go(HomeScreen())
        }
        ui.addSubview(cont)
        NSLayoutConstraint.activate([
            head.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            head.topAnchor.constraint(equalTo: safe.topAnchor, constant: 14),
            hs.leadingAnchor.constraint(equalTo: head.contentView.leadingAnchor, constant: 28),
            hs.trailingAnchor.constraint(equalTo: head.contentView.trailingAnchor, constant: -28),
            hs.topAnchor.constraint(equalTo: head.contentView.topAnchor, constant: 16),
            hs.bottomAnchor.constraint(equalTo: head.contentView.bottomAnchor, constant: -16),
            cards.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            cards.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            cards.bottomAnchor.constraint(equalTo: cont.topAnchor, constant: -12),
            cont.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 28),
            cont.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -28),
            cont.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -10),
            cont.heightAnchor.constraint(equalToConstant: 54),
        ])
    }
}
