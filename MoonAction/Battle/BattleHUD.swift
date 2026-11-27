import UIKit

/// Minimal portrait battle HUD on smoked Liquid Glass.
/// Top: timer · enemy status · range. Middle: 3D arena. Bottom: player status + fanned hand.
@MainActor
final class BattleHUD {
    private weak var screen: BattleScreen?
    private var root: PassthroughView { screen!.ui }
    let fxLayer = UIView()

    // Top
    private let timer = Glass.label("180", size: 17, weight: .semibold, mono: true)
    private let ePortrait = UIImageView()
    private let eName = Glass.label("", size: 13, weight: .semibold, align: .left)
    private let eLevel = Glass.label("", size: 11, weight: .medium, color: Theme.text2, align: .left, mono: true)
    private let eHP = MeterView(color: Theme.hpEnemy)
    private let eHPText = Glass.label("", size: 11, weight: .medium, color: Theme.text2, align: .right, mono: true)
    private let eSoul = MeterView(color: Theme.accent)
    private var eBench: [PortraitView] = []
    private var autoBtn: UIButton!
    private let rangeChip = Glass.caption("", size: 10, color: Theme.text)
    private var shardDots: [UIView] = []
    private var lastRange: RangeZone?

    // Bottom
    private let pPortrait = UIImageView()
    private let pName = Glass.label("", size: 13, weight: .semibold, align: .left)
    private let pSpeed = UIImageView()
    private let pHP = MeterView(color: Theme.hp)
    private let pHPText = Glass.label("", size: 11, weight: .medium, color: Theme.text2, align: .right, mono: true)
    private let pSoul = MeterView(color: Theme.accent)
    private var pips: [UIView] = []
    private var pBench: [PortraitView] = []
    private var cards: [CardView] = []
    private let ultCard = CardView()
    private let eclipseCard = CardView()
    private let nextCard = UIImageView()
    private let energyRing = RingView(color: Theme.energy)
    private let energyText = Glass.label("0", size: 18, weight: .semibold, mono: true)
    private let comboLabel = Glass.label("", size: 22, weight: .bold, color: .white, align: .left)
    private let chainLabel = Glass.caption("", size: 10, color: Theme.energy)
    private var pauseModal: UIView?
    private var lastEnergy = -1
    private var lastNext = ""
    private var lastActive = -1
    private var lastEActive = -1

    init(screen: BattleScreen) {
        self.screen = screen
        build()
    }

    private var safe: UILayoutGuide { root.safeAreaLayoutGuide }

    private func circleImage(_ iv: UIImageView, size: CGFloat) {
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.layer.cornerRadius = size / 2
        iv.layer.borderWidth = 1
        iv.layer.borderColor = UIColor(white: 1, alpha: 0.35).cgColor
        iv.translatesAutoresizingMaskIntoConstraints = false
        Glass.size(iv, size, size)
    }

    // MARK: Build

