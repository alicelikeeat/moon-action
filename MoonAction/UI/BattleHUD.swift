import UIKit
import SpriteKit

/// Native Liquid Glass battle HUD, layered over the SpriteKit arena.
@MainActor
final class BattleHUD {
    private weak var scene: BattleScene?
    private let root: PassthroughView

    private let pName = Glass.label("", size: 15, weight: .heavy, align: .left)
    private let eName = Glass.label("", size: 15, weight: .heavy, align: .right)
    private let pHP = MeterView(color: UIColor(hex: 0x58E37A))
    private let eHP = MeterView(color: UIColor(hex: 0xE5484D), fromRight: true)
    private let pSoul = MeterView(color: .maGold)
    private let eSoul = MeterView(color: .maGold, fromRight: true)
    private let timer = Glass.label("150", size: 24, weight: .heavy)
    private var pPortraits: [PortraitView] = []
    private var ePortraits: [PortraitView] = []

    private var cards: [UIButton] = []
    private var cardKeys: [String] = ["", "", "", ""]
    private let energyMeter = MeterView(color: UIColor(hex: 0x6FE3FF))
    private let energyLabel = Glass.label("0", size: 14, weight: .heavy, align: .left)
    private var special: UIButton!
    private var ultimate: UIButton!
    private let ultRing = RingView(color: .maCoin)
    private var charge: UIButton!
    private var evade: UIButton!
    private var pips: [UIView] = []
    private var lastUlt = -1
    private var lastSpecial = ""

    init(scene: BattleScene, root: PassthroughView) {
        self.scene = scene
        self.root = root
        build()
    }

    private var safe: UILayoutGuide { root.safeAreaLayoutGuide }

    // MARK: Build

    private func build() {
        guard let scene, let view = scene.view else { return }
        let player = scene.player!
        let enemy = scene.enemy!

        // Status panels (top corners)
        let pPanel = statusPanel(name: pName, hp: pHP, soul: pSoul, alignRight: false)
        let ePanel = statusPanel(name: eName, hp: eHP, soul: eSoul, alignRight: true)
        root.addSubview(pPanel)
        root.addSubview(ePanel)

        let pRow = UIStackView()
        pRow.spacing = 8
        pRow.translatesAutoresizingMaskIntoConstraints = false
        for (i, c) in player.team.enumerated() {
            let p = PortraitView(image: BattleHUD.portraitImage(c.def, in: view), tint: c.def.aura, interactive: true)
            p.onTap = { [weak self] in
                guard let s = self?.scene else { return }
                s.swap(s.player, to: i, forced: false)
            }
            pRow.addArrangedSubview(p)
            pPortraits.append(p)
        }
        let eRow = UIStackView()
        eRow.spacing = 8
        eRow.translatesAutoresizingMaskIntoConstraints = false
        for c in enemy.team {
            let p = PortraitView(image: BattleHUD.portraitImage(c.def, in: view), tint: c.def.aura, interactive: false)
            eRow.addArrangedSubview(p)
            ePortraits.append(p)
        }
        root.addSubview(pRow)
        root.addSubview(eRow)

        // Timer + pause (top center)
        let timerPanel = Glass.panel(radius: 22)
        timerPanel.contentView.addSubview(timer)
        root.addSubview(timerPanel)
        let pause = Glass.button(symbol: "pause.fill", fontSize: 14) { [weak self] in self?.scene?.setPaused(true) }
        root.addSubview(pause)

        // Cards (bottom right)
        let cardRow = UIStackView()
        cardRow.spacing = 8
        cardRow.distribution = .fillEqually
        cardRow.translatesAutoresizingMaskIntoConstraints = false
        for i in 0..<4 {
            let b = Glass.button("", subtitle: "", style: .prominent, tint: .maRed, fontSize: 13)
            b.configuration?.imagePlacement = .top
            b.configuration?.imagePadding = 3
            b.configuration?.cornerStyle = .large
            b.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4)
            b.addAction(UIAction { [weak self] _ in
                guard let s = self?.scene else { return }
                s.useCard(s.player, i)
            }, for: .touchDown)
            cardRow.addArrangedSubview(b)
            cards.append(b)
        }
        root.addSubview(cardRow)

