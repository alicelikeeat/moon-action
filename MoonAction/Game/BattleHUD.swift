import SpriteKit

@MainActor
final class CardButton: SKNode {
    static let size = CGSize(width: 116, height: 138)
    let index: Int
    var onTap: ((Int) -> Void)?
    private let bg: SKShapeNode
    private let inner: SKShapeNode
    private let nameLabel: SKLabelNode
    private let kindLabel: SKLabelNode
    private let costBadge: SKShapeNode
    private let costLabel: SKLabelNode
    private let icon: SKShapeNode
    private var shownName: String? = "?"
    private var shownAffordable: Bool?

    init(index: Int) {
        self.index = index
        bg = SKShapeNode(rectOf: CardButton.size, cornerRadius: 14)
        inner = SKShapeNode(rectOf: CGSize(width: CardButton.size.width - 14, height: CardButton.size.height - 14), cornerRadius: 10)
        nameLabel = SKLabelNode(fontNamed: Fonts.bold)
        kindLabel = makeLabel("", size: 20)
        costBadge = SKShapeNode(circleOfRadius: 19)
        costLabel = makeLabel("", size: 19, color: .white, font: Fonts.heavy)
        icon = SKShapeNode()
        super.init()
        bg.lineWidth = 3
        inner.lineWidth = 0
        inner.strokeColor = .clear
        addChild(bg)
        addChild(inner)

        icon.position = CGPoint(x: 0, y: 22)
        icon.lineWidth = 3
        addChild(icon)

        kindLabel.position = CGPoint(x: 0, y: -14)
        addChild(kindLabel)

        nameLabel.fontSize = 15
        nameLabel.fontColor = .white
        nameLabel.numberOfLines = 2
        nameLabel.preferredMaxLayoutWidth = CardButton.size.width - 12
        nameLabel.verticalAlignmentMode = .center
        nameLabel.horizontalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -44)
        addChild(nameLabel)

        costBadge.position = CGPoint(x: -CardButton.size.width / 2 + 14, y: CardButton.size.height / 2 - 14)
        costBadge.fillColor = UIColor(hex: 0x111122)
        costBadge.strokeColor = UIColor(hex: 0x6FE3FF)
        costBadge.lineWidth = 3
        costBadge.addChild(costLabel)
        addChild(costBadge)
        isUserInteractionEnabled = true
        set(card: nil, affordable: false)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func set(card: Card?, affordable: Bool) {
        let name = card?.name
        if name == shownName && affordable == shownAffordable { return }
        let changed = name != shownName
        shownName = name
        shownAffordable = affordable
        guard let card else {
            bg.fillColor = UIColor(white: 0.12, alpha: 0.85)
            bg.strokeColor = UIColor(white: 0.4, alpha: 0.8)
            inner.fillColor = .clear
            kindLabel.text = "· · ·"
            nameLabel.text = ""
            costBadge.isHidden = true
            icon.path = nil
            alpha = 0.8
            return
        }
        let color = card.kind == .strike ? UIColor(hex: 0xE0434F) : UIColor(hex: 0x2F8FE8)
        bg.fillColor = color.darker(0.25)
        bg.strokeColor = color.lighter(0.5)
        inner.fillColor = color.darker(0.55)
        kindLabel.text = card.kind == .strike ? "STRIKE" : "BLAST"
        kindLabel.fontColor = color.lighter(0.6)
        nameLabel.text = card.name
        costBadge.isHidden = false
        costLabel.text = "\(card.cost)"
        icon.path = card.kind == .strike ? CardButton.fistPath() : CardButton.orbPath()
        icon.fillColor = color.lighter(0.35)
        icon.strokeColor = .white
        alpha = affordable ? 1 : 0.5
        if changed {
            setScale(0.6)
            run(.scale(to: 1, duration: 0.12))
        }
    }

    static func fistPath() -> CGPath {
        let p = CGMutablePath()
        p.addRoundedRect(in: CGRect(x: -16, y: -12, width: 32, height: 24), cornerWidth: 7, cornerHeight: 7)
        for i in 0..<3 {
            p.move(to: CGPoint(x: -8 + CGFloat(i) * 8, y: 12))
            p.addLine(to: CGPoint(x: -8 + CGFloat(i) * 8, y: 0))
        }
        return p
    }

    static func orbPath() -> CGPath {
        let p = CGMutablePath()
        p.addEllipse(in: CGRect(x: -2, y: -12, width: 24, height: 24))
        p.move(to: CGPoint(x: -24, y: 6)); p.addLine(to: CGPoint(x: -6, y: 6))
        p.move(to: CGPoint(x: -28, y: -6)); p.addLine(to: CGPoint(x: -8, y: -6))
        return p
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTap?(index)
    }
}

/// Team member portrait used for tag-swapping.
@MainActor
final class PortraitButton: SKNode {
    let index: Int
    var onTap: ((Int) -> Void)?
    private let ring: SKShapeNode
    private let hpRing: SKShapeNode
    private let veil: SKShapeNode
    private let cdLabel: SKLabelNode
    private var lastKey = ""
    static let radius: CGFloat = 30

    init(index: Int, def: FighterDef) {
        self.index = index
        let r = PortraitButton.radius
        ring = SKShapeNode(circleOfRadius: r)
        hpRing = SKShapeNode()
        veil = SKShapeNode(circleOfRadius: r)
        cdLabel = makeLabel("", size: 20)
        super.init()
        ring.fillColor = def.aura.darker(0.6)
        ring.strokeColor = UIColor(white: 1, alpha: 0.5)
        ring.lineWidth = 2
        addChild(ring)
        let crop = SKCropNode()
        let mask = SKShapeNode(circleOfRadius: r - 2)
        mask.fillColor = .white
        crop.maskNode = mask
        let face = FighterNode.portrait(def)
        face.setScale(1.05)
        face.position = CGPoint(x: -3, y: -4)
        crop.addChild(face)
        addChild(crop)
        hpRing.lineWidth = 5
        hpRing.strokeColor = UIColor(hex: 0x58E37A)
        hpRing.lineCap = .round
        addChild(hpRing)
        veil.fillColor = UIColor(white: 0, alpha: 0.6)
        veil.strokeColor = .clear
        veil.isHidden = true
        addChild(veil)
        addChild(cdLabel)
        isUserInteractionEnabled = true
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func update(hp: CGFloat, active: Bool, ko: Bool, cooldown: Int) {
        let key = "\(Int(hp * 40))-\(active)-\(ko)-\(cooldown)"
        guard key != lastKey else { return }
        lastKey = key
        let r = PortraitButton.radius + 4
        let p = CGMutablePath()
        if hp > 0 {
            p.addArc(center: .zero, radius: r, startAngle: .pi / 2, endAngle: .pi / 2 - 2 * .pi * hp, clockwise: true)
        }
        hpRing.path = p
        hpRing.strokeColor = hp > 0.5 ? UIColor(hex: 0x58E37A) : (hp > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
        ring.strokeColor = active ? .white : UIColor(white: 1, alpha: 0.4)
        ring.lineWidth = active ? 4 : 2
        setScale(active ? 1.12 : 0.92)
        veil.isHidden = !(ko || (!active && cooldown > 0))
        cdLabel.text = ko ? "KO" : (!active && cooldown > 0 ? "\(cooldown)" : "")
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTap?(index)
    }
}
