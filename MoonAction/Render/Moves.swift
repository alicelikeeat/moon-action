import simd

/// Keyframed move set shared by every fighter (procedural and imported models).
/// Joint conventions (radians): shoulder x < 0 raises the arm forward, elbow x < 0 bends it;
/// hip x < 0 lifts the leg forward, knee x > 0 bends it; spine x > 0 leans forward, y twists
/// (positive turns the right shoulder forward); left limbs abduct with +z, right limbs with -z.
/// Body offsets: z forward, y up. Each strike: anticipation → snap to impact → short hold.
@MainActor
enum Moves {
    private static func P(_ e: [(Joint, Float, Float, Float)]) -> Pose {
        var p: Pose = [:]
        for (j, x, y, z) in e { p[j] = SIMD3(x, y, z) }
        return p
    }

    // MARK: Strikes

    static let jab = Clip(name: "jab", keys: [
        Key(0.05, P([(.spine, 0.12, 0.18, 0), (.shoulderL, -0.85, 0, 0.35), (.elbowL, -1.95, 0, 0)]), body: SIMD3(0, -0.02, -0.03)),
        Key(0.1, P([(.spine, 0.2, -0.45, 0), (.shoulderL, -1.62, 0, 0.05), (.elbowL, -0.05, 0, 0), (.shoulderR, -0.9, 0, -0.3),
                    (.hipL, -0.7, 0, 0.06), (.kneeL, 0.6, 0, 0)]), body: SIMD3(0, -0.03, 0.14), ease: .snap),
        Key(0.17, P([(.spine, 0.2, -0.45, 0), (.shoulderL, -1.6, 0, 0.05), (.elbowL, -0.1, 0, 0)]), body: SIMD3(0, -0.03, 0.14)),
    ], impact: 0.1, blendOut: 0.14)

    static let cross = Clip(name: "cross", keys: [
        Key(0.06, P([(.spine, 0.1, -0.3, 0), (.shoulderR, -0.6, 0, -0.4), (.elbowR, -2.0, 0, 0)]), body: SIMD3(0, -0.03, -0.05)),
        Key(0.11, P([(.spine, 0.25, 0.55, 0), (.shoulderR, -1.62, 0, -0.05), (.elbowR, -0.04, 0, 0), (.shoulderL, -1.0, 0, 0.45),
                     (.elbowL, -1.9, 0, 0), (.hipR, 0.45, 0, -0.06), (.kneeR, 0.3, 0, 0)]), body: SIMD3(0, -0.05, 0.2), ease: .snap),
        Key(0.19, P([(.spine, 0.25, 0.55, 0), (.shoulderR, -1.6, 0, -0.05), (.elbowR, -0.1, 0, 0)]), body: SIMD3(0, -0.05, 0.2)),
    ], impact: 0.11, blendOut: 0.15)

    static let hook = Clip(name: "hook", keys: [
        Key(0.07, P([(.spine, 0.1, 0.45, 0), (.shoulderL, -1.1, 0, 1.25), (.elbowL, -1.5, 0, 0)]), body: SIMD3(0, -0.04, 0)),
        Key(0.13, P([(.spine, 0.2, -0.75, 0.05), (.shoulderL, -1.5, 0, -0.15), (.elbowL, -1.45, 0, 0), (.head, 0.1, -0.2, 0)]),
            body: SIMD3(0, -0.06, 0.14), rot: SIMD3(0, -0.25, 0), ease: .snap),
        Key(0.21, P([(.spine, 0.2, -0.75, 0.05), (.shoulderL, -1.45, 0, -0.1), (.elbowL, -1.5, 0, 0)]),
            body: SIMD3(0, -0.06, 0.14), rot: SIMD3(0, -0.25, 0)),
    ], impact: 0.13, blendOut: 0.17)

    static let knee = Clip(name: "knee", keys: [
        Key(0.06, P([(.spine, -0.1, 0, 0), (.hipR, 0.4, 0, 0), (.kneeR, 0.9, 0, 0), (.shoulderL, -1.4, 0, 0.3), (.shoulderR, -1.4, 0, -0.3),
                     (.elbowL, -1.4, 0, 0), (.elbowR, -1.4, 0, 0)]), body: SIMD3(0, 0.02, -0.04)),
        Key(0.12, P([(.spine, 0.35, 0, 0), (.hipR, -1.75, 0, 0), (.kneeR, 2.1, 0, 0), (.hipL, 0.1, 0, 0.05), (.kneeL, 0.2, 0, 0),
                     (.shoulderL, -0.7, 0, 0.2), (.shoulderR, -0.7, 0, -0.2), (.elbowL, -1.0, 0, 0), (.elbowR, -1.0, 0, 0)]),
            body: SIMD3(0, 0.1, 0.18), ease: .snap),
        Key(0.2, P([(.spine, 0.35, 0, 0), (.hipR, -1.7, 0, 0), (.kneeR, 2.1, 0, 0)]), body: SIMD3(0, 0.1, 0.18)),
    ], impact: 0.12, blendOut: 0.18)

    static let roundhouse = Clip(name: "roundhouse", keys: [
        Key(0.08, P([(.spine, 0, 0.35, 0), (.hipR, -0.4, 0, -0.3), (.kneeR, 1.5, 0, 0), (.shoulderL, -1.2, 0, 0.6)]),
            rot: SIMD3(0, 0.35, 0)),
        Key(0.15, P([(.spine, -0.3, -0.6, -0.35), (.hipR, -1.45, 0, -1.05), (.kneeR, 0.1, 0, 0), (.hipL, 0, 0, 0.1), (.kneeL, 0.25, 0, 0),
                     (.shoulderL, -0.9, 0, 1.1), (.shoulderR, 0.3, 0, -0.8), (.elbowR, -0.6, 0, 0)]),
            body: SIMD3(0, 0.04, 0.12), rot: SIMD3(0, -0.7, 0), ease: .snap),
        Key(0.24, P([(.spine, -0.3, -0.6, -0.35), (.hipR, -1.4, 0, -1.0), (.kneeR, 0.2, 0, 0)]),
            body: SIMD3(0, 0.04, 0.12), rot: SIMD3(0, -0.75, 0)),
    ], impact: 0.15, blendOut: 0.2)

