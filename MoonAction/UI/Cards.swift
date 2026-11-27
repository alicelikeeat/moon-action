import UIKit

/// Procedurally illustrated card faces + the tappable card control.
@MainActor
enum CardArt {
    private static var cache: [String: UIImage] = [:]

    struct Style {
        let top: UIColor
        let bottom: UIColor
        let frame: UIColor
        let symbol: String?
        let label: String
    }

    static func style(_ card: Card) -> Style {
        switch card.kind {
        case .strike:
            return Style(top: UIColor(hex: 0xFF7A52), bottom: UIColor(hex: 0x8A1212), frame: UIColor(hex: 0xFFD2C2), symbol: nil, label: "STRIKE")
        case .blast:
            return Style(top: UIColor(hex: 0xFFE27A), bottom: UIColor(hex: 0xC2600A), frame: UIColor(hex: 0xFFF3C4), symbol: nil, label: "BLAST")
        case .special:
            return Style(top: UIColor(hex: 0x7BE7FF), bottom: UIColor(hex: 0x1F3FA8), frame: UIColor(hex: 0xE2FAFF), symbol: "sparkles", label: "SPECIAL")
        case .ultimate:
            return Style(top: UIColor(hex: 0xC86BFF), bottom: UIColor(hex: 0x2E0B5C), frame: UIColor(hex: 0xFFD45A), symbol: "flame.fill", label: "ULTIMATE")
        case .eclipse:
            return Style(top: UIColor(hex: 0x3A3A5A), bottom: UIColor(hex: 0x05050C), frame: UIColor(hex: 0xFFD45A), symbol: "moon.circle.fill", label: "TEAM")
        case .effect:
            switch card.effect {
            case .heal: return Style(top: UIColor(hex: 0x8CFF9E), bottom: UIColor(hex: 0x1C7A3A), frame: UIColor(hex: 0xE0FFE6), symbol: "cross.fill", label: "HEAL")
            case .barrier: return Style(top: UIColor(hex: 0x9FD8FF), bottom: UIColor(hex: 0x23508F), frame: UIColor(hex: 0xE6F5FF), symbol: "shield.fill", label: "BARRIER")
            case .powerUp: return Style(top: UIColor(hex: 0xFF9B5E), bottom: UIColor(hex: 0x9A2B0B), frame: UIColor(hex: 0xFFE3CF), symbol: "arrow.up.circle.fill", label: "POWER")
            case .energy: return Style(top: UIColor(hex: 0x8AF5FF), bottom: UIColor(hex: 0x0E6A80), frame: UIColor(hex: 0xE0FCFF), symbol: "bolt.fill", label: "ENERGY")
            case .curse: return Style(top: UIColor(hex: 0xD58CFF), bottom: UIColor(hex: 0x4A1070), frame: UIColor(hex: 0xF2DDFF), symbol: "eye.fill", label: "CURSE")
            case .none: return Style(top: .gray, bottom: .darkGray, frame: .white, symbol: "questionmark", label: "")
            }
        }
    }

