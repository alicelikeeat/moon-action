import Foundation

/// Each fighter fights in one style; every card of that fighter picks its own combo string,
/// finisher, shot and sound set from the style (deterministically, so a card always looks and
/// sounds the same, and the same card name on two fighters still differs).
enum FightStyle: Int, CaseIterable {
    case boxer, kicker, brawler, artist

    static func of(_ d: FighterDef) -> FightStyle {
        if d.look.bulk >= 1.12 || d.speed == .slow { return .brawler }
        let h = Signatures.hash(d.id)
        if d.speed == .fast { return h % 2 == 0 ? .kicker : .artist }
        return [FightStyle.boxer, .kicker, .artist, .boxer][Int(h % 4)]
    }

    var name: String { L("style.\(self)") }

    @MainActor var strikes: [Clip] {
        switch self {
        case .boxer: return [Moves.jab, Moves.cross, Moves.hook, Moves.bodyBlow, Moves.elbow, Moves.cross, Moves.hook]
        case .kicker: return [Moves.jab, Moves.roundhouse, Moves.sideKick, Moves.knee, Moves.spinKick, Moves.lowSweep]
        case .brawler: return [Moves.hook, Moves.bodyBlow, Moves.elbow, Moves.knee, Moves.cross, Moves.backfist]
        case .artist: return [Moves.palm, Moves.backfist, Moves.roundhouse, Moves.spinKick, Moves.lowSweep, Moves.palm]
        }
    }

    @MainActor var finishers: [Clip] {
        switch self {
        case .boxer: return [Moves.uppercut, Moves.flyingPunch]
        case .kicker: return [Moves.flyingKick, Moves.axeKick, Moves.tornadoKick]
        case .brawler: return [Moves.smash, Moves.tackle, Moves.uppercut]
        case .artist: return [Moves.doublePalm, Moves.tornadoKick, Moves.axeKick]
        }
    }

    @MainActor var shots: [Clip] {
        switch self {
        case .boxer: return [Moves.shotR, Moves.shotThrow]
        case .kicker: return [Moves.shotR, Moves.shotDisc]
        case .brawler: return [Moves.shotThrow, Moves.shotBig]
        case .artist: return [Moves.shotPalm, Moves.shotDisc]
        }
    }

    var impacts: [SFX] {
        switch self {
        case .boxer: return [.crack, .hit]
        case .kicker: return [.slap, .crack]
        case .brawler: return [.thud, .hit]
        case .artist: return [.slap, .hit]
        }
    }

    var fires: [SFX] {
        switch self {
        case .boxer: return [.blast, .zap]
        case .kicker: return [.zap, .blast]
        case .brawler: return [.boom, .blast]
        case .artist: return [.zap, .blast]
        }
    }
}

/// The moves and sounds a single card uses.
struct CardSig {
    let strikes: [Clip]
    let finisher: Clip
    let shot: Clip
    let impact: SFX
    let heavyImpact: SFX
    let fire: SFX
    let pitch: Float
}

@MainActor
enum Signatures {
    private static var cache: [String: CardSig] = [:]

    /// Stable FNV-1a hash (Swift's hashValue is randomized per launch).
    nonisolated static func hash(_ s: String) -> UInt64 {
        s.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 }
    }

    private struct RNG {
        var state: UInt64
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
        mutating func int(_ n: Int) -> Int { Int(next() % UInt64(max(1, n))) }
    }

    static func of(_ card: Card, _ def: FighterDef) -> CardSig { make(key: def.id + "|" + card.id, def: def) }

    /// Signature for a card identified by id only (BattleCore arts cards).
    static func of(cardID: String, _ def: FighterDef) -> CardSig { make(key: def.id + "|" + cardID, def: def) }

    /// Basic (gesture) attacks: the style's first two strikes.
    static func basic(_ def: FighterDef) -> CardSig { make(key: def.id + "|basic", def: def) }

    private static func make(key: String, def: FighterDef) -> CardSig {
        if let c = cache[key] { return c }
        let style = FightStyle.of(def)
        var r = RNG(state: hash(key))
        var pool = style.strikes
        for i in stride(from: pool.count - 1, to: 0, by: -1) { pool.swapAt(i, r.int(i + 1)) }
        let sig = CardSig(
            strikes: key.hasSuffix("|basic") ? Array(style.strikes.prefix(2)) : pool,
            finisher: style.finishers[r.int(style.finishers.count)],
            shot: style.shots[r.int(style.shots.count)],
            impact: style.impacts[r.int(style.impacts.count)],
            heavyImpact: r.int(2) == 0 ? .heavy : .thud,
            fire: style.fires[r.int(style.fires.count)],
            pitch: 0.85 + Float(r.int(31)) / 100)
        cache[key] = sig
        return sig
    }
}
