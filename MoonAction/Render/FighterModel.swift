import SceneKit
import UIKit
import simd

enum Joint: CaseIterable {
    case spine, head, shoulderL, elbowL, shoulderR, elbowR, hipL, kneeL, hipR, kneeR
}

typealias Pose = [Joint: SIMD3<Float>]

/// A fighter modeled procedurally with MeshKit: one smooth skinned body mesh (bone-weighted
/// lofts + ellipsoids), anime face, Bézier hair locks, outfit pieces and an outline hull.
/// Faces +Z. Animated by rotating skeleton joints.
@MainActor
final class FighterModel {
    let def: FighterDef
    let root = SCNNode()      // world placement + yaw (skeleton space)
    let body = SCNNode()      // hover / bob / tilt
    private(set) var joints: [Joint: SCNNode] = [:]
    let hips = SCNNode()
    let fistL = SCNNode()
    let fistR = SCNNode()
    let headTop = SCNNode()
    private let auraNode = SCNNode()
    private let aura: SCNParticleSystem
    private var barrier: SCNNode?
    private var powerGlow: SCNNode?
    private var materials: [SCNMaterial] = []
    private var currentAura = -1
    private var rng: UInt64
    private var retarget: Retargeter?
    private var importedHolder: SCNNode?
    /// Number of game joints mapped onto an imported skeleton (nil = procedural model).
    private(set) var importedBones: Int?

    private struct Weak { weak var m: FighterModel? }
    private static var live: [Weak] = []

    /// Called once per frame: copies procedural poses onto imported skeletons.
    static func syncImported() {
        live.removeAll { $0.m == nil }
        for w in live { w.m?.syncPose() }
    }

    func syncPose() {
        retarget?.sync(joints: joints, reference: hips)
    }

    static let hover: Float = 0.28

    // Bone indices
    private enum B { static let hips = 0, spine = 1, head = 2, shL = 3, elL = 4, fsL = 5, shR = 6, elR = 7, fsR = 8, hpL = 9, knL = 10, hpR = 11, knR = 12 }
    // Material slots
    private enum S { static let skin = 0, primary = 1, secondary = 2, accent = 3, hair = 4, white = 5, iris = 6, dark = 7, coat = 8, boots = 9, brow = 10 }

    init(def: FighterDef) {
        self.def = def
        rng = def.id.unicodeScalars.reduce(UInt64(1469598103934665603)) { ($0 ^ UInt64($1.value)) &* 1099511628211 } | 1
        aura = Toon.aura(def.look.aura, height: 1.9)
        buildSkeleton()
        if let url = ModelLibrary.url(for: def.id), let node = ModelLibrary.load(url) {
            setupImported(node)
        } else {
            buildMesh()
        }
        root.simdScale = SIMD3(repeating: def.look.height)
        apply(FighterModel.stancePose, duration: 0)
        idle()
    }

    private func rand(_ lo: Float, _ hi: Float) -> Float {
        rng = rng &* 6364136223846793005 &+ 1442695040888963407
        let u = Float((rng >> 33) & 0xFFFFFF) / Float(0xFFFFFF)
        return lo + (hi - lo) * u
    }

    // MARK: - Skeleton

    private func joint(_ j: Joint?, _ node: SCNNode = SCNNode(), parent: SCNNode, at p: SIMD3<Float>) -> SCNNode {
        node.simdPosition = p
        parent.addChildNode(node)
        if let j { joints[j] = node }
        return node
    }

    private var bones: [SCNNode] = []

    private func buildSkeleton() {
        let b = def.look.bulk
        root.addChildNode(body)
        body.simdPosition = SIMD3(0, FighterModel.hover, 0)
        _ = joint(nil, hips, parent: body, at: SIMD3(0, 0.95, 0))
        let spine = joint(.spine, parent: hips, at: SIMD3(0, 0.07, 0))
        let head = joint(.head, parent: spine, at: SIMD3(0, 0.74, 0.01))
        let shL = joint(.shoulderL, parent: spine, at: SIMD3(0.27 * b, 0.47, 0))
        let elL = joint(.elbowL, parent: shL, at: SIMD3(0, -0.3, 0))
        _ = joint(nil, fistL, parent: elL, at: SIMD3(0, -0.32, 0.01))
        let shR = joint(.shoulderR, parent: spine, at: SIMD3(-0.27 * b, 0.47, 0))
        let elR = joint(.elbowR, parent: shR, at: SIMD3(0, -0.3, 0))
        _ = joint(nil, fistR, parent: elR, at: SIMD3(0, -0.32, 0.01))
        let hpL = joint(.hipL, parent: hips, at: SIMD3(0.1 * b, -0.05, 0))
        let knL = joint(.kneeL, parent: hpL, at: SIMD3(0, -0.44, 0))
        let hpR = joint(.hipR, parent: hips, at: SIMD3(-0.1 * b, -0.05, 0))
        let knR = joint(.kneeR, parent: hpR, at: SIMD3(0, -0.44, 0))
        bones = [hips, spine, head, shL, elL, fistL, shR, elR, fistR, hpL, knL, hpR, knR]
        headTop.simdPosition = SIMD3(0, 0.3, 0)
        head.addChildNode(headTop)
        auraNode.simdPosition = SIMD3(0, 0.95, 0)
        auraNode.addParticleSystem(aura)
        body.addChildNode(auraNode)

        // Ground shadow
        let plane = SCNPlane(width: 0.95, height: 0.95)
        let sm = SCNMaterial()
        sm.diffuse.contents = Toon.glowImage
        sm.multiply.contents = UIColor.black
        sm.lightingModel = .constant
        sm.transparency = 0.5
        sm.writesToDepthBuffer = false
        plane.materials = [sm]
        let shadow = SCNNode(geometry: plane)
        shadow.simdEulerAngles = SIMD3(-.pi / 2, 0, 0)
        shadow.simdPosition = SIMD3(0, 0.01, 0)
        root.addChildNode(shadow)
    }

