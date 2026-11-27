import UIKit

/// Portrait battle HUD built from native Liquid Glass components.
/// Layout: enemy status on top · 3D arena in the middle · player status + fanned hand at the bottom.
@MainActor
final class BattleHUD {
    private weak var screen: BattleScreen?
    private var root: PassthroughView { screen!.ui }
    let fxLayer = UIView()

    // Top
    private let timer = Glass.label("180", size: 22, weight: .black)
    private let eName = Glass.label("", size: 13, weight: .heavy, align: .right)
    private let eHP = MeterView(color: UIColor(hex: 0x6BE36B), fromRight: true)
    private let eHPText = Glass.label("", size: 12, weight: .heavy, color: UIColor(white: 1, alpha: 0.85), align: .right)
    private let eSoul = MeterView(color: .maGold, fromRight: true)
    private var eBench: [PortraitView] = []
    private var autoBtn: UIButton!
    private var shardDots: [UIImageView] = []

    // Bottom
    private let pPortrait = UIImageView()
    private let pName = Glass.label("", size: 13, weight: .heavy, align: .left)
    private let pHP = MeterView(color: UIColor(hex: 0x6BE36B))
    private let pHPText = Glass.label("", size: 12, weight: .heavy, color: UIColor(white: 1, alpha: 0.85), align: .right)
    private let pSoul = MeterView(color: .maGold)
    private var pips: [UIView] = []
    private var pBench: [PortraitView] = []
    private var cards: [CardView] = []
    private let ultCard = CardView()
    private let eclipseCard = CardView()
    private let nextCard = UIImageView()
    private let energyRing = RingView(color: UIColor(hex: 0x5FE6FF))
    private let energyText = Glass.label("0", size: 20, weight: .black)
    private let comboLabel = Glass.label("", size: 26, weight: .black, color: .maCoin, align: .left)
    private let chainLabel = Glass.label("", size: 18, weight: .black, color: UIColor(hex: 0x7FE8FF), align: .left)
    private var pauseModal: UIView?
    private var lastEnergy = -1
    private var lastNext = ""
    private var lastActive = -1

    init(screen: BattleScreen) {
        self.screen = screen
        build()
    }

    private var safe: UILayoutGuide { root.safeAreaLayoutGuide }

    // MARK: Build

    private func build() {
        guard let s = screen else { return }
        fxLayer.isUserInteractionEnabled = false
        fxLayer.frame = root.bounds
        fxLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addSubview(fxLayer)

        // ---------- Top ----------
        let timerPanel = Glass.panel(radius: 20)
        timerPanel.contentView.addSubview(timer)
        root.addSubview(timerPanel)

        let pause = Glass.button(symbol: "pause.fill", fontSize: 13) { [weak self] in self?.screen?.setPaused(true) }
        root.addSubview(pause)
        autoBtn = Glass.button("AUTO", fontSize: 11) { [weak self] in self?.toggleAuto() }
        autoBtn.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8)
        root.addSubview(autoBtn)

        let ePanel = Glass.panel(radius: 18)
        let eTop = UIStackView(arrangedSubviews: [eHPText, eName])
        eTop.spacing = 8
        let eStack = UIStackView(arrangedSubviews: [eTop, eHP, eSoul])
        eStack.axis = .vertical
        eStack.spacing = 4
        eStack.alignment = .fill
        eStack.translatesAutoresizingMaskIntoConstraints = false
        ePanel.contentView.addSubview(eStack)
        root.addSubview(ePanel)

        let eRow = UIStackView()
        eRow.spacing = 6
        eRow.translatesAutoresizingMaskIntoConstraints = false
        for c in s.enemy.team {
            let p = PortraitView(image: Portraits.image(c.def, .bust, size: CGSize(width: 40, height: 40)), tint: c.def.aura, interactive: false, size: 36)
            eRow.addArrangedSubview(p)
            eBench.append(p)
        }
        root.addSubview(eRow)

