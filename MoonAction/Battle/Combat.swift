import SceneKit
import simd

enum Tune {
    static let energyMax = 100.0
    static let energyRegen = 6.0
    static let chargeRate = 30.0
    static let dodgeMax = 100.0
    static let dodgeCost = 25.0
    static let dodgeRegen = 7.0
    static let dodgeInvuln = 0.42
    static let swapCooldown = 8.0
    static let battleTime = 180.0
    static let meleeStop: Float = 1.3
    static let strikeRange: Float = 2.3
    static let arenaRadius: Float = 12
    static let blastSpeed: Float = 24
    static let shardsNeeded = 7
    static let launchWindow = 0.75   // launch / chase window after a heavy launching hit
    static let relayGrace = 0.45     // manual chase time guaranteed after a relay tag-in
    /// Start distances: near / mid / far
    static let startDistances: [Float] = [2.6, 6.2, 11.0]
    static let nearMax: Float = 3.6
    static let midMax: Float = 8.0
}

enum RangeZone: Int {
    case near, mid, far
    var key: String { ["range.near", "range.mid", "range.far"][rawValue] }
    static func of(_ d: Float) -> RangeZone { d < Tune.nearMax ? .near : (d < Tune.midMax ? .mid : .far) }
}

@MainActor
final class Combatant {
    let def: FighterDef
    let level: Int
    let maxHP: Double
    var hp: Double
    let atk: Double
    let dfn: Double
    let model: FighterModel
    var pos: SIMD2<Float> = .zero
    var busy = false
    var stunUntil = 0.0
    var invulnUntil = 0.0
    var barrierUntil = 0.0
    var powerUntil = 0.0
    var cursedUntil = 0.0
    var deck: [Card] = []
    var tween: (from: SIMD2<Float>, to: SIMD2<Float>, t0: Double, dur: Double)?
    var knockVel: SIMD2<Float> = .zero
    var wasCharging = false
    var vanishStart = -10.0
    var perfectUsed = true
    var launchedUntil = 0.0
    var auraBurstUntil = 0.0
    var abilityUsed = false

    var isKO: Bool { hp <= 0 }
    var hpFraction: CGFloat { CGFloat(max(0, hp) / maxHP) }

    init(def: FighterDef, level: Int) {
        self.def = def
        self.level = level
        let m = 1 + 0.05 * Double(level - 1)
        maxHP = (def.hp * m).rounded()
        hp = maxHP
        atk = def.atk * m
        dfn = def.defense * m
        model = FighterModel(def: def)
        deck = def.makeDeck()
    }

    func drawCard() -> Card {
        if deck.isEmpty { deck = def.makeDeck() }
        return deck.removeLast()
    }

    var nextCard: Card? {
        if deck.isEmpty { deck = def.makeDeck() }
        return deck.last
    }

    var world3: SIMD3<Float> { SIMD3(pos.x, 0, pos.y) }
    var chest: SIMD3<Float> { SIMD3(pos.x, 1.3 * def.look.height, pos.y) }
}

@MainActor
final class Side {
    let isPlayer: Bool
    var team: [Combatant]
    var active = 0
    var energy = 40.0
    var dodge = Tune.dodgeMax
    var soul = 0.0
    var shards = 0
    var hand: [Card?] = [nil, nil, nil, nil]
    var handGen = 0
    var charging = false
    var auto = false
    var chain = 0
    var chainOpenUntil = 0.0
    var comboCount = 0
    var lastHitTime = -10.0
    var swapReadyAt = 0.0
    var cardLanded = false
    var counterUntil = 0.0
    var relay: Relay?

    var current: Combatant { team[active] }
    var allKO: Bool { team.allSatisfy { $0.isKO } }
    var ultimateReady: Bool { soul >= 100 }
    var eclipseReady: Bool { shards >= Tune.shardsNeeded }

    init(isPlayer: Bool, team: [Combatant]) {
        self.isPlayer = isPlayer
        self.team = team
    }

    func addSoul(_ v: Double) { soul = min(100, soul + v) }
}

/// Tag-in relay chase opened by a launching heavy hit.
@MainActor
final class Relay {
    let target: Combatant          // the launched opponent
    let launcher: Combatant        // our fighter that launched it
    let launchUntil: Double        // base launch window end (0.75 s)
    var deadline: Double           // effective chase deadline
    var used = false               // the one relay swap has happened
    var entrant: Combatant?        // fighter that tagged in for the chase
    var closed = false

    init(target: Combatant, launcher: Combatant, until: Double) {
        self.target = target
        self.launcher = launcher
        launchUntil = until
        deadline = until
    }
}

/// What a hand card can do right now (shared by `playCard` and the HUD).
struct CardStatus: Equatable {
    var playable = false
    var chain = false
    var chase = false
}

@MainActor
final class Projectile {
    let node: SCNNode
    let owner: Side
    var pos: SIMD3<Float>
    let vel: SIMD3<Float>
    let radius: Float
    let power: Double
    var alive = true
    var aiRolled = false
    var evadeShown = false
    var age: Float = 0

    init(node: SCNNode, owner: Side, pos: SIMD3<Float>, vel: SIMD3<Float>, radius: Float, power: Double) {
        self.node = node
        self.owner = owner
        self.pos = pos
        self.vel = vel
        self.radius = radius
        self.power = power
    }
}