    private func P(_ n: SCNNode) -> SIMD3<Float> { n.simdConvertPosition(.zero, to: root) }

    // MARK: - Imported model

    private func setupImported(_ container: SCNNode) {
        let opts = ModelLibrary.settings(for: def.id)
        // Measure the model in its own space.
        var lo = SIMD3<Float>(repeating: .greatestFiniteMagnitude)
        var hi = SIMD3<Float>(repeating: -.greatestFiniteMagnitude)
        container.enumerateHierarchy { n, _ in
            guard n.geometry != nil else { return }
            let (a, b) = n.boundingBox
            for x in [a.x, b.x] { for y in [a.y, b.y] { for z in [a.z, b.z] {
                let p = n.simdConvertPosition(SIMD3(Float(x), Float(y), Float(z)), to: container)
                lo = simd_min(lo, p)
                hi = simd_max(hi, p)
            } } }
        }
        let height = max(0.001, hi.y - lo.y)
        let target = Float(opts["height"] ?? 2.15)
        let k = target / height
        let holder = SCNNode()
        holder.simdScale = SIMD3(repeating: k)
        holder.simdEulerAngles = SIMD3(0, Float(opts["yaw"] ?? 0) * .pi / 180, 0)
        let center = (lo + hi) / 2
        container.simdPosition = SIMD3(-center.x, -lo.y, -center.z)
        holder.addChildNode(container)
        body.addChildNode(holder)
        importedHolder = holder

        container.enumerateHierarchy { n, _ in
            for m in n.geometry?.materials ?? [] {
                m.isDoubleSided = m.isDoubleSided || m.transparency < 1
                self.materials.append(m)
            }
        }
        let r = Retargeter(container: container)
        importedBones = r.mappedCount
        if r.isValid {
            retarget = r
            FighterModel.live.append(Weak(m: self))
            syncPose()
        }
    }

    // MARK: - Mesh

