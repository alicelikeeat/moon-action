import SpriteKit

/// Generic touchable button. Supports tap (`action`) and hold (`onDown` / `onUp`).
@MainActor
class ButtonNode: SKNode {
    var action: (() -> Void)?
    var onDown: (() -> Void)?
    var onUp: (() -> Void)?
    let bg: SKShapeNode
    let label: SKLabelNode
    var baseColor: UIColor
    var enabled = true {
        didSet { alpha = enabled ? 1 : 0.45 }
    }
    private var pressed = false

    init(text: String, size: CGSize, color: UIColor, fontSize: CGFloat = 28, corner: CGFloat = 16, font: String = Fonts.heavy) {
        bg = SKShapeNode(rectOf: size, cornerRadius: corner)
        baseColor = color
        label = makeLabel(text, size: fontSize, font: font)
        super.init()
        styleBackground()
        addChild(bg)
        addChild(label)
        isUserInteractionEnabled = true
    }

    init(circleText text: String, radius: CGFloat, color: UIColor, fontSize: CGFloat = 20) {
        bg = SKShapeNode(circleOfRadius: radius)
        baseColor = color
        label = makeLabel(text, size: fontSize)
        super.init()
        styleBackground()
        addChild(bg)
        addChild(label)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func styleBackground() {
        bg.fillColor = baseColor
        bg.strokeColor = baseColor.lighter(0.45)
        bg.lineWidth = 3
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard enabled else { return }
        pressed = true
        removeAction(forKey: "press")
        run(.scale(to: 0.92, duration: 0.05), withKey: "press")
        onDown?()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        release()
        guard enabled, let t = touches.first, let p = parent else { return }
        if contains(t.location(in: p)) || calculateAccumulatedFrame().insetBy(dx: -20, dy: -20).contains(t.location(in: p)) {
            Sound.play(.ui)
            action?()
        }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        release()
    }

    private func release() {
        removeAction(forKey: "press")
        run(.scale(to: 1, duration: 0.08), withKey: "press")
        if pressed {
            pressed = false
            onUp?()
        }
    }
}

@MainActor
final class BarNode: SKNode {
    let width: CGFloat
    let height: CGFloat
    private let fill: SKShapeNode
    private let trail: SKShapeNode
    private(set) var value: CGFloat = 1
    private var trailValue: CGFloat = 1

    init(width: CGFloat, height: CGFloat, color: UIColor, fromRight: Bool = false) {
        self.width = width
        self.height = height
        let rect = fromRight
            ? CGRect(x: -width, y: -height / 2, width: width, height: height)
            : CGRect(x: 0, y: -height / 2, width: width, height: height)
        let back = SKShapeNode(rect: rect.insetBy(dx: -3, dy: -3), cornerRadius: (height + 6) / 2)
        back.fillColor = UIColor(white: 0, alpha: 0.6)
        back.strokeColor = UIColor(white: 1, alpha: 0.35)
        back.lineWidth = 2
        trail = SKShapeNode(rect: rect, cornerRadius: height / 2)
        trail.fillColor = UIColor(white: 1, alpha: 0.85)
        trail.strokeColor = .clear
        fill = SKShapeNode(rect: rect, cornerRadius: height / 2)
        fill.fillColor = color
        fill.strokeColor = .clear
        super.init()
        addChild(back)
        addChild(trail)
        addChild(fill)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    var color: UIColor {
        get { fill.fillColor }
        set { fill.fillColor = newValue }
    }

    func set(_ v: CGFloat, immediate: Bool = false) {
        value = v.clamped(0, 1)
        fill.xScale = max(0.0001, value)
        if immediate || trailValue < value { trailValue = value }
        trail.xScale = max(0.0001, trailValue)
    }

    func tick(_ dt: CGFloat) {
        if trailValue > value {
            trailValue = max(value, trailValue - dt * 0.5)
            trail.xScale = max(0.0001, trailValue)
        }
    }
}

/// Night-sky arena backdrop, drawn procedurally.
@MainActor
final class BackgroundNode: SKNode {
    struct Theme {
        let skyTop: UInt32, skyBottom: UInt32, far: UInt32, near: UInt32, ground: UInt32, moon: UInt32
    }