    static let spinKick = Clip(name: "spinKick", keys: [
        Key(0.07, P([(.spine, 0.15, 0, 0), (.kneeL, 1.0, 0, 0), (.kneeR, 1.0, 0, 0)]), body: SIMD3(0, -0.06, 0), rot: SIMD3(0, 0.4, 0)),
        Key(0.14, P([(.spine, -0.1, 0, 0), (.hipR, -0.5, 0, -0.4), (.kneeR, 1.3, 0, 0)]), body: SIMD3(0, 0.12, 0.05), rot: SIMD3(0, 2.4, 0),
            ease: .linear),
        Key(0.2, P([(.spine, -0.35, 0, 0.3), (.hipR, -1.5, 0, -0.6), (.kneeR, 0.05, 0, 0), (.shoulderL, 0.2, 0, 1.1), (.shoulderR, 0.2, 0, -1.1),
                    (.elbowL, -0.4, 0, 0), (.elbowR, -0.4, 0, 0)]),
            body: SIMD3(0, 0.14, 0.16), rot: SIMD3(0, 3.6, 0), ease: .snap),
        Key(0.3, P([(.hipR, -1.3, 0, -0.5), (.kneeR, 0.3, 0, 0)]), body: SIMD3(0, 0.04, 0.16), rot: SIMD3(0, 2 * .pi, 0), ease: .inOut),
    ], impact: 0.2, blendOut: 0.18)

    /// Rising uppercut: crouch, then explode upward. Used as a launcher.
    static let uppercut = Clip(name: "uppercut", keys: [
        Key(0.08, P([(.spine, 0.45, 0.35, 0), (.kneeL, 1.3, 0, 0), (.kneeR, 1.4, 0, 0), (.hipL, -0.8, 0, 0.1), (.hipR, -0.4, 0, -0.1),
                     (.shoulderR, 0.1, 0, -0.35), (.elbowR, -1.9, 0, 0)]), body: SIMD3(0, -0.2, -0.02)),
        Key(0.15, P([(.spine, -0.3, -0.35, 0), (.shoulderR, -2.95, 0, -0.15), (.elbowR, -0.5, 0, 0), (.shoulderL, 0.3, 0, 0.5), (.elbowL, -0.8, 0, 0),
                     (.kneeL, 0.2, 0, 0), (.kneeR, 0.5, 0, 0), (.hipL, -0.1, 0, 0.05), (.hipR, 0.2, 0, -0.05), (.head, -0.3, 0, 0)]),
            body: SIMD3(0, 0.3, 0.16), ease: .snap),
        Key(0.27, P([(.shoulderR, -2.9, 0, -0.15), (.elbowR, -0.5, 0, 0)]), body: SIMD3(0, 0.26, 0.16)),
    ], impact: 0.15, blendOut: 0.22)

    /// Double axe-handle smash: leap, both fists overhead, slam down. Heavy finisher.
    static let smash = Clip(name: "smash", keys: [
        Key(0.1, P([(.spine, -0.35, 0, 0), (.shoulderL, -3.0, 0, 0.1), (.shoulderR, -3.0, 0, -0.1), (.elbowL, -0.7, 0, 0), (.elbowR, -0.7, 0, 0),
                    (.hipL, -0.9, 0, 0.1), (.kneeL, 1.4, 0, 0), (.hipR, -0.3, 0, -0.1), (.kneeR, 1.0, 0, 0), (.head, -0.3, 0, 0)]),
            body: SIMD3(0, 0.32, 0.05)),
        Key(0.17, P([(.spine, 0.75, 0, 0), (.shoulderL, -1.0, 0, -0.15), (.shoulderR, -1.0, 0, 0.15), (.elbowL, -0.15, 0, 0), (.elbowR, -0.15, 0, 0),
                     (.hipL, -0.6, 0, 0.1), (.kneeL, 1.1, 0, 0), (.hipR, 0.2, 0, -0.1), (.kneeR, 0.9, 0, 0), (.head, 0.2, 0, 0)]),
            body: SIMD3(0, 0.0, 0.2), ease: .snap),
        Key(0.3, P([(.spine, 0.7, 0, 0)]), body: SIMD3(0, -0.04, 0.2)),
    ], impact: 0.17, blendOut: 0.24)

    /// Flying knee / dragon kick finisher: lunge with the whole body.
    static let flyingKick = Clip(name: "flyingKick", keys: [
        Key(0.08, P([(.spine, 0.4, 0, 0), (.kneeL, 1.2, 0, 0), (.kneeR, 1.2, 0, 0), (.shoulderL, 0.6, 0, 0.3), (.shoulderR, 0.6, 0, -0.3)]),
            body: SIMD3(0, -0.12, -0.05)),
        Key(0.16, P([(.spine, -0.45, 0, 0), (.hipR, -1.55, 0, 0), (.kneeR, 0.05, 0, 0), (.hipL, 0.4, 0, 0.1), (.kneeL, 1.6, 0, 0),
                     (.shoulderL, -0.2, 0, 1.3), (.shoulderR, -0.2, 0, -1.3), (.elbowL, -0.3, 0, 0), (.elbowR, -0.3, 0, 0)]),
            body: SIMD3(0, 0.35, 0.3), rot: SIMD3(-0.35, 0, 0), ease: .snap),
        Key(0.28, P([(.hipR, -1.5, 0, 0), (.kneeR, 0.1, 0, 0)]), body: SIMD3(0, 0.3, 0.3), rot: SIMD3(-0.3, 0, 0)),
    ], impact: 0.16, blendOut: 0.24)