    private func build() {
        guard let s = screen else { return }
        fxLayer.isUserInteractionEnabled = false
        fxLayer.frame = root.bounds
        fxLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        root.addSubview(fxLayer)

        // ---------- Top bar ----------
        let timerPanel = Glass.panel(radius: 18)
        timerPanel.contentView.addSubview(timer)
        root.addSubview(timerPanel)

        let ePanel = Glass.panel(radius: 20)
        circleImage(ePortrait, size: 34)
        let eNameRow = UIStackView(arrangedSubviews: [eName, eLevel, UIView(), eHPText])
        eNameRow.spacing = 6
        eNameRow.alignment = .firstBaseline
        let eBars = UIStackView(arrangedSubviews: [eNameRow, eHP, eSoul])
        eBars.axis = .vertical
        eBars.spacing = 4
        let eRow = UIStackView(arrangedSubviews: [ePortrait, eBars])
        eRow.spacing = 10
        eRow.alignment = .center
        eRow.translatesAutoresizingMaskIntoConstraints = false
        ePanel.contentView.addSubview(eRow)
        root.addSubview(ePanel)

        let eBenchRow = UIStackView()
        eBenchRow.spacing = 6
        eBenchRow.translatesAutoresizingMaskIntoConstraints = false
        for c in s.enemy.team {
            let p = PortraitView(image: Portraits.image(c.def, .bust, size: CGSize(width: 40, height: 40)), tint: c.def.aura, interactive: false, size: 26)
            eBenchRow.addArrangedSubview(p)
            eBench.append(p)
        }
        root.addSubview(eBenchRow)

        let pause = Glass.button(symbol: "pause.fill", style: .secondary, fontSize: 12) { [weak self] in self?.screen?.setPaused(true) }
        root.addSubview(pause)
        autoBtn = Glass.button(L("battle.auto"), style: .secondary, fontSize: 11) { [weak self] in self?.toggleAuto() }
        autoBtn.configuration?.contentInsets = NSDirectionalEdgeInsets(top: 4, leading: 10, bottom: 4, trailing: 10)
        root.addSubview(autoBtn)

        let rangePanel = Glass.panel(radius: 11)
        rangePanel.contentView.addSubview(rangeChip)
        root.addSubview(rangePanel)

        // Moon shards: a quiet column of dots on the right edge
        let shardCol = UIStackView()
        shardCol.axis = .vertical
        shardCol.spacing = 7
        shardCol.translatesAutoresizingMaskIntoConstraints = false
        for _ in 0..<Tune.shardsNeeded {
            let d = UIView()
            d.layer.cornerRadius = 3.5
            d.layer.borderWidth = 1
            d.layer.borderColor = UIColor(white: 1, alpha: 0.4).cgColor
            Glass.size(d, 7, 7)
            shardCol.addArrangedSubview(d)
            shardDots.append(d)
        }
        let moon = UIImageView(image: UIImage(systemName: "moon.fill", withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold)))
        moon.tintColor = Theme.accent
        shardCol.addArrangedSubview(moon)
        root.addSubview(shardCol)

        // ---------- Bottom ----------
        let pPanel = Glass.panel(radius: 22)
        circleImage(pPortrait, size: 40)
        pSpeed.tintColor = Theme.text2
        pSpeed.contentMode = .center
        Glass.size(pSpeed, 14, 14)
        let pipRow = UIStackView()
        pipRow.spacing = 3
        for _ in 0..<4 {
            let pip = UIView()
            pip.layer.cornerRadius = 1.5
            Glass.size(pip, 12, 3)
            pipRow.addArrangedSubview(pip)
            pips.append(pip)
        }
        let pNameRow = UIStackView(arrangedSubviews: [pName, pSpeed, UIView(), pipRow, pHPText])
        pNameRow.spacing = 6
        pNameRow.alignment = .center
        let pBars = UIStackView(arrangedSubviews: [pNameRow, pHP, pSoul])
        pBars.axis = .vertical
        pBars.spacing = 5
        let pRow = UIStackView(arrangedSubviews: [pPortrait, pBars])
        pRow.spacing = 10
        pRow.alignment = .center
        pRow.translatesAutoresizingMaskIntoConstraints = false
        pPanel.contentView.addSubview(pRow)
        root.addSubview(pPanel)

        let benchRow = UIStackView()
        benchRow.spacing = 8
        benchRow.translatesAutoresizingMaskIntoConstraints = false
        for (i, c) in s.player.team.enumerated() {
            let p = PortraitView(image: Portraits.image(c.def, .bust, size: CGSize(width: 44, height: 44)), tint: c.def.aura, interactive: true, size: 36)
            p.onTap = { [weak self] in
                guard let sc = self?.screen else { return }
                sc.swap(sc.player, to: i, forced: false)
            }
            benchRow.addArrangedSubview(p)
            pBench.append(p)
        }
        root.addSubview(benchRow)

        let energyPanel = Glass.panel(radius: 28)
        energyPanel.contentView.addSubview(energyText)
        let enLabel = Glass.caption(L("battle.energy"), size: 7, color: Theme.energy)
        energyPanel.contentView.addSubview(enLabel)
        root.addSubview(energyPanel)
        energyRing.lineWidth = 2.5
        root.addSubview(energyRing)

        nextCard.contentMode = .scaleAspectFill
        nextCard.layer.cornerRadius = 5
        nextCard.clipsToBounds = true
        nextCard.alpha = 0.9
        nextCard.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(nextCard)
        let nextLabel = Glass.caption(L("battle.next"), size: 8)
        root.addSubview(nextLabel)

