import SpriteKit
import UIKit

final class TeamSelectScene: GameScene {
    private var selected: [String] = []
    private var tiles: [FighterTile] = []
    private var fightBtn: UIButton?
    private var enemyIDs: [String] = []
    private var teamLabel: UILabel?

    override func didMove(to view: SKView) {
        anchorPoint = .zero
        backgroundColor = .black
        let save = Save.shared
        let W = size.width
        let H = size.height
        addChild(BackgroundNode(size: size, groundY: 120, theme: 2))

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
            tile.position = CGPoint(x: x, y: H * 0.53)
            tile.onTap = { [weak self] t in self?.toggle(t) }
            addChild(tile)
            tiles.append(tile)
            x += (tileW + gap) * scale
        }
        enemyIDs = Array(Roster.all.map { $0.id }.shuffled().prefix(3))
        installUI(in: view)
        refresh()
    }

    override func buildUI() {
        let stage = Save.shared.data.stage
        let back = Glass.button(symbol: "chevron.left", fontSize: 17) { [weak self] in
            guard let self else { return }
            self.transition(to: HomeScene(size: self.size))
        }
        ui.addSubview(back)

        let header = Glass.panel(radius: 24)
        let title = Glass.label("Choose Your Team", size: 22, weight: .heavy)
        let hint = Glass.label("Pick 3 fighters · the first one starts the battle", size: 13, weight: .semibold,
                               color: UIColor(white: 1, alpha: 0.7))
        let hs = UIStackView(arrangedSubviews: [title, hint])
        hs.axis = .vertical
        hs.spacing = 2
        hs.translatesAutoresizingMaskIntoConstraints = false
        header.contentView.addSubview(hs)
        ui.addSubview(header)

        // Opponent preview
        let foe = Glass.panel(radius: 22, tint: UIColor.maRed.withAlphaComponent(0.25))
        let foeTitle = Glass.label("Stage \(stage) · Opponents Lv \(BattleSetup.enemyLevel(stage: stage))", size: 13,
                                   weight: .bold, color: UIColor(hex: 0xFFB3AA), align: .left)
        let foeNames = Glass.label(enemyIDs.map { Roster.byID($0).name }.joined(separator: "  ·  "), size: 15,
                                   weight: .heavy, align: .left)
        let fs = UIStackView(arrangedSubviews: [foeTitle, foeNames])
        fs.axis = .vertical
        fs.spacing = 2
        fs.translatesAutoresizingMaskIntoConstraints = false
        foe.contentView.addSubview(fs)
        ui.addSubview(foe)

        let team = Glass.label("", size: 14, weight: .semibold, color: UIColor(white: 1, alpha: 0.8))
        teamLabel = team
        ui.addSubview(team)

        let fight = Glass.button("Fight!", symbol: "bolt.fill", style: .prominent, tint: .maRed, fontSize: 24) { [weak self] in
            self?.startBattle()
        }
        fightBtn = fight
        ui.addSubview(fight)

        NSLayoutConstraint.activate([
            back.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            back.topAnchor.constraint(equalTo: safe.topAnchor, constant: 12),
            back.widthAnchor.constraint(equalToConstant: 48),
            back.heightAnchor.constraint(equalToConstant: 48),

            header.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            header.topAnchor.constraint(equalTo: safe.topAnchor, constant: 8),
            hs.leadingAnchor.constraint(equalTo: header.contentView.leadingAnchor, constant: 24),
            hs.trailingAnchor.constraint(equalTo: header.contentView.trailingAnchor, constant: -24),
            hs.topAnchor.constraint(equalTo: header.contentView.topAnchor, constant: 8),
            hs.bottomAnchor.constraint(equalTo: header.contentView.bottomAnchor, constant: -8),

            foe.leadingAnchor.constraint(equalTo: safe.leadingAnchor, constant: 16),
            foe.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            fs.leadingAnchor.constraint(equalTo: foe.contentView.leadingAnchor, constant: 18),
            fs.trailingAnchor.constraint(equalTo: foe.contentView.trailingAnchor, constant: -18),
            fs.topAnchor.constraint(equalTo: foe.contentView.topAnchor, constant: 8),
            fs.bottomAnchor.constraint(equalTo: foe.contentView.bottomAnchor, constant: -8),
            foe.trailingAnchor.constraint(lessThanOrEqualTo: fight.leadingAnchor, constant: -16),

            fight.trailingAnchor.constraint(equalTo: safe.trailingAnchor, constant: -16),
            fight.bottomAnchor.constraint(equalTo: safe.bottomAnchor, constant: -12),
            fight.widthAnchor.constraint(equalToConstant: 190),
            fight.heightAnchor.constraint(equalToConstant: 58),

            team.centerXAnchor.constraint(equalTo: ui.centerXAnchor),
            team.bottomAnchor.constraint(equalTo: foe.topAnchor, constant: -10),
        ])
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
        UISelectionFeedbackGenerator().selectionChanged()
        refresh()
    }

    private func refresh() {
        for t in tiles {
            t.setSelected(selected.firstIndex(of: t.def.id).map { $0 + 1 })
        }
        fightBtn?.isEnabled = selected.count == 3
        fightBtn?.alpha = selected.count == 3 ? 1 : 0.5
        teamLabel?.text = selected.isEmpty ? "Tap fighters to build your team"
            : selected.map { Roster.byID($0).name }.joined(separator: "  →  ")
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