    private func buildMesh() {
        let L = def.look
        let b = L.bulk
        let mb = MeshBuilder()
        typealias Bd = MeshBuilder.Bind
        for s in [S.white, S.iris, S.dark, S.brow] { mb.disableOutline(slot: s) }

        let hipsP = P(hips)
        let spineP = P(bones[B.spine])
        let headP = P(bones[B.head])

        // ---- Torso (pelvis → chest → neck base), blended hips/spine
        let ys: [Float] = [-0.13, -0.05, 0.03, 0.11, 0.23, 0.35, 0.47, 0.55, 0.61]
        let rad: [SIMD2<Float>] = [
            SIMD2(0.12 * b, 0.095), SIMD2(0.165 * b, 0.115), SIMD2(0.158 * b, 0.11), SIMD2(0.138 * b, 0.1),
            SIMD2(0.165 * b, 0.118), SIMD2(0.2 * b, 0.13), SIMD2(0.205 * b, 0.125), SIMD2(0.165 * b, 0.105), SIMD2(0.07, 0.065),
        ]
        let zs: [Float] = [0, 0, 0, 0, 0.005, 0.012, 0.008, 0, 0]
        let path = ys.enumerated().map { hipsP + SIMD3(0, $0.element, zs[$0.offset]) }
        let binds = ys.map { y -> Bd in Bd(B.hips, B.spine, simd_smoothstep(0.0, 0.18, y)) }
        mb.loft(path: path, radii: rad, binds: binds,
                slots: [S.secondary, S.secondary, S.accent, S.primary, S.primary, S.primary, S.primary, S.primary],
                sides: 20, capStart: true)

        // Lapels / collar detail
        for s in [Float(1), Float(-1)] {
            mb.strand(spineP + SIMD3(s * 0.11, 0.53, 0.07), spineP + SIMD3(s * 0.08, 0.46, 0.125),
                      spineP + SIMD3(s * 0.03, 0.36, 0.14), spineP + SIMD3(0, 0.28, 0.14),
                      width: 0.03, flatten: 0.3, taper: 0.4, bind: Bd(B.spine), slot: S.accent, segments: 5, sides: 5, ref: SIMD3(0, 0, 1))
        }
        // Neck
        mb.loft(path: [spineP + SIMD3(0, 0.55, 0), spineP + SIMD3(0, 0.63, 0.005), headP + SIMD3(0, -0.1, 0.0)],
                radii: [SIMD2(0.062, 0.058), SIMD2(0.055, 0.052), SIMD2(0.055, 0.05)],
                binds: [Bd(B.spine), Bd(B.spine, B.head, 0.5), Bd(B.head)], slots: [S.skin], sides: 12)

        // ---- Head (anime proportions: wide cranium, narrow V jaw)
        mb.ellipsoid(center: headP, radii: SIMD3(0.152, 0.17, 0.162), bind: Bd(B.head), slot: S.skin, rings: 18, sides: 22) { u in
            var v = u
            if v.y < 0 {
                let k = pow(-v.y, 1.3)
                v.x *= 1 - 0.36 * k
                if v.z > 0 { v.z *= 1 + 0.07 * k }
            }
            if v.z < 0 { v.z *= 1.05 }
            return v
        }
        for s in [Float(1), Float(-1)] {
            mb.ellipsoid(center: headP + SIMD3(s * 0.147, -0.012, -0.01), radii: SIMD3(0.024, 0.042, 0.03), bind: Bd(B.head),
                         slot: S.skin, rings: 6, sides: 8)
        }
        mb.ellipsoid(center: headP + SIMD3(0, -0.035, 0.153), radii: SIMD3(0.014, 0.022, 0.018), bind: Bd(B.head), slot: S.skin, rings: 5, sides: 8)
        buildFace(mb, headP)
        buildHair(mb, headP)

        // ---- Arms
        for (s, sh, el, fs, shoulder, elbow, fist) in [(Float(1), B.shL, B.elL, B.fsL, bones[B.shL], bones[B.elL], fistL),
                                                     (Float(-1), B.shR, B.elR, B.fsR, bones[B.shR], bones[B.elR], fistR)] {
            let S0 = P(shoulder), E = P(elbow), F = P(fist)
            let sleeve = L.sleeves
            let segSlots = [sleeve >= 1 ? S.primary : S.skin, sleeve >= 1 ? S.primary : S.skin,
                            sleeve >= 2 ? S.primary : S.skin, sleeve >= 2 ? S.primary : S.skin]
            mb.loft(path: [S0 + SIMD3(0, 0.03, 0), S0 + SIMD3(0, -0.13, 0), E, E + SIMD3(0, -0.14, 0), F + SIMD3(0, 0.065, 0)],
                    radii: [SIMD2(0.082 * b, 0.078 * b), SIMD2(0.07 * b, 0.068 * b), SIMD2(0.057 * b, 0.055 * b),
                            SIMD2(0.058 * b, 0.054 * b), SIMD2(0.044, 0.04)],
                    binds: [Bd(sh), Bd(sh), Bd(sh, el, 0.5), Bd(el), Bd(el, fs, 0.3)],
                    slots: segSlots, sides: 14)
            // Sleeve cuff / wristband
            mb.loft(path: [F + SIMD3(0, 0.09, 0), F + SIMD3(0, 0.035, 0)], radii: [SIMD2(0.052, 0.049), SIMD2(0.05, 0.047)],
                    binds: [Bd(el), Bd(el, fs, 0.5)], slots: [S.accent], sides: 12)
            let fistSlot = L.gloves ? S.accent : S.skin
            mb.ellipsoid(center: F + SIMD3(0, -0.012, 0.012), radii: SIMD3(0.056 * b, 0.062, 0.068), bind: Bd(fs), slot: fistSlot, rings: 8, sides: 12)
            mb.ellipsoid(center: F + SIMD3(-s * 0.038, 0.0, 0.04), radii: SIMD3(0.022, 0.03, 0.024), bind: Bd(fs), slot: fistSlot, rings: 5, sides: 8)
            if L.shoulderPads {
                mb.ellipsoid(center: S0 + SIMD3(s * 0.035, 0.04, 0), radii: SIMD3(0.115, 0.07, 0.115), bind: Bd(sh), slot: S.accent, rings: 8, sides: 14)
            }
        }

        // ---- Legs + boots
        for (hp, kn, hipJ, knee) in [(B.hpL, B.knL, bones[B.hpL], bones[B.knL]), (B.hpR, B.knR, bones[B.hpR], bones[B.knR])] {
            let H = P(hipJ), K = P(knee)
            let A = K + SIMD3<Float>(0, -0.4, 0)
            mb.loft(path: [H + SIMD3(0, 0.06, 0), H + SIMD3(0, -0.12, 0), K, K + SIMD3(0, -0.14, 0), A + SIMD3(0, 0.08, 0)],
                    radii: [SIMD2(0.105 * b, 0.11 * b), SIMD2(0.093 * b, 0.096 * b), SIMD2(0.067 * b, 0.07 * b),
                            SIMD2(0.072 * b, 0.077 * b), SIMD2(0.058, 0.06)],
                    binds: [Bd(hp), Bd(hp), Bd(hp, kn, 0.5), Bd(kn), Bd(kn)], slots: [S.secondary], sides: 14)
            mb.loft(path: [K + SIMD3(0, -0.2, 0), A + SIMD3(0, 0.02, 0), A + SIMD3(0, -0.05, 0)],
                    radii: [SIMD2(0.074, 0.078), SIMD2(0.066, 0.07), SIMD2(0.064, 0.07)],
                    binds: [Bd(kn), Bd(kn), Bd(kn)], slots: [S.boots], sides: 14, capEnd: true)
            mb.ellipsoid(center: A + SIMD3(0, -0.07, 0.055), radii: SIMD3(0.068, 0.052, 0.135), bind: Bd(kn), slot: S.boots, rings: 8, sides: 14)
            mb.loft(path: [K + SIMD3(0, -0.17, 0), K + SIMD3(0, -0.22, 0)], radii: [SIMD2(0.082, 0.086), SIMD2(0.08, 0.084)],
                    binds: [Bd(kn), Bd(kn)], slots: [S.accent], sides: 14)
        }

        // ---- Outfit pieces
        if L.coat {
            for s in [Float(1), Float(-1)] {
                mb.strand(hipsP + SIMD3(s * 0.1 * b, 0.06, -0.1), hipsP + SIMD3(s * 0.12 * b, -0.15, -0.14),
                          hipsP + SIMD3(s * 0.13 * b, -0.38, -0.17), hipsP + SIMD3(s * 0.12 * b, -0.62, -0.2),
                          width: 0.1, flatten: 0.15, taper: 0.35, bind: Bd(B.hips), slot: S.coat, segments: 6, sides: 8, ref: SIMD3(0, 0, -1))
            }
        }
        if L.cape {
            mb.strand(spineP + SIMD3(0, 0.5, -0.13), spineP + SIMD3(0, 0.2, -0.2),
                      hipsP + SIMD3(0, -0.3, -0.27), hipsP + SIMD3(0, -0.72, -0.32),
                      width: 0.24, flatten: 0.1, taper: -0.25, bind: Bd(B.spine), slot: S.coat, segments: 8, sides: 10, ref: SIMD3(0, 0, -1))
        }
        if L.scarf {
            var ring: [SIMD3<Float>] = []
            for i in 0...12 {
                let a = Float(i) / 12 * 2 * .pi
                ring.append(spineP + SIMD3(cos(a) * 0.088, 0.56, sin(a) * 0.082))
            }
            mb.loft(path: ring, radii: Array(repeating: SIMD2(0.036, 0.03), count: ring.count),
                    binds: Array(repeating: Bd(B.spine), count: ring.count), slots: [S.accent], sides: 8, ref: SIMD3(0, 1, 0))
            mb.strand(spineP + SIMD3(0.05, 0.54, -0.08), spineP + SIMD3(0.09, 0.42, -0.2),
                      spineP + SIMD3(0.12, 0.25, -0.28), spineP + SIMD3(0.16, 0.08, -0.36),
                      width: 0.05, flatten: 0.3, taper: 0.3, bind: Bd(B.spine), slot: S.accent, segments: 6, sides: 6, ref: SIMD3(0, 0, -1))
        }
        if L.headband {
            var ring: [SIMD3<Float>] = []
            for i in 0...14 {
                let a = Float(i) / 14 * 2 * .pi
                ring.append(headP + SIMD3(cos(a) * 0.165, 0.075 + sin(a) * 0.012, sin(a) * 0.172 - 0.01))
            }
            mb.loft(path: ring, radii: Array(repeating: SIMD2(0.012, 0.025), count: ring.count),
                    binds: Array(repeating: Bd(B.head), count: ring.count), slots: [S.accent], sides: 6, ref: SIMD3(0, 1, 0))
            for s in [Float(1), Float(-1)] {
                mb.strand(headP + SIMD3(s * 0.03, 0.07, -0.18), headP + SIMD3(s * 0.07, 0.03, -0.26),
                          headP + SIMD3(s * 0.1, -0.06, -0.3), headP + SIMD3(s * 0.12, -0.16, -0.32),
                          width: 0.025, flatten: 0.3, taper: 0.2, bind: Bd(B.head), slot: S.accent, segments: 5, sides: 5, ref: SIMD3(0, 0, -1))
            }
        }
        // Belt sash
        mb.strand(hipsP + SIMD3(0.13 * b, 0.07, 0.06), hipsP + SIMD3(0.16 * b, 0.0, 0.07),
                  hipsP + SIMD3(0.17 * b, -0.1, 0.06), hipsP + SIMD3(0.17 * b, -0.2, 0.05),
                  width: 0.03, flatten: 0.3, taper: 0.2, bind: Bd(B.hips), slot: S.accent, segments: 4, sides: 5, ref: SIMD3(1, 0, 0))

        // ---- Materials & skin binding
        var mats: [Int: SCNMaterial] = [
            S.skin: Toon.material(L.skin), S.primary: Toon.material(L.primary), S.secondary: Toon.material(L.secondary),
            S.accent: Toon.material(L.accent), S.hair: Toon.material(L.hair), S.white: Toon.material(.white, rim: false),
            S.iris: Toon.material(L.eyes, rim: false, emission: L.eyes.darker(0.6)), S.dark: Toon.material(UIColor(white: 0.12, alpha: 1), rim: false),
            S.coat: Toon.material(L.primary.darker(0.15)), S.boots: Toon.material(L.accent.darker(0.35)),
            S.brow: Toon.material(L.hair.darker(0.45), rim: false),
        ]
        for (_, m) in mats { materials.append(m) }
        mats[S.white]?.emission.contents = UIColor(white: 0.35, alpha: 1)
        let (mesh, hull) = mb.buildSkinned(bones: bones, skeleton: root, materials: mats, outline: Toon.outline, outlineWidth: 0.009)
        root.addChildNode(hull)
        root.addChildNode(mesh)
    }

