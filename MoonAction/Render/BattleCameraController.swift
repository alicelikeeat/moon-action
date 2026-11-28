import SceneKit
import simd

/// Dynamic battle camera: spring-damped over-the-shoulder framing, dash wide-angle, vanish counter-angle cut,
/// special / ultimate low-angle close-up, combo side view, shake and impact kick.
/// Everything is smoothed with a critically damped spring; only the vanish cut is a hard cut.
@MainActor
final class BattleCameraController {
    struct Context {
        var player: SIMD3<Float>
        var enemy: SIMD3<Float>
        var gap: Float
        /// 0…1: player is comboing / player is being comboed.
        var comboW: Float
        var guardW: Float
        /// Side doing a special / ultimate startup (close-up), if any.
        var closeUpSide: Int?
        var closeUpChest: SIMD3<Float>
        var now: Double
    }

    private(set) var pos = SIMD3<Float>(0, 3, -9)
    private(set) var look = SIMD3<Float>(0, 1.2, 0)
    private(set) var fov: Float = 48
    private var velPos = SIMD3<Float>(repeating: 0)
    private var velLook = SIMD3<Float>(repeating: 0)
    private var velFov: Float = 0

    var shake: Float = 0
    var kick = SIMD3<Float>(repeating: 0)

    private var dashUntil: Double = 0
    private var cutUntil: Double = 0
    private var cutPos = SIMD3<Float>(repeating: 0)
    private var cutLook = SIMD3<Float>(repeating: 0)
    private var closeUpStart: Double = -1

    /// Current FOV presets (brief §3.2).
    enum FOV {
        static let neutral: Float = 48
        static let dash: Float = 56
        static let vanish: Float = 50
        static let closeUp: Float = 38
    }

    var isDashing: Bool { lastNow < dashUntil }
    private var lastNow: Double = 0

    /// Forward dash / strike rush: lower, slightly closer, wider FOV for speed.
    func dashPulse(now: Double, duration: Double) { dashUntil = max(dashUntil, now + duration + 0.12) }

    /// Vanish: hard cut (0.08 s) to a counter angle 120° around the opponent, then spring back.
    func vanishCut(_ c: Context, vanisher: SIMD3<Float>) {
        let pivot = c.enemy
        var off = pos - pivot
        off.y = 0
        let a: Float = 2 * .pi / 3
        let r = SIMD3(off.x * cos(a) - off.z * sin(a), 0, off.x * sin(a) + off.z * cos(a))
        let len = max(3.2, simd_length(r))
        cutPos = pivot + simd_normalize(r) * len + SIMD3(0, 1.7, 0)
        cutLook = (vanisher + pivot) / 2 + SIMD3(0, 1.1, 0)
        cutUntil = c.now + 0.08 + 0.3
        pos = cutPos
        look = cutLook
        velPos = .zero
        velLook = .zero
        fov = FOV.vanish
        velFov = 0
    }

    func snap(_ c: Context) {
        let t = target(c)
        pos = t.pos
        look = t.look
        fov = t.fov
        velPos = .zero
        velLook = .zero
        velFov = 0
    }