    /// Combo string used by strike cards; the last hit is a finisher/launcher.
    static let string: [Clip] = [jab, cross, hook, knee, roundhouse, cross, hook, spinKick]
    static let finishers: [Clip] = [uppercut, smash, flyingKick]
    static let basicString: [Clip] = [jab, cross]

    // MARK: Shots

    static let shotR = Clip(name: "shotR", keys: [
        Key(0.07, P([(.spine, 0.05, -0.35, 0), (.shoulderR, -0.5, 0, -0.7), (.elbowR, -1.6, 0, 0), (.shoulderL, -0.9, 0, 0.4), (.elbowL, -1.7, 0, 0)])),
        Key(0.11, P([(.spine, 0.05, 0.55, 0), (.shoulderR, -1.57, 0, 0.05), (.elbowR, 0, 0, 0), (.head, 0, -0.3, 0)]), body: SIMD3(0, 0, 0.06), ease: .snap),
        Key(0.2, P([(.spine, -0.05, 0.5, 0), (.shoulderR, -1.75, 0, 0.05), (.elbowR, -0.1, 0, 0)]), body: SIMD3(0, 0, -0.08)),
    ], impact: 0.11, blendOut: 0.16)

    static let shotL = Clip(name: "shotL", keys: [
        Key(0.07, P([(.spine, 0.05, 0.35, 0), (.shoulderL, -0.5, 0, 0.7), (.elbowL, -1.6, 0, 0)])),
        Key(0.11, P([(.spine, 0.05, -0.5, 0), (.shoulderL, -1.57, 0, -0.05), (.elbowL, 0, 0, 0), (.head, 0, 0.3, 0)]), body: SIMD3(0, 0, 0.06), ease: .snap),
        Key(0.2, P([(.spine, -0.05, -0.45, 0), (.shoulderL, -1.75, 0, -0.05), (.elbowL, -0.1, 0, 0)]), body: SIMD3(0, 0, -0.08)),
    ], impact: 0.11, blendOut: 0.16)

    /// Two-handed heavy shot (big blast cards).
    static let shotBig = Clip(name: "shotBig", keys: [
        Key(0.14, FighterModel.beamChargePose, body: SIMD3(0, -0.05, -0.05)),
        Key(0.2, FighterModel.beamFirePose, body: SIMD3(0, 0, 0.08), ease: .snap),
        Key(0.34, FighterModel.beamFirePose, body: SIMD3(0, 0, -0.14)),
    ], impact: 0.2, blendOut: 0.2)

    // MARK: Movement

    static let dash = Clip(name: "dash", keys: [
        Key(0.08, FighterModel.dashPose, rot: SIMD3(0.35, 0, 0)),
    ], hold: true)

    static let stepBack = Clip(name: "stepBack", keys: [
        Key(0.07, P([(.spine, -0.3, 0, 0), (.kneeL, 1.2, 0, 0), (.kneeR, 1.2, 0, 0), (.hipL, -1.0, 0, 0.1), (.hipR, -0.8, 0, -0.1),
                     (.shoulderL, -0.4, 0, 0.6), (.shoulderR, -0.4, 0, -0.6)]), body: SIMD3(0, 0.2, 0), rot: SIMD3(-0.25, 0, 0)),
        Key(0.22, [:], body: SIMD3(0, 0.05, 0), rot: SIMD3(-0.1, 0, 0), ease: .inOut),
    ], blendOut: 0.12)

    /// Vanish sidestep: low, fast lean.
    static func sidestep(_ dir: Float) -> Clip {
        Clip(name: "sidestep", keys: [
            Key(0.06, P([(.spine, 0.35, 0, dir * 0.35), (.kneeL, 1.3, 0, 0), (.kneeR, 1.3, 0, 0), (.hipL, -0.9, 0, 0.3), (.hipR, -0.9, 0, -0.3)]),
                body: SIMD3(0, -0.15, 0), rot: SIMD3(0, 0, dir * 0.3)),
            Key(0.16, [:], body: SIMD3(0, -0.08, 0), rot: SIMD3(0, 0, dir * 0.15)),
        ], blendOut: 0.12)
    }

    // MARK: Ki

    /// Powering up: wide stance, fists clenched low, trembling.
    static let charge = Clip(name: "charge", keys: [
        Key(0.15, FighterModel.chargePose, body: SIMD3(0, -0.06, 0)),
        Key(0.2, P([(.spine, 0.24, 0, 0.02), (.head, -0.3, 0, 0)]), body: SIMD3(0.01, -0.07, 0), ease: .linear),
        Key(0.25, P([(.spine, 0.2, 0, -0.02), (.head, -0.25, 0, 0)]), body: SIMD3(-0.01, -0.06, 0), ease: .linear),
    ], loop: true)

    static let beamCharge = Clip(name: "beamCharge", keys: [Key(0.15, FighterModel.beamChargePose, body: SIMD3(0, -0.06, -0.04))], hold: true)
    static let beamFire = Clip(name: "beamFire", keys: [Key(0.06, FighterModel.beamFirePose, body: SIMD3(0, 0, 0.06), ease: .snap)], hold: true)

    // MARK: Reactions

    /// Light hit: head snaps back.
    static let hitHead = Clip(name: "hitHead", keys: [
        Key(0.04, P([(.spine, -0.4, 0.25, 0.1), (.head, -0.6, 0.3, 0), (.shoulderL, -0.4, 0, 0.8), (.shoulderR, -0.4, 0, -0.8),
                     (.elbowL, -1.0, 0, 0), (.elbowR, -1.0, 0, 0)]), body: SIMD3(0, 0, -0.1), ease: .snap),
        Key(0.18, P([(.spine, -0.25, 0.15, 0.05), (.head, -0.35, 0.1, 0)]), body: SIMD3(0, 0, -0.12)),
    ], blendOut: 0.2)

