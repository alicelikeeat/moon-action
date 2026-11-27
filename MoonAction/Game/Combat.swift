import SpriteKit

enum Tune {
    static let energyMax = 100.0
    static let energyRegen = 7.0
    static let chargeRate = 30.0
    static let dodgeMax = 100.0
    static let dodgeCost = 25.0
    static let dodgeRegen = 6.5
    static let dodgeInvuln = 0.42
    static let specialCost = 40.0
    static let specialCooldown = 14.0
    static let swapCooldown = 8.0
    static let moveSpeed: CGFloat = 320
    static let battleTime = 150.0
    static let strikeRange: CGFloat = 140
}

@MainActor
final class Combatant {
    let def: FighterDef
    let level: Int
    let maxHP: Double
    var hp: Double
    let atk: Double
    let dfn: Double
    let node: FighterNode
    var busy = false
    var stunUntil: TimeInterval = 0
    var invulnUntil: TimeInterval = 0
    var isKO: Bool { hp <= 0 }
    var hpFraction: CGFloat { CGFloat(hp / maxHP) }

    init(def: FighterDef, level: Int) {
        self.def = def
        self.level = level
        let m = 1 + 0.05 * Double(level - 1)
        maxHP = def.hp * m
        hp = maxHP
        atk = def.atk * m
        dfn = def.defense * m
        node = FighterNode(def: def)
    }
}

@MainActor
final class Side {
    let isPlayer: Bool
    var team: [Combatant]
    var active = 0
    var energy: Double = 35
    var dodge: Double = Tune.dodgeMax
    var soul: Double = 0
    var hand: [Card?] = [nil, nil, nil, nil]
    var handGen = 0
    var specialReadyAt: TimeInterval = 5
    var swapReadyAt: TimeInterval = 0
    var charging = false
    var moveDir: CGFloat = 0
    var comboCount = 0
    var lastHitTime: TimeInterval = -10
    var current: Combatant { team[active] }
    var allKO: Bool { team.allSatisfy { $0.isKO } }

    init(isPlayer: Bool, team: [Combatant]) {
        self.isPlayer = isPlayer
        self.team = team
    }

    func addSoul(_ v: Double) { soul = min(100, soul + v) }
}

@MainActor
final class Projectile {
    let node: SKNode
    let owner: Side
    let vx: CGFloat
    let radius: CGFloat
    let power: Double
    var alive = true
    var aiRolled = false
    var evadeShown = false

    init(node: SKNode, owner: Side, vx: CGFloat, radius: CGFloat, power: Double) {
        self.node = node
        self.owner = owner
        self.vx = vx
        self.radius = radius
        self.power = power
    }
}