        let energyPanel = Glass.panel(radius: 15)
        let bolt = UIImageView(image: UIImage(systemName: "bolt.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
        bolt.tintColor = UIColor(hex: 0x6FE3FF)
        bolt.translatesAutoresizingMaskIntoConstraints = false
        energyPanel.contentView.addSubview(bolt)
        energyPanel.contentView.addSubview(energyLabel)
        energyPanel.contentView.addSubview(energyMeter)
        root.addSubview(energyPanel)

        special = circle(symbol: "sparkles", title: "40", style: .prominent, tint: .maPurple, size: 60)
        special.addAction(UIAction { [weak self] _ in
            guard let s = self?.scene else { return }
            s.doSpecial(s.player)
        }, for: .touchDown)
        root.addSubview(special)

        ultimate = circle(symbol: "flame.fill", title: "0%", style: .prominent, tint: UIColor(hex: 0x8A5A10), size: 60)
        ultimate.addAction(UIAction { [weak self] _ in
            guard let s = self?.scene else { return }
            s.doUltimate(s.player)
        }, for: .touchDown)
        root.addSubview(ultimate)
        ultRing.lineWidth = 4
        root.addSubview(ultRing)

        charge = circle(symbol: "bolt.circle.fill", title: "Charge", style: .regular, tint: nil, size: 56)
        Glass.hold(charge, down: { [weak self] in
            self?.scene?.player.charging = true
            Sound.play(.charge)
        }, up: { [weak self] in self?.scene?.player.charging = false })
        root.addSubview(charge)

        // Movement + evade (bottom left)
        let left = circle(symbol: "chevron.left", title: nil, style: .regular, tint: nil, size: 58)
        let right = circle(symbol: "chevron.right", title: nil, style: .regular, tint: nil, size: 58)
        for (b, dir) in [(left, CGFloat(-1)), (right, CGFloat(1))] {
            Glass.hold(b, down: { [weak self] in self?.scene?.player.moveDir = dir },
                       up: { [weak self] in
                           guard let p = self?.scene?.player, p.moveDir == dir else { return }
                           p.moveDir = 0
                       })
            root.addSubview(b)
        }
        evade = circle(symbol: "wind", title: "Evade", style: .prominent, tint: .maBlue, size: 64)
        evade.addAction(UIAction { [weak self] _ in
            guard let s = self?.scene else { return }
            let p = s.player!
            s.dodge(p, dir: p.moveDir != 0 ? p.moveDir : -p.current.node.facing)
        }, for: .touchDown)
        root.addSubview(evade)
        let pipRow = UIStackView()
        pipRow.spacing = 4
        pipRow.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<4 {
            let pip = UIView()
            pip.layer.cornerRadius = 3
            pip.layer.borderWidth = 1
            pip.layer.borderColor = UIColor(white: 1, alpha: 0.6).cgColor
            Glass.size(pip, 14, 6)
            pipRow.addArrangedSubview(pip)
            pips.append(pip)
        }
        root.addSubview(pipRow)

        NSLayoutConstraint.activate([
            pPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            pPanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            pPanel.widthAnchor.constraint(equalToConstant: 250),
            ePanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            ePanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            ePanel.widthAnchor.constraint(equalToConstant: 250),
            pRow.leadingAnchor.constraint(equalTo: pPanel.leadingAnchor, constant: 4),
            pRow.topAnchor.constraint(equalTo: pPanel.bottomAnchor, constant: 8),
            eRow.trailingAnchor.constraint(equalTo: ePanel.trailingAnchor, constant: -4),
            eRow.topAnchor.constraint(equalTo: ePanel.bottomAnchor, constant: 8),

            timerPanel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            timerPanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            timerPanel.widthAnchor.constraint(equalToConstant: 76),
            timerPanel.heightAnchor.constraint(equalToConstant: 44),
            timer.centerXAnchor.constraint(equalTo: timerPanel.contentView.centerXAnchor),
            timer.centerYAnchor.constraint(equalTo: timerPanel.contentView.centerYAnchor),
            pause.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            pause.topAnchor.constraint(equalTo: timerPanel.bottomAnchor, constant: 8),
            pause.widthAnchor.constraint(equalToConstant: 40),
            pause.heightAnchor.constraint(equalToConstant: 40),

            cardRow.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            cardRow.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -8),
            cardRow.heightAnchor.constraint(equalToConstant: 74),
            cardRow.widthAnchor.constraint(equalToConstant: 4 * 78 + 3 * 8),

            energyPanel.leadingAnchor.constraint(equalTo: cardRow.leadingAnchor),
            energyPanel.trailingAnchor.constraint(equalTo: cardRow.trailingAnchor),
            energyPanel.bottomAnchor.constraint(equalTo: cardRow.topAnchor, constant: -8),
            energyPanel.heightAnchor.constraint(equalToConstant: 30),
            bolt.leadingAnchor.constraint(equalTo: energyPanel.contentView.leadingAnchor, constant: 12),
            bolt.centerYAnchor.constraint(equalTo: energyPanel.contentView.centerYAnchor),
            energyLabel.leadingAnchor.constraint(equalTo: bolt.trailingAnchor, constant: 5),
            energyLabel.centerYAnchor.constraint(equalTo: energyPanel.contentView.centerYAnchor),
            energyLabel.widthAnchor.constraint(equalToConstant: 30),
            energyMeter.leadingAnchor.constraint(equalTo: energyLabel.trailingAnchor, constant: 6),
            energyMeter.trailingAnchor.constraint(equalTo: energyPanel.contentView.trailingAnchor, constant: -12),
            energyMeter.centerYAnchor.constraint(equalTo: energyPanel.contentView.centerYAnchor),
            energyMeter.heightAnchor.constraint(equalToConstant: 8),

            special.trailingAnchor.constraint(equalTo: cardRow.leadingAnchor, constant: -12),
            special.bottomAnchor.constraint(equalTo: cardRow.bottomAnchor),
            ultimate.centerXAnchor.constraint(equalTo: special.centerXAnchor),
            ultimate.bottomAnchor.constraint(equalTo: special.topAnchor, constant: -14),
            ultRing.centerXAnchor.constraint(equalTo: ultimate.centerXAnchor),
            ultRing.centerYAnchor.constraint(equalTo: ultimate.centerYAnchor),
            ultRing.widthAnchor.constraint(equalToConstant: 72),
            ultRing.heightAnchor.constraint(equalToConstant: 72),
            charge.trailingAnchor.constraint(equalTo: special.leadingAnchor, constant: -12),
            charge.bottomAnchor.constraint(equalTo: cardRow.bottomAnchor),

            left.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            left.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -10),
            right.leadingAnchor.constraint(equalTo: left.trailingAnchor, constant: 12),
            right.bottomAnchor.constraint(equalTo: left.bottomAnchor),
            evade.centerXAnchor.constraint(equalTo: left.trailingAnchor, constant: 6),
            evade.bottomAnchor.constraint(equalTo: left.topAnchor, constant: -26),
            pipRow.centerXAnchor.constraint(equalTo: evade.centerXAnchor),
            pipRow.topAnchor.constraint(equalTo: evade.bottomAnchor, constant: 6),
        ])
    }

    private func statusPanel(name: UILabel, hp: MeterView, soul: MeterView, alignRight: Bool) -> UIView {
        let panel = Glass.panel(radius: 20)
        let soulRow = UIStackView(arrangedSubviews: [soul])
        soulRow.translatesAutoresizingMaskIntoConstraints = false
        let st = UIStackView(arrangedSubviews: [name, hp, soulRow])
        st.axis = .vertical
        st.spacing = 5
        st.alignment = .fill
        st.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(st)
        NSLayoutConstraint.activate([
            hp.heightAnchor.constraint(equalToConstant: 12),
            soul.heightAnchor.constraint(equalToConstant: 5),
            soul.widthAnchor.constraint(equalTo: st.widthAnchor, multiplier: 0.6),
            st.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 14),
            st.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -14),
            st.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 8),
            st.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -10),
        ])
        soulRow.alignment = .center
        if alignRight {
            soulRow.semanticContentAttribute = .forceRightToLeft
        }
        return panel
    }

    private func circle(symbol: String, title: String?, style: GlassStyle, tint: UIColor?, size: CGFloat) -> UIButton {
        let b = Glass.button(title, symbol: symbol, style: style, tint: tint, fontSize: title == nil ? 20 : 11)
        b.configuration?.imagePlacement = .top
        b.configuration?.imagePadding = 2
        b.configuration?.contentInsets = .zero
        if title != nil {
            b.configuration?.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .bold))
        }
        Glass.size(b, size, size)
        return b
    }

    static func portraitImage(_ def: FighterDef, in view: SKView) -> UIImage? {
        let bust = FighterNode.portrait(def)
        guard let tex = view.texture(from: bust, crop: CGRect(x: -26, y: -24, width: 52, height: 56)) else { return nil }
        return UIImage(cgImage: tex.cgImage())
    }

    // MARK: Update (per frame, change-driven)

    func update(dt: CGFloat) {
        guard let s = scene, let p = s.player, let e = s.enemy else { return }
        let pc = p.current
        let ec = e.current
        let pn = "\(pc.def.name)  ·  Lv \(pc.level)"
        if pName.text != pn { pName.text = pn }
        let en = "Lv \(ec.level)  ·  \(ec.def.name)"
        if eName.text != en { eName.text = en }
        pHP.set(pc.hpFraction)
        eHP.set(ec.hpFraction)
        pHP.tick(dt)
        eHP.tick(dt)
        pHP.color = pc.hpFraction > 0.5 ? UIColor(hex: 0x58E37A) : (pc.hpFraction > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
        pSoul.set(CGFloat(p.soul / 100))
        eSoul.set(CGFloat(e.soul / 100))
        let t = "\(Int(ceil(s.timeLeft)))"
        if timer.text != t {
            timer.text = t
            timer.textColor = s.timeLeft < 20 ? UIColor(hex: 0xFF6A6A) : .white
        }

        energyMeter.set(CGFloat(p.energy / Tune.energyMax))
        let el = "\(Int(p.energy))"
        if energyLabel.text != el { energyLabel.text = el }

        for (i, b) in cards.enumerated() {
            let card = p.hand[i]
            let affordable = card.map { p.energy >= Double($0.cost) } ?? false
            let key = "\(card?.name ?? "-")|\(affordable)"
            guard key != cardKeys[i] else { continue }
            let changedCard = cardKeys[i].split(separator: "|").first.map(String.init) != (card?.name ?? "-")
            cardKeys[i] = key
            if let card {
                let strike = card.kind == .strike
                b.tintColor = strike ? .maRed : .maBlue
                b.configuration?.image = UIImage(systemName: strike ? "hand.raised.fill" : "circle.hexagongrid.fill",
                                                 withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold))
                Glass.setTitle(b, card.name, subtitle: "\(strike ? "STRIKE" : "BLAST") · \(card.cost)")
                b.isEnabled = true
                b.alpha = affordable ? 1 : 0.45
                if changedCard {
                    b.transform = CGAffineTransform(scaleX: 0.6, y: 0.6)
                    UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0) {
                        b.transform = .identity
                    }
                }
            } else {
                b.tintColor = UIColor(white: 0.3, alpha: 1)
                b.configuration?.image = nil
                Glass.setTitle(b, "···", subtitle: "drawing")
                b.alpha = 0.35
            }
        }

        let cd = p.specialReadyAt - s.now
        let spKey = cd > 0 ? "\(Int(ceil(cd)))s" : "\(Int(Tune.specialCost))"
        if spKey != lastSpecial {
            lastSpecial = spKey
            Glass.setTitle(special, spKey)
        }
        special.alpha = cd > 0 ? 0.45 : (p.energy >= Tune.specialCost ? 1 : 0.6)

        let pct = Int(p.soul)
        if pct != lastUlt {
            lastUlt = pct
            ultRing.set(CGFloat(pct) / 100)
            Glass.setTitle(ultimate, pct >= 100 ? "READY" : "\(pct)%")
            ultimate.tintColor = pct >= 100 ? .maGold : UIColor(hex: 0x8A5A10)
            ultimate.layer.removeAnimation(forKey: "pulse")
            if pct >= 100 {
                let a = CABasicAnimation(keyPath: "transform.scale")
                a.fromValue = 1
                a.toValue = 1.1
                a.duration = 0.35
                a.autoreverses = true
                a.repeatCount = .infinity
                ultimate.layer.add(a, forKey: "pulse")
            }
        }

        let pipCount = Int(p.dodge / Tune.dodgeCost)
        for (i, pip) in pips.enumerated() {
            pip.backgroundColor = i < pipCount ? UIColor(hex: 0x6FB7FF) : UIColor(white: 0, alpha: 0.35)
        }
        evade.alpha = pipCount > 0 ? 1 : 0.5

        let swapCD = max(0, Int(ceil(p.swapReadyAt - s.now)))
        for (i, v) in pPortraits.enumerated() {
            let c = p.team[i]
            v.update(hp: c.hpFraction, active: i == p.active, ko: c.isKO, cooldown: swapCD)
        }
        let eCD = max(0, Int(ceil(e.swapReadyAt - s.now)))
        for (i, v) in ePortraits.enumerated() {
            let c = e.team[i]
            v.update(hp: c.hpFraction, active: i == e.active, ko: c.isKO, cooldown: eCD)
        }
    }
}