    /// Light hit: doubled over from a body blow.
    static let hitGut = Clip(name: "hitGut", keys: [
        Key(0.04, P([(.spine, 0.75, 0, 0), (.head, 0.35, 0, 0), (.shoulderL, -0.7, 0, 0.2), (.shoulderR, -0.7, 0, -0.2),
                     (.elbowL, -1.7, 0, 0), (.elbowR, -1.7, 0, 0), (.kneeL, 1.0, 0, 0), (.kneeR, 1.0, 0, 0)]),
            body: SIMD3(0, -0.08, -0.12), ease: .snap),
        Key(0.2, P([(.spine, 0.55, 0, 0), (.head, 0.2, 0, 0)]), body: SIMD3(0, -0.06, -0.14)),
    ], blendOut: 0.22)

    /// Heavy hit: launched backwards, tumbling, air-recovery flip, land in a crouch (≈0.75 s).
    static let launched = Clip(name: "launched", keys: [
        Key(0.05, P([(.spine, -0.8, 0, 0), (.head, -0.7, 0, 0), (.shoulderL, 0.4, 0, 1.3), (.shoulderR, 0.4, 0, -1.3),
                     (.elbowL, -0.3, 0, 0), (.elbowR, -0.3, 0, 0), (.hipL, -0.4, 0, 0.2), (.hipR, -0.1, 0, -0.2), (.kneeL, 0.7, 0, 0), (.kneeR, 0.4, 0, 0)]),
            body: SIMD3(0, 0.15, -0.05), rot: SIMD3(-0.5, 0, 0), ease: .snap),
        Key(0.32, P([(.spine, -0.6, 0, 0), (.head, -0.5, 0, 0)]), body: SIMD3(0, 0.75, -0.1), rot: SIMD3(-1.1, 0, 0), ease: .out),
        Key(0.5, P([(.spine, 0.6, 0, 0), (.head, 0.3, 0, 0), (.hipL, -1.6, 0, 0.1), (.hipR, -1.6, 0, -0.1), (.kneeL, 2.0, 0, 0), (.kneeR, 2.0, 0, 0),
                    (.shoulderL, -1.2, 0, 0.3), (.shoulderR, -1.2, 0, -0.3), (.elbowL, -1.6, 0, 0), (.elbowR, -1.6, 0, 0)]),
            body: SIMD3(0, 0.6, -0.05), rot: SIMD3(-2 * .pi + 0.3, 0, 0), ease: .inOut),
        Key(0.66, P([(.spine, 0.45, 0, 0), (.hipL, -1.0, 0, 0.15), (.hipR, -0.6, 0, -0.15), (.kneeL, 1.5, 0, 0), (.kneeR, 1.4, 0, 0),
                     (.shoulderL, -0.6, 0, 0.7), (.shoulderR, -0.6, 0, -0.7), (.elbowL, -1.0, 0, 0), (.elbowR, -1.0, 0, 0)]),
            body: SIMD3(0, -0.18, 0), rot: SIMD3(-2 * .pi, 0, 0), ease: .inQuad),
    ], blendOut: 0.18)

    static let knockedOut = Clip(name: "ko", keys: [
        Key(0.12, P([(.spine, -0.6, 0, 0), (.head, -0.7, 0, 0), (.shoulderL, 0.4, 0, 1.2), (.shoulderR, 0.4, 0, -1.2),
                     (.elbowL, -0.2, 0, 0), (.elbowR, -0.2, 0, 0), (.hipL, -0.3, 0, 0.1), (.kneeL, 0.4, 0, 0), (.hipR, 0.1, 0, -0.1), (.kneeR, 0.2, 0, 0)]),
            body: SIMD3(0, 0.25, -0.1), rot: SIMD3(-0.4, 0, 0), ease: .snap),
        Key(0.55, P([(.spine, -0.2, 0, 0), (.head, -0.3, 0, 0)]), body: SIMD3(0, -0.18, -0.4), rot: SIMD3(-1.5, 0, 0), ease: .inQuad),
        Key(0.7, [:], body: SIMD3(0, -0.12, -0.45), rot: SIMD3(-1.42, 0, 0), ease: .out),
        Key(0.8, [:], body: SIMD3(0, -0.17, -0.47), rot: SIMD3(-1.5, 0, 0), ease: .inOut),
    ], hold: true)

    static let victory = Clip(name: "victory", keys: [
        Key(0.15, P([(.spine, 0.3, 0, 0), (.kneeL, 1.0, 0, 0), (.kneeR, 1.0, 0, 0)]), body: SIMD3(0, -0.1, 0)),
        Key(0.35, FighterModel.victoryPose, body: SIMD3(0, 0.12, 0), ease: .snap),
        Key(0.6, FighterModel.victoryPose, body: SIMD3(0, 0.05, 0), ease: .inOut),
    ], hold: true)

    static func hold(_ pose: Pose, _ duration: Double) -> Clip {
        Clip(name: "pose", keys: [Key(max(0.01, duration), pose, ease: .inOut)], hold: true)
    }
}

// MARK: - Extended move set (style / per-card variety)

extension Moves {
    private static func Q(_ e: [(Joint, Float, Float, Float)]) -> Pose {
        var p: Pose = [:]
        for (j, x, y, z) in e { p[j] = SIMD3(x, y, z) }
        return p
    }

    static let elbow = Clip(name: "elbow", keys: [
        Key(0.06, Q([(.spine, 0.1, -0.4, 0), (.shoulderR, -1.3, 0, -1.1), (.elbowR, -2.3, 0, 0)])),
        Key(0.11, Q([(.spine, 0.25, 0.7, 0), (.shoulderR, -1.45, 0, 0.35), (.elbowR, -2.4, 0, 0), (.shoulderL, -1.0, 0, 0.5)]),
            body: SIMD3(0, -0.04, 0.16), rot: SIMD3(0, 0.25, 0), ease: .snap),
        Key(0.19, Q([(.spine, 0.25, 0.7, 0)]), body: SIMD3(0, -0.04, 0.16), rot: SIMD3(0, 0.25, 0)),
    ], impact: 0.11, blendOut: 0.16)

