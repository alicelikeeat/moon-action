import SpriteKit

final class ResultScene: SKScene {
    let won: Bool
    let teamIDs: [String]
    let stage: Int

    init(size: CGSize, won: Bool, teamIDs: [String], stage: Int) {
        self.won = won
        self.teamIDs = teamIDs
        self.stage = stage
        super.init(size: size)
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 120, theme: won ? 1 : 3))
        let veil = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        veil.fillColor = UIColor(white: 0, alpha: 0.45)
        veil.strokeColor = .clear
        addChild(veil)

        let save = Save.shared
        let coins = won ? 120 + stage * 15 : 40
        let xp = won ? 140 + stage * 10 : 50
        let before = teamIDs.map { save.level($0) }
        save.data.coins += coins
        for id in teamIDs { save.addXP(id, xp) }
        if won {
            save.data.stage += 1
            save.data.wins += 1
        } else {
            save.data.losses += 1
        }
        save.persist()

        let title = ShadowLabel(won ? "VICTORY" : "DEFEAT", size: 96,
                                color: won ? UIColor(hex: 0xFFD45A) : UIColor(hex: 0x9AA4C8))
        title.position = CGPoint(x: W / 2, y: H - 110)
        addChild(title)
        let sub = makeLabel(won ? "Stage \(stage) cleared! Next: Stage \(stage + 1)" : "Train up and try Stage \(stage) again.",
                            size: 24, color: UIColor(white: 1, alpha: 0.85), font: Fonts.bold)
        sub.position = CGPoint(x: W / 2, y: H - 180)
        addChild(sub)

        let reward = ShadowLabel("◉ +\(coins)     XP +\(xp)", size: 34, color: UIColor(hex: 0xFFE7A8))
        reward.position = CGPoint(x: W / 2, y: H - 240)
        addChild(reward)

        for (i, id) in teamIDs.enumerated() {
            let def = Roster.byID(id)
            let info = save.levelInfo(id)
            let x = W / 2 + (CGFloat(i) - 1) * 260
            let f = FighterNode(def: def)
            f.setScale(0.95 * def.bodyScale)
            f.position = CGPoint(x: x, y: 190)
            addChild(f)
            if won { f.burstAura(1.0) }
            let name = makeLabel(def.name, size: 22, font: Fonts.bold)
            name.position = CGPoint(x: x, y: 160)
            addChild(name)
            let lvl = makeLabel("Lv \(info.level)", size: 22, color: def.aura.lighter(0.3))
            lvl.position = CGPoint(x: x, y: 132)
            addChild(lvl)
            let bar = BarNode(width: 160, height: 10, color: def.aura)
            bar.position = CGPoint(x: x - 80, y: 108)
            bar.set(CGFloat(info.into) / CGFloat(info.need), immediate: true)
            addChild(bar)
            if info.level > before[i] {
                let up = ShadowLabel("LEVEL UP!", size: 26, color: UIColor(hex: 0x7CFF8A))
                up.position = CGPoint(x: x, y: 395)
                addChild(up)
                up.run(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.4), .scale(to: 1, duration: 0.4)])))
            }
        }

        let cont = ButtonNode(text: "CONTINUE", size: CGSize(width: 280, height: 80), color: UIColor(hex: 0xD9432F), fontSize: 32)
        cont.position = CGPoint(x: W - Layout.safeRight - 170, y: 60)
        cont.action = { [weak self] in
            guard let self else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        addChild(cont)
    }
}
