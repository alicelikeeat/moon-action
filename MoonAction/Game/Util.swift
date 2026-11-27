import UIKit
import SpriteKit

enum GameSize {
    static var size = CGSize(width: 1334, height: 750)
}

enum Layout {
    static var safeLeft: CGFloat = 16
    static var safeRight: CGFloat = 16
    static var safeBottom: CGFloat = 10
}

enum Fonts {
    static let heavy = "AvenirNext-HeavyItalic"
    static let bold = "AvenirNext-Bold"
    static let demi = "AvenirNext-DemiBold"
}

extension UIColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255,
                  alpha: alpha)
    }

    func blend(_ other: UIColor, _ t: CGFloat) -> UIColor {
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        other.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        return UIColor(red: r1 + (r2 - r1) * t, green: g1 + (g2 - g1) * t, blue: b1 + (b2 - b1) * t, alpha: a1)
    }

    func lighter(_ t: CGFloat = 0.3) -> UIColor { blend(.white, t) }
    func darker(_ t: CGFloat = 0.3) -> UIColor { blend(.black, t) }
}

@MainActor
func makeLabel(_ text: String, size: CGFloat, color: UIColor = .white, font: String = Fonts.heavy,
               align: SKLabelHorizontalAlignmentMode = .center) -> SKLabelNode {
    let l = SKLabelNode(fontNamed: font)
    l.text = text
    l.fontSize = size
    l.fontColor = color
    l.verticalAlignmentMode = .center
    l.horizontalAlignmentMode = align
    return l
}

/// A label with a dark drop shadow for readability over busy backgrounds.
@MainActor
final class ShadowLabel: SKNode {
    let main: SKLabelNode
    let shadow: SKLabelNode

    init(_ text: String, size: CGFloat, color: UIColor = .white, font: String = Fonts.heavy,
         align: SKLabelHorizontalAlignmentMode = .center) {
        main = makeLabel(text, size: size, color: color, font: font, align: align)
        shadow = makeLabel(text, size: size, color: UIColor(white: 0, alpha: 0.65), font: font, align: align)
        super.init()
        shadow.position = CGPoint(x: 2, y: -3)
        addChild(shadow)
        addChild(main)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var text: String? {
        get { main.text }
        set { main.text = newValue; shadow.text = newValue }
    }

    var color: UIColor? {
        get { main.fontColor }
        set { main.fontColor = newValue }
    }
}

@MainActor
enum Tex {
    static let glow: SKTexture = {
        let size = CGSize(width: 64, height: 64)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0.5).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.35, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
        return SKTexture(image: img)
    }()

    static func verticalGradient(top: UIColor, bottom: UIColor, height: CGFloat = 256) -> SKTexture {
        let size = CGSize(width: 4, height: height)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
        return SKTexture(image: img)
    }
}

@MainActor
enum Haptics {
    static let light = UIImpactFeedbackGenerator(style: .light)
    static let heavy = UIImpactFeedbackGenerator(style: .heavy)

    static func hit(_ big: Bool) {
        (big ? heavy : light).impactOccurred()
    }
}

extension CGFloat {
    func clamped(_ lo: CGFloat, _ hi: CGFloat) -> CGFloat { Swift.min(hi, Swift.max(lo, self)) }
}

extension Double {
    func clamped(_ lo: Double, _ hi: Double) -> Double { Swift.min(hi, Swift.max(lo, self)) }
}

func chance(_ p: Double) -> Bool { Double.random(in: 0..<1) < p }

extension SKScene {
    @MainActor
    func transition(to scene: SKScene, duration: TimeInterval = 0.45) {
        scene.scaleMode = .aspectFit
        view?.presentScene(scene, transition: .fade(with: .black, duration: duration))
    }
}