    static let backfist = Clip(name: "backfist", keys: [
        Key(0.07, Q([(.spine, 0, 0.6, 0), (.shoulderL, -1.4, 0, -0.5), (.elbowL, -2.2, 0, 0)]), rot: SIMD3(0, 0.6, 0)),
        Key(0.13, Q([(.spine, 0.05, -0.5, 0), (.shoulderL, -1.5, 0, 1.2), (.elbowL, -0.2, 0, 0), (.head, 0, -0.3, 0)]),
            body: SIMD3(0, 0, 0.12), rot: SIMD3(0, -0.5, 0), ease: .snap),
        Key(0.2, Q([(.shoulderL, -1.45, 0, 1.15), (.elbowL, -0.3, 0, 0)]), body: SIMD3(0, 0, 0.12), rot: SIMD3(0, -0.5, 0)),
    ], impact: 0.13, blendOut: 0.18)

    static let palm = Clip(name: "palm", keys: [
        Key(0.07, Q([(.spine, 0.05, -0.4, 0), (.shoulderR, 0.1, 0, -0.4), (.elbowR, -2.0, 0, 0), (.kneeL, 1.1, 0, 0), (.kneeR, 1.1, 0, 0)]),
            body: SIMD3(0, -0.1, -0.04)),
        Key(0.12, Q([(.spine, 0.3, 0.5, 0), (.shoulderR, -1.55, 0, 0), (.elbowR, 0, 0, 0), (.hipL, -0.9, 0, 0.1), (.kneeL, 1.0, 0, 0),
                     (.hipR, 0.5, 0, -0.1), (.kneeR, 0.2, 0, 0)]), body: SIMD3(0, -0.12, 0.22), ease: .snap),
        Key(0.22, Q([(.spine, 0.3, 0.5, 0)]), body: SIMD3(0, -0.12, 0.22)),
    ], impact: 0.12, blendOut: 0.18)

    static let bodyBlow = Clip(name: "bodyBlow", keys: [
        Key(0.06, Q([(.spine, 0.45, -0.3, 0), (.shoulderR, -0.2, 0, -0.3), (.elbowR, -1.9, 0, 0), (.kneeL, 1.2, 0, 0), (.kneeR, 1.2, 0, 0)]),
            body: SIMD3(0, -0.16, 0)),
        Key(0.11, Q([(.spine, 0.55, 0.5, 0), (.shoulderR, -1.25, 0, 0), (.elbowR, -0.3, 0, 0)]), body: SIMD3(0, -0.18, 0.18), ease: .snap),
        Key(0.18, Q([(.spine, 0.5, 0.5, 0)]), body: SIMD3(0, -0.18, 0.18)),
    ], impact: 0.11, blendOut: 0.16)

    static let sideKick = Clip(name: "sideKick", keys: [
        Key(0.08, Q([(.spine, -0.1, 0.9, 0), (.hipL, -1.3, 0, 0.2), (.kneeL, 2.0, 0, 0)]), rot: SIMD3(0, -0.9, 0)),
        Key(0.15, Q([(.spine, -0.35, 0.9, 0.45), (.hipL, -1.5, 0, 0.6), (.kneeL, 0.05, 0, 0), (.shoulderL, -0.3, 0, 0.6), (.shoulderR, 0.3, 0, -1.0)]),
            body: SIMD3(0, 0.05, 0.16), rot: SIMD3(0, -1.2, 0), ease: .snap),
        Key(0.25, Q([(.hipL, -1.4, 0, 0.6), (.kneeL, 0.2, 0, 0)]), body: SIMD3(0, 0.05, 0.16), rot: SIMD3(0, -1.2, 0)),
    ], impact: 0.15, blendOut: 0.2)

    static let lowSweep = Clip(name: "lowSweep", keys: [
        Key(0.08, Q([(.spine, 0.5, 0, 0), (.hipL, -1.5, 0, 0.3), (.kneeL, 2.2, 0, 0), (.hipR, -0.3, 0, -0.6), (.kneeR, 0.2, 0, 0),
                     (.shoulderL, -0.5, 0, 0.9), (.shoulderR, -0.5, 0, -0.9)]), body: SIMD3(0, -0.42, 0), rot: SIMD3(0, 0.6, 0)),
        Key(0.16, Q([(.hipR, -1.2, 0, -1.3), (.kneeR, 0.05, 0, 0)]), body: SIMD3(0, -0.45, 0.08), rot: SIMD3(0, 2.6, 0), ease: .snap),
        Key(0.3, [:], body: SIMD3(0, -0.4, 0.08), rot: SIMD3(0, 2 * .pi, 0), ease: .inOut),
    ], impact: 0.16, blendOut: 0.2)

    static let axeKick = Clip(name: "axeKick", keys: [
        Key(0.1, Q([(.spine, -0.35, 0, 0), (.hipR, -2.6, 0, -0.2), (.kneeR, 0.1, 0, 0), (.shoulderL, -0.4, 0, 0.8), (.shoulderR, -0.4, 0, -0.8)]),
            body: SIMD3(0, 0.08, -0.04)),
        Key(0.17, Q([(.spine, 0.45, 0, 0), (.hipR, -0.9, 0, 0), (.kneeR, 0.1, 0, 0)]), body: SIMD3(0, -0.04, 0.2), ease: .snap),
        Key(0.28, Q([(.spine, 0.4, 0, 0), (.hipR, -0.7, 0, 0), (.kneeR, 0.4, 0, 0)]), body: SIMD3(0, -0.06, 0.2)),
    ], impact: 0.17, blendOut: 0.22)

