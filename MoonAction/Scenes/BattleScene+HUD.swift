import SpriteKit

extension BattleScene {
    // MARK: - Effects

    func spark(at p: CGPoint, color: UIColor, big: Bool) {
        let g = SKSpriteNode(texture: Tex.glow)
        g.color = color
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.position = p
        g.size = CGSize(width: big ? 150 : 90, height: big ? 150 : 90)
        g.zPosition = 50
        world.addChild(g)
        g.run(.sequence([.group([.scale(by: 1.7, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
        for _ in 0..<(big ? 10 : 6) {
            let a = CGFloat.random(in: 0..<(2 * .pi))
            let len = CGFloat.random(in: 30...70) * (big ? 1.5 : 1)
            let path = CGMutablePath()
            path.move(to: CGPoint(x: cos(a) * len * 0.3, y: sin(a) * len * 0.3))
            path.addLine(to: CGPoint(x: cos(a) * len, y: sin(a) * len))
            let line = SKShapeNode(path: path)
            line.strokeColor = .white
            line.lineWidth = big ? 5 : 3
            line.lineCap = .round
            line.position = p
            line.zPosition = 51
            line.setScale(0.4)
            world.addChild(line)
            line.run(.sequence([.group([.scale(to: 1.2, duration: 0.12), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        }
    }

    func burst(at p: CGPoint, color: UIColor, scale: CGFloat) {
        let g = SKSpriteNode(texture: Tex.glow)
        g.color = color
        g.colorBlendFactor = 1
        g.blendMode = .add
        g.position = p
        g.size = CGSize(width: 110 * scale, height: 110 * scale)
        g.zPosition = 49
        world.addChild(g)
        g.run(.sequence([.group([.scale(by: 2, duration: 0.22), .fadeOut(withDuration: 0.22)]), .removeFromParent()]))
    }

    func explosion(at p: CGPoint, color: UIColor) {
        Sound.play(.explode)
        shake(18, duration: 0.5)
        Haptics.hit(true)
        for i in 0..<3 {
            let ring = SKShapeNode(circleOfRadius: 60)
            ring.strokeColor = i == 0 ? .white : color
            ring.lineWidth = 10
            ring.glowWidth = 10
            ring.position = p
            ring.zPosition = 55
            ring.setScale(0.3)
            world.addChild(ring)
            ring.run(.sequence([.wait(forDuration: Double(i) * 0.08),
                                .group([.scale(to: 4.5, duration: 0.5), .fadeOut(withDuration: 0.5)]),
                                .removeFromParent()]))
        }
        let flash = SKSpriteNode(texture: Tex.glow)
        flash.color = color
        flash.colorBlendFactor = 1
        flash.blendMode = .add
        flash.position = p
        flash.size = CGSize(width: 600, height: 600)
        flash.zPosition = 54
        world.addChild(flash)
        flash.run(.sequence([.fadeOut(withDuration: 0.7), .removeFromParent()]))
        let screen = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        screen.fillColor = .white
        screen.strokeColor = .clear
        screen.alpha = 0.6
        screen.zPosition = 90
        addChild(screen)
        screen.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    func damageNumber(_ value: Int, at p: CGPoint, crit: Bool) {
        let l = ShadowLabel(crit ? "\(value)!" : "\(value)", size: crit ? 40 : 30,
                            color: crit ? UIColor(hex: 0xFFD45A) : .white)
        l.position = CGPoint(x: p.x + CGFloat.random(in: -24...24), y: p.y + 40)
        l.zPosition = 60
        world.addChild(l)
        l.setScale(1.4)
        l.run(.sequence([.scale(to: 1, duration: 0.08),
                         .group([.moveBy(x: 0, y: 55, duration: 0.6), .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.3)])]),
                         .removeFromParent()]))
    }

    func shake(_ amount: CGFloat, duration: Double) {
        let steps = max(2, Int(duration / 0.03))
        var acts: [SKAction] = []
        for i in 0..<steps {
            let k = amount * CGFloat(steps - i) / CGFloat(steps)
            acts.append(.move(to: CGPoint(x: CGFloat.random(in: -k...k), y: CGFloat.random(in: -k...k)), duration: 0.03))
        }
        acts.append(.move(to: .zero, duration: 0.03))
        world.removeAction(forKey: "shake")
        world.run(.sequence(acts), withKey: "shake")
    }

    func showEvade(_ c: Combatant) {
        let l = ShadowLabel("EVADE", size: 30, color: UIColor(hex: 0x8FE3FF))
        l.position = CGPoint(x: c.node.position.x, y: c.node.position.y + 210)
        l.zPosition = 61
        world.addChild(l)
        l.run(.sequence([.group([.moveBy(x: 0, y: 30, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    func showCombo(_ count: Int) {
        guard count >= 2 else { return }
        comboLabel.text = "\(count) HITS"
        comboLabel.removeAllActions()
        comboLabel.alpha = 1
        comboLabel.setScale(1.35)
        comboLabel.run(.sequence([.scale(to: 1, duration: 0.1), .wait(forDuration: 1.0), .fadeOut(withDuration: 0.3)]))
    }

    func showMoveBanner(_ name: String, side: Side, ultimate: Bool) {
        let w: CGFloat = 420
        let node = SKNode()
        let band = SKShapeNode(rect: CGRect(x: -w / 2, y: -26, width: w, height: 52), cornerRadius: 10)
        band.fillColor = side.current.def.aura.darker(0.55).withAlphaComponent(0.92)
        band.strokeColor = side.current.def.aura
        band.lineWidth = 3
        node.addChild(band)
        let l = makeLabel(name.uppercased(), size: 26)
        node.addChild(l)
        let x = side.isPlayer ? size.width * 0.3 : size.width * 0.7
        node.position = CGPoint(x: x + (side.isPlayer ? -80 : 80), y: size.height - 300)
        node.alpha = 0
        node.zPosition = 120
        hud.addChild(node)
        node.run(.sequence([.group([.fadeIn(withDuration: 0.12), .moveTo(x: x, duration: 0.12)]),
                            .wait(forDuration: 1.0), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    func showTagBanner(_ def: FighterDef, side: Side) {
        let l = ShadowLabel("TAG IN · \(def.name.uppercased())", size: 26, color: def.aura.lighter(0.3))
        let x = side.isPlayer ? size.width * 0.3 : size.width * 0.7
        l.position = CGPoint(x: x, y: size.height - 300)
        l.zPosition = 120
        hud.addChild(l)
        l.run(.sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    /// Full-screen ultimate cut-in. Returns its duration.
    func ultimateCutIn(_ def: FighterDef, side: Side) -> Double {
        let duration = 1.5
        let W = size.width
        let H = size.height
        let layer = SKNode()
        layer.zPosition = 250
        overlay.addChild(layer)

        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = UIColor(white: 0, alpha: 0.7)
        dim.strokeColor = .clear
        layer.addChild(dim)

        let bandNode = SKNode()
        bandNode.position = CGPoint(x: W / 2, y: H / 2)
        bandNode.zRotation = side.isPlayer ? 0.06 : -0.06
        layer.addChild(bandNode)
        let band = SKShapeNode(rect: CGRect(x: -W, y: -120, width: W * 2, height: 240))
        band.fillColor = def.aura.darker(0.35)
        band.strokeColor = def.aura.lighter(0.5)
        band.lineWidth = 6
        bandNode.addChild(band)
        for _ in 0..<14 {
            let line = SKShapeNode(rect: CGRect(x: 0, y: 0, width: CGFloat.random(in: 120...380), height: CGFloat.random(in: 2...6)))
            line.fillColor = UIColor(white: 1, alpha: 0.5)
            line.strokeColor = .clear
            let dir: CGFloat = side.isPlayer ? 1 : -1
            line.position = CGPoint(x: -dir * W * 0.8, y: CGFloat.random(in: -110...110))
            bandNode.addChild(line)
            line.run(.repeatForever(.sequence([
                .moveTo(x: dir * W * 0.8, duration: Double.random(in: 0.25...0.5)),
                .moveTo(x: -dir * W * 0.8, duration: 0),
            ])))
        }
        bandNode.yScale = 0.01
        bandNode.run(.scaleY(to: 1, duration: 0.12))

        let f = FighterNode(def: def)
        f.setScale(2.3 * def.bodyScale)
        f.setFacing(side.isPlayer ? 1 : -1)
        f.shadow.isHidden = true
        let fx = side.isPlayer ? W * 0.26 : W * 0.74
        f.position = CGPoint(x: fx - (side.isPlayer ? 300 : -300), y: H / 2 - 260)
        f.zPosition = 2
        layer.addChild(f)
        f.powerUpPose(duration)
        let slide = SKAction.moveTo(x: fx, duration: 0.2)
        slide.timingMode = .easeOut
        f.run(slide)

        let tx = side.isPlayer ? W * 0.64 : W * 0.36
        let tag = makeLabel("ULTIMATE ART", size: 26, color: def.aura.lighter(0.5))
        tag.position = CGPoint(x: tx, y: H / 2 + 50)
        tag.zPosition = 3
        layer.addChild(tag)
        let name = ShadowLabel(def.ultimateName.uppercased(), size: 64)
        name.position = CGPoint(x: tx, y: H / 2 - 20)
        name.zPosition = 3
        name.setScale(1.8)
        name.alpha = 0
        layer.addChild(name)
        name.run(.sequence([.wait(forDuration: 0.15), .group([.fadeIn(withDuration: 0.12), .scale(to: 1, duration: 0.12)])]))

        layer.run(.sequence([.wait(forDuration: duration - 0.2), .fadeOut(withDuration: 0.2), .removeFromParent()]))
        return duration
    }
}