        let hand = UIStackView()
        hand.spacing = 6
        hand.distribution = .fillEqually
        hand.alignment = .bottom
        hand.translatesAutoresizingMaskIntoConstraints = false
        let tilts: [CGFloat] = [-0.05, -0.017, 0.017, 0.05]
        let lifts: [CGFloat] = [5, 0, 0, 5]
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
        power.spacing = 8
        power.translatesAutoresizingMaskIntoConstraints = false
        for (cv, idx) in [(ultCard, -1), (eclipseCard, -2)] {
            cv.onPlay = { [weak self] in
                guard let sc = self?.screen else { return }
                sc.playCard(sc.player, idx)
            }
            Glass.size(cv, 60, 84)
            cv.isHidden = true
        }
        root.addSubview(power)

        root.addSubview(comboLabel)
        root.addSubview(chainLabel)
        comboLabel.alpha = 0
        chainLabel.alpha = 0

        NSLayoutConstraint.activate([
            timerPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            timerPanel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 6),
            timerPanel.widthAnchor.constraint(equalToConstant: 54),
            timerPanel.heightAnchor.constraint(equalToConstant: 54),
            timer.centerXAnchor.constraint(equalTo: timerPanel.contentView.centerXAnchor),
            timer.centerYAnchor.constraint(equalTo: timerPanel.contentView.centerYAnchor),

            ePanel.leadingAnchor.constraint(equalTo: timerPanel.trailingAnchor, constant: 8),
            ePanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            ePanel.topAnchor.constraint(equalTo: timerPanel.topAnchor),
            ePanel.heightAnchor.constraint(equalToConstant: 54),
            eRow.leadingAnchor.constraint(equalTo: ePanel.contentView.leadingAnchor, constant: 10),
            eRow.trailingAnchor.constraint(equalTo: ePanel.contentView.trailingAnchor, constant: -14),
            eRow.centerYAnchor.constraint(equalTo: ePanel.contentView.centerYAnchor),
            eHP.heightAnchor.constraint(equalToConstant: 5),
            eSoul.heightAnchor.constraint(equalToConstant: 2),

            eBenchRow.trailingAnchor.constraint(equalTo: ePanel.trailingAnchor, constant: -6),
            eBenchRow.topAnchor.constraint(equalTo: ePanel.bottomAnchor, constant: 8),
            pause.leadingAnchor.constraint(equalTo: timerPanel.leadingAnchor),
            pause.topAnchor.constraint(equalTo: timerPanel.bottomAnchor, constant: 8),
            pause.widthAnchor.constraint(equalToConstant: 30),
            pause.heightAnchor.constraint(equalToConstant: 30),
            autoBtn.leadingAnchor.constraint(equalTo: pause.trailingAnchor, constant: 6),
            autoBtn.centerYAnchor.constraint(equalTo: pause.centerYAnchor),
            autoBtn.heightAnchor.constraint(equalToConstant: 30),

            rangePanel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            rangePanel.centerYAnchor.constraint(equalTo: pause.centerYAnchor),
            rangePanel.heightAnchor.constraint(equalToConstant: 22),
            rangeChip.leadingAnchor.constraint(equalTo: rangePanel.contentView.leadingAnchor, constant: 12),
            rangeChip.trailingAnchor.constraint(equalTo: rangePanel.contentView.trailingAnchor, constant: -12),
            rangeChip.centerYAnchor.constraint(equalTo: rangePanel.contentView.centerYAnchor),

            shardCol.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            shardCol.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -40),

            pPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 14),
            pPanel.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            pPanel.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -4),
            pPanel.heightAnchor.constraint(equalToConstant: 58),
            pRow.leadingAnchor.constraint(equalTo: pPanel.contentView.leadingAnchor, constant: 10),
            pRow.trailingAnchor.constraint(equalTo: pPanel.contentView.trailingAnchor, constant: -14),
            pRow.centerYAnchor.constraint(equalTo: pPanel.contentView.centerYAnchor),
            pHP.heightAnchor.constraint(equalToConstant: 5),
            pSoul.heightAnchor.constraint(equalToConstant: 2),

            energyPanel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            energyPanel.bottomAnchor.constraint(equalTo: pPanel.topAnchor, constant: -16),
            energyPanel.widthAnchor.constraint(equalToConstant: 56),
            energyPanel.heightAnchor.constraint(equalToConstant: 56),
            energyText.centerXAnchor.constraint(equalTo: energyPanel.contentView.centerXAnchor),
            energyText.centerYAnchor.constraint(equalTo: energyPanel.contentView.centerYAnchor, constant: -3),
            enLabel.centerXAnchor.constraint(equalTo: energyPanel.contentView.centerXAnchor),
            enLabel.topAnchor.constraint(equalTo: energyText.bottomAnchor, constant: -1),
            energyRing.centerXAnchor.constraint(equalTo: energyPanel.centerXAnchor),
            energyRing.centerYAnchor.constraint(equalTo: energyPanel.centerYAnchor),
            energyRing.widthAnchor.constraint(equalToConstant: 62),
            energyRing.heightAnchor.constraint(equalToConstant: 62),

            nextCard.centerXAnchor.constraint(equalTo: energyPanel.centerXAnchor),
            nextCard.bottomAnchor.constraint(equalTo: energyPanel.topAnchor, constant: -14),
            nextCard.widthAnchor.constraint(equalToConstant: 30),
            nextCard.heightAnchor.constraint(equalToConstant: 42),
            nextLabel.centerXAnchor.constraint(equalTo: nextCard.centerXAnchor),
            nextLabel.bottomAnchor.constraint(equalTo: nextCard.topAnchor, constant: -3),

            hand.leadingAnchor.constraint(equalTo: energyPanel.trailingAnchor, constant: 12),
            hand.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -14),
            hand.bottomAnchor.constraint(equalTo: pPanel.topAnchor, constant: -12),

            power.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            power.bottomAnchor.constraint(equalTo: hand.topAnchor, constant: -16),

            benchRow.leadingAnchor.constraint(equalTo: hand.leadingAnchor),
            benchRow.bottomAnchor.constraint(equalTo: hand.topAnchor, constant: -16),

            comboLabel.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 20),
            comboLabel.centerYAnchor.constraint(equalTo: safe.centerYAnchor, constant: -50),
            chainLabel.leadingAnchor.constraint(equalTo: comboLabel.leadingAnchor),
            chainLabel.topAnchor.constraint(equalTo: comboLabel.bottomAnchor, constant: 2),
        ])
        root.bringSubviewToFront(fxLayer)
        teamChanged()
        enemyChanged()
    }

    private func toggleAuto() {
        guard let s = screen else { return }
        s.player.auto.toggle()
        s.player.charging = false
        autoBtn.configuration?.title = L(s.player.auto ? "battle.autoOn" : "battle.auto")
        autoBtn.tintColor = s.player.auto ? Theme.accent.withAlphaComponent(0.85) : Theme.smoke
        autoBtn.configuration?.baseForegroundColor = s.player.auto ? Theme.ink : .white
    }

    func teamChanged() {
        guard let s = screen else { return }
        let c = s.player.current
        pPortrait.image = Portraits.image(c.def, .bust, size: CGSize(width: 64, height: 64))
        pPortrait.backgroundColor = c.def.aura.withAlphaComponent(0.3)
        pSpeed.image = UIImage(systemName: c.def.speed.icon, withConfiguration: UIImage.SymbolConfiguration(pointSize: 10, weight: .semibold))
    }

    private func enemyChanged() {
        guard let s = screen else { return }
        let c = s.enemy.current
        ePortrait.image = Portraits.image(c.def, .bust, size: CGSize(width: 64, height: 64))
        ePortrait.backgroundColor = c.def.aura.withAlphaComponent(0.3)
    }

    // MARK: Update

    func update(dt: Double) {
        guard let s = screen, let p = s.player, let e = s.enemy else { return }
        let pc = p.current
        let ec = e.current
        set(pName, pc.def.name.s)
        set(eName, ec.def.name.s)
        set(eLevel, "Lv\(ec.level)")
        set(pHPText, "\(Int(max(0, pc.hp)))")
        set(eHPText, "\(Int(max(0, ec.hp)))")
        pHP.set(pc.hpFraction)
        eHP.set(ec.hpFraction)
        pHP.tick(CGFloat(dt))
        eHP.tick(CGFloat(dt))
        pHP.color = pc.hpFraction > 0.25 ? Theme.hp : Theme.hpEnemy
        pSoul.set(CGFloat(p.soul / 100))
        eSoul.set(CGFloat(e.soul / 100))
        set(timer, "\(Int(ceil(s.timeLeft)))")
        timer.textColor = s.timeLeft < 20 ? Theme.hpEnemy : .white

        let zone = RangeZone.of(s.dist(pc, ec))
        if zone != lastRange {
            lastRange = zone
            Glass.setCaption(rangeChip, L(zone.key))
        }

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
        if let n = pc.nextCard, n.id != lastNext {
            lastNext = n.id
            nextCard.image = CardArt.image(n)
        }
        updatePower(ultCard, ready: p.ultimateReady, card: pc.def.ultimateCard)
        updatePower(eclipseCard, ready: p.eclipseReady, card: Roster.eclipseCard)
        for (i, dot) in shardDots.enumerated() {
            let lit = (Tune.shardsNeeded - 1 - i) < p.shards
            dot.backgroundColor = lit ? Theme.accent : .clear
            dot.layer.borderColor = (lit ? Theme.accent : UIColor(white: 1, alpha: 0.4)).cgColor
        }
        let pipCount = Int(p.dodge / Tune.dodgeCost)
        for (i, pip) in pips.enumerated() {
            pip.backgroundColor = i < pipCount ? Theme.energy : UIColor(white: 1, alpha: 0.18)
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
        if e.active != lastEActive {
            lastEActive = e.active
            enemyChanged()
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
            cv.alpha = 0
            cv.transform = CGAffineTransform(translationX: 0, y: 20)
            UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                cv.alpha = 1
                cv.transform = .identity
            }
            Sound.play(.ultimate)
        } else if !ready && !cv.isHidden {
            cv.isHidden = true
            cv.show(nil, affordable: false)
        }
    }

    private func set(_ l: UILabel, _ t: String) { if l.text != t { l.text = t } }

    // MARK: Events

    func cardPlayed(_ idx: Int) {
        if idx >= 0 && idx < cards.count { cards[idx].playAnimation() }
        else if idx == -1 { ultCard.playAnimation() } else if idx == -2 { eclipseCard.playAnimation() }
    }

    func combo(_ n: Int) {
        guard n >= 2 else { return }
        comboLabel.text = L10n.f("battle.hits", n)
        pop(comboLabel)
    }

    func chain(_ n: Int) {
        Glass.setCaption(chainLabel, L10n.f("battle.chain", n))
        pop(chainLabel)
    }

    private func pop(_ l: UILabel) {
        l.layer.removeAllAnimations()
        l.alpha = 1
        l.transform = CGAffineTransform(scaleX: 1.25, y: 1.25)
        UIView.animate(withDuration: 0.12, animations: { l.transform = .identity }) { _ in
            UIView.animate(withDuration: 0.3, delay: 0.9, options: [.allowUserInteraction], animations: { l.alpha = 0 })
        }
    }

    func flashEvade() {
        let v = UIView(frame: root.bounds)
        v.backgroundColor = Theme.energy.withAlphaComponent(0.1)
        v.isUserInteractionEnabled = false
        fxLayer.addSubview(v)
        UIView.animate(withDuration: 0.25, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    /// Anime focus lines converging on the action.
    func speedLines(_ duration: Double) {
        let b = root.bounds
        let v = UIView(frame: b)
        v.isUserInteractionEnabled = false
        let shape = CAShapeLayer()
        let path = UIBezierPath()
        let c = CGPoint(x: b.midX, y: b.midY * 0.85)
        let R = hypot(b.width, b.height)
        for _ in 0..<64 {
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let w = CGFloat.random(in: 0.004...0.016)
            let inner = R * CGFloat.random(in: 0.3...0.42)
            path.move(to: CGPoint(x: c.x + cos(a - w) * R, y: c.y + sin(a - w) * R))
            path.addLine(to: CGPoint(x: c.x + cos(a) * inner, y: c.y + sin(a) * inner))
            path.addLine(to: CGPoint(x: c.x + cos(a + w) * R, y: c.y + sin(a + w) * R))
            path.close()
        }
        shape.path = path.cgPath
        shape.fillColor = UIColor(white: 1, alpha: 0.45).cgColor
        v.layer.addSublayer(shape)
        fxLayer.insertSubview(v, at: 0)
        v.alpha = 0
        UIView.animate(withDuration: 0.06, animations: { v.alpha = 1 }) { _ in
            UIView.animate(withDuration: 0.2, delay: max(0, duration - 0.2), options: [], animations: { v.alpha = 0 },
                           completion: { _ in v.removeFromSuperview() })
        }
    }

    func screenFlash(_ color: UIColor) {
        let v = UIView(frame: root.bounds)
        v.backgroundColor = color.lighter(0.6).withAlphaComponent(0.25)
        v.isUserInteractionEnabled = false
        fxLayer.addSubview(v)
        UIView.animate(withDuration: 0.4, animations: { v.alpha = 0 }) { _ in v.removeFromSuperview() }
    }

    /// Big centered word (READY / FIGHT / K.O.) — thin, wide-tracked.
    func banner(_ text: String, color: UIColor, big: Bool, duration: Double) {
        let l = UILabel()
        l.attributedText = NSAttributedString(string: text, attributes: [
            .font: Glass.font(big ? 44 : 26, .bold), .foregroundColor: color, .kern: L10n.isZH ? 4 : 8,
        ])
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.5
        l.layer.shadowRadius = 10
        l.layer.shadowOffset = .zero
        l.sizeToFit()
        l.center = CGPoint(x: root.bounds.midX, y: root.bounds.midY * 0.78)
        l.isUserInteractionEnabled = false
        fxLayer.addSubview(l)
        l.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        l.alpha = 0
        UIView.animate(withDuration: 0.2, animations: {
            l.transform = .identity
            l.alpha = 1
        }) { _ in
            UIView.animate(withDuration: 0.3, delay: duration, options: [], animations: {
                l.alpha = 0
            }, completion: { _ in l.removeFromSuperview() })
        }
    }

    func rangeStart(_ zone: RangeZone) {
        moveBanner(L10n.f("range.start", L(zone.key)), kind: .blast, side: screen!.player, symbol: "scope")
    }

    /// Glass pill announcing a special art / effect / tag-in.
    func moveBanner(_ name: String, kind: CardKind, side: Side, symbol: String? = nil) {
        let panel = Glass.panel(radius: 17)
        let st = CardArt.style(Card(id: "banner", name: Text(name, name), kind: kind, cost: 0, power: 0, hits: 0))
        let icon = UIImageView(image: UIImage(systemName: symbol ?? (side.isPlayer ? st.fallback : "exclamationmark.triangle.fill"),
                                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)))
        icon.tintColor = side.isPlayer ? st.color : Theme.hpEnemy
        let l = Glass.label(name, size: 14, weight: .semibold)
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
                ? panel.bottomAnchor.constraint(equalTo: root.centerYAnchor, constant: 40)
                : panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 104),
        ])
        panel.alpha = 0
        panel.transform = CGAffineTransform(translationX: 0, y: 8)
        UIView.animate(withDuration: 0.25, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0, animations: {
            panel.alpha = 1
            panel.transform = .identity
        }) { _ in
            UIView.animate(withDuration: 0.25, delay: 1.1, options: [], animations: { panel.alpha = 0 },
                           completion: { _ in panel.removeFromSuperview() })
        }
    }

    /// Ultimate cut-in: dark veil, thin accent rules, full-body render, quiet typography.
    func ultimateCutIn(_ def: FighterDef, side: Side) -> Double {
        let duration = 1.6
        let v = UIView(frame: root.bounds)
        v.isUserInteractionEnabled = false
        v.backgroundColor = UIColor(white: 0, alpha: 0.62)
        let midY = v.bounds.midY
        for dy in [CGFloat(-150), CGFloat(110)] {
            let rule = UIView(frame: CGRect(x: 0, y: midY + dy, width: v.bounds.width, height: 1))
            rule.backgroundColor = def.look.aura.withAlphaComponent(0.8)
            v.addSubview(rule)
            rule.transform = CGAffineTransform(scaleX: 0.01, y: 1)
            UIView.animate(withDuration: 0.35, delay: 0.05, options: [.curveEaseOut]) { rule.transform = .identity }
        }
        let glow = UIView(frame: CGRect(x: 0, y: midY - 150, width: v.bounds.width, height: 260))
        let gl = CAGradientLayer()
        gl.frame = glow.bounds
        gl.colors = [def.look.aura.withAlphaComponent(0).cgColor, def.look.aura.withAlphaComponent(0.35).cgColor, def.look.aura.withAlphaComponent(0).cgColor]
        gl.startPoint = CGPoint(x: side.isPlayer ? 0 : 1, y: 0.5)
        gl.endPoint = CGPoint(x: side.isPlayer ? 1 : 0, y: 0.5)
        glow.layer.addSublayer(gl)
        v.addSubview(glow)
        let art = UIImageView(image: Portraits.image(def, .body, size: CGSize(width: 240, height: 320)))
        art.contentMode = .scaleAspectFit
        art.frame = CGRect(x: side.isPlayer ? -10 : v.bounds.width - 230, y: midY - 205, width: 240, height: 320)
        v.addSubview(art)
        let tag = Glass.caption(L("battle.ultimate"), size: 11, color: def.look.aura.lighter(0.4))
        tag.translatesAutoresizingMaskIntoConstraints = true
        let name = UILabel()
        name.text = def.ultimateName.s
        name.font = Glass.font(28, .bold)
        name.textColor = .white
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.5
        let textX: CGFloat = side.isPlayer ? v.bounds.width * 0.46 : 22
        let textW = v.bounds.width * 0.5
        tag.frame = CGRect(x: textX, y: midY + 40, width: textW, height: 16)
        tag.textAlignment = .left
        name.frame = CGRect(x: textX, y: midY + 56, width: textW, height: 36)
        v.addSubview(tag)
        v.addSubview(name)
        fxLayer.addSubview(v)
        art.alpha = 0
        art.transform = CGAffineTransform(translationX: side.isPlayer ? -60 : 60, y: 0)
        name.alpha = 0
        tag.alpha = 0
        v.alpha = 0
        UIView.animate(withDuration: 0.15) { v.alpha = 1 }
        UIView.animate(withDuration: 0.35, delay: 0.05, usingSpringWithDamping: 0.85, initialSpringVelocity: 0) {
            art.alpha = 1
            art.transform = .identity
        }
        UIView.animate(withDuration: 0.25, delay: 0.25) {
            name.alpha = 1
            tag.alpha = 1
        }
        UIView.animate(withDuration: 0.2, delay: duration - 0.2, options: []) { v.alpha = 0 } completion: { _ in v.removeFromSuperview() }
        return duration
    }

    func eclipseCutIn(_ side: Side) -> Double {
        let duration = 1.5
        let v = UIView(frame: root.bounds)
        v.isUserInteractionEnabled = false
        v.backgroundColor = UIColor(white: 0, alpha: 0.78)
        let title = UILabel()
        title.attributedText = NSAttributedString(string: L("battle.eclipse"), attributes: [
            .font: Glass.font(28, .bold), .foregroundColor: Theme.accent, .kern: 6,
        ])
        title.textAlignment = .center
        title.frame = CGRect(x: 0, y: v.bounds.midY + 80, width: v.bounds.width, height: 40)
        v.addSubview(title)
        let alive = side.team.filter { !$0.isKO }
        let w = v.bounds.width / CGFloat(max(1, alive.count))
        for (i, c) in alive.enumerated() {
            let iv = UIImageView(image: Portraits.image(c.def, .body, size: CGSize(width: 180, height: 240)))
            iv.contentMode = .scaleAspectFit
            iv.frame = CGRect(x: CGFloat(i) * w, y: v.bounds.midY - 190, width: w, height: 250)
            iv.alpha = 0
            v.addSubview(iv)
            UIView.animate(withDuration: 0.25, delay: Double(i) * 0.12) { iv.alpha = 1 }
        }
        fxLayer.addSubview(v)
        v.alpha = 0
        UIView.animate(withDuration: 0.15) { v.alpha = 1 }
        UIView.animate(withDuration: 0.2, delay: duration - 0.2, options: []) { v.alpha = 0 } completion: { _ in v.removeFromSuperview() }
        return duration
    }

    func finalBanner(won: Bool) {
        let panel = Glass.panel(radius: 24)
        let l = UILabel()
        l.attributedText = NSAttributedString(string: L(won ? "battle.victory" : "battle.defeat"), attributes: [
            .font: Glass.font(30, .bold), .foregroundColor: won ? Theme.accent : Theme.text2, .kern: L10n.isZH ? 6 : 10,
        ])
        l.translatesAutoresizingMaskIntoConstraints = false
        panel.contentView.addSubview(l)
        root.insertSubview(panel, belowSubview: fxLayer)
        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            panel.topAnchor.constraint(equalTo: safe.topAnchor, constant: 130),
            l.leadingAnchor.constraint(equalTo: panel.contentView.leadingAnchor, constant: 32),
            l.trailingAnchor.constraint(equalTo: panel.contentView.trailingAnchor, constant: -32),
            l.topAnchor.constraint(equalTo: panel.contentView.topAnchor, constant: 14),
            l.bottomAnchor.constraint(equalTo: panel.contentView.bottomAnchor, constant: -14),
        ])
        panel.alpha = 0
        UIView.animate(withDuration: 0.35) { panel.alpha = 1 }
    }

    // MARK: Pause

    func openPause() {
        guard let s = screen else { return }
        pauseModal = s.presentModal(width: 290) { stack in
            stack.addArrangedSubview(Glass.label(L("battle.paused"), size: 20, weight: .semibold))
            let resume = Glass.button(L("battle.resume"), symbol: "play.fill", style: .primary, fontSize: 16) { [weak self] in
                self?.screen?.setPaused(false)
            }
            let quit = Glass.button(L("battle.retreat"), symbol: "flag.fill", style: .secondary, fontSize: 16) { [weak self] in
                self?.screen?.retreat()
            }
            for b in [resume, quit] {
                b.heightAnchor.constraint(equalToConstant: 48).isActive = true
                stack.addArrangedSubview(b)
            }
        }
    }

    func closePause() {
        screen?.dismissModal(pauseModal)
        pauseModal = nil
    }
}