    static func image(_ card: Card, size: CGSize = CGSize(width: 90, height: 126)) -> UIImage {
        let key = "\(card.name)-\(Int(size.width))"
        if let c = cache[key] { return c }
        let st = style(card)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let rect = CGRect(origin: .zero, size: size)
            let path = UIBezierPath(roundedRect: rect.insetBy(dx: 1, dy: 1), cornerRadius: 11)
            path.addClip()
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [st.top.cgColor, st.bottom.cgColor] as CFArray, locations: [0, 1])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: size.width * 0.4, y: size.height), options: [])

            // Radial speed rays
            let center = CGPoint(x: size.width / 2, y: size.height * 0.44)
            c.saveGState()
            c.setFillColor(UIColor(white: 1, alpha: 0.13).cgColor)
            let rays = 18
            for i in 0..<rays where i % 2 == 0 {
                let a0 = CGFloat(i) / CGFloat(rays) * 2 * .pi
                let a1 = CGFloat(i + 1) / CGFloat(rays) * 2 * .pi
                c.move(to: center)
                c.addLine(to: CGPoint(x: center.x + cos(a0) * 200, y: center.y + sin(a0) * 200))
                c.addLine(to: CGPoint(x: center.x + cos(a1) * 200, y: center.y + sin(a1) * 200))
                c.closePath()
            }
            c.fillPath()
            c.restoreGState()

            // Glow behind the icon
            let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                  colors: [UIColor(white: 1, alpha: 0.75).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray,
                                  locations: [0, 1])!
            c.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: size.width * 0.42, options: [])

            c.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor(white: 0, alpha: 0.5).cgColor)
            switch card.kind {
            case .strike: drawFist(c, center: center, scale: size.width / 90)
            case .blast: drawOrb(c, center: center, scale: size.width / 90, color: st.top)
            default:
                if let name = st.symbol,
                   let sym = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: size.width * 0.38, weight: .black))?
                    .withTintColor(.white, renderingMode: .alwaysOriginal) {
                    sym.draw(at: CGPoint(x: center.x - sym.size.width / 2, y: center.y - sym.size.height / 2))
                }
            }
            c.setShadow(offset: .zero, blur: 0, color: nil)

            // Inner frame
            let frame = UIBezierPath(roundedRect: rect.insetBy(dx: 4, dy: 4), cornerRadius: 8)
            frame.lineWidth = 2
            st.frame.withAlphaComponent(0.9).setStroke()
            frame.stroke()
            // Name strip
            let strip = CGRect(x: 4, y: size.height * 0.7, width: size.width - 8, height: size.height * 0.3 - 4)
            let sg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                                colors: [UIColor(white: 0, alpha: 0).cgColor, UIColor(white: 0, alpha: 0.65).cgColor] as CFArray,
                                locations: [0, 1])!
            c.drawLinearGradient(sg, start: CGPoint(x: 0, y: strip.minY), end: CGPoint(x: 0, y: strip.maxY), options: [])
        }
        cache[key] = img
        return img
    }

    private static func drawFist(_ c: CGContext, center: CGPoint, scale s: CGFloat) {
        c.setFillColor(UIColor.white.cgColor)
        c.setStrokeColor(UIColor(white: 0, alpha: 0.35).cgColor)
        c.setLineWidth(1.5 * s)
        let body = UIBezierPath(roundedRect: CGRect(x: center.x - 19 * s, y: center.y - 8 * s, width: 36 * s, height: 30 * s), cornerRadius: 9 * s)
        body.fill()
        body.stroke()
        for i in 0..<4 {
            let k = UIBezierPath(roundedRect: CGRect(x: center.x - 19 * s + CGFloat(i) * 9 * s, y: center.y - 20 * s, width: 9.5 * s, height: 17 * s),
                                 cornerRadius: 4.5 * s)
            k.fill()
            k.stroke()
        }
        let thumb = UIBezierPath(roundedRect: CGRect(x: center.x - 24 * s, y: center.y + 1 * s, width: 22 * s, height: 10 * s), cornerRadius: 5 * s)
        thumb.fill()
        thumb.stroke()
        // impact lines
        c.setStrokeColor(UIColor(white: 1, alpha: 0.85).cgColor)
        c.setLineWidth(3 * s)
        for (dx, dy) in [(24.0, -16.0), (28.0, 0.0), (24.0, 16.0)] {
            c.move(to: CGPoint(x: center.x + CGFloat(dx) * s, y: center.y + CGFloat(dy) * s))
            c.addLine(to: CGPoint(x: center.x + CGFloat(dx + 10) * s, y: center.y + CGFloat(dy * 1.4) * s))
        }
        c.strokePath()
    }

    private static func drawOrb(_ c: CGContext, center: CGPoint, scale s: CGFloat, color: UIColor) {
        // comet tail
        c.setFillColor(UIColor(white: 1, alpha: 0.55).cgColor)
        c.move(to: CGPoint(x: center.x - 34 * s, y: center.y + 22 * s))
        c.addLine(to: CGPoint(x: center.x - 4 * s, y: center.y - 14 * s))
        c.addLine(to: CGPoint(x: center.x + 10 * s, y: center.y + 6 * s))
        c.closePath()
        c.fillPath()
        let orbCenter = CGPoint(x: center.x + 6 * s, y: center.y - 4 * s)
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [UIColor.white.cgColor, color.lighter(0.4).cgColor, color.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0, 0.55, 1])!
        c.drawRadialGradient(g, startCenter: orbCenter, startRadius: 0, endCenter: orbCenter, endRadius: 24 * s, options: [])
    }
}

