import SpriteKit

final class TeamSelectScene: SKScene {
    private var selected: [String] = []
    private var tiles: [FighterTile] = []
    private var fightBtn: ButtonNode!
    private var enemyIDs: [String] = []

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let save = Save.shared
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 120, theme: 2))
        let veil = SKShapeNode(rect: CGRect(origin: .zero, size: size))
        veil.fillColor = UIColor(white: 0, alpha: 0.35)
        veil.strokeColor = .clear
        addChild(veil)

        let title = ShadowLabel("CHOOSE YOUR TEAM", size: 44)
        title.position = CGPoint(x: W / 2, y: H - 50)
        addChild(title)
        let hint = makeLabel("Pick 3 fighters. The first one starts the battle.", size: 20,
                             color: UIColor(white: 1, alpha: 0.75), font: Fonts.demi)
        hint.position = CGPoint(x: W / 2, y: H - 92)
        addChild(hint)

        let back = ButtonNode(text: "BACK", size: CGSize(width: 130, height: 56), color: UIColor(white: 0.15, alpha: 0.85), fontSize: 22, corner: 12)
        back.position = CGPoint(x: Layout.safeLeft + 85, y: H - 50)
        back.action = { [weak self] in
            guard let self else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        addChild(back)

        selected = save.data.team.filter { save.isUnlocked($0) }
        let all = Roster.all
        let gap: CGFloat = 16
        let tileW = FighterTile.size.width
        let usable = W - Layout.safeLeft - Layout.safeRight - 40
        let scale = min(1, usable / (CGFloat(all.count) * (tileW + gap)))
        let totalW = CGFloat(all.count) * (tileW + gap) * scale - gap * scale
        var x = (W - totalW) / 2 + tileW * scale / 2
        for def in all {
            let unlocked = save.isUnlocked(def.id)
            let tile = FighterTile(def: def, level: unlocked ? save.level(def.id) : nil, locked: !unlocked)
            tile.setScale(scale)
            tile.position = CGPoint(x: x, y: H * 0.52)
            tile.onTap = { [weak self] t in self?.toggle(t) }
            addChild(tile)
            tiles.append(tile)
            x += (tileW + gap) * scale
        }

        // Enemy preview
        let stage = save.data.stage
        let pool = Roster.all.map { $0.id }.shuffled()
        enemyIDs = Array(pool.prefix(3))
        let enemyLevel = BattleSetup.enemyLevel(stage: stage)
        let foe = makeLabel("STAGE \(stage) OPPONENTS  ·  Lv \(enemyLevel)", size: 20, color: UIColor(hex: 0xFF8A80), font: Fonts.bold)
        foe.position = CGPoint(x: W / 2 - 200, y: 150)
        addChild(foe)
        for (i, id) in enemyIDs.enumerated() {
            let def = Roster.byID(id)
            let circle = SKShapeNode(circleOfRadius: 30)
            circle.fillColor = def.aura.darker(0.6)
            circle.strokeColor = UIColor(hex: 0xFF8A80)
            circle.lineWidth = 2
            circle.position = CGPoint(x: W / 2 - 290 + CGFloat(i) * 80, y: 92)
            let crop = SKCropNode()
            let mask = SKShapeNode(circleOfRadius: 28)
            mask.fillColor = .white
            crop.maskNode = mask
            let face = FighterNode.portrait(def)
            face.setScale(-1.05)
            face.yScale = 1.05
            face.position = CGPoint(x: 3, y: -4)
            crop.addChild(face)
            circle.addChild(crop)
            addChild(circle)
        }

        fightBtn = ButtonNode(text: "FIGHT!", size: CGSize(width: 300, height: 90), color: UIColor(hex: 0xD9432F), fontSize: 40)
        fightBtn.position = CGPoint(x: W - Layout.safeRight - 190, y: 100)
        fightBtn.action = { [weak self] in self?.startBattle() }
        addChild(fightBtn)
        refresh()
    }

    private func toggle(_ tile: FighterTile) {
        let id = tile.def.id
        guard Save.shared.isUnlocked(id) else {
            Sound.play(.ui)
            return
        }
        if let i = selected.firstIndex(of: id) {
            selected.remove(at: i)
        } else if selected.count < 3 {
            selected.append(id)
        } else {
            selected[2] = id
        }
        Sound.play(.card)
        refresh()
    }

    private func refresh() {
        for t in tiles {
            t.setSelected(selected.firstIndex(of: t.def.id).map { $0 + 1 })
        }
        fightBtn.enabled = selected.count == 3
    }

    private func startBattle() {
        guard selected.count == 3 else { return }
        Save.shared.data.team = selected
        Save.shared.persist()
        let stage = Save.shared.data.stage
        let scene = BattleScene(size: size, playerIDs: selected, enemyIDs: enemyIDs,
                                enemyLevel: BattleSetup.enemyLevel(stage: stage), stage: stage)
        transition(to: scene)
    }
}

@MainActor
enum BattleSetup {
    static func enemyLevel(stage: Int) -> Int {
        min(Save.maxLevel, max(1, stage + stage / 4))
    }
}
