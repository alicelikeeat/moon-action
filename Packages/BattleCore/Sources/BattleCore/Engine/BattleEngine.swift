/// What a fighter is doing right now (the per-fighter state machine).
public enum FighterPhase: Sendable, Equatable {
    case idle
    case moving
    case charging
    case acting       // playing a card / attacking
    case stunned      // hit / locked in a combo
    case vanishing
    case ko
}

public struct FighterState: Sendable {
    public let def: FighterDef
    /// Resolved battle stats (level, stars, Z ability, leader, equipment).
    public let stats: FinalStats
    public var hp: Double
    public var vanish: Double = Tune.vanishMax
    public var phase: FighterPhase = .idle
    /// Game time at which a timed phase (moving / acting / stunned / vanishing) ends.
    public var phaseUntil: Double = 0
    /// Kind of hitstun while `phase == .stunned`.
    public internal(set) var hitstun: Hitstun = .none
    /// Paralysis: until then, every second there is a 25 % chance the current action is interrupted.
    public internal(set) var paralyzedUntil: Double = 0
    public internal(set) var nextParalysisCheck: Double = 0
    /// Recovery (cannot act) queued after the current movement, e.g. a back dash.
    public internal(set) var pendingRecovery: Double = 0
    /// Unique gauge 0…100 and its states.
    public internal(set) var gauge: Double = 0
    public internal(set) var overload = false
    public internal(set) var counterUses = 0
    public internal(set) var attackBurstUntil: Double = 0
    public var abilityUsed = false
    public var tenacityUsed = false
    /// Card / attack in progress.
    public internal(set) var action: Action?
    public internal(set) var invulnUntil: Double = 0
    public internal(set) var shieldUntil: Double = 0
    public internal(set) var shieldReduction: Double = 0
    public internal(set) var counterUntil: Double = 0
    public internal(set) var counterStun: Double = 0
    public internal(set) var nextStrikeBonus: Double = 0
    public internal(set) var guaranteedCrit = false
    public internal(set) var armorUntil: Double = 0
    public internal(set) var damageBonus: Double = 0
    public internal(set) var statBonus: Double = 0

    public init(def: FighterDef, stats: FinalStats? = nil) {
        self.def = def
        self.stats = stats ?? FinalStats(def.benchmark)
        self.hp = self.stats.hp
    }

    public var maxHP: Double { stats.hp }
    public var isKO: Bool { phase == .ko }
    public var canAct: Bool { phase == .idle || phase == .moving || phase == .charging }
}

public struct SideState: Sendable {
    public var team: [FighterState]
    public var active = 0
    public var ki: Double = 50
    public var switchReadyAt: Double = 0
    public var damageDealt: Double = 0
    /// Up to 4 hand slots; nil while a slot is refilling.
    public internal(set) var hand: [HandCard?] = [nil, nil, nil, nil]
    public internal(set) var refillAt: [Double?] = [nil, nil, nil, nil]
    public internal(set) var deck: [ArtsCard] = []
    /// Energy orbs collected for the rush (0…7).
    public internal(set) var orbs = 0
    /// Cards landed in the current combo (for combo compensation).
    public internal(set) var comboCards = 0
    public internal(set) var comboHits = 0
    public internal(set) var fastDrawUntil: Double = 0
    /// Cover nullification: until then the opponent's special covers cannot interrupt this side's combos.
    public internal(set) var coverNullUntil: Double = 0
    /// Team-wide damage up from a main ability (e.g. Lan) until a time.
    public internal(set) var teamDamageUp: Double = 0
    public internal(set) var teamDamageUntil: Double = 0
    public func teamDamageBonus(at t: Double) -> Double { t < teamDamageUntil ? teamDamageUp : 0 }

    /// Input buffer / combo routes.
    public internal(set) var combo = ComboTracker()

    /// A special cover change was used during the opponent's current combo.
    public internal(set) var specialCoverUsed = false

    public var current: FighterState {
        get { team[active] }
        set { team[active] = newValue }
    }
    public var allKO: Bool { team.allSatisfy { $0.isKO } }