    private func buildFace(_ mb: MeshBuilder, _ headP: SIMD3<Float>) {
        typealias Bd = MeshBuilder.Bind
        let sharp = def.speed == .fast
        for s in [Float(1), Float(-1)] {
            let q = simd_quatf(angle: s * 0.4, axis: SIMD3(0, 1, 0))
            let c = headP + SIMD3(s * 0.058, -0.008, 0.138)
            mb.ellipsoid(center: c, radii: SIMD3(0.036, sharp ? 0.036 : 0.043, 0.012), bind: Bd(B.head), slot: S.white, rings: 6, sides: 12,
                         rotation: q * simd_quatf(angle: sharp ? -s * 0.18 : 0, axis: SIMD3(0, 0, 1)))
            mb.ellipsoid(center: c + q.act(SIMD3(-s * 0.004, -0.002, 0.008)), radii: SIMD3(0.022, sharp ? 0.03 : 0.035, 0.01),
                         bind: Bd(B.head), slot: S.iris, rings: 6, sides: 12, rotation: q)
            mb.ellipsoid(center: c + q.act(SIMD3(-s * 0.009, -0.006, 0.014)), radii: SIMD3(0.011, 0.016, 0.006),
                         bind: Bd(B.head), slot: S.dark, rings: 4, sides: 8, rotation: q)
            mb.ellipsoid(center: c + q.act(SIMD3(s * 0.006, 0.012, 0.017)), radii: SIMD3(0.007, 0.009, 0.004),
                         bind: Bd(B.head), slot: S.white, rings: 4, sides: 6, rotation: q)
            // Brow
            let inner = headP + SIMD3(s * 0.028, 0.048, 0.152)
            let outer = headP + SIMD3(s * 0.095, sharp ? 0.07 : 0.058, 0.128)
            mb.strand(inner, inner + (outer - inner) * 0.33 + SIMD3(0, 0.006, 0.004), inner + (outer - inner) * 0.66 + SIMD3(0, 0.006, 0.002), outer,
                      width: 0.011, flatten: 0.5, taper: 0.6, bind: Bd(B.head), slot: S.brow, segments: 4, sides: 5, ref: SIMD3(0, 0, 1))
        }
        mb.ellipsoid(center: headP + SIMD3(0, -0.095, 0.142), radii: SIMD3(0.022, 0.0045, 0.006), bind: Bd(B.head), slot: S.dark, rings: 4, sides: 8)
    }