/// A hand card: illustrated face, cost gem, name; tap to play.
final class CardView: UIControl {
    private let art = UIImageView()
    private let name = UILabel()
    private let kind = UILabel()
    private let gem = UIView()
    private let cost = UILabel()
    private let dim = UIView()
    private(set) var card: Card?
    private var key = ""
    var onPlay: (() -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        translatesAutoresizingMaskIntoConstraints = false
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.45
        layer.shadowRadius = 6
        layer.shadowOffset = CGSize(width: 0, height: 3)

        art.contentMode = .scaleToFill
        art.layer.cornerRadius = 11
        art.layer.cornerCurve = .continuous
        art.clipsToBounds = true
        art.translatesAutoresizingMaskIntoConstraints = false
        addSubview(art)

        kind.font = Glass.font(9, .heavy)
        kind.textColor = UIColor(white: 1, alpha: 0.9)
        kind.textAlignment = .center
        kind.translatesAutoresizingMaskIntoConstraints = false
        addSubview(kind)

        name.font = Glass.font(11, .heavy)
        name.textColor = .white
        name.numberOfLines = 2
        name.textAlignment = .center
        name.adjustsFontSizeToFitWidth = true
        name.minimumScaleFactor = 0.7
        name.layer.shadowColor = UIColor.black.cgColor
        name.layer.shadowOpacity = 0.8
        name.layer.shadowRadius = 2
        name.layer.shadowOffset = .zero
        name.translatesAutoresizingMaskIntoConstraints = false
        addSubview(name)

        gem.backgroundColor = UIColor(hex: 0x10142A)
        gem.layer.borderColor = UIColor(hex: 0x7FE8FF).cgColor
        gem.layer.borderWidth = 2
        gem.layer.cornerRadius = 4
        gem.transform = CGAffineTransform(rotationAngle: .pi / 4)
        gem.translatesAutoresizingMaskIntoConstraints = false
        addSubview(gem)
        cost.font = Glass.font(13, .black)
        cost.textColor = .white
        cost.textAlignment = .center
        cost.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cost)

        dim.backgroundColor = UIColor(white: 0, alpha: 0.5)
        dim.layer.cornerRadius = 11
        dim.isUserInteractionEnabled = false
        dim.translatesAutoresizingMaskIntoConstraints = false
        addSubview(dim)

        for v in [art, name, kind, gem, cost, dim] { v.isUserInteractionEnabled = false }

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
            name.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -6),
            kind.centerXAnchor.constraint(equalTo: centerXAnchor),
            kind.bottomAnchor.constraint(equalTo: name.topAnchor, constant: -1),
            gem.widthAnchor.constraint(equalToConstant: 22),
            gem.heightAnchor.constraint(equalToConstant: 22),
            gem.centerXAnchor.constraint(equalTo: leadingAnchor, constant: 14),
            gem.centerYAnchor.constraint(equalTo: topAnchor, constant: 14),
            cost.centerXAnchor.constraint(equalTo: gem.centerXAnchor),
            cost.centerYAnchor.constraint(equalTo: gem.centerYAnchor),
        ])
        addTarget(self, action: #selector(down), for: .touchDown)
        addTarget(self, action: #selector(up), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    @objc private func down() {
        UIView.animate(withDuration: 0.08) { self.art.transform = CGAffineTransform(scaleX: 0.94, y: 0.94) }
        onPlay?()
    }

    @objc private func up() {
        UIView.animate(withDuration: 0.12) { self.art.transform = .identity }
    }

    func show(_ card: Card?, affordable: Bool, animateIn: Bool = true) {
        let k = "\(card?.name ?? "-")|\(affordable)"
        guard k != key else { return }
        let changed = key.split(separator: "|").first.map(String.init) != (card?.name ?? "-")
        key = k
        self.card = card
        guard let card else {
            art.image = nil
            art.backgroundColor = UIColor(white: 1, alpha: 0.08)
            name.text = nil
            kind.text = nil
            gem.isHidden = true
            cost.isHidden = true
            dim.isHidden = true
            layer.removeAnimation(forKey: "glow")
            return
        }
        art.backgroundColor = nil
        art.image = CardArt.image(card)
        name.text = card.name
        kind.text = CardArt.style(card).label
        let free = card.kind == .ultimate || card.kind == .eclipse
        gem.isHidden = free
        cost.isHidden = free
        cost.text = "\(card.cost)"
        dim.isHidden = affordable
        if free {
            layer.shadowColor = UIColor.maCoin.cgColor
            let a = CABasicAnimation(keyPath: "shadowRadius")
            a.fromValue = 4
            a.toValue = 14
            a.duration = 0.5
            a.autoreverses = true
            a.repeatCount = .infinity
            layer.shadowOpacity = 0.9
            layer.add(a, forKey: "glow")
        } else {
            layer.shadowColor = UIColor.black.cgColor
            layer.shadowOpacity = 0.45
            layer.removeAnimation(forKey: "glow")
        }
        if changed && animateIn {
            art.alpha = 0
            transform = transform.translatedBy(x: 40, y: 0)
            let base = restTransform
            UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
                self.art.alpha = 1
                self.transform = base
            }
        }
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
        UIView.animate(withDuration: 0.35, delay: 0, options: [.curveEaseOut]) {
            snap.transform = CGAffineTransform(translationX: 0, y: -120).scaledBy(x: 1.3, y: 1.3)
            snap.alpha = 0
        } completion: { _ in snap.removeFromSuperview() }
    }
}