    public init(team: [FighterDef], stats: [FinalStats]? = nil) {
        self.team = team.enumerated().map { i, d in
            FighterState(def: d, stats: stats.flatMap { $0.indices.contains(i) ? $0[i] : nil })
        }
    }
}

public enum Input: Sendable, Equatable {
    case moveForward      // swipe up
    case moveBack         // swipe down
    case sidestep(Int)    // swipe left (-1) / right (+1): vanish inside a warning window
    case tap              // basic attack
    case chargeBegin      // long press began
    case chargeEnd        // long press ended
    case play(Int)        // hand slot 0…3
    case clashTap         // lock the clash bar
    case risingRush       // 7 orbs: unleash the rush
    case rushPick(Int)    // attacker: card the defender must guess
    case rushGuess(Int)   // defender: guess one of 4
    case switchTo(Int)    // team member index (tag switch / cover change while being hit)
}

public enum HitKind: Sendable, Equatable { case basic, strike, blast, special, ultimate }

public struct HitInfo: Sendable, Equatable {
    public let attacker: Int
    public let kind: HitKind
    public let damage: Double
    public let crit: Bool
    public let matchup: Element.Matchup
    /// Last hit of a card: knock back / launch.
    public let heavy: Bool
    public let hitIndex: Int
    public let comboHits: Int
    /// Hitstun the defender was put in by this hit (`.none` under super armor).
    public var stun: Hitstun = .combo
}

public enum BattleEvent: Sendable, Equatable {
    case zoneChanged(Zone)
    case ko(side: Int, fighter: Int)
    case tenacity(side: Int)
    case switched(side: Int, to: Int)
    case battleOver(winner: Int?)
    case cardPlayed(side: Int, card: ArtsCard, comboIndex: Int)
    case dash(side: Int, duration: Double)
    case swing(side: Int, kind: HitKind, hitIndex: Int, heavy: Bool)
    case shotFired(side: Int, travel: Double, big: Bool)
    case hit(HitInfo)
    case shieldBlocked(side: Int)
    case armorBreak(side: Int)
    case countered(side: Int)
    case warning(side: Int, lead: Double)
    case vanished(side: Int)
    case whiff(side: Int)
    case sidestep(side: Int, dir: Int)
    case support(side: Int, effect: SupportEffect)
    case handChanged(side: Int)
    case comboEnded(side: Int, hits: Int)
    case cinematic(side: Int, card: ArtsCard)
    /// Manual tag switch. `cover`: switched in while being comboed; `special`: matching cover tag knocked the attacker away.
    case tagged(side: Int, to: Int, cover: Bool, special: Bool)
    /// Swipe movement: forward dash (0.28 s) or back dash (with a 0.15 s recovery).
    case stepped(side: Int, forward: Bool, duration: Double)
    /// Heavy knockback finished with an air recovery roll; the fighter is free again.
    case recovered(side: Int)
    /// Status ailments.
    case stunApplied(side: Int, duration: Double)
    case paralyzed(side: Int, duration: Double)
    case paralysisJolt(side: Int)
    /// Combo tracker.
    case inputBuffered(side: Int, slot: Int)
    case comboRoute(side: Int, route: ComboRoute)
    case comboDropped(side: Int)
    /// Unique gauges.
    case gaugeTriggered(side: Int, type: UniqueGaugeType)
    case autoEvaded(side: Int)
    /// Strike clash.
    case clashStarted(until: Double)
    case clashLocked(side: Int, score: Int)
    case clashResolved(winner: Int?, scores: [Int])
    /// Rising Rush.
    case rushStarted(side: Int)
    case rushMissed(side: Int)
    case rushGuessing(defender: Int, until: Double)
    case rushParried(side: Int)
    case rushFinish(side: Int)
}

