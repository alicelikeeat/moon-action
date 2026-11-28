import UIKit

/// Native iOS "Liquid Glass" helpers.
/// On iOS 26+ (built with the iOS 26 SDK) these use `UIGlassEffect` and the
/// `.glass()` / `.prominentGlass()` button configurations. Older systems fall
/// back to the closest native material (blur) so the app still runs on iOS 15+.
enum GlassStyle {
    case regular     // clear glass, white content
    case prominent   // glass tinted with the button's tint color
    case clear
    case primary     // gold accent, dark content
    case secondary   // dark smoked glass, white content
}

/// Design tokens for a calm, minimal look.
enum Theme {
    static let accent = UIColor(hex: 0xF2C46D)          // moon gold
    static let ink = UIColor(hex: 0x14161F)             // dark content on gold
    static let text = UIColor.white
    static let text2 = UIColor(white: 1, alpha: 0.62)
    static let text3 = UIColor(white: 1, alpha: 0.38)
    static let smoke = UIColor(white: 0.04, alpha: 0.42) // glass tint
    static let hp = UIColor(hex: 0x7EE2A8)
    static let hpEnemy = UIColor(hex: 0xFF7A70)
    static let energy = UIColor(hex: 0x7FD8FF)
    static let strike = UIColor(hex: 0xFF6B5B)
    static let blast = UIColor(hex: 0xF2C46D)
    static let special = UIColor(hex: 0x6FC3FF)
    static let ultimate = UIColor(hex: 0xC49BFF)
    static let effect = UIColor(hex: 0x7EE2A8)
}

@MainActor
enum Glass {
    static var isLiquidGlass: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .semibold, rounded: Bool = false) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if rounded, let d = base.fontDescriptor.withDesign(.rounded) { return UIFont(descriptor: d, size: size) }
        return base
    }

    static func mono(_ size: CGFloat, _ weight: UIFont.Weight = .semibold) -> UIFont {
        UIFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
    }

    static func configuration(_ style: GlassStyle, tint: UIColor?) -> UIButton.Configuration {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            var c: UIButton.Configuration
            switch style {
            case .regular: c = .glass()
            case .clear: c = .clearGlass()
            case .prominent, .primary, .secondary: c = .prominentGlass()
            }
            c.baseForegroundColor = style == .primary ? Theme.ink : .white
            c.cornerStyle = .capsule
            return c
        }
        #endif
        var c = UIButton.Configuration.filled()
        c.baseForegroundColor = style == .primary ? Theme.ink : .white
        switch style {
        case .prominent, .primary:
            c.baseBackgroundColor = nil // follows tintColor
        case .regular, .clear, .secondary:
            c.baseBackgroundColor = UIColor(white: 0.05, alpha: 0.35)
            c.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        c.background.strokeColor = UIColor(white: 1, alpha: 0.18)
        c.background.strokeWidth = 0.5
        c.cornerStyle = .capsule
        return c
    }

    /// A glass button. `symbol` is an SF Symbol name.
    static func button(_ title: String? = nil, subtitle: String? = nil, symbol: String? = nil,
                       style: GlassStyle = .regular, tint: UIColor? = nil, fontSize: CGFloat = 16,
                       action: (() -> Void)? = nil) -> UIButton {
        var c = configuration(style, tint: tint)
        c.title = title
        c.subtitle = subtitle
        let f = font(fontSize, .semibold)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a
            a.font = f
            return a
        }
        let sf = font(max(10, fontSize * 0.68), .medium)
        c.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a
            a.font = sf
            return a
        }
        c.titleAlignment = .center
        if let symbol {
            c.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize * 0.9, weight: .semibold))
            c.imagePadding = title == nil ? 0 : 7
        }
        c.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12)
        let b = UIButton(configuration: c)
        switch style {
        case .primary: b.tintColor = tint ?? Theme.accent
        case .secondary: b.tintColor = tint ?? Theme.smoke
        default: if let tint { b.tintColor = tint }
        }
        if let action {
            b.addAction(UIAction { _ in
                Sound.play(.ui)
                Haptics.select()
                action()
            }, for: .touchUpInside)
        }
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    /// Adds press-and-hold callbacks to a control.
    static func hold(_ b: UIControl, down: @escaping () -> Void, up: @escaping () -> Void) {
        b.addAction(UIAction { _ in down() }, for: .touchDown)
        b.addAction(UIAction { _ in up() }, for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    /// A smoked glass surface (dark tint for legibility). Put content inside `contentView`.
    static func panel(radius: CGFloat, tint: UIColor? = nil, interactive: Bool = false) -> UIVisualEffectView {
        let t = tint ?? Theme.smoke
        let v: UIVisualEffectView
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let e = UIGlassEffect(style: .regular)
            e.isInteractive = interactive
            e.tintColor = t
            v = UIVisualEffectView(effect: e)
        } else {
            v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            v.contentView.backgroundColor = t
        }
        #else
        v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        v.contentView.backgroundColor = t
        #endif
        v.layer.cornerRadius = radius
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    static func label(_ text: String = "", size: CGFloat, weight: UIFont.Weight = .semibold,
                      color: UIColor = .white, align: NSTextAlignment = .center, mono: Bool = false) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = mono ? Glass.mono(size, weight) : font(size, weight)
        l.textColor = color
        l.textAlignment = align
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.6
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }

    /// Small uppercase caption with letter spacing.
    static func caption(_ text: String, size: CGFloat = 10, color: UIColor = Theme.text2) -> UILabel {
        let l = label("", size: size, weight: .semibold, color: color)
        setCaption(l, text)
        return l
    }

    static func setCaption(_ l: UILabel, _ text: String) {
        l.attributedText = NSAttributedString(string: L10n.isZH ? text : text.uppercased(), attributes: [.kern: L10n.isZH ? 1.0 : 1.6])
    }

    static func size(_ v: UIView, _ w: CGFloat, _ h: CGFloat) {
        v.widthAnchor.constraint(equalToConstant: w).isActive = true
        v.heightAnchor.constraint(equalToConstant: h).isActive = true
    }

    /// Updates a button's title/subtitle only when it changed (cheap per-frame use).
    static func setTitle(_ b: UIButton, _ title: String?, subtitle: String? = nil) {
        guard b.configuration?.title != title || b.configuration?.subtitle != subtitle else { return }
        b.configuration?.title = title
        b.configuration?.subtitle = subtitle
    }
}