        // Moon shards (team finisher meter)
        let shardPanel = Glass.panel(radius: 16)
        let shardStack = UIStackView()
        shardStack.axis = .vertical
        shardStack.spacing = 5
        shardStack.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<Tune.shardsNeeded {
            let iv = UIImageView(image: UIImage(systemName: "moon.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .bold)))
            iv.tintColor = UIColor(white: 1, alpha: 0.25)
            iv.contentMode = .center
            Glass.size(iv, 18, 16)
            shardStack.addArrangedSubview(iv)
            shardDots.append(iv)
        }
        shardPanel.contentView.addSubview(shardStack)
        root.addSubview(shardPanel)

        // ---------- Bottom ----------
        let pPanel = Glass.panel(radius: 22)
        let pipRow = UIStackView()
        pipRow.spacing = 3
        for _ in 0..<4 {
            let pip = UIView()
            pip.layer.cornerRadius = 2.5
            pip.layer.borderWidth = 1
            pip.layer.borderColor = UIColor(white: 1, alpha: 0.6).cgColor
            Glass.size(pip, 12, 5)
            pipRow.addArrangedSubview(pip)
            pips.append(pip)
        }
        let pTop = UIStackView(arrangedSubviews: [pName, pipRow, pHPText])
        pTop.spacing = 8
        pTop.alignment = .center
        let pStack = UIStackView(arrangedSubviews: [pTop, pHP, pSoul])
        pStack.axis = .vertical
        pStack.spacing = 4
        pStack.translatesAutoresizingMaskIntoConstraints = false
        pPanel.contentView.addSubview(pStack)
        root.addSubview(pPanel)

        pPortrait.contentMode = .scaleAspectFill
        pPortrait.clipsToBounds = true
        pPortrait.layer.cornerRadius = 30
        pPortrait.layer.borderWidth = 2.5
        pPortrait.layer.borderColor = UIColor.white.cgColor
        pPortrait.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(pPortrait)

        let benchRow = UIStackView()
        benchRow.spacing = 6
        benchRow.translatesAutoresizingMaskIntoConstraints = false
        for (i, c) in s.player.team.enumerated() {
            let p = PortraitView(image: Portraits.image(c.def, .bust, size: CGSize(width: 44, height: 44)), tint: c.def.aura, interactive: true, size: 40)
            p.onTap = { [weak self] in
                guard let sc = self?.screen else { return }
                sc.swap(sc.player, to: i, forced: false)
            }
            benchRow.addArrangedSubview(p)
            pBench.append(p)
        }
        root.addSubview(benchRow)

        // Energy orb
        let energyPanel = Glass.panel(radius: 31)
        energyPanel.contentView.addSubview(energyText)
        root.addSubview(energyPanel)
        energyRing.lineWidth = 4
        root.addSubview(energyRing)
        let enLabel = Glass.label("ENERGY", size: 8, weight: .heavy, color: UIColor(hex: 0x9FEFFF))
        energyPanel.contentView.addSubview(enLabel)

        nextCard.contentMode = .scaleAspectFill
        nextCard.layer.cornerRadius = 6
        nextCard.clipsToBounds = true
        nextCard.alpha = 0.85
        nextCard.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(nextCard)
        let nextLabel = Glass.label("NEXT", size: 9, weight: .heavy, color: UIColor(white: 1, alpha: 0.8))
        root.addSubview(nextLabel)

        let hand = UIStackView()
        hand.spacing = 4
        hand.distribution = .fillEqually
        hand.alignment = .bottom
        hand.translatesAutoresizingMaskIntoConstraints = false
        let tilts: [CGFloat] = [-0.07, -0.025, 0.025, 0.07]
        let lifts: [CGFloat] = [8, 1, 1, 8]
        for i in 0..<4 {
            let cv = CardView()
            cv.onPlay = { [weak self] in
                guard let sc = self?.screen else { return }
                sc.playCard(sc.player, i)
            }
            cv.heightAnchor.constraint(equalTo: cv.widthAnchor, multiplier: 1.4).isActive = true
            cv.restTransform = CGAffineTransform(translationX: 0, y: lifts[i]).rotated(by: tilts[i])
            hand.addArrangedSubview(cv)
            cards.append(cv)
        }
        root.addSubview(hand)

        let power = UIStackView(arrangedSubviews: [eclipseCard, ultCard])
        power.spacing = 6
        power.translatesAutoresizingMaskIntoConstraints = false
        for (cv, idx) in [(ultCard, -1), (eclipseCard, -2)] {
            cv.onPlay = { [weak self] in
                guard let sc = self?.screen else { return }
                sc.playCard(sc.player, idx)
            }
            Glass.size(cv, 64, 90)
            cv.isHidden = true
        }
        root.addSubview(power)

        root.addSubview(comboLabel)
        root.addSubview(chainLabel)
        comboLabel.alpha = 0
        chainLabel.alpha = 0

        NSLayoutConstraint.activate([
            timerPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            timerPanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 6),
            timerPanel.widthAnchor.constraint(equalToConstant: 66),
            timerPanel.heightAnchor.constraint(equalToConstant: 40),
            timer.centerXAnchor.constraint(equalTo: timerPanel.contentView.centerXAnchor),
            timer.centerYAnchor.constraint(equalTo: timerPanel.contentView.centerYAnchor),
            pause.leadingAnchor.constraint(equalTo: timerPanel.leadingAnchor),
            pause.topAnchor.constraint(equalTo: timerPanel.bottomAnchor, constant: 8),
            pause.widthAnchor.constraint(equalToConstant: 34),
            pause.heightAnchor.constraint(equalToConstant: 34),
            autoBtn.leadingAnchor.constraint(equalTo: pause.trailingAnchor, constant: 6),
            autoBtn.centerYAnchor.constraint(equalTo: pause.centerYAnchor),
            autoBtn.heightAnchor.constraint(equalToConstant: 34),

            ePanel.leadingAnchor.constraint(equalTo: timerPanel.trailingAnchor, constant: 8),
            ePanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            ePanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 6),
            eStack.leadingAnchor.constraint(equalTo: ePanel.contentView.leadingAnchor, constant: 14),
            eStack.trailingAnchor.constraint(equalTo: ePanel.contentView.trailingAnchor, constant: -14),
            eStack.topAnchor.constraint(equalTo: ePanel.contentView.topAnchor, constant: 7),
            eStack.bottomAnchor.constraint(equalTo: ePanel.contentView.bottomAnchor, constant: -8),
            eHP.heightAnchor.constraint(equalToConstant: 11),
            eSoul.heightAnchor.constraint(equalToConstant: 4),
            eRow.trailingAnchor.constraint(equalTo: ePanel.trailingAnchor, constant: -4),
            eRow.topAnchor.constraint(equalTo: ePanel.bottomAnchor, constant: 6),

            shardPanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -10),
            shardPanel.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -30),
            shardStack.leadingAnchor.constraint(equalTo: shardPanel.contentView.leadingAnchor, constant: 6),
            shardStack.trailingAnchor.constraint(equalTo: shardPanel.contentView.trailingAnchor, constant: -6),
            shardStack.topAnchor.constraint(equalTo: shardPanel.contentView.topAnchor, constant: 9),
            shardStack.bottomAnchor.constraint(equalTo: shardPanel.contentView.bottomAnchor, constant: -9),

            pPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 40),
            pPanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            pPanel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -4),
            pStack.leadingAnchor.constraint(equalTo: pPanel.contentView.leadingAnchor, constant: 36),
            pStack.trailingAnchor.constraint(equalTo: pPanel.contentView.trailingAnchor, constant: -14),
            pStack.topAnchor.constraint(equalTo: pPanel.contentView.topAnchor, constant: 7),
            pStack.bottomAnchor.constraint(equalTo: pPanel.contentView.bottomAnchor, constant: -8),
            pHP.heightAnchor.constraint(equalToConstant: 12),
            pSoul.heightAnchor.constraint(equalToConstant: 4),
            pPortrait.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 10),
            pPortrait.centerYAnchor.constraint(equalTo: pPanel.centerYAnchor),
            pPortrait.widthAnchor.constraint(equalToConstant: 60),
            pPortrait.heightAnchor.constraint(equalToConstant: 60),

            energyPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 12),
            energyPanel.bottomAnchor.constraint(equalTo: pPanel.topAnchor, constant: -14),
            energyPanel.widthAnchor.constraint(equalToConstant: 62),
            energyPanel.heightAnchor.constraint(equalToConstant: 62),
            energyText.centerXAnchor.constraint(equalTo: energyPanel.contentView.centerXAnchor),
            energyText.centerYAnchor.constraint(equalTo: energyPanel.contentView.centerYAnchor, constant: -3),
            enLabel.centerXAnchor.constraint(equalTo: energyPanel.contentView.centerXAnchor),
            enLabel.topAnchor.constraint(equalTo: energyText.bottomAnchor, constant: -3),
            energyRing.centerXAnchor.constraint(equalTo: energyPanel.centerXAnchor),
            energyRing.centerYAnchor.constraint(equalTo: energyPanel.centerYAnchor),
            energyRing.widthAnchor.constraint(equalToConstant: 70),
            energyRing.heightAnchor.constraint(equalToConstant: 70),

            nextCard.centerXAnchor.constraint(equalTo: energyPanel.centerXAnchor),
            nextCard.bottomAnchor.constraint(equalTo: energyPanel.topAnchor, constant: -16),
            nextCard.widthAnchor.constraint(equalToConstant: 34),
            nextCard.heightAnchor.constraint(equalToConstant: 48),
            nextLabel.centerXAnchor.constraint(equalTo: nextCard.centerXAnchor),
            nextLabel.bottomAnchor.constraint(equalTo: nextCard.topAnchor, constant: -2),

            hand.leadingAnchor.constraint(equalTo: energyPanel.trailingAnchor, constant: 10),
            hand.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -12),
            hand.bottomAnchor.constraint(equalTo: pPanel.topAnchor, constant: -10),

            power.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            power.bottomAnchor.constraint(equalTo: hand.topAnchor, constant: -14),

            benchRow.leadingAnchor.constraint(equalTo: nextCard.trailingAnchor, constant: 14),
            benchRow.bottomAnchor.constraint(equalTo: hand.topAnchor, constant: -14),

            comboLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 18),
            comboLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -40),
            chainLabel.leadingAnchor.constraint(equalTo: comboLabel.leadingAnchor),
            chainLabel.topAnchor.constraint(equalTo: comboLabel.bottomAnchor, constant: 2),
        ])
        root.bringSubviewToFront(fxLayer)
        teamChanged()
    }

    private func toggleAuto() {
        guard let s = screen else { return }
        s.player.auto.toggle()
        s.player.charging = false
        autoBtn.configuration?.title = s.player.auto ? "AUTO ON" : "AUTO"
        autoBtn.tintColor = s.player.auto ? .maBlue : nil
    }

    func teamChanged() {
        guard let s = screen else { return }
        let c = s.player.current
        pPortrait.image = Portraits.image(c.def, .bust, size: CGSize(width: 64, height: 64))
        pPortrait.backgroundColor = c.def.aura.darker(0.5)
        pPortrait.layer.borderColor = c.def.aura.lighter(0.4).cgColor
    }

    // MARK: Update

    func update(dt: Double) {
        guard let s = screen, let p = s.player, let e = s.enemy else { return }
        let pc = p.current
        let ec = e.current
        set(pName, "\(pc.def.name)  Lv\(pc.level)")
        set(eName, "Lv\(ec.level)  \(ec.def.name)")
        set(pHPText, "\(Int(max(0, pc.hp)))")
        set(eHPText, "\(Int(max(0, ec.hp)))")
        pHP.set(pc.hpFraction)
        eHP.set(ec.hpFraction)
        pHP.tick(CGFloat(dt))
        eHP.tick(CGFloat(dt))
        pHP.color = hpColor(pc.hpFraction)
        eHP.color = hpColor(ec.hpFraction)
        pSoul.set(CGFloat(p.soul / 100))
        eSoul.set(CGFloat(e.soul / 100))
        set(timer, "\(Int(ceil(s.timeLeft)))")
        timer.textColor = s.timeLeft < 20 ? UIColor(hex: 0xFF6A6A) : .white

        let en = Int(p.energy)
        if en != lastEnergy {
            lastEnergy = en
            energyText.text = "\(en)"
            energyRing.set(CGFloat(p.energy / Tune.energyMax))
        }
        for (i, cv) in cards.enumerated() {
            let card = p.hand[i]
            cv.show(card, affordable: card.map { p.energy >= Double($0.cost) } ?? false)
        }
        if let n = pc.nextCard, n.name != lastNext {
            lastNext = n.name
            nextCard.image = CardArt.image(n)
        }
        updatePower(ultCard, ready: p.ultimateReady, card: pc.def.ultimateCard)
        updatePower(eclipseCard, ready: p.eclipseReady, card: Roster.eclipseCard)
        for (i, dot) in shardDots.enumerated() {
            let lit = (Tune.shardsNeeded - 1 - i) < p.shards
            dot.tintColor = lit ? .maCoin : UIColor(white: 1, alpha: 0.25)
        }
        let pipCount = Int(p.dodge / Tune.dodgeCost)
        for (i, pip) in pips.enumerated() {
            pip.backgroundColor = i < pipCount ? UIColor(hex: 0x6FB7FF) : UIColor(white: 0, alpha: 0.35)
        }
        let swapCD = max(0, Int(ceil(p.swapReadyAt - s.now)))
        for (i, v) in pBench.enumerated() {
            let c = p.team[i]
            v.isHidden = i == p.active
            v.update(hp: c.hpFraction, active: false, ko: c.isKO, cooldown: swapCD)
        }
        if p.active != lastActive {
            lastActive = p.active
            teamChanged()
        }
        for (i, v) in eBench.enumerated() {
            let c = e.team[i]
            v.update(hp: c.hpFraction, active: i == e.active, ko: c.isKO, cooldown: 0)
        }
    }

    private func updatePower(_ cv: CardView, ready: Bool, card: Card) {
        if ready && cv.isHidden {
            cv.isHidden = false
            cv.show(card, affordable: true)
            cv.transform = CGAffineTransform(scaleX: 0.3, y: 0.3)
            UIView.animate(withDuration: 0.4, delay: 0, usingSpringWithDamping: 0.55, initialSpringVelocity: 0) { cv.transform = .identity }
            Sound.play(.ultimate)
        } else if !ready && !cv.isHidden {
            cv.isHidden = true
            cv.show(nil, affordable: false)
        }
    }

    private func set(_ l: UILabel, _ t: String) { if l.text != t { l.text = t } }

    private func hpColor(_ f: CGFloat) -> UIColor {
        f > 0.5 ? UIColor(hex: 0x6BE36B) : (f > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
    }

    // MARK: Events

    func cardPlayed(_ idx: Int) {
        if idx >= 0 && idx < cards.count { cards[idx].playAnimation() }
        else if idx == -1 { ultCard.playAnimation() } else if idx == -2 { eclipseCard.playAnimation() }
    }

    func combo(_ n: Int) {
        guard n >= 2 else { return }
        comboLabel.text = "\(n) HITS"
        pop(comboLabel)
    }

    func chain(_ n: Int) {
        chainLabel.text = "CARD CHAIN ×\(n)"
        pop(chainLabel)
    }

    private func pop(_ l: UILabel) {
        l.layer.removeAllAnimations()
        l.alpha = 1
        l.transform = CGAffineTransform(scaleX: 1.4, y: 1.4)
        UIView.animate(withDuration: 0.12, animations: { l.transform = .identity }) { _ in
            UIView.animate(withDuration: 0.3, delay: 1.0, options: [.allowUserInteraction], animations: { l.alpha = 0 })
        }
    }

    func flashEvade() {
        let v = UIView(frame: root.bounds)
        v.backgroundColor = UIColor(hex: 0x6FD0FF).withAlphaComponent(0.12)
        v.isUserInteractionEnabled = false
        fxLayer.addSubview(v)
        UIView.animate(withDuration: 0.25, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    func screenFlash(_ color: UIColor) {
        let v = UIView(frame: root.bounds)
        v.backgroundColor = color.lighter(0.6).withAlphaComponent(0.7)
        v.isUserInteractionEnabled = false
        fxLayer.addSubview(v)
        UIView.animate(withDuration: 0.4, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    /// Big centered text (READY / FIGHT / K.O.)
    func banner(_ text: String, color: UIColor, big: Bool, duration: Double) {
        let l = UILabel()
        l.text = text
        l.font = Glass.font(big ? 64 : 30, .black)
        l.textColor = color
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.85
        l.layer.shadowRadius = 6
        l.layer.shadowOffset = CGSize(width: 0, height: 3)
        l.sizeToFit()
        l.center = CGPoint(x: root.bounds.midX, y: root.bounds.midY * 0.8)
        l.isUserInteractionEnabled = false
        fxLayer.addSubview(l)
        l.transform = CGAffineTransform(scaleX: 2.2, y: 2.2)
        l.alpha = 0
        UIView.animate(withDuration: 0.18, animations: {
            l.transform = .identity
            l.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: duration, options: [], animations: {
                l.alpha = 0
                l.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
            }, completion: { _ in l.removeFromSuperview() })
        }
    }

    /// Glass ribbon announcing a special art / effect / tag-in.
    func moveBanner(_ name: String, kind: CardKind, side: Side) {
        let st = CardArt.style(Card(name: name, kind: kind, cost: 0, power: 0, hits: 0))
        let panel = Glass.panel(radius: 18, tint: st.bottom.withAlphaComponent(0.55))
        let icon = UIImageView(image: UIImage(systemName: side.isPlayer ? "sparkles" : "exclamationmark.triangle.fill",
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .bold)))
        icon.tintColor = side.isPlayer ? .white : UIColor(hex: 0xFFB3AA)
        let l = Glass.label(name.uppercased(), size: 16, weight: .black)
        let row = UIStackView(arrangedSubviews: [icon, l])
        row.spacing = 8
        row.alignment = .center
        row.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(row)
        root.insertSubview(panel, belowSubview: fxLayer)
        NSLayoutConstraint.activate([
            row.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -16),
            row.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 8),
            row.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -8),
            panel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            side.isPlayer
                ? panel.bottomAnchor.constraint(equalTo: root.centerYAnchor, constant: 70)
                : panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 104),
        ])
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: side.isPlayer ? -60 : 60, y: 0)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0, animations: {
            panel.alpha = 1
            panel.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.1, options: [], animations: { panel.alpha = 0 },
                           completion: { _ in panel.removeFromSuperview() })
        }
    }

    /// Full-screen Ultimate cut-in: dimmed screen, angled band, full-body render, move name.
    func ultimateCutIn(_ def: FighterDef, side: Side) -> Double {
        let duration = 1.6
        let v = UIView(frame: root.bounds)
        v.isUserInteractionEnabled = false
        v.backgroundColor = UIColor(white: 0, alpha: 0.55)
        let band = UIView(frame: CGRect(x: -100, y: v.bounds.midY - 130, width: v.bounds.width + 200, height: 260))
        band.backgroundColor = def.aura.darker(0.3).withAlphaComponent(0.92)
        band.transform = CGAffineTransform(rotationAngle: side.isPlayer ? -0.12 : 0.12)
        band.layer.borderColor = def.aura.lighter(0.5).cgColor
        band.layer.borderWidth = 4
        v.addSubview(band)
        for _ in 0..<12 {
            let line = UIView(frame: CGRect(x: -200, y: CGFloat.random(in: 10...250), width: CGFloat.random(in: 80...220), height: CGFloat.random(in: 2...5)))
            line.backgroundColor = UIColor(white: 1, alpha: 0.5)
            band.addSubview(line)
            UIView.animate(withDuration: Double.random(in: 0.25...0.45), delay: 0, options: [.repeat, .curveLinear]) {
                line.frame.origin.x = band.bounds.width + 50
            }
        }
        let art = UIImageView(image: Portraits.image(def, .body, size: CGSize(width: 260, height: 340)))
        art.contentMode = .scaleAspectFit
        art.frame = CGRect(x: side.isPlayer ? -20 : v.bounds.width - 240, y: v.bounds.midY - 220, width: 260, height: 340)
        v.addSubview(art)
        let tag = UILabel()
        tag.text = "ULTIMATE ART"
        tag.font = Glass.font(15, .heavy)
        tag.textColor = def.aura.lighter(0.6)
        tag.sizeToFit()
        let name = UILabel()
        name.text = def.ultimateName.uppercased()
        name.font = Glass.font(34, .black)
        name.textColor = .white
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.5
        name.layer.shadowColor = UIColor.black.cgColor
        name.layer.shadowOpacity = 0.8
        name.layer.shadowRadius = 4
        let textX: CGFloat = side.isPlayer ? v.bounds.width * 0.42 : 20
        name.frame = CGRect(x: textX, y: v.bounds.midY + 40, width: v.bounds.width * 0.56, height: 44)
        tag.frame.origin = CGPoint(x: textX, y: v.bounds.midY + 18)
        v.addSubview(tag)
        v.addSubview(name)
        fxLayer.addSubview(v)
        band.transform = band.transform.scaledBy(x: 1, y: 0.01)
        art.transform = CGAffineTransform(translationX: side.isPlayer ? -200 : 200, y: 0)
        name.alpha = 0
        UIView.animate(withDuration: 0.18) {
            band.transform = CGAffineTransform(rotationAngle: side.isPlayer ? -0.12 : 0.12)
        }
        UIView.animate(withDuration: 0.3, delay: 0.05, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            art.transform = .identity
        }
        UIView.animate(withDuration: 0.2, delay: 0.25) { name.alpha = 1 }
        UIView.animate(withDuration: 0.2, delay: duration - 0.2, options: []) { v.alpha = 0 } completion: { _ in v.removeFromSuperview() }
        return duration
    }

    func eclipseCutIn(_ side: Side) -> Double {
        let duration = 1.5
        let v = UIView(frame: root.bounds)
        v.isUserInteractionEnabled = false
        v.backgroundColor = UIColor(white: 0, alpha: 0.75)
        let title = UILabel()
        title.text = "ECLIPSE RUSH"
        title.font = Glass.font(40, .black)
        title.textColor = .maCoin
        title.textAlignment = .center
        title.frame = CGRect(x: 0, y: v.bounds.midY + 70, width: v.bounds.width, height: 50)
        v.addSubview(title)
        let alive = side.team.filter { !$0.isKO }
        let w = v.bounds.width / CGFloat(max(1, alive.count))
        for (i, c) in alive.enumerated() {
            let iv = UIImageView(image: Portraits.image(c.def, .body, size: CGSize(width: 180, height: 240)))
            iv.contentMode = .scaleAspectFit
            iv.frame = CGRect(x: CGFloat(i) * w, y: v.bounds.midY - 200, width: w, height: 260)
            iv.alpha = 0
            v.addSubview(iv)
            UIView.animate(withDuration: 0.25, delay: Double(i) * 0.15) { iv.alpha = 1 }
        }
        fxLayer.addSubview(v)
        UIView.animate(withDuration: 0.2, delay: duration - 0.2, options: []) { v.alpha = 0 } completion: { _ in v.removeFromSuperview() }
        return duration
    }

    func finalBanner(won: Bool) {
        let panel = Glass.panel(radius: 28, tint: (won ? UIColor.maGold : UIColor.gray).withAlphaComponent(0.3))
        let l = Glass.label(won ? "VICTORY" : "DEFEAT", size: 46, weight: .black, color: won ? .maCoin : UIColor(hex: 0xC4CBE6))
        panel.contentView.addSubview(l)
        root.insertSubview(panel, belowSubview: fxLayer)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 130),
            l.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 34),
            l.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -34),
            l.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 10),
            l.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -10),
        ])
        panel.transform = CGAffineTransform(scaleX: 1.6, y: 1.6)
        panel.alpha = 0
        UIView.animate(withDuration: 0.3) {
            panel.transform = .identity
            panel.alpha = 1
        }
    }

    // MARK: Pause

    func openPause() {
        guard let s = screen else { return }
        pauseModal = s.presentModal(width: 300) { stack in
            stack.addArrangedSubview(Glass.label("Paused", size: 26, weight: .heavy))
            let resume = Glass.button("Resume", symbol: "play.fill", style: .prominent, tint: .maBlue, fontSize: 18) { [weak self] in
                self?.screen?.setPaused(false)
            }
            let quit = Glass.button("Retreat", symbol: "flag.fill", style: .regular, fontSize: 18) { [weak self] in
                self?.screen?.retreat()
            }
            for b in [resume, quit] {
                b.heightAnchor.constraint(equalToConstant: 50).isActive = true
                stack.addArrangedSubview(b)
            }
        }
    }

    func closePause() {
        screen?.dismissModal(pauseModal)
        pauseModal = nil
    }
}