    private func buildHair(_ mb: MeshBuilder, _ headP: SIMD3<Float>) {
        typealias Bd = MeshBuilder.Bind
        let style = def.look.hairStyle
        let small = style == 10 || style == 8
        let capC = headP + (small ? SIMD3<Float>(0, 0.025, -0.01) : SIMD3<Float>(0, 0.045, -0.022))
        let capR: SIMD3<Float> = small ? SIMD3(0.158, 0.158, 0.168) : SIMD3(0.168, 0.165, 0.176)
        mb.ellipsoid(center: capC, radii: capR, bind: Bd(B.head), slot: S.hair, rings: 14, sides: 20)

        func dirFrom(lat: Float, lon: Float) -> SIMD3<Float> {
            SIMD3(sin(lon) * cos(lat), sin(lat), cos(lon) * cos(lat))
        }
        func lock(_ anchor: SIMD3<Float>, _ dir: SIMD3<Float>, _ len: Float, _ w: Float,
                  bend: SIMD3<Float> = .zero, flat: Float = 0.55) {
            let a = simd_normalize(anchor)
            let A = capC + a * capR * 0.93
            let d = simd_normalize(dir)
            mb.strand(A - d * 0.02, A + d * len * 0.33, A + d * len * 0.66 + bend * len * 0.4, A + d * len + bend * len * 0.6,
                      width: w, flatten: flat, bind: Bd(B.head), slot: S.hair, segments: 7, sides: 6, ref: simd_normalize(A - headP))
        }
        func bangs(_ n: Int = 5, length: Float = 0.15, sweep: Float = 0) {
            for i in 0..<n {
                let x = (Float(i) / Float(max(1, n - 1)) - 0.5) * 0.9
                lock(SIMD3(x, 0.62, 0.78), SIMD3(x * 0.6 + sweep, -0.88, 0.48), length * rand(0.85, 1.15), 0.042,
                     bend: SIMD3(sweep, -0.2, 0.2))
            }
        }
        let deg: Float = .pi / 180
        switch style {
        case 1: // long straight
            for lon in stride(from: Float(70), through: 290, by: 18) {
                let a = dirFrom(lat: 0.15, lon: lon * deg)
                lock(a, SIMD3(a.x * 0.25, -1, a.z * 0.2), rand(0.5, 0.62), 0.07, bend: SIMD3(a.x * 0.15, 0, a.z * 0.1))
            }
            for s in [Float(1), Float(-1)] { lock(SIMD3(s * 0.9, 0.2, 0.4), SIMD3(s * 0.15, -1, 0.15), 0.4, 0.05) }
            bangs(5, length: 0.15, sweep: 0.25)
        case 2: // flat top
            mb.ellipsoid(center: headP + SIMD3(0, 0.15, -0.02), radii: SIMD3(0.172, 0.085, 0.172), bind: Bd(B.head), slot: S.hair, rings: 8, sides: 18) { u in
                SIMD3(u.x, u.y > 0 ? min(u.y, 0.55) : u.y, u.z)
            }
            for s in [Float(1), Float(-1)] { lock(SIMD3(s * 0.95, 0.0, 0.25), SIMD3(0, -1, 0.1), 0.07, 0.035) }
        case 3: // ponytail
            bangs(4, length: 0.13, sweep: -0.2)
            let tie = headP + SIMD3<Float>(0, 0.07, -0.19)
            mb.ellipsoid(center: tie, radii: SIMD3(0.045, 0.045, 0.04), bind: Bd(B.head), slot: S.accent, rings: 6, sides: 10)
            for (dx, w) in [(Float(0), Float(0.08)), (Float(0.035), Float(0.05)), (Float(-0.035), Float(0.05))] {
                mb.strand(tie, tie + SIMD3(dx, 0.03, -0.13), tie + SIMD3(dx * 1.5, -0.2, -0.22), tie + SIMD3(dx, -0.5, -0.16),
                          width: w, flatten: 0.6, bind: Bd(B.head), slot: S.hair, segments: 8, sides: 6, ref: SIMD3(0, 0, -1))
            }
            for s in [Float(1), Float(-1)] { lock(SIMD3(s * 0.9, 0.15, 0.4), SIMD3(s * 0.1, -1, 0.2), 0.22, 0.04) }
        case 4: // swept-back blades
            for i in 0..<10 {
                let lat = rand(0.1, 0.8)
                let lon = rand(110, 250) * deg
                let a = dirFrom(lat: lat, lon: lon)
                lock(a, SIMD3(a.x * 0.45, 0.2 + lat * 0.2, -1), rand(0.34, 0.46), 0.06, bend: SIMD3(0, -0.15, 0), flat: 0.4)
                _ = i
            }
            for s in [Float(1), Float(-1)] { lock(SIMD3(s * 0.7, 0.5, 0.5), SIMD3(s * 0.5, 0.25, -1), 0.3, 0.05, flat: 0.4) }
            lock(SIMD3(0.2, 0.6, 0.75), SIMD3(0.4, -0.85, 0.4), 0.17, 0.045)
        case 5: // flame crest
            for _ in 0..<9 {
                let a = dirFrom(lat: rand(0.6, 1.3), lon: rand(-120, 120) * deg)
                lock(a, a + SIMD3(0, 1.3, -0.25), rand(0.3, 0.44), 0.07, bend: SIMD3(0, 0.25, -0.1))
            }
            for lon in stride(from: Float(120), through: 240, by: 30) {
                let a = dirFrom(lat: 0.3, lon: lon * deg)
                lock(a, a + SIMD3(0, 0.6, -0.4), 0.26, 0.065)
            }
            bangs(3, length: 0.13)
        case 6: // bob
            for lon in stride(from: Float(55), through: 305, by: 16) {
                let a = dirFrom(lat: 0.3, lon: lon * deg)
                lock(a, SIMD3(a.x * 0.2, -1, a.z * 0.2), 0.21, 0.085, bend: SIMD3(-a.x * 0.35, 0, -a.z * 0.35), flat: 0.45)
            }
            bangs(6, length: 0.14)
        case 7: // twin tails
            bangs(5, length: 0.14)
            for s in [Float(1), Float(-1)] {
                let tie = headP + SIMD3<Float>(s * 0.15, 0.1, -0.08)
                mb.ellipsoid(center: tie, radii: SIMD3(0.04, 0.04, 0.04), bind: Bd(B.head), slot: S.accent, rings: 6, sides: 10)
                mb.strand(tie, tie + SIMD3(s * 0.1, 0.02, -0.05), tie + SIMD3(s * 0.15, -0.3, -0.08), tie + SIMD3(s * 0.1, -0.62, -0.04),
                          width: 0.075, flatten: 0.6, bind: Bd(B.head), slot: S.hair, segments: 8, sides: 6, ref: SIMD3(s, 0, 0))
            }
        case 8: // mohawk ridge
            for i in 0..<8 {
                let ang = (-20 + Float(i) * 30) * deg
                let a = SIMD3<Float>(0, cos(ang), sin(ang) * -1)
                lock(a, a + SIMD3(0, 0.7, 0), rand(0.17, 0.24), 0.05, flat: 0.25)
            }
        case 9: // shaggy
            for _ in 0..<16 {
                let a = dirFrom(lat: rand(0.1, 0.9), lon: rand(-170, 170) * deg)
                if a.z > 0.55 && a.y < 0.6 { continue }
                lock(a, a * 0.5 + SIMD3(rand(-0.2, 0.2), -0.85, 0), rand(0.17, 0.26), 0.055, bend: SIMD3(rand(-0.3, 0.3), 0, rand(-0.2, 0.2)))
            }
            bangs(5, length: 0.16, sweep: rand(-0.3, 0.3))
        case 10: // close crop
            break
        case 11: // wild mane
            for _ in 0..<14 {
                let a = dirFrom(lat: rand(-0.1, 0.85), lon: rand(90, 270) * deg)
                lock(a, a + SIMD3(0, 0.1, -0.7), rand(0.34, 0.5), 0.08, bend: SIMD3(0, -0.25, -0.1))
            }
            for _ in 0..<5 {
                let a = dirFrom(lat: rand(0.8, 1.3), lon: rand(-60, 60) * deg)
                lock(a, a + SIMD3(0, 0.6, -0.5), rand(0.25, 0.32), 0.07)
            }
            bangs(4, length: 0.17, sweep: 0.15)
        default: // 0: spiky swept-back
            for lat in [Float(0.35), Float(0.75)] {
                for lon in stride(from: Float(-150), through: 150, by: 30) {
                    if lat < 0.5 && abs(lon) < 45 { continue }
                    let a = dirFrom(lat: lat, lon: lon * deg)
                    lock(a, a * 0.6 + SIMD3(0, 0.55, -0.6), rand(0.24, 0.32), 0.065, bend: SIMD3(0, 0.3, -0.2))
                }
            }
            lock(SIMD3(0, 1, 0), SIMD3(0, 1, -0.3), 0.3, 0.07, bend: SIMD3(0, 0.1, -0.3))
            bangs(3, length: 0.15)
        }
    }

