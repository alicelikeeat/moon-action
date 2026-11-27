import UIKit

/// Native iOS "Liquid Glass" helpers.
/// On iOS 26+ (built with the iOS 26 SDK) these use `UIGlassEffect` and the
/// `.glass()` / `.prominentGlass()` button configurations. Older systems fall
/// back to the closest native material (blur) so the app still runs on iOS 15+.
enum GlassStyle {
    case regular
    case prominent
    case clear
}

@MainActor
enum Glass {
    static var isLiquidGlass: Bool {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) { return true }
        #endif
        return false
    }

    static func font(_ size: CGFloat, _ weight: UIFont.Weight = .bold) -> UIFont {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        if let d = base.fontDescriptor.withDesign(.rounded) {
            return UIFont(descriptor: d, size: size)
        }
        return base
    }

    static func configuration(_ style: GlassStyle, tint: UIColor?) -> UIButton.Configuration {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            var c: UIButton.Configuration
            switch style {
            case .regular: c = .glass()
            case .prominent: c = .prominentGlass()
            case .clear: c = .clearGlass()
            }
            c.baseForegroundColor = .white
            c.cornerStyle = .capsule
            return c
        }
        #endif
        var c = UIButton.Configuration.filled()
        c.baseForegroundColor = .white
        switch style {
        case .prominent:
            c.baseBackgroundColor = nil // follows the button's tintColor
        case .regular, .clear:
            c.baseBackgroundColor = UIColor(white: 1, alpha: 0.12)
            c.background.visualEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        }
        c.background.strokeColor = UIColor(white: 1, alpha: 0.35)
        c.background.strokeWidth = 1
        c.cornerStyle = .capsule
        return c
    }

    /// A glass button. `symbol` is an SF Symbol name.
    static func button(_ title: String? = nil, subtitle: String? = nil, symbol: String? = nil,
                       style: GlassStyle = .regular, tint: UIColor? = nil, fontSize: CGFloat = 17,
                       action: (() -> Void)? = nil) -> UIButton {
        var c = configuration(style, tint: tint)
        c.title = title
        c.subtitle = subtitle
        let f = font(fontSize, .heavy)
        c.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a
            a.font = f
            return a
        }
        let sf = font(max(10, fontSize * 0.62), .semibold)
        c.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { a in
            var a = a
            a.font = sf
            return a
        }
        c.titleAlignment = .center
        if let symbol {
            c.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: fontSize * 0.95, weight: .bold))
            c.imagePadding = title == nil ? 0 : 6
        }
        c.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10)
        let b = UIButton(configuration: c)
        if let tint { b.tintColor = tint }
        if let action {
            b.addAction(UIAction { _ in
                Sound.play(.ui)
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

    /// A glass surface. Put content inside `contentView`.
    static func panel(radius: CGFloat, tint: UIColor? = nil, interactive: Bool = false) -> UIVisualEffectView {
        let v: UIVisualEffectView
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            let e = UIGlassEffect(style: .regular)
            e.isInteractive = interactive
            e.tintColor = tint
            v = UIVisualEffectView(effect: e)
        } else {
            v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
            v.contentView.backgroundColor = tint?.withAlphaComponent(0.25)
        }
        #else
        v = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        v.contentView.backgroundColor = tint?.withAlphaComponent(0.25)
        #endif
        v.layer.cornerRadius = radius
        v.layer.cornerCurve = .continuous
        v.clipsToBounds = true
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }

    static func label(_ text: String = "", size: CGFloat, weight: UIFont.Weight = .bold,
                      color: UIColor = .white, align: NSTextAlignment = .center) -> UILabel {
        let l = UILabel()
        l.text = text
        l.font = font(size, weight)
        l.textColor = color
        l.textAlignment = align
        l.adjustsFontSizeToFitWidth = true
        l.minimumScaleFactor = 0.6
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
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
        backgroundColor = UIColor(white: 0, alpha: 0.35)
        layer.cornerCurve = .continuous
        clipsToBounds = true
        trail.backgroundColor = UIColor(white: 1, alpha: 0.8)
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