/// Transparent container that lets touches fall through to the SpriteKit view
/// unless they hit one of its interactive subviews.
final class PassthroughView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isMultipleTouchEnabled = true
        backgroundColor = .clear
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hit = super.hitTest(point, with: event)
        return hit === self ? nil : hit
    }
}

/// Simple glassy meter (HP / energy / gauges) with a lagging damage trail.
final class MeterView: UIView {
    private let fill = UIView()
    private let trail = UIView()
    var fromRight = false
    private(set) var value: CGFloat = 1
    private var trailValue: CGFloat = 1

    var color: UIColor {
        get { fill.backgroundColor ?? .white }
        set { if fill.backgroundColor != newValue { fill.backgroundColor = newValue } }
    }

    init(color: UIColor, fromRight: Bool = false) {
        self.fromRight = fromRight
        super.init(frame: .zero)
        backgroundColor = UIColor(white: 1, alpha: 0.12)
        layer.cornerCurve = .continuous
        clipsToBounds = true
        trail.backgroundColor = UIColor(white: 1, alpha: 0.55)
        fill.backgroundColor = color
        addSubview(trail)
        addSubview(fill)
        translatesAutoresizingMaskIntoConstraints = false
        isUserInteractionEnabled = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(_ v: CGFloat, immediate: Bool = false) {
        let nv = min(1, max(0, v))
        if abs(nv - value) < 0.001 && !immediate { return }
        value = nv
        if immediate || trailValue < value { trailValue = value }
        setNeedsLayout()
    }

    func tick(_ dt: CGFloat) {
        if trailValue > value {
            trailValue = max(value, trailValue - dt * 0.5)
            setNeedsLayout()
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = bounds.height / 2
        let w = bounds.width
        let h = bounds.height
        let fw = w * value
        let tw = w * trailValue
        fill.frame = fromRight ? CGRect(x: w - fw, y: 0, width: fw, height: h) : CGRect(x: 0, y: 0, width: fw, height: h)
        trail.frame = fromRight ? CGRect(x: w - tw, y: 0, width: tw, height: h) : CGRect(x: 0, y: 0, width: tw, height: h)
        fill.layer.cornerRadius = h / 2
        trail.layer.cornerRadius = h / 2
    }
}

/// Circular progress ring drawn around a round glass button.
final class RingView: UIView {
    private let shape = CAShapeLayer()
    private var lastValue: CGFloat = -1
    var lineWidth: CGFloat = 4

    init(color: UIColor) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        shape.fillColor = UIColor.clear.cgColor
        shape.strokeColor = color.cgColor
        shape.lineCap = .round
        layer.addSublayer(shape)
        translatesAutoresizingMaskIntoConstraints = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var color: UIColor = .white {
        didSet { shape.strokeColor = color.cgColor }
    }

    func set(_ v: CGFloat) {
        let nv = min(1, max(0, v))
        guard abs(nv - lastValue) > 0.004 else { return }
        lastValue = nv
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        shape.frame = bounds
        shape.lineWidth = lineWidth
        let r = min(bounds.width, bounds.height) / 2 - lineWidth / 2
        let c = CGPoint(x: bounds.midX, y: bounds.midY)
        let p = UIBezierPath()
        if lastValue > 0 {
            p.addArc(withCenter: c, radius: r, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * max(0, lastValue), clockwise: true)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = p.cgPath
        CATransaction.commit()
    }
}