    /// Shoulder tackle finisher: whole body drives through.
    static let tackle = Clip(name: "tackle", keys: [
        Key(0.1, Q([(.spine, 0.2, -0.9, 0), (.shoulderR, -0.3, 0, -0.2), (.elbowR, -2.2, 0, 0), (.kneeL, 1.2, 0, 0), (.kneeR, 1.2, 0, 0)]),
            body: SIMD3(0, -0.14, -0.08), rot: SIMD3(0, 0.6, 0)),
        Key(0.17, Q([(.spine, 0.55, -0.9, 0), (.hipL, -1.0, 0, 0.1), (.kneeL, 0.8, 0, 0), (.hipR, 0.6, 0, -0.1), (.kneeR, 0.2, 0, 0)]),
            body: SIMD3(0, -0.06, 0.45), rot: SIMD3(0, 0.9, 0), ease: .snap),
        Key(0.3, [:], body: SIMD3(0, -0.06, 0.45), rot: SIMD3(0, 0.9, 0)),
    ], impact: 0.17, blendOut: 0.24)

    static let doublePalm = Clip(name: "doublePalm", keys: [
        Key(0.12, Q([(.spine, -0.1, 0, 0), (.shoulderL, 0.2, 0, 0.3), (.shoulderR, 0.2, 0, -0.3), (.elbowL, -2.0, 0, 0), (.elbowR, -2.0, 0, 0),
                     (.kneeL, 1.0, 0, 0), (.kneeR, 1.0, 0, 0)]), body: SIMD3(0, -0.1, -0.06)),
        Key(0.18, Q([(.spine, 0.35, 0, 0), (.shoulderL, -1.55, 0, -0.15), (.shoulderR, -1.55, 0, 0.15), (.elbowL, 0, 0, 0), (.elbowR, 0, 0, 0),
                     (.hipL, -1.0, 0, 0.1), (.kneeL, 0.9, 0, 0), (.hipR, 0.5, 0, -0.1), (.kneeR, 0.2, 0, 0)]),
            body: SIMD3(0, -0.1, 0.3), ease: .snap),
        Key(0.32, Q([(.spine, 0.3, 0, 0)]), body: SIMD3(0, -0.1, 0.3)),
    ], impact: 0.18, blendOut: 0.24)

    /// Superman punch: leap forward, arm fully extended.
    static let flyingPunch = Clip(name: "flyingPunch", keys: [
        Key(0.09, Q([(.spine, 0.3, -0.4, 0), (.shoulderR, 0.5, 0, -0.3), (.elbowR, -1.6, 0, 0), (.kneeL, 1.3, 0, 0), (.kneeR, 1.3, 0, 0)]),
            body: SIMD3(0, -0.15, -0.06)),
        Key(0.17, Q([(.spine, 0.5, 0.6, 0), (.shoulderR, -1.7, 0, 0), (.elbowR, 0, 0, 0), (.shoulderL, 0.6, 0, 0.4), (.hipR, 0.9, 0, 0),
                     (.kneeR, 1.2, 0, 0), (.hipL, -0.6, 0, 0.1), (.kneeL, 0.6, 0, 0)]),
            body: SIMD3(0, 0.35, 0.42), rot: SIMD3(0.4, 0, 0), ease: .snap),
        Key(0.3, [:], body: SIMD3(0, 0.2, 0.42), rot: SIMD3(0.3, 0, 0)),
    ], impact: 0.17, blendOut: 0.24)

    /// Tornado kick: jumping 540° spin.
    static let tornadoKick = Clip(name: "tornadoKick", keys: [
        Key(0.08, Q([(.spine, 0.2, 0, 0), (.kneeL, 1.3, 0, 0), (.kneeR, 1.3, 0, 0)]), body: SIMD3(0, -0.14, 0), rot: SIMD3(0, 0.5, 0)),
        Key(0.17, Q([(.hipL, -1.2, 0, 0.3), (.kneeL, 1.6, 0, 0), (.shoulderL, 0, 0, 1.3), (.shoulderR, 0, 0, -1.3)]),
            body: SIMD3(0, 0.45, 0.1), rot: SIMD3(0, 3.0, 0), ease: .linear),
        Key(0.23, Q([(.spine, -0.35, 0, 0.3), (.hipR, -1.55, 0, -0.7), (.kneeR, 0.05, 0, 0)]),
            body: SIMD3(0, 0.5, 0.25), rot: SIMD3(0, 4.6, 0), ease: .snap),
        Key(0.36, Q([(.hipR, -1.0, 0, -0.3), (.kneeR, 0.6, 0, 0)]), body: SIMD3(0, 0.05, 0.25), rot: SIMD3(0, 2 * .pi, 0), ease: .inQuad),
    ], impact: 0.23, blendOut: 0.2)

    // Shot variants

    static let shotThrow = Clip(name: "shotThrow", keys: [
        Key(0.1, Q([(.spine, -0.3, -0.4, 0), (.shoulderR, -2.9, 0, -0.3), (.elbowR, -1.4, 0, 0), (.shoulderL, -1.2, 0, 0.5)]), body: SIMD3(0, 0.04, -0.06)),
        Key(0.16, Q([(.spine, 0.45, 0.4, 0), (.shoulderR, -1.3, 0, 0), (.elbowR, -0.1, 0, 0)]), body: SIMD3(0, 0, 0.12), ease: .snap),
        Key(0.26, Q([(.spine, 0.4, 0.4, 0), (.shoulderR, -1.1, 0, 0)]), body: SIMD3(0, 0, 0.1)),
    ], impact: 0.16, blendOut: 0.18)

    static let shotDisc = Clip(name: "shotDisc", keys: [
        Key(0.1, Q([(.spine, 0, 0.8, 0), (.shoulderR, -1.3, 0, -1.4), (.elbowR, -0.6, 0, 0)]), rot: SIMD3(0, 0.6, 0)),
        Key(0.16, Q([(.spine, 0.1, -0.6, 0), (.shoulderR, -1.5, 0, 0.6), (.elbowR, -0.05, 0, 0)]), body: SIMD3(0, 0, 0.1), rot: SIMD3(0, -0.5, 0), ease: .snap),
        Key(0.26, Q([(.shoulderR, -1.45, 0, 0.7)]), body: SIMD3(0, 0, 0.08), rot: SIMD3(0, -0.5, 0)),
    ], impact: 0.16, blendOut: 0.18)

