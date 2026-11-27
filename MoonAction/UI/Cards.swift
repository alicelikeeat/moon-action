import UIKit

/// Minimal card faces: dark glass-like base, a thin colored edge, a single SF Symbol glyph.
@MainActor
enum CardArt {
    private static var cache: [String: UIImage] = [:]

    struct Style {
        let color: UIColor
        let symbol: String
        let fallback: String
        let labelKey: String
    }

    static func style(_ card: Card) -> Style {
        switch card.kind {
        case .strike: return Style(color: Theme.strike, symbol: "figure.boxing", fallback: "hand.raised.fill", labelKey: "kind.strike")
        case .blast: return Style(color: Theme.blast, symbol: "dot.radiowaves.right", fallback: "smallcircle.filled.circle", labelKey: "kind.blast")
        case .special: return Style(color: Theme.special, symbol: "sparkles", fallback: "sparkles", labelKey: "kind.special")
        case .ultimate: return Style(color: Theme.ultimate, symbol: "flame.fill", fallback: "flame.fill", labelKey: "kind.ultimate")
        case .eclipse: return Style(color: Theme.accent, symbol: "moon.fill", fallback: "moon.fill", labelKey: "kind.team")
        case .effect:
            switch card.effect {
            case .heal: return Style(color: Theme.effect, symbol: "cross.fill", fallback: "cross.fill", labelKey: "kind.heal")
            case .barrier: return Style(color: UIColor(hex: 0x8FD0FF), symbol: "shield.fill", fallback: "shield.fill", labelKey: "kind.barrier")
            case .powerUp: return Style(color: UIColor(hex: 0xFF9F6B), symbol: "arrow.up.forward", fallback: "arrow.up", labelKey: "kind.power")
            case .energy: return Style(color: Theme.energy, symbol: "bolt.fill", fallback: "bolt.fill", labelKey: "kind.energy")
            case .curse: return Style(color: UIColor(hex: 0xD49BFF), symbol: "eye.fill", fallback: "eye.fill", labelKey: "kind.curse")
            case .none: return Style(color: .gray, symbol: "questionmark", fallback: "questionmark", labelKey: "")
            }
        }
    }

    static func image(_ card: Card, size: CGSize = CGSize(width: 90, height: 126)) -> UIImage {
        let key = "\(card.id)-\(Int(size.width))"
        if let c = cache[key] { return c }
        let st = style(card)
        let premium = card.kind == .ultimate || card.kind == .eclipse
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let r: CGFloat = 12
            let path = UIBezierPath(roundedRect: rect.insetBy(dx: 0.5, dy: 0.5), cornerRadius: r)
            c.saveGState()
            path.addClip()
            let base = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(hex: 0x1D2130).cgColor, UIColor(hex: 0x0E1018).cgColor] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(base, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
            // soft color bloom behind the glyph
            let center = CGPoint(x: size.width / 2, y: size.height * 0.4)
            let bloom = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                   colors: [st.color.withAlphaComponent(0.32).cgColor, st.color.withAlphaComponent(0).cgColor] as CFArray,
                                   locations: [0, 1])!
            c.drawRadialGradient(bloom, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width * 0.62, options: [])
            // top edge
            c.setFillColor(st.color.cgColor)
            c.fill(CGRect(x: 0, y: 0, width: size.width, height: 3))
            c.restoreGState()

            let sym = UIImage(systemName: st.symbol) != nil ? st.symbol : st.fallback
            if let glyph = UIImage(systemName: sym, withConfiguration: UIImage.SymbolConfiguration(pointSize: size.width * 0.3, weight: .semibold))?
                .withTintColor(st.color, renderingMode: .alwaysOriginal) {
                glyph.draw(at: CGPoint(x: center.x - glyph.size.width / 2, y: center.y - glyph.size.height / 2))
            }
            let border = UIBezierPath(roundedRect: rect.insetBy(dx: 0.75, dy: 0.75), cornerRadius: r)
            border.lineWidth = premium ? 1.5 : 1
            (premium ? Theme.accent : UIColor(white: 1, alpha: 0.16)).setStroke()
            border.stroke()
        }
        cache[key] = img
        return img
    }
}

