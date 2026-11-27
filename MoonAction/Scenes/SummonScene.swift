import SpriteKit

final class SummonScene: SKScene {
    private var coinLabel: ShadowLabel!
    private var summonBtn: ButtonNode!
    private var stageNode = SKNode()
    private var busy = false

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 140, theme: 3))
        addChild(stageNode)

        let title = ShadowLabel("SUMMON", size: 48, color: UIColor(hex: 0xD9B8FF))
        title.position = CGPoint(x: W / 2, y: H - 55)
        addChild(title)
        let rates = makeLabel("★★ 75%   ·   ★★★ 25%   ·   Duplicates grant \(Save.duplicateXP) XP", size: 18,
                              color: UIColor(white: 1, alpha: 0.7), font: Fonts.demi)
        rates.position = CGPoint(x: W / 2, y: H - 98)
        addChild(rates)

        coinLabel = ShadowLabel("", size: 30, color: UIColor(hex: 0xFFD45A), align: .right)
        coinLabel.position = CGPoint(x: W - Layout.safeRight - 24, y: H - 50)
        addChild(coinLabel)

        let back = ButtonNode(text: "BACK", size: CGSize(width: 130, height: 56), color: UIColor(white: 0.15, alpha: 0.85), fontSize: 22, corner: 12)
        back.position = CGPoint(x: Layout.safeLeft + 85, y: H - 50)
        back.action = { [weak self] in
            guard let self, !self.busy else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        addChild(back)

        summonBtn = ButtonNode(text: "SUMMON ×1  ·  ◉ \(Save.summonCost)", size: CGSize(width: 420, height: 88),
                               color: UIColor(hex: 0x7B3FBF), fontSize: 30)
        summonBtn.position = CGPoint(x: W / 2, y: 90)
        summonBtn.action = { [weak self] in self?.summon() }
        addChild(summonBtn)

        showIdleOrb()
        refresh()
    }

    private func refresh() {
        coinLabel.text = "◉ \(Save.shared.data.coins)"
        summonBtn.enabled = Save.shared.data.coins >= Save.summonCost && !busy
    }

    private func showIdleOrb() {
        stageNode.removeAllChildren()
        let orb = SKShapeNode(circleOfRadius: 90)
        orb.fillColor = UIColor(hex: 0x3A2D7A)
        orb.strokeColor = UIColor(hex: 0xD9B8FF)
        orb.lineWidth = 5
        orb.glowWidth = 10
        orb.position = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        let moon = SKShapeNode(path: FighterNode.crescentPath(radius: 46))
        moon.fillColor = UIColor(hex: 0xFFD45A)
        moon.strokeColor = .clear
        orb.addChild(moon)
        stageNode.addChild(orb)
        orb.run(.repeatForever(.sequence([.scale(to: 1.06, duration: 0.8), .scale(to: 1, duration: 0.8)])))
    }

    private func roll() -> FighterDef {
        let rarity = chance(0.25) ? 3 : 2
        return Roster.all.filter { $0.rarity == rarity }.randomElement() ?? Roster.kai
    }

    private func summon() {
        let save = Save.shared
        guard !busy, save.data.coins >= Save.summonCost else { return }
        busy = true
        save.data.coins -= Save.summonCost
        let def = roll()
        let isNew = !save.isUnlocked(def.id)
        if isNew {
            save.data.unlocked.append(def.id)
        } else {
            save.addXP(def.id, Save.duplicateXP)
        }
        save.persist()
        refresh()

        stageNode.removeAllChildren()
        let center = CGPoint(x: size.width / 2, y: size.height / 2 + 10)
        let orb = SKShapeNode(circleOfRadius: 70)
        orb.fillColor = UIColor.white
        orb.strokeColor = def.rarity == 3 ? UIColor(hex: 0xFFD45A) : UIColor(hex: 0x8FE3FF)
        orb.lineWidth = 8
        orb.glowWidth = 14
        orb.position = center
        stageNode.addChild(orb)
        Sound.play(.charge)
        orb.run(.sequence([
            .repeat(.sequence([.scale(to: 1.25, duration: 0.12), .scale(to: 0.9, duration: 0.12)]), count: 4),
            .run { [weak self] in self?.reveal(def, isNew: isNew, at: center) },
            .removeFromParent(),
        ]))
    }

    private func reveal(_ def: FighterDef, isNew: Bool, at center: CGPoint) {
        Sound.play(def.rarity == 3 ? .ultimate : .explode)
        Haptics.hit(true)
        let flash = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        flash.fillColor = def.aura
        flash.strokeColor = .clear
        flash.alpha = 0.8
        stageNode.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.5), .removeFromParent()]))

        for i in 0..<12 {
            let a = CGFloat(i) / 12 * 2 * .pi
            let ray = SKShapeNode(rect: CGRect(x: 0, y: -6, width: 600, height: 12))
            ray.fillColor = def.aura.withAlphaComponent(0.35)
            ray.strokeColor = .clear
            ray.zRotation = a
            ray.position = center
            ray.zPosition = -1
            stageNode.addChild(ray)
            ray.run(.repeatForever(.rotate(byAngle: 0.6, duration: 2)))
        }

        let f = FighterNode(def: def)
        f.setScale(1.6 * def.bodyScale)
        f.position = CGPoint(x: center.x - 160, y: 150)
        stageNode.addChild(f)
        f.burstAura(1.2)
        f.enterEffect()

        let stars = ShadowLabel(String(repeating: "★", count: def.rarity), size: 44,
                                color: def.rarity == 3 ? UIColor(hex: 0xFFD45A) : UIColor(hex: 0x8FE3FF))
        stars.position = CGPoint(x: center.x + 170, y: center.y + 110)
        stageNode.addChild(stars)
        let name = ShadowLabel(def.name.uppercased(), size: 50)
        name.position = CGPoint(x: center.x + 170, y: center.y + 45)
        stageNode.addChild(name)
        let title = makeLabel(def.title, size: 26, color: def.aura.lighter(0.4), font: Fonts.bold)
        title.position = CGPoint(x: center.x + 170, y: center.y - 5)
        stageNode.addChild(title)
        let result = ShadowLabel(isNew ? "NEW FIGHTER!" : "+\(Save.duplicateXP) XP", size: 34,
                                 color: isNew ? UIColor(hex: 0x7CFF8A) : UIColor(hex: 0xFFD45A))
        result.position = CGPoint(x: center.x + 170, y: center.y - 60)
        stageNode.addChild(result)
        let moves = makeLabel("Special: \(def.specialName)   ·   Ultimate: \(def.ultimateName)", size: 18,
                              color: UIColor(white: 1, alpha: 0.75), font: Fonts.demi)
        moves.position = CGPoint(x: center.x + 170, y: center.y - 105)
        stageNode.addChild(moves)
        for n in [stars, name, result] as [SKNode] {
            n.setScale(0.3)
            n.run(.scale(to: 1, duration: 0.18))
        }
        busy = false
        refresh()
    }
}