    static let shotPalm = Clip(name: "shotPalm", keys: [
        Key(0.09, Q([(.spine, -0.1, 0, 0), (.shoulderL, -0.6, 0, 0.2), (.shoulderR, -0.6, 0, -0.2), (.elbowL, -2.0, 0, 0), (.elbowR, -2.0, 0, 0)]),
            body: SIMD3(0, -0.04, -0.04)),
        Key(0.14, Q([(.spine, 0.2, 0, 0), (.shoulderL, -1.55, 0, -0.12), (.shoulderR, -1.55, 0, 0.12), (.elbowL, 0, 0, 0), (.elbowR, 0, 0, 0)]),
            body: SIMD3(0, -0.04, 0.12), ease: .snap),
        Key(0.24, Q([(.spine, 0.1, 0, 0)]), body: SIMD3(0, -0.02, -0.06)),
    ], impact: 0.14, blendOut: 0.18)
}

// MARK: - Switching (cover change / tag-in)

extension Moves {
    private static func R(_ e: [(Joint, Float, Float, Float)]) -> Pose {
        var p: Pose = [:]
        for (j, x, y, z) in e { p[j] = SIMD3(x, y, z) }
        return p
    }

    /// Cover: arms crossed in front of the face, braced low.
    static let coverGuard = Clip(name: "coverGuard", keys: [
        Key(0.06, R([(.spine, 0.2, 0, 0), (.head, 0.15, 0, 0), (.shoulderL, -1.75, 0, -0.3), (.elbowL, -2.15, 0, 0),
                     (.shoulderR, -1.75, 0, 0.3), (.elbowR, -2.15, 0, 0), (.hipL, -0.8, 0, 0.15), (.kneeL, 1.2, 0, 0),
                     (.hipR, 0.1, 0, -0.15), (.kneeR, 0.9, 0, 0)]), body: SIMD3(0, -0.12, 0.08), ease: .snap),
        Key(0.24, R([(.spine, 0.25, 0, 0)]), body: SIMD3(0, -0.14, 0.02)),
    ], blendOut: 0.1)

    /// Leaving a combo: backflip out.
    static let backflip = Clip(name: "backflip", keys: [
        Key(0.07, R([(.spine, 0.3, 0, 0), (.kneeL, 1.3, 0, 0), (.kneeR, 1.3, 0, 0), (.hipL, -0.8, 0, 0.1), (.hipR, -0.8, 0, -0.1)]),
            body: SIMD3(0, -0.14, 0)),
        Key(0.25, R([(.spine, 0.5, 0, 0), (.hipL, -1.6, 0, 0.1), (.hipR, -1.6, 0, -0.1), (.kneeL, 2.0, 0, 0), (.kneeR, 2.0, 0, 0),
                     (.shoulderL, -1.2, 0, 0.3), (.shoulderR, -1.2, 0, -0.3)]), body: SIMD3(0, 0.7, -0.2), rot: SIMD3(-.pi, 0, 0), ease: .linear),
        Key(0.42, R([(.spine, 0.3, 0, 0), (.kneeL, 1.1, 0, 0), (.kneeR, 1.1, 0, 0), (.hipL, -0.7, 0, 0.1), (.hipR, -0.7, 0, -0.1)]),
            body: SIMD3(0, -0.1, -0.3), rot: SIMD3(-2 * .pi, 0, 0), ease: .out),
    ], hold: true)

    /// Tag-in: drop from above and land in a crouch.
    static let tagDrop = Clip(name: "tagDrop", keys: [
        Key(0.001, R([(.spine, 0.3, 0, 0), (.hipL, -1.2, 0, 0.1), (.hipR, -0.6, 0, -0.1), (.kneeL, 1.6, 0, 0), (.kneeR, 1.2, 0, 0),
                      (.shoulderL, -0.4, 0, 0.9), (.shoulderR, -0.4, 0, -0.9)]), body: SIMD3(0, 1.8, -0.2), ease: .linear),
        Key(0.18, R([(.spine, 0.55, 0, 0), (.head, -0.3, 0, 0), (.hipL, -1.3, 0, 0.2), (.hipR, -0.5, 0, -0.2), (.kneeL, 1.8, 0, 0),
                     (.kneeR, 1.6, 0, 0), (.shoulderL, 0.3, 0, 0.6), (.shoulderR, 0.5, 0, -0.5), (.elbowR, -0.3, 0, 0)]),
            body: SIMD3(0, -0.32, 0), ease: .inQuad),
        Key(0.34, R([(.spine, 0.5, 0, 0)]), body: SIMD3(0, -0.3, 0)),
    ], blendOut: 0.22)
}

// MARK: - Hit reactions

/// How a hit lands on the defender (chosen from the attacking move).
enum HitReact {
    case head, gut, spin, trip, slam, launch, blast

    /// Light reaction for a move, and its heavy (finisher) version.
    static func of(_ clip: Clip) -> HitReact {
        switch clip.name {
        case "bodyBlow", "knee": return .gut
        case "hook", "roundhouse", "sideKick", "spinKick", "backfist": return .spin
        case "lowSweep": return .trip
        case "smash", "axeKick": return .slam
        case "uppercut", "flyingKick", "tornadoKick", "doublePalm", "tackle", "flyingPunch": return .launch
        default: return .head
        }
    }

    /// Knockdowns need longer stun so the defender is not free while still on the ground.
    var minStun: Double {
        switch self {
        case .trip, .slam: return 0.95
        default: return 0
        }
    }
}

extension Moves {
    private static func H(_ e: [(Joint, Float, Float, Float)]) -> Pose {
        var p: Pose = [:]
        for (j, x, y, z) in e { p[j] = SIMD3(x, y, z) }
        return p
    }