/// Deterministic fixed-step battle simulation. Side 0 = player, side 1 = enemy.
public struct BattleEngine: Sendable {
    public internal(set) var time: Double = 0
    public internal(set) var timer: Double = Tune.battleTime
    public var sides: [SideState]
    public internal(set) var gap: Double
    public internal(set) var over = false
    public internal(set) var winner: Int?
    /// Paused during cinematics, clashes and rush guessing.
    public var timerPaused = false
    /// Seconds of timer pause owed to a running cinematic (special / ultimate startup).
    var cinematicUntil: Double = 0
    /// Strike clash in progress (both strike cards collided).
    public internal(set) var clash: ClashState?
    /// Rising Rush in progress.
    public internal(set) var rush: RushState?
    public var rng: SplitMix64
    public internal(set) var shots: [Shot] = []

    var accumulator: Double = 0
    var gapFrom: Double = 0
    var gapTo: Double = 0
    var gapStart: Double = 0
    var gapDuration: Double = 0
    var lastZone: Zone
    var nextCardID = 1

    /// Battle from full loadouts: final stats come from level, stars, Z abilities (leader = first), Ultra and equipment.
    public init(player: [FighterLoadout], enemy: [FighterLoadout], startZone: Zone = .mid, seed: UInt64 = 0x5EED) {
        self.init(player: player.map(\.def), enemy: enemy.map(\.def), startZone: startZone, seed: seed,
                  playerStats: TeamBuild.finalStats(team: player), enemyStats: TeamBuild.finalStats(team: enemy))
    }

    public init(player: [FighterDef], enemy: [FighterDef], startZone: Zone = .mid, seed: UInt64 = 0x5EED,
                playerStats: [FinalStats]? = nil, enemyStats: [FinalStats]? = nil) {
        sides = [SideState(team: player, stats: playerStats), SideState(team: enemy, stats: enemyStats)]
        gap = Tune.zoneGap[startZone] ?? 6.2
        gapTo = gap
        lastZone = Zone.of(gap)
        rng = SplitMix64(seed: seed)
        for s in 0..<2 { fillHand(s) }
    }

    public var zone: Zone { Zone.of(gap) }
    public var inCinematic: Bool { time < cinematicUntil }

    // MARK: Loop

    /// Advance by a rendered frame's dt (clamped), in fixed steps. Returns the events that happened.
    @discardableResult
    public mutating func advance(_ dt: Double) -> [BattleEvent] {
        var events: [BattleEvent] = []
        accumulator += min(max(0, dt), Tune.maxFrameDT)
        while accumulator >= Tune.step - 1e-12 {
            accumulator -= Tune.step
            tick(&events)
        }
        return events
    }

    mutating func tick(_ events: inout [BattleEvent]) {
        guard !over else { return }
        let dt = Tune.step
        time += dt
        if !timerPaused && !inCinematic {
            timer = max(0, timer - dt)
            if timer == 0 {
                finishOnTime(&events)
                return
            }
        }
        // Distance tween.
        if gapDuration > 0 {
            let t = min(1, (time - gapStart) / gapDuration)
            let e = t * t * (3 - 2 * t)
            gap = gapFrom + (gapTo - gapFrom) * e
            if t >= 1 { gapDuration = 0 }
        }
        let z = zone
        if z != lastZone {
            lastZone = z
            events.append(.zoneChanged(z))
        }
        checkClash(&events)
        stepClash(&events)
        stepRush(&events)
        stepGauges(dt, &events)
        stepActions(&events)
        stepCombos(&events)
        stepShots(&events)
        stepWarnings(&events)
        for s in 0..<2 {
            var side = sides[s]
            var f = side.current
            // Timed phases expire back to idle.
            switch f.phase {
            case .moving, .acting, .stunned, .vanishing:
                if time >= f.phaseUntil, f.phase == .moving, f.pendingRecovery > 0 {
                    f.phase = .acting
                    f.phaseUntil = time + f.pendingRecovery
                    f.pendingRecovery = 0
                } else if time >= f.phaseUntil {
                    if f.phase == .stunned && f.hitstun == .heavy { events.append(.recovered(side: s)) }
                    f.phase = .idle
                    f.hitstun = .none
                    f.action = nil
                }
            default: break
            }
            // Ki recovers all the time (DBL-style); holding to charge is much faster.
            switch f.phase {
            case .charging: side.ki = min(Tune.kiMax, side.ki + Tune.chargeRate * dt)
            case .ko: break
            default: side.ki = min(Tune.kiMax, side.ki + Tune.kiRegen * (1 + f.stats.kiRecoveryUp) * dt)
            }
            if !f.isKO { f.vanish = min(Tune.vanishMax, f.vanish + Tune.vanishRegen * dt) }
            side.current = f
            sides[s] = side
            stepParalysis(s, &events)
            refillHand(s, &events)
        }
        // A combo ends once the defender is free again.
        for s in 0..<2 where sides[s].comboCards > 0 || sides[s].comboHits > 0 {
            let d = sides[1 - s].current
            if d.phase != .stunned && d.phase != .ko {
                events.append(.comboEnded(side: s, hits: sides[s].comboHits))
                sides[1 - s].specialCoverUsed = false
                sides[s].combo.reset()
                sides[s].comboCards = 0
                sides[s].comboHits = 0
            }
        }
    }