/// A hand card: minimal face, cost badge, name; tap to play.
final class CardView: UIControl {
    private let art = UIImageView()
    private let name = UILabel()
    private let kind = UILabel()
    private let badge = UIView()
    private let cost = UILabel()
    private let dim = UIView()
    private let hintBorder = UIView()
    private let linkIcon = UIImageView(image: UIImage(systemName: "link", withConfiguration: UIImage.SymbolConfiguration(pointSize: 9, weight: .bold)))
    private let chaseTag = UILabel()
    private var hintKey = ""
    private(set) var card: Card?
    private var key = ""
    var onPlay: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 8
        layer.shadowOffset = CGSize(width: 0, height: 4)

        art.contentMode = .scaleToFill
        art.layer.cornerRadius = 12
        art.layer.cornerCurve = .continuous
        art.clipsToBounds = true
        addSubview(art)

        kind.font = Glass.font(8, .semibold)
        kind.textAlignment = .center
        addSubview(kind)

        name.font = Glass.font(11, .semibold)
        name.textColor = .white
        name.numberOfLines = 2
        name.textAlignment = .center
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.7
        addSubview(name)

        badge.backgroundColor = UIColor(hex: 0x0E1018)
        badge.layer.cornerRadius = 10
        badge.layer.borderWidth = 1
        addSubview(badge)
        cost.font = Glass.mono(11, .bold)
        cost.textColor = .white
        cost.textAlignment = .center
        addSubview(cost)

        dim.backgroundColor = UIColor(white: 0, alpha: 0.55)
        dim.layer.cornerRadius = 12
        addSubview(dim)

