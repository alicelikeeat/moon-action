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
    public var hp: Double
    public var vanish: Double = Tune.vanishMax
    public var phase: FighterPhase = .idle
    /// Game time at which a timed phase (moving / acting / stunned / vanishing) ends.
    public var phaseUntil: Double = 0
    public var abilityUsed = false
    public var tenacityUsed = false

    public init(def: FighterDef) {
        self.def = def
        self.hp = def.maxHP
    }

    public var isKO: Bool { phase == .ko }
    public var canAct: Bool { phase == .idle || phase == .moving || phase == .charging }
}

public struct SideState: Sendable {
    public var team: [FighterState]
    public var active = 0
    public var ki: Double = 50
    public var switchReadyAt: Double = 0
    public var damageDealt: Double = 0
    public var current: FighterState {
        get { team[active] }
        set { team[active] = newValue }
    }
    public var allKO: Bool { team.allSatisfy { $0.isKO } }

    public init(team: [FighterDef]) {
        self.team = team.map { FighterState(def: $0) }
    }
}

public enum Input: Sendable, Equatable {
    case moveForward      // swipe up
    case moveBack         // swipe down
    case chargeBegin      // long press began
    case chargeEnd        // long press ended
}

public enum BattleEvent: Sendable, Equatable {
    case zoneChanged(Zone)
    case ko(side: Int, fighter: Int)
    case tenacity(side: Int)
    case switched(side: Int, to: Int)
    case battleOver(winner: Int?)
}

/// Deterministic fixed-step battle simulation. Side 0 = player, side 1 = enemy.
public struct BattleEngine: Sendable {
    public private(set) var time: Double = 0
    public private(set) var timer: Double = Tune.battleTime
    public var sides: [SideState]
    public private(set) var gap: Double
    public private(set) var over = false
    public private(set) var winner: Int?
    /// Paused during cinematics, clashes and rush guessing.
    public var timerPaused = false

    private var accumulator: Double = 0
    private var gapFrom: Double = 0
    private var gapTo: Double = 0
    private var gapStart: Double = 0
    private var gapDuration: Double = 0
    private var lastZone: Zone

    public init(player: [FighterDef], enemy: [FighterDef], startZone: Zone = .mid) {
        sides = [SideState(team: player), SideState(team: enemy)]
        gap = Tune.zoneGap[startZone] ?? 6.2
        gapTo = gap
        lastZone = Zone.of(gap)
    }

    public var zone: Zone { Zone.of(gap) }

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

    private mutating func tick(_ events: inout [BattleEvent]) {
        guard !over else { return }
        let dt = Tune.step
        time += dt
        if !timerPaused {
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
        for s in 0..<2 {
            var side = sides[s]
            var f = side.current
            // Timed phases expire back to idle.
            switch f.phase {
            case .moving, .acting, .stunned, .vanishing:
                if time >= f.phaseUntil { f.phase = .idle }
            default: break
            }
            switch f.phase {
            case .charging: side.ki = min(Tune.kiMax, side.ki + Tune.chargeRate * dt)
            case .idle, .moving: side.ki = min(Tune.kiMax, side.ki + Tune.kiRegen * dt)
            default: break
            }
            if !f.isKO { f.vanish = min(Tune.vanishMax, f.vanish + Tune.vanishRegen * dt) }
            side.current = f
            sides[s] = side
        }
    }

    // MARK: Input

    @discardableResult
    public mutating func apply(_ input: Input, side s: Int) -> Bool {
        guard !over else { return false }
        var f = sides[s].current
        switch input {
        case .moveForward, .moveBack:
            guard f.canAct else { return false }
            let target: Double
            if input == .moveForward {
                target = zone == .close ? Tune.dashGap : (Tune.zoneGap[zone.closer] ?? gap)
            } else {
                target = Tune.zoneGap[zone.farther] ?? gap
            }
            guard abs(target - gap) > 0.01 else { return false }
            moveGap(to: target, over: Tune.moveTime)
            f.phase = .moving
            f.phaseUntil = time + Tune.moveTime
        case .chargeBegin:
            guard f.phase == .idle || f.phase == .moving else { return false }
            f.phase = .charging
        case .chargeEnd:
            guard f.phase == .charging else { return false }
            f.phase = .idle
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
    public mutating func stun(side s: Int, until: Double) {
        guard !sides[s].current.isKO else { return }
        sides[s].current.phase = .stunned
        sides[s].current.phaseUntil = max(sides[s].current.phaseUntil, until)
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
        if f.hp <= 0, f.def.has(.tenacity), !f.tenacityUsed {
            f.tenacityUsed = true
            f.hp = 1
            events.append(.tenacity(side: s))
        }
        sides[1 - s].damageDealt += dealt
        if f.hp <= 0 {
            f.hp = 0
            f.phase = .ko
            sides[s].current = f
            events.append(.ko(side: s, fighter: sides[s].active))
            if sides[s].allKO {
                over = true
                winner = 1 - s
                events.append(.battleOver(winner: 1 - s))
            } else if let next = sides[s].team.indices.first(where: { !sides[s].team[$0].isKO }) {
                sides[s].active = next
                sides[s].current.phase = .idle
                events.append(.switched(side: s, to: next))
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