    // MARK: - Poses

    static let stancePose: Pose = [
        .spine: SIMD3(0.1, 0.25, 0), .head: SIMD3(0, -0.2, 0),
        .shoulderL: SIMD3(-1.0, 0, 0.3), .elbowL: SIMD3(-1.75, 0, 0),
        .shoulderR: SIMD3(-0.75, 0, -0.35), .elbowR: SIMD3(-1.95, 0, 0),
        .hipL: SIMD3(-0.5, 0, 0.06), .kneeL: SIMD3(0.85, 0, 0),
        .hipR: SIMD3(0.2, 0, -0.06), .kneeR: SIMD3(0.7, 0, 0),
    ]

    static let dashPose: Pose = [
        .spine: SIMD3(0.6, 0, 0), .head: SIMD3(-0.4, 0, 0),
        .shoulderL: SIMD3(0.9, 0, 0.25), .elbowL: SIMD3(-0.3, 0, 0),
        .shoulderR: SIMD3(0.9, 0, -0.25), .elbowR: SIMD3(-0.3, 0, 0),
        .hipL: SIMD3(0.5, 0, 0.05), .kneeL: SIMD3(1.0, 0, 0),
        .hipR: SIMD3(0.8, 0, -0.05), .kneeR: SIMD3(1.2, 0, 0),
    ]

