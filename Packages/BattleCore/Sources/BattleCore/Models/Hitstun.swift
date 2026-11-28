/// Hitstun / control types (60 FPS frame counts from the brief).
public enum Hitstun: Sendable, Equatable {
    case none
    /// 18 f (0.30 s): head / upper body snaps back. Only a cover change is possible.
    case light
    /// 28 f (0.47 s): rocking side to side inside a combo. No vanish; only a cover change.
    case combo
    /// 40 f (0.67 s): spinning knockback, air recovery at the end, then free.
    case heavy
    /// Status stun (2.5 s by default): no actions and no switching.
    case stun
    /// Paralysis jolt: a short action interruption while paralyzed. No switching.
    case jolt

    public var duration: Double {
        switch self {
        case .none: return 0
        case .light: return 18.0 / 60
        case .combo: return 28.0 / 60
        case .heavy: return 40.0 / 60
        case .stun: return 2.5
        case .jolt: return 0.4
        }
    }

    /// Ailments lock out switching as well.
    public var isAilment: Bool { self == .stun || self == .jolt }
}
