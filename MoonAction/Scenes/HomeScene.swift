import SpriteKit

final class HomeScene: SKScene {
    private var coinLabel: ShadowLabel!
    private var helpLayer: SKNode?

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let save = Save.shared
        Sound.shared.enabled = save.data.soundOn
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 170, theme: 0))

        // Logo
        let logo = SKNode()
        logo.position = CGPoint(x: W * 0.32, y: H * 0.68)
        addChild(logo)
        let crescent = SKShapeNode(path: FighterNode.crescentPath(radius: 70))
        crescent.fillColor = UIColor(hex: 0xFFD45A)
        crescent.strokeColor = UIColor(hex: 0xFFF2C2)
        crescent.lineWidth = 4
        crescent.glowWidth = 6
        crescent.position = CGPoint(x: -200, y: 30)
        crescent.zRotation = 0.4
        logo.addChild(crescent)
        let title = ShadowLabel("MOON ACTION", size: 92, color: .white)
        title.position = CGPoint(x: 20, y: 40)
        logo.addChild(title)
        let sub = ShadowLabel("ARENA CARD FIGHTER", size: 28, color: UIColor(hex: 0x8FE3FF), font: Fonts.bold)
        sub.position = CGPoint(x: 20, y: -26)
        logo.addChild(sub)
        logo.run(.repeatForever(.sequence([.moveBy(x: 0, y: 6, duration: 1.2), .moveBy(x: 0, y: -6, duration: 1.2)])))

        // Showcase fighters from the player's team
        let team = save.data.team.filter { save.isUnlocked($0) }
        for (i, id) in team.prefix(2).enumerated() {
            let f = FighterNode(def: Roster.byID(id))
            f.setScale(1.5 * f.def.bodyScale)
            f.position = CGPoint(x: W * (0.70 + CGFloat(i) * 0.16), y: 150)
            f.setFacing(i == 0 ? 1 : -1)
            f.zPosition = CGFloat(5 - i)
            addChild(f)
            f.burstAura(0.8)
        }

        // Top bar
        coinLabel = ShadowLabel("", size: 30, color: UIColor(hex: 0xFFD45A), align: .right)
        coinLabel.position = CGPoint(x: W - Layout.safeRight - 24, y: H - 40)
        addChild(coinLabel)
        let rec = ShadowLabel("W \(save.data.wins)  ·  L \(save.data.losses)", size: 22, color: UIColor(white: 1, alpha: 0.75),
                              font: Fonts.bold, align: .left)
        rec.position = CGPoint(x: Layout.safeLeft + 24, y: H - 40)
        addChild(rec)
        refreshCoins()

        // Menu
        let x = W * 0.32
        let battle = ButtonNode(text: "BATTLE  ·  STAGE \(save.data.stage)", size: CGSize(width: 440, height: 92),
                                color: UIColor(hex: 0xD9432F), fontSize: 34)
        battle.position = CGPoint(x: x, y: H * 0.40)
        battle.action = { [weak self] in
            guard let self else { return }
            self.transition(to: TeamSelectScene(size: self.size))
        }
        addChild(battle)
        battle.run(.repeatForever(.sequence([.scale(to: 1.03, duration: 0.6), .scale(to: 1, duration: 0.6)])))

        let summon = ButtonNode(text: "SUMMON", size: CGSize(width: 212, height: 74), color: UIColor(hex: 0x7B3FBF), fontSize: 28)
        summon.position = CGPoint(x: x - 114, y: H * 0.40 - 104)
        summon.action = { [weak self] in
            guard let self else { return }
            self.transition(to: SummonScene(size: self.size))
        }
        addChild(summon)

        let help = ButtonNode(text: "HOW TO PLAY", size: CGSize(width: 212, height: 74), color: UIColor(hex: 0x1F7A8C), fontSize: 24)
        help.position = CGPoint(x: x + 114, y: H * 0.40 - 104)
        help.action = { [weak self] in self?.showHelp() }
        addChild(help)

        let sound = ButtonNode(text: save.data.soundOn ? "SOUND ON" : "SOUND OFF", size: CGSize(width: 170, height: 50),
                               color: UIColor(white: 0.15, alpha: 0.8), fontSize: 18, corner: 12)
        sound.position = CGPoint(x: W - Layout.safeRight - 110, y: H - 100)
        sound.action = { [weak sound] in
            Save.shared.data.soundOn.toggle()
            Save.shared.persist()
            Sound.shared.enabled = Save.shared.data.soundOn
            sound?.label.text = Save.shared.data.soundOn ? "SOUND ON" : "SOUND OFF"
        }
        addChild(sound)

        let footer = makeLabel("An original game. All characters and art are procedurally drawn originals.", size: 14,
                               color: UIColor(white: 1, alpha: 0.45), font: Fonts.demi)
        footer.position = CGPoint(x: W / 2, y: 22 + Layout.safeBottom * 0.3)
        addChild(footer)
    }

    private func refreshCoins() {
        coinLabel.text = "◉ \(Save.shared.data.coins)"
    }

    private func showHelp() {
        helpLayer?.removeFromParent()
        let layer = SKNode()
        layer.zPosition = 500
        let dim = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        dim.fillColor = UIColor(white: 0, alpha: 0.85)
        dim.strokeColor = .clear
        layer.addChild(dim)
        let title = ShadowLabel("HOW TO PLAY", size: 48, color: UIColor(hex: 0xFFD45A))
        title.position = CGPoint(x: size.width / 2, y: size.height - 80)
        layer.addChild(title)
        let lines = [
            "Battles are 3 vs 3. Knock out the whole enemy team before time runs out.",
            "STRIKE cards (red) dash in for melee combos. BLAST cards (blue) fire projectiles.",
            "Cards cost ENERGY. It refills over time — hold CHARGE to refill it faster.",
            "Blasts stop a strike that is dashing in. Up close, a strike beats a blast.",
            "Swipe the arena or tap EVADE to dodge with a brief invincibility (uses 1 evade pip).",
            "Evading also breaks you out of the enemy's combo — time it well!",
            "SPECIAL is a powerful signature move with a cooldown.",
            "Landing and taking hits fills ULTIMATE. At 100% unleash your Ultimate Art.",
            "Tap a teammate portrait to tag them in. Win battles to earn coins and XP.",
        ]
        for (i, line) in lines.enumerated() {
            let l = makeLabel("•  " + line, size: 22, font: Fonts.demi, align: .left)
            l.position = CGPoint(x: max(Layout.safeLeft + 40, size.width / 2 - 520), y: size.height - 160 - CGFloat(i) * 52)
            layer.addChild(l)
        }
        let close = ButtonNode(text: "GOT IT", size: CGSize(width: 240, height: 70), color: UIColor(hex: 0xD9432F))
        close.position = CGPoint(x: size.width / 2, y: 70)
        close.action = { [weak self] in
            self?.helpLayer?.removeFromParent()
            self?.helpLayer = nil
        }
        layer.addChild(close)
        addChild(layer)
        helpLayer = layer
    }
}