/// Team member portrait: glass circle with face, HP ring and cooldown veil.
final class PortraitView: UIView {
    var onTap: (() -> Void)?
    private let button: UIButton
    private let ring = RingView(color: UIColor(hex: 0x58E37A))
    private let veil = UIView()
    private let label = Glass.label("", size: 13, weight: .heavy)
    private var lastKey = ""

    init(image: UIImage?, tint: UIColor, interactive: Bool) {
        button = Glass.button(style: .regular)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        button.configuration?.contentInsets = .zero
        button.isUserInteractionEnabled = interactive
        addSubview(button)
        let face = UIImageView(image: image)
        face.contentMode = .scaleAspectFill
        face.clipsToBounds = true
        face.layer.cornerRadius = 17
        face.isUserInteractionEnabled = false
        face.backgroundColor = tint.withAlphaComponent(0.35)
        face.translatesAutoresizingMaskIntoConstraints = false
        addSubview(face)
        ring.lineWidth = 3
        addSubview(ring)
        veil.backgroundColor = UIColor(white: 0, alpha: 0.55)
        veil.layer.cornerRadius = 17
        veil.isUserInteractionEnabled = false
        veil.isHidden = true
        veil.translatesAutoresizingMaskIntoConstraints = false
        addSubview(veil)
        addSubview(label)
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: 46),
            heightAnchor.constraint(equalToConstant: 46),
            button.centerXAnchor.constraint(equalTo: centerXAnchor),
            button.centerYAnchor.constraint(equalTo: centerYAnchor),
            button.widthAnchor.constraint(equalToConstant: 42),
            button.heightAnchor.constraint(equalToConstant: 42),
            face.centerXAnchor.constraint(equalTo: centerXAnchor),
            face.centerYAnchor.constraint(equalTo: centerYAnchor),
            face.widthAnchor.constraint(equalToConstant: 34),
            face.heightAnchor.constraint(equalToConstant: 34),
            veil.centerXAnchor.constraint(equalTo: centerXAnchor),
            veil.centerYAnchor.constraint(equalTo: centerYAnchor),
            veil.widthAnchor.constraint(equalToConstant: 34),
            veil.heightAnchor.constraint(equalToConstant: 34),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        button.addAction(UIAction { [weak self] _ in self?.onTap?() }, for: .touchDown)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(hp: CGFloat, active: Bool, ko: Bool, cooldown: Int) {
        let key = "\(Int(hp * 50))-\(active)-\(ko)-\(cooldown)"
        guard key != lastKey else { return }
        lastKey = key
        ring.set(hp)
        ring.color = hp > 0.5 ? UIColor(hex: 0x58E37A) : (hp > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
        transform = active ? CGAffineTransform(scaleX: 1.12, y: 1.12) : CGAffineTransform(scaleX: 0.92, y: 0.92)
        let showVeil = ko || (!active && cooldown > 0)
        veil.isHidden = !showVeil
        label.text = ko ? "KO" : (!active && cooldown > 0 ? "\(cooldown)" : "")
    }
}