    /// Advance and write to the camera node.
    func update(_ c: Context, dt: Float, node: SCNNode) {
        lastNow = c.now
        if c.now < cutUntil {
            pos = cutPos
            look = cutLook
        } else {
            let t = target(c)
            let stiff: Float = c.closeUpSide != nil ? 10 : 6.5
            Self.spring(&pos, &velPos, to: t.pos, omega: stiff, dt: dt)
            Self.spring(&look, &velLook, to: t.look, omega: stiff * 1.2, dt: dt)
            Self.spring(&fov, &velFov, to: t.fov, omega: 8, dt: dt)
        }
        var p = pos + kick
        kick *= max(0, 1 - dt * 14)
        if shake > 0.001 {
            p += SIMD3(Float.random(in: -shake...shake), Float.random(in: -shake...shake), Float.random(in: -shake...shake))
            shake *= max(0, 1 - dt * 9)
        }
        node.simdPosition = p
        node.simdLook(at: look, up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
        node.camera?.fieldOfView = CGFloat(fov)
    }

    // MARK: Framing

    private func target(_ c: Context) -> (pos: SIMD3<Float>, look: SIMD3<Float>, fov: Float) {
        let p = c.player, e = c.enemy
        var f = e - p
        f.y = 0
        f = simd_length(f) > 1e-3 ? simd_normalize(f) : SIMD3(0, 0, 1)
        let right = SIMD3<Float>(f.z, 0, -f.x) * -1
        let gap = c.gap
        // Special / ultimate: 2.4 m in front of the attacker, low angle looking up, orbiting up to 30°.
        if let s = c.closeUpSide {
            if closeUpStart < 0 { closeUpStart = c.now }
            let a = s == 0 ? p : e
            let fw = s == 0 ? f : -f
            let side = s == 0 ? right : -right
            // Start 40° off the facing axis so the opponent (often right in front at close range) never blocks the shot,
            // then orbit a further 30°.
            let orbit = Float.pi * 40 / 180 + Float(min(1, (c.now - closeUpStart) / 0.9)) * (.pi / 6)
            let dir = fw * cos(orbit) + side * sin(orbit)
            return (a + dir * 2.4 + SIMD3(0, 0.75, 0), c.closeUpChest + SIMD3(0, 0.35, 0), FOV.closeUp)
        }
        closeUpStart = -1
        // Neutral over-the-shoulder (DBL footage: behind-left, player large right of center),
        // aimed at the line between the fighters 60 % of the way to the opponent.
        let mid = (p + e) / 2
        let aim = p + (e - p) * 0.6
        var pos = p - f * (2.2 + gap * 0.06) - right * 0.95 + SIMD3(0, 1.6, 0)
        var look = aim - right * 0.25 + SIMD3(0, 1.2, 0)
        var fov = FOV.neutral
        // Forward dash / rush: lower (y 1.4), a bit closer, wide angle.
        if isDashing {
            pos = p - f * 1.9 - right * 0.85 + SIMD3(0, 1.4, 0)
            fov = FOV.dash
        }
        // Comboing: swing to the 3/4 side and close in on the exchange.
        pos = simd_mix(pos, mid - f * 1.0 + right * (3.0 + gap * 0.1) + SIMD3(0, 1.35, 0), SIMD3(repeating: c.comboW))
        look = simd_mix(look, mid + f * 0.3 + SIMD3(0, 1.2, 0), SIMD3(repeating: c.comboW))
        fov += (FOV.neutral + 2 - fov) * c.comboW
        // Being comboed: pull back to show both.
        let g = c.guardW * (1 - c.comboW)
        pos = simd_mix(pos, p - f * 4.2 + right * 2.6 + SIMD3(0, 2.2, 0), SIMD3(repeating: g))
        look = simd_mix(look, mid + SIMD3(0, 1.1, 0), SIMD3(repeating: g))
        return (pos, look, fov)
    }

    /// Critically damped spring (no overshoot).
    static func spring(_ x: inout SIMD3<Float>, _ v: inout SIMD3<Float>, to target: SIMD3<Float>, omega: Float, dt: Float) {
        let f = 1 + 2 * dt * omega
        let oo = omega * omega
        let hoo = dt * oo
        let det = 1 / (f + dt * hoo)
        let x0 = x
        x = (x0 * f + v * dt + target * (dt * hoo)) * det
        v = (v + (target - x0) * hoo) * det
    }

    static func spring(_ x: inout Float, _ v: inout Float, to target: Float, omega: Float, dt: Float) {
        var xv = SIMD3<Float>(x, 0, 0), vv = SIMD3<Float>(v, 0, 0)
        spring(&xv, &vv, to: SIMD3(target, 0, 0), omega: omega, dt: dt)
        x = xv.x
        v = vv.x
    }
}