/// Round portrait with a thin HP ring and cooldown/KO veil.
final class PortraitView: UIView {
    var onTap: (() -> Void)?
    private let face = UIImageView()
    private let ring = RingView(color: Theme.hp)
    private let veil = UIView()
    private let label = Glass.label("", size: 11, weight: .semibold, mono: true)
    private var lastKey = ""

    init(image: UIImage?, tint: UIColor, interactive: Bool, size: CGFloat) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let inner = size - 6
        face.image = image
        face.contentMode = .scaleAspectFill
        face.clipsToBounds = true
        face.layer.cornerRadius = inner / 2
        face.backgroundColor = tint.withAlphaComponent(0.3)
        face.translatesAutoresizingMaskIntoConstraints = false
        addSubview(face)
        ring.lineWidth = 2
        addSubview(ring)
        veil.backgroundColor = UIColor(white: 0, alpha: 0.6)
        veil.layer.cornerRadius = inner / 2
        veil.isHidden = true
        veil.translatesAutoresizingMaskIntoConstraints = false
        addSubview(veil)
        addSubview(label)
        for v in [face, ring, veil, label] as [UIView] { v.isUserInteractionEnabled = false }
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
            face.centerXAnchor.constraint(equalTo: centerXAnchor),
            face.centerYAnchor.constraint(equalTo: centerYAnchor),
            face.widthAnchor.constraint(equalToConstant: inner),
            face.heightAnchor.constraint(equalToConstant: inner),
            veil.centerXAnchor.constraint(equalTo: centerXAnchor),
            veil.centerYAnchor.constraint(equalTo: centerYAnchor),
            veil.widthAnchor.constraint(equalToConstant: inner),
            veil.heightAnchor.constraint(equalToConstant: inner),
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
        ring.color = hp > 0.25 ? Theme.hp : Theme.hpEnemy
        alpha = active ? 1 : 0.8
        veil.isHidden = !(ko || cooldown > 0)
        label.text = ko ? "KO" : (cooldown > 0 ? "\(cooldown)" : "")
    }
}