    static let themes: [Theme] = [
        Theme(skyTop: 0x0B1030, skyBottom: 0x3B2C6B, far: 0x2A2350, near: 0x1B1838, ground: 0x2C2A3E, moon: 0xF4F1DE),
        Theme(skyTop: 0x1A0B24, skyBottom: 0x8A3B4A, far: 0x4A2136, near: 0x2A1424, ground: 0x3A2A2A, moon: 0xFFD9A8),
        Theme(skyTop: 0x04182A, skyBottom: 0x1F6E7A, far: 0x174452, near: 0x0F2C38, ground: 0x24363A, moon: 0xDFF7FF),
        Theme(skyTop: 0x101010, skyBottom: 0x3D3D55, far: 0x2B2B3E, near: 0x1A1A26, ground: 0x2E2E36, moon: 0xE8E8FF),
    ]

    init(size: CGSize, groundY: CGFloat, theme index: Int) {
        super.init()
        let t = BackgroundNode.themes[abs(index) % BackgroundNode.themes.count]

        let sky = SKSpriteNode(texture: Tex.verticalGradient(top: UIColor(hex: t.skyTop), bottom: UIColor(hex: t.skyBottom)))
        sky.anchorPoint = .zero
        sky.size = size
        sky.zPosition = -100
        addChild(sky)

        for _ in 0..<70 {
            let s = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.8...2.2))
            s.fillColor = .white
            s.strokeColor = .clear
            s.alpha = CGFloat.random(in: 0.3...0.9)
            s.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: (groundY + 150)...size.height))
            s.zPosition = -99
            if chance(0.3) {
                s.run(.repeatForever(.sequence([.fadeAlpha(to: 0.15, duration: Double.random(in: 0.6...1.6)),
                                                .fadeAlpha(to: 0.9, duration: Double.random(in: 0.6...1.6))])))
            }
            addChild(s)
        }

        let moonPos = CGPoint(x: size.width * 0.74, y: size.height * 0.74)
        let halo = SKSpriteNode(texture: Tex.glow)
        halo.size = CGSize(width: 520, height: 520)
        halo.color = UIColor(hex: t.moon)
        halo.colorBlendFactor = 1
        halo.alpha = 0.35
        halo.blendMode = .add
        halo.position = moonPos
        halo.zPosition = -98
        addChild(halo)
        let moon = SKShapeNode(circleOfRadius: 78)
        moon.fillColor = UIColor(hex: t.moon)
        moon.strokeColor = .clear
        moon.position = moonPos
        moon.zPosition = -97
        addChild(moon)
        for (dx, dy, r) in [(CGFloat(-22), CGFloat(18), CGFloat(14)), (24, -10, 18), (-8, -32, 9), (30, 34, 7)] {
            let c = SKShapeNode(circleOfRadius: r)
            c.fillColor = UIColor(hex: t.moon).darker(0.12)
            c.strokeColor = .clear
            c.position = CGPoint(x: dx, y: dy)
            moon.addChild(c)
        }

        addChild(BackgroundNode.ridge(width: size.width, base: groundY, minH: 90, maxH: 240, step: 90, color: UIColor(hex: t.far), z: -96))
        addChild(BackgroundNode.ridge(width: size.width, base: groundY, minH: 30, maxH: 120, step: 60, color: UIColor(hex: t.near), z: -95))

        let ground = SKSpriteNode(texture: Tex.verticalGradient(top: UIColor(hex: t.ground).lighter(0.12), bottom: UIColor(hex: t.ground).darker(0.5), height: 64))
        ground.anchorPoint = .zero
        ground.size = CGSize(width: size.width, height: groundY)
        ground.zPosition = -94
        addChild(ground)
        let edge = SKShapeNode(rect: CGRect(x: 0, y: groundY - 2, width: size.width, height: 3))
        edge.fillColor = UIColor(hex: t.ground).lighter(0.35)
        edge.strokeColor = .clear
        edge.zPosition = -93
        addChild(edge)
        for _ in 0..<18 {
            let rock = SKShapeNode(ellipseOf: CGSize(width: CGFloat.random(in: 14...46), height: CGFloat.random(in: 5...12)))
            rock.fillColor = UIColor(hex: t.ground).darker(0.3)
            rock.strokeColor = .clear
            rock.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 20...(groundY - 12)))
            rock.zPosition = -93
            addChild(rock)
        }
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private static func ridge(width: CGFloat, base: CGFloat, minH: CGFloat, maxH: CGFloat, step: CGFloat, color: UIColor, z: CGFloat) -> SKShapeNode {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: base))
        var x: CGFloat = 0
        while x <= width + step {
            p.addLine(to: CGPoint(x: x, y: base + CGFloat.random(in: minH...maxH)))
            x += CGFloat.random(in: step * 0.5...step * 1.2)
            p.addLine(to: CGPoint(x: x, y: base + CGFloat.random(in: minH * 0.4...minH)))
            x += CGFloat.random(in: step * 0.3...step * 0.7)
        }
        p.addLine(to: CGPoint(x: width + step * 2, y: base))
        p.closeSubpath()
        let n = SKShapeNode(path: p)
        n.fillColor = color
        n.strokeColor = .clear
        n.zPosition = z
        return n
    }
}

