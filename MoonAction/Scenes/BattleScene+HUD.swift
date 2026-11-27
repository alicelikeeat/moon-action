import SpriteKit

extension BattleScene {
    // MARK: - HUD construction

    func buildHUD() {
        let W = size.width
        let H = size.height
        let L = Layout.safeLeft + 14
        let R = W - Layout.safeRight - 14
        let barW = min(430, W * 0.3)

        pName = ShadowLabel("", size: 24, align: .left)
        pName.position = CGPoint(x: L, y: H - 30)
        hud.addChild(pName)
        pHP = BarNode(width: barW, height: 22, color: UIColor(hex: 0x58E37A))
        pHP.position = CGPoint(x: L, y: H - 60)
        hud.addChild(pHP)
        pSoulBar = BarNode(width: barW * 0.6, height: 8, color: UIColor(hex: 0xFFC94A))
        pSoulBar.position = CGPoint(x: L, y: H - 84)
        hud.addChild(pSoulBar)

        eName = ShadowLabel("", size: 24, align: .right)
        eName.position = CGPoint(x: R, y: H - 30)
        hud.addChild(eName)
        eHP = BarNode(width: barW, height: 22, color: UIColor(hex: 0xE5484D), fromRight: true)
        eHP.position = CGPoint(x: R, y: H - 60)
        hud.addChild(eHP)
        eSoulBar = BarNode(width: barW * 0.6, height: 8, color: UIColor(hex: 0xFFC94A), fromRight: true)
        eSoulBar.position = CGPoint(x: R, y: H - 84)
        hud.addChild(eSoulBar)

        for (i, c) in player.team.enumerated() {
            let p = PortraitButton(index: i, def: c.def)
            p.position = CGPoint(x: L + 36 + CGFloat(i) * 76, y: H - 136)
            p.onTap = { [weak self] idx in
                guard let self else { return }
                self.swap(self.player, to: idx, forced: false)
            }
            hud.addChild(p)
            pPortraits.append(p)
        }
        for (i, c) in enemy.team.enumerated() {
            let p = PortraitButton(index: i, def: c.def)
            p.position = CGPoint(x: R - 36 - CGFloat(i) * 76, y: H - 136)
            p.isUserInteractionEnabled = false
            hud.addChild(p)
            ePortraits.append(p)
        }

        timerLabel = ShadowLabel("\(Int(Tune.battleTime))", size: 46)
        timerLabel.position = CGPoint(x: W / 2, y: H - 42)
        hud.addChild(timerLabel)
        let pause = ButtonNode(text: "II", size: CGSize(width: 64, height: 46), color: UIColor(white: 0.1, alpha: 0.7), fontSize: 24, corner: 12)
        pause.position = CGPoint(x: W / 2, y: H - 100)
        pause.action = { [weak self] in self?.setPaused(true) }
        hud.addChild(pause)

        comboLabel = ShadowLabel("", size: 44, color: UIColor(hex: 0xFFD45A))
        comboLabel.position = CGPoint(x: L + 110, y: H * 0.58)
        comboLabel.alpha = 0
        hud.addChild(comboLabel)

        // Cards + energy (bottom right)
        let cardY: CGFloat = 86 + Layout.safeBottom * 0.4
        let step: CGFloat = 126
        for i in 0..<4 {
            let b = CardButton(index: i)
            b.position = CGPoint(x: R - CardButton.size.width / 2 - CGFloat(3 - i) * step, y: cardY)
            b.onTap = { [weak self] idx in
                guard let self else { return }
                self.useCard(self.player, idx)
            }
            hud.addChild(b)
            cardButtons.append(b)
        }
        let cardsLeft = R - CardButton.size.width - 3 * step
        energyBar = BarNode(width: R - cardsLeft, height: 14, color: UIColor(hex: 0x6FE3FF))
        energyBar.position = CGPoint(x: cardsLeft, y: cardY + 90)
        hud.addChild(energyBar)
        energyLabel = ShadowLabel("", size: 22, color: UIColor(hex: 0x6FE3FF), align: .left)
        energyLabel.position = CGPoint(x: cardsLeft, y: cardY + 116)
        hud.addChild(energyLabel)

        specialBtn = ButtonNode(circleText: "", radius: 50, color: UIColor(hex: 0x7B3FBF))
        specialBtn.position = CGPoint(x: cardsLeft - 68, y: cardY)
        specialBtn.action = { [weak self] in
            guard let self else { return }
            self.doSpecial(self.player)
        }
        let spTitle = makeLabel("SPECIAL", size: 17)
        spTitle.position = CGPoint(x: 0, y: 14)
        specialBtn.addChild(spTitle)
        specialCD = makeLabel("", size: 22, color: UIColor(hex: 0xE9D8FF))
        specialCD.position = CGPoint(x: 0, y: -14)
        specialBtn.addChild(specialCD)
        hud.addChild(specialBtn)

        ultBtn = ButtonNode(circleText: "", radius: 50, color: UIColor(hex: 0x8A5A10))
        ultBtn.position = CGPoint(x: cardsLeft - 68, y: cardY + 128)
        ultBtn.action = { [weak self] in
            guard let self else { return }
            self.doUltimate(self.player)
        }
        ultRing = SKShapeNode()
        ultRing.strokeColor = UIColor(hex: 0xFFD45A)
        ultRing.lineWidth = 7
        ultRing.lineCap = .round
        ultBtn.addChild(ultRing)
        let ultTitle = makeLabel("ULTIMATE", size: 15)
        ultTitle.position = CGPoint(x: 0, y: 13)
        ultBtn.addChild(ultTitle)
        ultLabel = makeLabel("", size: 22, color: UIColor(hex: 0xFFE7A8))
        ultLabel.position = CGPoint(x: 0, y: -14)
        ultBtn.addChild(ultLabel)
        hud.addChild(ultBtn)

        chargeBtn = ButtonNode(circleText: "CHARGE", radius: 46, color: UIColor(hex: 0x1F7A8C), fontSize: 17)
        chargeBtn.position = CGPoint(x: cardsLeft - 180, y: cardY)
        chargeBtn.onDown = { [weak self] in
            guard let self else { return }
            self.player.charging = true
            Sound.play(.charge)
        }
        chargeBtn.onUp = { [weak self] in self?.player.charging = false }
        hud.addChild(chargeBtn)

        // Movement + evade (bottom left)
        for (k, dir) in [(0, CGFloat(-1)), (1, CGFloat(1))] {
            let b = ButtonNode(text: "", size: CGSize(width: 92, height: 92), color: UIColor(white: 0.12, alpha: 0.7), corner: 20)
            b.position = CGPoint(x: L + 48 + CGFloat(k) * 106, y: cardY)
            let tri = SKShapeNode(path: {
                let p = CGMutablePath()
                p.move(to: CGPoint(x: 18 * dir, y: 0))
                p.addLine(to: CGPoint(x: -14 * dir, y: 20))
                p.addLine(to: CGPoint(x: -14 * dir, y: -20))
                p.closeSubpath()
                return p
            }())
            tri.fillColor = .white
            tri.strokeColor = .clear
            b.addChild(tri)
            b.onDown = { [weak self] in self?.player.moveDir = dir }
            b.onUp = { [weak self] in
                guard let self, self.player.moveDir == dir else { return }
                self.player.moveDir = 0
            }
            hud.addChild(b)
        }
        dodgeBtn = ButtonNode(circleText: "EVADE", radius: 50, color: UIColor(hex: 0x2B5FB8), fontSize: 19)
        dodgeBtn.position = CGPoint(x: L + 101, y: cardY + 130)
        dodgeBtn.onDown = { [weak self] in
            guard let self else { return }
            let dir: CGFloat = self.player.moveDir != 0 ? self.player.moveDir : -self.player.current.node.facing
            self.dodge(self.player, dir: dir)
        }
        hud.addChild(dodgeBtn)
        for i in 0..<4 {
            let pip = SKShapeNode(rect: CGRect(x: -11, y: -5, width: 22, height: 10), cornerRadius: 3)
            pip.position = CGPoint(x: L + 101 + (CGFloat(i) - 1.5) * 27, y: cardY + 196)
            pip.strokeColor = UIColor(white: 1, alpha: 0.6)
            pip.lineWidth = 1.5
            hud.addChild(pip)
            dodgePips.append(pip)
        }

        let hint = makeLabel("Swipe the arena to evade", size: 15, color: UIColor(white: 1, alpha: 0.55), font: Fonts.demi)
        hint.position = CGPoint(x: W / 2, y: H - 136)
        hud.addChild(hint)
        hint.run(.sequence([.wait(forDuration: 8), .fadeOut(withDuration: 1), .removeFromParent()]))

        updateHUD(0)
        pHP.set(1, immediate: true)
        eHP.set(1, immediate: true)
    }