        hintBorder.layer.cornerRadius = 12
        hintBorder.layer.cornerCurve = .continuous
        hintBorder.layer.borderWidth = 2
        hintBorder.layer.borderColor = Theme.energy.cgColor
        hintBorder.isHidden = true
        addSubview(hintBorder)
        linkIcon.tintColor = Theme.ink
        linkIcon.backgroundColor = Theme.energy
        linkIcon.contentMode = .center
        linkIcon.layer.cornerRadius = 8
        linkIcon.clipsToBounds = true
        linkIcon.isHidden = true
        addSubview(linkIcon)
        chaseTag.font = Glass.font(9, .bold)
        chaseTag.textColor = Theme.ink
        chaseTag.backgroundColor = Theme.accent
        chaseTag.textAlignment = .center
        chaseTag.layer.cornerRadius = 7
        chaseTag.clipsToBounds = true
        chaseTag.isHidden = true
        addSubview(chaseTag)
        for v in [art, name, kind, badge, cost, dim, hintBorder, linkIcon, chaseTag] {
            v.isUserInteractionEnabled = false
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        NSLayoutConstraint.activate([
            art.leadingAnchor.constraint(equalTo: leadingAnchor),
            art.trailingAnchor.constraint(equalTo: trailingAnchor),
            art.topAnchor.constraint(equalTo: topAnchor),
            art.bottomAnchor.constraint(equalTo: bottomAnchor),
            dim.leadingAnchor.constraint(equalTo: leadingAnchor),
            dim.trailingAnchor.constraint(equalTo: trailingAnchor),
            dim.topAnchor.constraint(equalTo: topAnchor),
            dim.bottomAnchor.constraint(equalTo: bottomAnchor),
            name.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            name.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            name.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -7),
            kind.centerXAnchor.constraint(equalTo: centerXAnchor),
            kind.bottomAnchor.constraint(equalTo: name.topAnchor, constant: -1),
            badge.widthAnchor.constraint(equalToConstant: 20),
            badge.heightAnchor.constraint(equalToConstant: 20),
            badge.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5),
            badge.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            cost.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            cost.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
            hintBorder.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -2),
            hintBorder.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 2),
            hintBorder.topAnchor.constraint(equalTo: topAnchor, constant: -2),
            hintBorder.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 2),
            linkIcon.widthAnchor.constraint(equalToConstant: 16),
            linkIcon.heightAnchor.constraint(equalToConstant: 16),
            linkIcon.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            linkIcon.topAnchor.constraint(equalTo: topAnchor, constant: 7),
            chaseTag.heightAnchor.constraint(equalToConstant: 14),
            chaseTag.widthAnchor.constraint(greaterThanOrEqualToConstant: 32),
            chaseTag.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            chaseTag.topAnchor.constraint(equalTo: topAnchor, constant: 8),
        ])
        addTarget(self, action: #selector(down), for: .touchDown)
        addTarget(self, action: #selector(up), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func down() {
        UIView.animate(withDuration: 0.08) { self.art.transform = CGAffineTransform(scaleX: 0.95, y: 0.95) }
        onPlay?()
    }

    @objc private func up() {
        UIView.animate(withDuration: 0.12) { self.art.transform = .identity }
    }

    func show(_ card: Card?, affordable: Bool, animateIn: Bool = true) {
        let k = "\(card?.id ?? "-")|\(affordable)"
        guard k != key else { return }
        let changed = key.split(separator: "|").first.map(String.init) != (card?.id ?? "-")
        key = k
        self.card = card
        guard let card else {
            art.image = nil
            art.backgroundColor = UIColor(white: 1, alpha: 0.05)
            name.text = nil
            kind.text = nil
            badge.isHidden = true
            cost.isHidden = true
            dim.isHidden = true
            layer.removeAnimation(forKey: "glow")
            return
        }
        let st = CardArt.style(card)
        art.backgroundColor = nil
        art.image = CardArt.image(card)
        name.text = card.name.s
        kind.textColor = st.color
        Glass.setCaption(kind, L(st.labelKey))
        let free = card.kind == .ultimate || card.kind == .eclipse
        badge.isHidden = free
        cost.isHidden = free
        badge.layer.borderColor = st.color.withAlphaComponent(0.8).cgColor
        cost.text = "\(card.cost)"
        dim.isHidden = affordable
        if free {
            layer.shadowColor = Theme.accent.cgColor
            layer.shadowOpacity = 0.8
            let a = CABasicAnimation(keyPath: "shadowRadius")
            a.fromValue = 4
            a.toValue = 12
            a.duration = 0.7
            a.autoreverses = true
            a.repeatCount = .infinity
            layer.add(a, forKey: "glow")
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.35
            layer.removeAnimation(forKey: "glow")
        }
        if changed && animateIn {
            art.alpha = 0
            transform = restTransform.translatedBy(x: 30, y: 0)
            UIView.animate(withDuration: 0.32, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
                self.art.alpha = 1
                self.transform = self.restTransform
            }
        }
    }

    /// Chain / chase hints. Chain = colored border + link glyph; chase = text tag (takes priority).
    /// Both live on the right edge so the cost badge (top-left) stays readable.
    func setHint(chain: Bool, chase: Bool) {
        let k = "\(chain)|\(chase)"
        guard k != hintKey else { return }
        hintKey = k
        hintBorder.isHidden = !(chain || chase)
        hintBorder.layer.borderColor = (chase ? Theme.accent : Theme.energy).cgColor
        chaseTag.isHidden = !chase
        chaseTag.text = " " + L("card.chase") + " "
        linkIcon.isHidden = !chain || chase
    }

    /// Resting transform (fan tilt), restored after draw animations.
    var restTransform: CGAffineTransform = .identity {
        didSet { transform = restTransform }
    }

    /// Fly-off animation when the card is played.
    func playAnimation() {
        guard let snap = art.snapshotView(afterScreenUpdates: false), let sv = superview else { return }
        snap.frame = convert(art.frame, to: sv)
        sv.addSubview(snap)
        UIView.animate(withDuration: 0.32, delay: 0, options: [.curveEaseOut]) {
            snap.transform = CGAffineTransform(translationX: 0, y: -90).scaledBy(x: 1.15, y: 1.15)
            snap.alpha = 0
        } completion: { _ in snap.removeFromSuperview() }
    }
}