    /// Hooked / kicked from the side: torso and head twist away.
    static func hitSpin(_ dir: Float) -> Clip {
        Clip(name: "hitSpin", keys: [
            Key(0.04, H([(.spine, -0.15, dir * 0.8, dir * 0.25), (.head, -0.2, dir * 0.7, 0), (.shoulderL, -0.3, 0, 0.9), (.shoulderR, -0.3, 0, -0.9),
                         (.elbowL, -0.8, 0, 0), (.elbowR, -0.8, 0, 0)]), body: SIMD3(dir * 0.08, -0.03, -0.06), rot: SIMD3(0, dir * 0.55, 0), ease: .snap),
            Key(0.22, H([(.spine, -0.05, dir * 0.4, 0.1)]), body: SIMD3(dir * 0.06, -0.04, -0.1), rot: SIMD3(0, dir * 0.3, 0)),
        ], blendOut: 0.22)
    }

    /// Energy shot: shield with forearms, pushed back.
    static let hitBlast = Clip(name: "hitBlast", keys: [
        Key(0.05, H([(.spine, -0.35, 0, 0), (.head, 0.2, 0, 0), (.shoulderL, -1.6, 0, -0.2), (.elbowL, -2.0, 0, 0),
                     (.shoulderR, -1.6, 0, 0.2), (.elbowR, -2.0, 0, 0), (.kneeL, 0.9, 0, 0), (.kneeR, 0.9, 0, 0)]),
            body: SIMD3(0, -0.05, -0.18), ease: .snap),
        Key(0.24, H([(.spine, -0.15, 0, 0)]), body: SIMD3(0, -0.06, -0.24)),
    ], blendOut: 0.2)

    /// Swept: legs taken out, fall on the back, kip-up (~1 s).
    static let trip = Clip(name: "trip", keys: [
        Key(0.06, H([(.spine, -0.4, 0, 0), (.head, -0.3, 0, 0), (.hipL, -1.3, 0, 0.1), (.hipR, -1.1, 0, -0.1), (.kneeL, 0.3, 0, 0), (.kneeR, 0.4, 0, 0),
                     (.shoulderL, -0.6, 0, 1.2), (.shoulderR, -0.6, 0, -1.2)]), body: SIMD3(0, 0.3, 0), rot: SIMD3(-0.9, 0, 0), ease: .snap),
        Key(0.28, H([(.spine, 0.1, 0, 0), (.head, 0.2, 0, 0), (.hipL, -0.6, 0, 0.1), (.hipR, -0.4, 0, -0.1)]),
            body: SIMD3(0, -0.12, -0.15), rot: SIMD3(-1.5, 0, 0), ease: .inQuad),
        Key(0.36, [:], body: SIMD3(0, -0.06, -0.15), rot: SIMD3(-1.45, 0, 0), ease: .out),
        Key(0.6, [:], body: SIMD3(0, -0.14, -0.15), rot: SIMD3(-1.5, 0, 0), ease: .inOut),
        Key(0.74, H([(.spine, 0.9, 0, 0), (.hipL, -1.9, 0, 0.1), (.hipR, -1.9, 0, -0.1), (.kneeL, 2.2, 0, 0), (.kneeR, 2.2, 0, 0),
                     (.shoulderL, -2.6, 0, 0.3), (.shoulderR, -2.6, 0, -0.3)]), body: SIMD3(0, 0.05, -0.1), rot: SIMD3(-1.9, 0, 0), ease: .inOut),
        Key(0.88, H([(.spine, 0.45, 0, 0), (.hipL, -1.0, 0, 0.2), (.hipR, -0.6, 0, -0.2), (.kneeL, 1.5, 0, 0), (.kneeR, 1.3, 0, 0),
                     (.shoulderL, -0.6, 0, 0.7), (.shoulderR, -0.6, 0, -0.7)]), body: SIMD3(0, -0.2, 0), rot: .zero, ease: .snap),
    ], blendOut: 0.16)

    /// Slammed: driven face-first into the ground, bounce, land, get up (~1 s).
    static let slam = Clip(name: "slam", keys: [
        Key(0.05, H([(.spine, 0.9, 0, 0), (.head, 0.5, 0, 0), (.shoulderL, 0.4, 0, 1.0), (.shoulderR, 0.4, 0, -1.0), (.kneeL, 0.6, 0, 0), (.kneeR, 0.6, 0, 0)]),
            body: SIMD3(0, -0.1, -0.05), rot: SIMD3(0.7, 0, 0), ease: .snap),
        Key(0.14, H([(.spine, 0.3, 0, 0)]), body: SIMD3(0, -0.2, -0.1), rot: SIMD3(1.45, 0, 0), ease: .inQuad),
        Key(0.38, H([(.spine, -0.5, 0, 0), (.head, -0.5, 0, 0), (.shoulderL, 0.6, 0, 1.3), (.shoulderR, 0.6, 0, -1.3), (.hipL, -0.3, 0, 0.2), (.hipR, -0.3, 0, -0.2)]),
            body: SIMD3(0, 0.55, -0.35), rot: SIMD3(2.8, 0, 0), ease: .out),
        Key(0.56, H([(.spine, -0.2, 0, 0), (.head, -0.2, 0, 0)]), body: SIMD3(0, -0.15, -0.5), rot: SIMD3(4.75, 0, 0), ease: .inQuad),
        Key(0.74, [:], body: SIMD3(0, -0.15, -0.5), rot: SIMD3(4.75, 0, 0)),
        Key(0.9, H([(.spine, 0.45, 0, 0), (.hipL, -1.0, 0, 0.2), (.hipR, -0.6, 0, -0.2), (.kneeL, 1.5, 0, 0), (.kneeR, 1.3, 0, 0),
                    (.shoulderL, -0.6, 0, 0.7), (.shoulderR, -0.6, 0, -0.7)]), body: SIMD3(0, -0.2, -0.4), rot: SIMD3(2 * .pi, 0, 0), ease: .inOut),
    ], blendOut: 0.18)
}