    // MARK: Input

    @discardableResult
    public mutating func apply(_ input: Input, side s: Int) -> Bool {
        var events: [BattleEvent] = []
        return apply(input, side: s, events: &events)
    }

    /// Input with the events it produces (cards played, vanish, …).
    @discardableResult
    public mutating func apply(_ input: Input, side s: Int, events: inout [BattleEvent]) -> Bool {
        guard !over else { return false }
        // Clash / rush lock all other input.
        if clash != nil { return input == .clashTap ? lockClash(s, &events) : false }
        if rush != nil {
            switch input {
            case .rushPick(let slot): return rushPick(s, slot: slot)
            case .rushGuess(let slot): return rushGuess(s, slot: slot, &events)
            default: return false
            }
        }
        var f = sides[s].current
        switch input {
        case .clashTap, .rushPick, .rushGuess:
            return false
        case .risingRush:
            return startRush(s, &events)
        case .moveForward, .moveBack:
            let route = input == .moveForward && routeOpen(s)
            guard f.canAct || route else { return false }
            if route {
                noteRouteStep(s, .dash)
                f.action = nil
            }
            let target: Double
            if input == .moveForward {
                target = zone == .close ? Tune.dashGap : (Tune.zoneGap[zone.closer] ?? gap)
            } else {
                target = Tune.zoneGap[zone.farther] ?? gap
            }
            guard abs(target - gap) > 0.01 else { return false }
            let forward = input == .moveForward
            let travel = forward ? Tune.dashTime : Tune.moveTime
            moveGap(to: target, over: travel)
            f.phase = .moving
            // Back dash ends in a short recovery so it cannot be spammed for free; a forward dash can be card-cancelled.
            f.phaseUntil = time + travel
            f.pendingRecovery = forward ? 0 : Tune.backDashRecovery
            events.append(.stepped(side: s, forward: forward, duration: travel))
        case .chargeBegin:
            let route = routeOpen(s)
            guard f.phase == .idle || f.phase == .moving || route else { return false }
            if route {
                sides[s].combo.chargeStart = time
                f.action = nil
            }
            f.phase = .charging
        case .chargeEnd:
            guard f.phase == .charging else { return false }
            if let start = sides[s].combo.chargeStart {
                sides[s].combo.chargeHeld = time - start
                sides[s].combo.chargeStart = nil
                sides[s].combo.steps.append(.charge)
            }
            f.phase = .idle
        case .sidestep(let dir):
            return sidestep(s, dir: dir, &events)
        case .tap:
            return basicAttack(s, &events)
        case .play(let slot):
            return playCard(s, slot: slot, &events) || bufferCard(s, slot: slot, &events)
        case .switchTo(let i):
            return switchFighter(s, to: i, &events)
        }
        sides[s].current = f
        return true
    }

    public mutating func moveGap(to target: Double, over duration: Double) {
        gapFrom = gap
        gapTo = max(0.8, target)
        gapStart = time
        gapDuration = max(Tune.step, duration)
    }