/// Round glass portrait with HP ring, cooldown/KO veil.
final class PortraitView: UIView {
    var onTap: (() -> Void)?
    private let face = UIImageView()
    private let ring = RingView(color: UIColor(hex: 0x6BE36B))
    private let veil = UIView()
    private let label = Glass.label("", size: 12, weight: .heavy)
    private var lastKey = ""

    init(image: UIImage?, tint: UIColor, interactive: Bool, size: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let glass = Glass.panel(radius: size / 2)
        addSubview(glass)
        face.image = image
        face.contentMode = .scaleAspectFill
        face.clipsToBounds = true
        face.layer.cornerRadius = (size - 8) / 2
        face.backgroundColor = tint.withAlphaComponent(0.4)
        face.translatesAutoresizingMaskIntoConstraints = false
        addSubview(face)
        ring.lineWidth = 3
        addSubview(ring)
        veil.backgroundColor = UIColor(white: 0, alpha: 0.55)
        veil.layer.cornerRadius = (size - 8) / 2
        veil.isHidden = true
        veil.translatesAutoresizingMaskIntoConstraints = false
        addSubview(veil)
        addSubview(label)
        for v in [glass, face, ring, veil, label] as [UIView] { v.isUserInteractionEnabled = false }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            glass.leadingAnchor.constraint(equalTo: leadingAnchor),
            glass.trailingAnchor.constraint(equalTo: trailingAnchor),
            glass.topAnchor.constraint(equalTo: topAnchor),
            glass.bottomAnchor.constraint(equalTo: bottomAnchor),
            face.centerXAnchor.constraint(equalTo: centerXAnchor),
            face.centerYAnchor.constraint(equalTo: centerYAnchor),
            face.widthAnchor.constraint(equalToConstant: size - 8),
            face.heightAnchor.constraint(equalToConstant: size - 8),
            veil.centerXAnchor.constraint(equalTo: centerXAnchor),
            veil.centerYAnchor.constraint(equalTo: centerYAnchor),
            veil.widthAnchor.constraint(equalToConstant: size - 8),
            veil.heightAnchor.constraint(equalToConstant: size - 8),
            ring.leadingAnchor.constraint(equalTo: leadingAnchor),
            ring.trailingAnchor.constraint(equalTo: trailingAnchor),
            ring.topAnchor.constraint(equalTo: topAnchor),
            ring.bottomAnchor.constraint(equalTo: bottomAnchor),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isUserInteractionEnabled = interactive
        if interactive {
            addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped)))
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func tapped() {
        Sound.play(.ui)
        onTap?()
    }

    func update(hp: CGFloat, active: Bool, ko: Bool, cooldown: Int) {
        let key = "\(Int(hp * 50))-\(active)-\(ko)-\(cooldown)"
        guard key != lastKey else { return }
        lastKey = key
        ring.set(hp)
        ring.color = hp > 0.5 ? UIColor(hex: 0x6BE36B) : (hp > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
        alpha = active ? 1 : 0.85
        veil.isHidden = !(ko || cooldown > 0)
        label.text = ko ? "KO" : (cooldown > 0 ? "\(cooldown)" : "")
    }
}