    static let chargePose: Pose = [
        .spine: SIMD3(0.2, 0, 0), .head: SIMD3(-0.25, 0, 0),
        .shoulderL: SIMD3(0.15, 0, 0.45), .elbowL: SIMD3(-0.5, 0, 0),
        .shoulderR: SIMD3(0.15, 0, -0.45), .elbowR: SIMD3(-0.5, 0, 0),
        .hipL: SIMD3(-0.3, 0, 0.2), .kneeL: SIMD3(0.6, 0, 0),
        .hipR: SIMD3(-0.3, 0, -0.2), .kneeR: SIMD3(0.6, 0, 0),
    ]

    static let beamChargePose: Pose = [
        .spine: SIMD3(0.05, 0.75, 0), .head: SIMD3(0, -0.6, 0),
        .shoulderL: SIMD3(0.35, 0, 0.1), .elbowL: SIMD3(-1.5, 0, 0),
        .shoulderR: SIMD3(0.45, 0, -0.1), .elbowR: SIMD3(-1.4, 0, 0),
        .hipL: SIMD3(-0.6, 0, 0.15), .kneeL: SIMD3(0.7, 0, 0),
        .hipR: SIMD3(0.3, 0, -0.15), .kneeR: SIMD3(0.5, 0, 0),
    ]

    static let beamFirePose: Pose = [
        .spine: SIMD3(-0.05, 0, 0), .head: SIMD3(0, 0, 0),
        .shoulderL: SIMD3(-1.55, 0, -0.18), .elbowL: SIMD3(-0.05, 0, 0),
        .shoulderR: SIMD3(-1.55, 0, 0.18), .elbowR: SIMD3(-0.05, 0, 0),
        .hipL: SIMD3(-0.6, 0, 0.15), .kneeL: SIMD3(0.5, 0, 0),
        .hipR: SIMD3(0.45, 0, -0.15), .kneeR: SIMD3(0.4, 0, 0),
    ]

    static let victoryPose: Pose = [
        .spine: SIMD3(-0.1, 0.1, 0), .head: SIMD3(-0.15, 0, 0),
        .shoulderL: SIMD3(0.2, 0, 0.35), .elbowL: SIMD3(-1.9, 0, 0),
        .shoulderR: SIMD3(-2.95, 0, -0.2), .elbowR: SIMD3(-0.25, 0, 0),
        .hipL: SIMD3(-0.25, 0, 0.1), .kneeL: SIMD3(0.4, 0, 0),
        .hipR: SIMD3(0.1, 0, -0.1), .kneeR: SIMD3(0.3, 0, 0),
    ]

    func apply(_ pose: Pose, duration: Double) {
        for (j, e) in pose {
            guard let n = joints[j] else { continue }
            n.removeAction(forKey: "pose")
            if duration <= 0 {
                n.simdEulerAngles = e
            } else {
                let a = SCNAction.rotateTo(x: CGFloat(e.x), y: CGFloat(e.y), z: CGFloat(e.z), duration: duration, usesShortestUnitArc: true)
                a.timingMode = .easeOut
                n.runAction(a, forKey: "pose")
            }
        }
    }

    /// Momentary pose, then return to stance.
    func strikeAndReturn(_ pose: Pose, hold: Double = 0.08, recover: Double = 0.14) {
        for (j, e) in pose {
            guard let n = joints[j] else { continue }
            n.removeAction(forKey: "pose")
            let back = FighterModel.stancePose[j] ?? .zero
            n.runAction(.sequence([
                .rotateTo(x: CGFloat(e.x), y: CGFloat(e.y), z: CGFloat(e.z), duration: 0.045, usesShortestUnitArc: true),
                .wait(duration: hold),
                .rotateTo(x: CGFloat(back.x), y: CGFloat(back.y), z: CGFloat(back.z), duration: recover, usesShortestUnitArc: true),
            ]), forKey: "pose")
        }
    }

    func stance() { apply(FighterModel.stancePose, duration: 0.14) }

    func idle() {
        body.removeAction(forKey: "bob")
        let up = SCNAction.moveBy(x: 0, y: 0.06, z: 0, duration: 0.6)
        up.timingMode = .easeInEaseOut
        body.runAction(.repeatForever(.sequence([up, up.reversed()])), forKey: "bob")
    }

    func attack(_ i: Int) {
        switch i % 5 {
        case 0: // left jab
            strikeAndReturn([.shoulderL: SIMD3(-1.6, 0, 0.05), .elbowL: SIMD3(-0.08, 0, 0), .spine: SIMD3(0.15, -0.35, 0)])
        case 1: // right cross
            strikeAndReturn([.shoulderR: SIMD3(-1.6, 0, -0.05), .elbowR: SIMD3(-0.08, 0, 0), .spine: SIMD3(0.18, 0.45, 0)])
        case 2: // front kick
            strikeAndReturn([.hipL: SIMD3(-1.55, 0, 0), .kneeL: SIMD3(0.05, 0, 0), .spine: SIMD3(-0.25, 0, 0)], hold: 0.1)
        case 3: // uppercut
            strikeAndReturn([.shoulderR: SIMD3(-2.7, 0, -0.1), .elbowR: SIMD3(-0.7, 0, 0), .spine: SIMD3(-0.15, 0.3, 0)], hold: 0.1)
        default: // spinning back kick
            strikeAndReturn([.hipR: SIMD3(-1.4, 0, -0.5), .kneeR: SIMD3(0.1, 0, 0), .spine: SIMD3(-0.2, -0.9, 0)], hold: 0.12)
        }
    }

    func finisher() {
        strikeAndReturn([
            .shoulderL: SIMD3(-1.55, 0, -0.15), .elbowL: SIMD3(-0.05, 0, 0),
            .shoulderR: SIMD3(-1.55, 0, 0.15), .elbowR: SIMD3(-0.05, 0, 0),
            .spine: SIMD3(0.3, 0, 0),
        ], hold: 0.14, recover: 0.2)
    }

