import SceneKit
import simd

// MARK: - Keyframe clips

/// Easing applied over the segment that ends at a key.
enum Ease {
    case linear, inOut, out, inQuad, snap   // snap: very fast start, long settle (strikes)

    func f(_ x: Float) -> Float {
        let t = max(0, min(1, x))
        switch self {
        case .linear: return t
        case .inOut: return t * t * (3 - 2 * t)
        case .out: return 1 - (1 - t) * (1 - t)
        case .inQuad: return t * t
        case .snap: return 1 - pow(1 - t, 4)
        }
    }
}

/// One keyframe: joint rotations (unlisted joints carry over), plus optional body offset / rotation.
struct Key {
    var t: Double
    var pose: Pose = [:]
    var body: SIMD3<Float>? = nil      // offset from the hover rest position (x right, y up, z forward)
    var rot: SIMD3<Float>? = nil       // body euler (lean / spin / tumble)
    var ease: Ease = .out

    init(_ t: Double, _ pose: Pose = [:], body: SIMD3<Float>? = nil, rot: SIMD3<Float>? = nil, ease: Ease = .out) {
        self.t = t
        self.pose = pose
        self.body = body
        self.rot = rot
        self.ease = ease
    }
}

/// A move: anticipation → strike (impact) → hold → automatic blend back to the guard stance.
struct Clip {
    let name: String
    var keys: [Key]
    var impact: Double = 0          // time of the hit / release frame
    var hold = false                // stay on the last key until another clip plays
    var loop = false
    var blendOut = 0.16             // time to settle back into the stance afterwards
    var duration: Double { keys.last?.t ?? 0 }
}

// MARK: - Animator

/// Plays clips on a fighter's joints + body node. Driven by game time (`tick(dt)`), so hit stop and
/// slow motion freeze / slow animation exactly like the rest of the fight.
@MainActor
final class Animator {
    private let joints: [Joint: SCNNode]
    private let body: SCNNode
    private let rest: SIMD3<Float>

    private struct Track {
        var times: [Double]
        var values: [SIMD3<Float>]
        var eases: [Ease]
    }
    private var tracks: [Joint: Track] = [:]
    private var bodyTrack: Track?
    private var rotTrack: Track?
    private(set) var clip: Clip?
    private var t: Double = 0
    private var idleT: Double = 0
    private(set) var idling = true

    /// Current values (what is on screen).
    private var cur: [Joint: SIMD3<Float>] = [:]
    private var curBody = SIMD3<Float>(repeating: 0)
    private var curRot = SIMD3<Float>(repeating: 0)

    var base: Pose = FighterModel.stancePose

    init(joints: [Joint: SCNNode], body: SCNNode, rest: SIMD3<Float>) {
        self.joints = joints
        self.body = body
        self.rest = rest
        for (j, n) in joints { cur[j] = n.simdEulerAngles }
    }

    var playing: String? { idling ? nil : clip?.name }
    var isHolding: Bool { !idling && (clip?.hold == true || clip?.loop == true) }

    /// Snap every channel to a pose (no blend).
    func set(_ pose: Pose) {
        for (j, v) in pose { cur[j] = v }
        curBody = .zero
        curRot = .zero
        idling = true
        clip = nil
        write()
    }

    func play(_ c: Clip, speed: Double = 1) {
        var c = c
        if speed != 1 {
            c.keys = c.keys.map { var k = $0; k.t /= speed; return k }
            c.impact /= speed
            c.blendOut /= speed
        }
        // Automatic return to the guard stance (unless the clip holds or loops).
        if !c.hold && !c.loop {
            // Settle to the nearest whole turn so spins / flips never unwind on the way back.
            let lastRot = c.keys.last(where: { $0.rot != nil })?.rot ?? .zero
            let turn = 2 * Float.pi
            let rest = SIMD3<Float>((lastRot.x / turn).rounded() * turn, (lastRot.y / turn).rounded() * turn, (lastRot.z / turn).rounded() * turn)
            c.keys.append(Key(c.duration + c.blendOut, base, body: .zero, rot: rest, ease: .inOut))
        }
        clip = c
        t = 0
        idling = false
        build(c)
    }