    // MARK: - HUD update

    func updateHUD(_ dt: CGFloat) {
        guard pHP != nil else { return }
        let pc = player.current
        let ec = enemy.current
        pName.text = "\(pc.def.name)  Lv\(pc.level)"
        eName.text = "Lv\(ec.level)  \(ec.def.name)"
        pHP.set(pc.hpFraction)
        eHP.set(ec.hpFraction)
        pHP.tick(dt)
        eHP.tick(dt)
        pHP.color = pc.hpFraction > 0.5 ? UIColor(hex: 0x58E37A) : (pc.hpFraction > 0.25 ? UIColor(hex: 0xF2C84B) : UIColor(hex: 0xE5484D))
        pSoulBar.set(CGFloat(player.soul / 100))
        eSoulBar.set(CGFloat(enemy.soul / 100))
        timerLabel.text = "\(Int(ceil(timeLeft)))"
        timerLabel.color = timeLeft < 20 ? UIColor(hex: 0xFF6A6A) : .white

        energyBar.set(CGFloat(player.energy / Tune.energyMax))
        energyLabel.text = "ENERGY \(Int(player.energy))"
        for (i, b) in cardButtons.enumerated() {
            let card = player.hand[i]
            b.set(card: card, affordable: card.map { player.energy >= Double($0.cost) } ?? false)
        }

        let cd = player.specialReadyAt - now
        if cd > 0 {
            specialCD.text = "\(Int(ceil(cd)))s"
            specialBtn.alpha = 0.5
        } else {
            specialCD.text = "\(Int(Tune.specialCost))"
            specialBtn.alpha = player.energy >= Tune.specialCost ? 1 : 0.6
        }

        let pct = Int(player.soul)
        if pct != lastUltPct {
            lastUltPct = pct
            let path = CGMutablePath()
            if pct > 0 {
                path.addArc(center: .zero, radius: 56, startAngle: .pi / 2,
                            endAngle: .pi / 2 - 2 * .pi * CGFloat(pct) / 100, clockwise: true)
            }
            ultRing.path = path
            ultLabel.text = pct >= 100 ? "READY" : "\(pct)%"
            ultBtn.removeAction(forKey: "pulse")
            ultBtn.setScale(1)
            if pct >= 100 {
                ultBtn.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.3), .scale(to: 1, duration: 0.3)])), withKey: "pulse")
                ultBtn.bg.fillColor = UIColor(hex: 0xD99A1E)
            } else {
                ultBtn.bg.fillColor = UIColor(hex: 0x8A5A10)
            }
        }

        let pips = Int(player.dodge / Tune.dodgeCost)
        for (i, pip) in dodgePips.enumerated() {
            pip.fillColor = i < pips ? UIColor(hex: 0x6FB7FF) : UIColor(white: 0, alpha: 0.4)
        }
        dodgeBtn.alpha = pips > 0 ? 1 : 0.5

        let swapCD = max(0, Int(ceil(player.swapReadyAt - now)))
        for (i, p) in pPortraits.enumerated() {
            let c = player.team[i]
            p.update(hp: c.hpFraction, active: i == player.active, ko: c.isKO, cooldown: swapCD)
        }
        let eSwapCD = max(0, Int(ceil(enemy.swapReadyAt - now)))
        for (i, p) in ePortraits.enumerated() {
            let c = enemy.team[i]
            p.update(hp: c.hpFraction, active: i == enemy.active, ko: c.isKO, cooldown: eSwapCD)
        }
    }

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
        node.position = CGPoint(x: x + (side.isPlayer ? -80 : 80), y: size.height - 205)
        node.alpha = 0
        node.zPosition = 120
        hud.addChild(node)
        node.run(.sequence([.group([.fadeIn(withDuration: 0.12), .moveTo(x: x, duration: 0.12)]),
                            .wait(forDuration: 1.0), .fadeOut(withDuration: 0.25), .removeFromParent()]))
    }

    func showTagBanner(_ def: FighterDef, side: Side) {
        let l = ShadowLabel("TAG IN · \(def.name.uppercased())", size: 26, color: def.aura.lighter(0.3))
        let x = side.isPlayer ? size.width * 0.3 : size.width * 0.7
        l.position = CGPoint(x: x, y: size.height - 205)
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