/// A tile with a portrait used in team select / summon.
@MainActor
final class FighterTile: SKNode {
    let def: FighterDef
    let frameNode: SKShapeNode
    var onTap: ((FighterTile) -> Void)?
    static let size = CGSize(width: 190, height: 230)

    init(def: FighterDef, level: Int?, locked: Bool) {
        self.def = def
        frameNode = SKShapeNode(rectOf: FighterTile.size, cornerRadius: 18)
        super.init()
        frameNode.fillColor = def.aura.darker(0.72)
        frameNode.strokeColor = def.aura.darker(0.2)
        frameNode.lineWidth = 3
        addChild(frameNode)

        let fighter = FighterNode(def: def)
        fighter.setScale(0.72 * def.bodyScale)
        fighter.position = CGPoint(x: 0, y: -92)
        fighter.shadow.isHidden = true
        let crop = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: FighterTile.size.width - 8, height: FighterTile.size.height - 8), cornerRadius: 15)
        mask.fillColor = .white
        crop.maskNode = mask
        crop.addChild(fighter)
        addChild(crop)

        let band = SKShapeNode(rect: CGRect(x: -FighterTile.size.width / 2 + 4, y: -FighterTile.size.height / 2 + 4,
                                            width: FighterTile.size.width - 8, height: 58), cornerRadius: 12)
        band.fillColor = UIColor(white: 0, alpha: 0.6)
        band.strokeColor = .clear
        addChild(band)
        let name = makeLabel(def.name, size: 19, font: Fonts.bold)
        name.position = CGPoint(x: 0, y: -FighterTile.size.height / 2 + 42)
        addChild(name)
        let sub = makeLabel(level.map { "Lv \($0)  " + String(repeating: "★", count: def.rarity) } ?? def.title,
                            size: 15, color: def.aura.lighter(0.3), font: Fonts.demi)
        sub.position = CGPoint(x: 0, y: -FighterTile.size.height / 2 + 18)
        addChild(sub)

        if locked {
            let veil = SKShapeNode(rectOf: FighterTile.size, cornerRadius: 18)
            veil.fillColor = UIColor(white: 0, alpha: 0.7)
            veil.strokeColor = .clear
            addChild(veil)
            let l = makeLabel("LOCKED", size: 26)
            l.fontColor = UIColor(white: 1, alpha: 0.8)
            addChild(l)
        }
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func setSelected(_ order: Int?) {
        childNode(withName: "sel")?.removeFromParent()
        frameNode.strokeColor = order == nil ? def.aura.darker(0.2) : .white
        frameNode.lineWidth = order == nil ? 3 : 6
        if let o = order {
            let badge = SKShapeNode(circleOfRadius: 20)
            badge.name = "sel"
            badge.fillColor = UIColor(hex: 0xFFC94A)
            badge.strokeColor = .white
            badge.lineWidth = 3
            badge.position = CGPoint(x: FighterTile.size.width / 2 - 22, y: FighterTile.size.height / 2 - 22)
            let l = makeLabel("\(o)", size: 22, color: .black)
            badge.addChild(l)
            addChild(badge)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let p = parent, contains(t.location(in: p)) else { return }
        run(.sequence([.scale(to: 0.95, duration: 0.05), .scale(to: 1, duration: 0.08)]))
        onTap?(self)
    }
}