    /// Lock a fighter in hitstun until `until` (cannot act, vanish or charge).
    public mutating func stun(side s: Int, until: Double, type: Hitstun = .combo) {
        guard !sides[s].current.isKO else { return }
        let wasStunned = sides[s].current.phase == .stunned
        let previous = wasStunned ? sides[s].current.phaseUntil : 0
        sides[s].current.phase = .stunned
        sides[s].current.action = nil
        sides[s].current.phaseUntil = max(previous, until)
        // An ailment is never downgraded by a hit landing during it.
        if !(wasStunned && sides[s].current.hitstun.isAilment && !type.isAilment) { sides[s].current.hitstun = type }
    }

    /// Status stun: no actions, no vanish and no switching for `duration`.
    public mutating func applyStun(side s: Int, duration: Double = Hitstun.stun.duration, _ events: inout [BattleEvent]) {
        guard !sides[s].current.isKO else { return }
        stun(side: s, until: time + duration, type: .stun)
        events.append(.stunApplied(side: s, duration: duration))
    }

    /// Paralysis (10 s by default): every second a 25 % chance to interrupt whatever the fighter is doing.
    public mutating func paralyze(side s: Int, duration: Double = 10, _ events: inout [BattleEvent]) {
        guard !sides[s].current.isKO else { return }
        sides[s].current.paralyzedUntil = time + duration
        sides[s].current.nextParalysisCheck = time + 1
        events.append(.paralyzed(side: s, duration: duration))
    }

    mutating func stepParalysis(_ s: Int, _ events: inout [BattleEvent]) {
        let f = sides[s].current
        guard !f.isKO, time < f.paralyzedUntil, time >= f.nextParalysisCheck else { return }
        sides[s].current.nextParalysisCheck = time + 1
        guard f.phase != .stunned, rng.chance(Tune.paralysisChance) else { return }
        stun(side: s, until: time + Hitstun.jolt.duration, type: .jolt)
        events.append(.paralysisJolt(side: s))
    }

    // MARK: Damage / KO

    /// Apply damage to the active fighter of side `s`; handles tenacity, KO, auto-switch and victory.
    @discardableResult
    public mutating func damage(_ amount: Double, to s: Int) -> [BattleEvent] {
        var events: [BattleEvent] = []
        guard !over, !sides[s].current.isKO else { return events }
        var f = sides[s].current
        let dealt = min(f.hp, max(0, amount))
        f.hp -= dealt
        if f.hp <= 0, let heal = f.def.tenacityHeal, !f.tenacityUsed {
            // Endurance: survive at 1 HP, then recover a fraction of max HP.
            f.tenacityUsed = true
            f.hp = 1 + f.maxHP * heal
            events.append(.tenacity(side: s))
        }
        sides[1 - s].damageDealt += dealt
        if f.hp <= 0 {
            f.hp = 0
            f.phase = .ko
            f.action = nil
            sides[s].current = f
            events.append(.ko(side: s, fighter: sides[s].active))
            // The attacker's pending hits on the KO'd fighter end safely.
            shots.removeAll { $0.target == s }
            if sides[s].allKO {
                over = true
                winner = 1 - s
                events.append(.battleOver(winner: 1 - s))
            } else if let next = sides[s].team.indices.first(where: { !sides[s].team[$0].isKO }) {
                sides[s].active = next
                sides[s].current.phase = .idle
                sides[s].current.invulnUntil = time + 0.8
                sides[s].comboCards = 0
                sides[1 - s].comboCards = 0
                sides[1 - s].comboHits = 0
                refreshHand(s)
                events.append(.switched(side: s, to: next))
                events.append(.handChanged(side: s))
            }
        } else {
            sides[s].current = f
        }
        return events
    }

    private mutating func finishOnTime(_ events: inout [BattleEvent]) {
        over = true
        let a = sides[0].damageDealt, b = sides[1].damageDealt
        winner = a == b ? nil : (a > b ? 0 : 1)
        events.append(.battleOver(winner: winner))
    }
}

/// Small deterministic RNG (SplitMix64) so battles and tests are reproducible.
public struct SplitMix64: Sendable {
    public var state: UInt64
    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }

    /// Uniform in [0, 1).
    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
    public mutating func chance(_ p: Double) -> Bool { unit() < p }
    public mutating func int(_ n: Int) -> Int { n <= 1 ? 0 : Int(next() % UInt64(n)) }
}