    func dash() { apply(FighterModel.dashPose, duration: 0.08) }

    func blast() {
        strikeAndReturn([.shoulderR: SIMD3(-1.57, 0, 0.05), .elbowR: SIMD3(0, 0, 0), .spine: SIMD3(0, 0.5, 0),
                         .shoulderL: SIMD3(-0.6, 0, 0.5), .elbowL: SIMD3(-1.6, 0, 0)], hold: 0.12)
    }

    func hurt(heavy: Bool) {
        let p: Pose = heavy
            ? [.spine: SIMD3(-0.6, 0.2, 0), .head: SIMD3(-0.5, 0, 0),
               .shoulderL: SIMD3(0.7, 0, 0.9), .shoulderR: SIMD3(0.7, 0, -0.9), .elbowL: SIMD3(-0.3, 0, 0), .elbowR: SIMD3(-0.3, 0, 0)]
            : [.spine: SIMD3(-0.35, 0, 0), .head: SIMD3(-0.45, 0, 0)]
        strikeAndReturn(p, hold: heavy ? 0.35 : 0.12, recover: 0.2)
        flash()
    }

    func ko() {
        setAura(0)
        body.removeAction(forKey: "bob")
        apply([.spine: SIMD3(-0.4, 0, 0), .head: SIMD3(-0.6, 0, 0), .shoulderL: SIMD3(0.4, 0, 1.2), .shoulderR: SIMD3(0.4, 0, -1.2),
               .elbowL: SIMD3(-0.2, 0, 0), .elbowR: SIMD3(-0.2, 0, 0), .hipL: SIMD3(-0.2, 0, 0.1), .kneeL: SIMD3(0.3, 0, 0),
               .hipR: SIMD3(0.1, 0, -0.1), .kneeR: SIMD3(0.2, 0, 0)], duration: 0.3)
        let fall = SCNAction.group([
            .rotateTo(x: -1.45, y: 0, z: 0, duration: 0.5, usesShortestUnitArc: true),
            .move(to: SCNVector3(0, 0.1, 0), duration: 0.5),
        ])
        fall.timingMode = .easeIn
        body.runAction(fall)
    }

    func revive() {
        body.removeAllActions()
        body.simdEulerAngles = .zero
        body.simdPosition = SIMD3(0, FighterModel.hover, 0)
        stance()
        idle()
    }

    func victory() {
        setAura(1)
        apply(FighterModel.victoryPose, duration: 0.3)
    }

    // MARK: - FX helpers

    /// 0 off, 1 idle glow, 2 charging, 3 burst
    func setAura(_ level: Int) {
        guard level != currentAura else { return }
        currentAura = level
        aura.birthRate = [0, 10, 120, 240][max(0, min(3, level))]
    }

    func flash() {
        for m in materials { m.emission.contents = UIColor(white: 0.75, alpha: 1) }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 70_000_000)
            self?.materials.forEach { $0.emission.contents = UIColor.black }
        }
    }

    func afterimage(in parent: SCNNode) {
        // Teleport afterimage: a fading aura silhouette + speed sparks at the departure point.
        let base = root.simdWorldPosition
        for (i, h) in [Float(0.55), Float(1.1), Float(1.75)].enumerated() {
            let g = Toon.glowSprite(def.look.aura, size: CGFloat(i == 2 ? 0.8 : 1.1))
            g.simdPosition = base + SIMD3(0, h * def.look.height, 0)
            g.opacity = 0.7
            parent.addChildNode(g)
            g.runAction(.sequence([.group([.fadeOut(duration: 0.28), .scale(to: 0.4, duration: 0.28)]), .removeFromParentNode()]))
        }
        let sparks = Toon.burst(def.look.aura, count: 18, speed: 3, size: 0.18, life: 0.25)
        SCNNode.emit(sparks, at: base + SIMD3(0, 1.1, 0), in: parent, life: 0.5)
    }

    func setVisible(_ v: Bool) {
        root.opacity = v ? 1 : 0.15
    }

    func setBarrier(_ on: Bool) {
        if on, barrier == nil {
            let s = SCNNode(geometry: SCNSphere(radius: 1.05))
            s.geometry?.materials = [Toon.energy(UIColor(hex: 0x6FD0FF), alpha: 0.18)]
            s.simdPosition = SIMD3(0, 1.0, 0)
            s.runAction(.repeatForever(.sequence([.scale(to: 1.05, duration: 0.4), .scale(to: 0.97, duration: 0.4)])))
            body.addChildNode(s)
            barrier = s
        } else if !on, let b = barrier {
            b.runAction(.sequence([.fadeOut(duration: 0.2), .removeFromParentNode()]))
            barrier = nil
        }
    }

    func setPowered(_ on: Bool) {
        if on, powerGlow == nil {
            // Subtle power-up marker: a thin red ring at the feet.
            let g = SCNNode(geometry: SCNTorus(ringRadius: 0.55, pipeRadius: 0.015))
            g.geometry?.materials = [Toon.energy(UIColor(hex: 0xFF6A5A), alpha: 0.8)]
            g.simdPosition = SIMD3(0, 0.03, 0)
            g.runAction(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.5), .scale(to: 0.95, duration: 0.5)])))
            root.addChildNode(g)
            powerGlow = g
        } else if !on, let g = powerGlow {
            g.removeFromParentNode()
            powerGlow = nil
        }
    }

    var handWorld: SIMD3<Float> { retarget?.handR?.simdWorldPosition ?? fistR.simdWorldPosition }
    var isImported: Bool { importedHolder != nil }
    var chestWorld: SIMD3<Float> { root.simdWorldPosition + SIMD3(0, 1.35 * def.look.height, 0) }
}