    private func build(_ c: Clip) {
        tracks = [:]
        for j in Joint.allCases {
            var times: [Double] = [0], values = [cur[j] ?? .zero], eases: [Ease] = [.linear]
            var last = base[j] ?? (cur[j] ?? .zero)
            for (i, k) in c.keys.enumerated() {
                let v = k.pose[j] ?? (i == 0 ? last : values.last!)
                last = v
                times.append(max(k.t, 1e-3))
                values.append(unwrapNear(v, values.last!))
                eases.append(k.ease)
            }
            tracks[j] = Track(times: times, values: values, eases: eases)
        }
        func channel(_ start: SIMD3<Float>, _ pick: (Key) -> SIMD3<Float>?, angular: Bool) -> Track {
            var times: [Double] = [0], values = [start], eases: [Ease] = [.linear]
            for (i, k) in c.keys.enumerated() {
                let v = pick(k) ?? (i == 0 ? SIMD3<Float>(repeating: 0) : values.last!)
                times.append(max(k.t, 1e-3))
                values.append(v)
                eases.append(k.ease)
            }
            return Track(times: times, values: values, eases: eases)
        }
        bodyTrack = channel(curBody, { $0.body }, angular: false)
        rotTrack = channel(curRot, { $0.rot }, angular: true)
    }

    /// Keep joint rotations on the short way round when blending from the current value.
    private func unwrapNear(_ v: SIMD3<Float>, _ ref: SIMD3<Float>) -> SIMD3<Float> {
        var o = v
        for i in 0..<3 {
            while o[i] - ref[i] > .pi { o[i] -= 2 * .pi }
            while o[i] - ref[i] < -.pi { o[i] += 2 * .pi }
        }
        return o
    }

    private func sample(_ tr: Track, _ time: Double) -> SIMD3<Float> {
        guard let lastT = tr.times.last else { return .zero }
        if time >= lastT { return tr.values.last! }
        var i = 1
        while i < tr.times.count && tr.times[i] < time { i += 1 }
        let t0 = tr.times[i - 1], t1 = tr.times[i]
        let x = Float((time - t0) / max(1e-4, t1 - t0))
        return simd_mix(tr.values[i - 1], tr.values[i], SIMD3(repeating: tr.eases[i].f(x)))
    }

    func tick(_ dt: Double) {
        guard dt > 0 else { return }
        if idling {
            idleT += dt
            idle(dt)
        } else if let c = clip {
            t += dt
            let total = c.keys.last?.t ?? 0
            // Loops cycle between their first and last key (the blend-in from the previous pose plays once).
            if c.loop && t > total {
                let first = c.keys.first?.t ?? 0
                t = first + (t - total).truncatingRemainder(dividingBy: max(total - first, 0.01))
            }
            for (j, tr) in tracks { cur[j] = sample(tr, t) }
            if let b = bodyTrack { curBody = sample(b, t) }
            if let r = rotTrack { curRot = sample(r, t) }
            if !c.hold && !c.loop && t >= total {
                // Normalise spins (e.g. a 360° kick) so the next blend does not unwind them.
                for i in 0..<3 { curRot[i] = remainder(curRot[i], 2 * .pi) }
                idling = true
                idleT = 0
            }
        }
        write()
    }

    /// Guard stance with breathing and a light bounce (fighting-game idle).
    private func idle(_ dt: Double) {
        let k = Float(min(1, dt * 10))
        let s = Float(sin(idleT * 2.4))
        for j in Joint.allCases {
            var target = base[j] ?? .zero
            switch j {
            case .spine: target.x += 0.03 * s
            case .shoulderL, .shoulderR: target.x += 0.04 * s
            case .kneeL, .kneeR: target.x += 0.05 * (s + 1)
            default: break
            }
            cur[j] = simd_mix(cur[j] ?? target, target, SIMD3(repeating: k))
        }
        curBody = simd_mix(curBody, SIMD3(0, 0.03 * s - 0.02, 0), SIMD3(repeating: k))
        curRot = simd_mix(curRot, .zero, SIMD3(repeating: k))
    }

    private func write() {
        for (j, n) in joints { if let v = cur[j] { n.simdEulerAngles = v } }
        body.simdPosition = rest + curBody
        body.simdEulerAngles = curRot
    }
}
