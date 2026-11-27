import SceneKit
import UIKit
import simd

enum Joint: CaseIterable {
    case spine, head, shoulderL, elbowL, shoulderR, elbowR, hipL, kneeL, hipR, kneeR
}

typealias Pose = [Joint: SIMD3<Float>]

/// Procedurally generated, cel-shaded 3D fighter with a joint skeleton.
/// Faces +Z. Everything (geometry, hair, outfit, animation) is generated in code.
@MainActor
final class FighterModel {
    let def: FighterDef
    let root = SCNNode()      // world placement + yaw
    let body = SCNNode()      // hover / bob / tilt
    private(set) var joints: [Joint: SCNNode] = [:]
    let fistL = SCNNode()
    let fistR = SCNNode()
    let headTop = SCNNode()
    private let auraNode = SCNNode()
    private let aura: SCNParticleSystem
    private var barrier: SCNNode?
    private var powerGlow: SCNNode?
    private var materials: [SCNMaterial] = []
    private var currentAura = -1

    static let hover: Float = 0.28

    init(def: FighterDef) {
        self.def = def
        aura = Toon.aura(def.look.aura, height: 1.9)
        build()
        root.simdScale = SIMD3(repeating: def.look.height)
        apply(FighterModel.stancePose, duration: 0)
        idle()
    }

    // MARK: - Construction

    private func add(_ geo: SCNGeometry, _ color: UIColor, to parent: SCNNode, at p: SIMD3<Float>,
                     outline: Float = 0.012, scale: SIMD3<Float>? = nil, euler: SIMD3<Float>? = nil, rim: Bool = true) -> SCNNode {
        let n = Toon.part(geo, color, outline: outline, rim: rim)
        n.simdPosition = p
        if let scale { n.simdScale = scale }
        if let euler { n.simdEulerAngles = euler }
        parent.addChildNode(n)
        if let m = geo.firstMaterial { materials.append(m) }
        return n
    }

    private func joint(_ j: Joint, parent: SCNNode, at p: SIMD3<Float>) -> SCNNode {
        let n = SCNNode()
        n.simdPosition = p
        parent.addChildNode(n)
        joints[j] = n
        return n
    }

    private func build() {
        let L = def.look
        let b = L.bulk
        root.addChildNode(body)
        body.simdPosition = SIMD3(0, FighterModel.hover, 0)

        // Shadow blob on the ground (not hovering)
        let shadowPlane = SCNPlane(width: 0.9, height: 0.9)
        let sm = SCNMaterial()
        sm.diffuse.contents = Toon.glowImage
        sm.multiply.contents = UIColor.black
        sm.lightingModel = .constant
        sm.transparency = 0.55
        sm.writesToDepthBuffer = false
        shadowPlane.materials = [sm]
        let shadow = SCNNode(geometry: shadowPlane)
        shadow.simdEulerAngles = SIMD3(-.pi / 2, 0, 0)
        shadow.simdPosition = SIMD3(0, 0.01, 0)
        root.addChildNode(shadow)

        let hips = SCNNode()
        hips.simdPosition = SIMD3(0, 0.95, 0)
        body.addChildNode(hips)

        // Pelvis + belt
        _ = add(SCNBox(width: CGFloat(0.31 * b), height: 0.18, length: 0.21, chamferRadius: 0.06), L.secondary, to: hips, at: .zero)

        // Legs
        for (j, k, x) in [(Joint.hipL, Joint.kneeL, Float(0.1)), (Joint.hipR, Joint.kneeR, Float(-0.1))] {
            let hip = joint(j, parent: hips, at: SIMD3(x * b, -0.05, 0))
            _ = add(SCNCapsule(capRadius: CGFloat(0.088 * b), height: 0.5), L.secondary, to: hip, at: SIMD3(0, -0.22, 0))
            let knee = joint(k, parent: hip, at: SIMD3(0, -0.44, 0))
            _ = add(SCNCapsule(capRadius: CGFloat(0.076 * b), height: 0.46), L.secondary.darker(0.08), to: knee, at: SIMD3(0, -0.2, 0))
            _ = add(SCNBox(width: 0.16, height: 0.15, length: 0.3, chamferRadius: 0.05), L.accent, to: knee, at: SIMD3(0, -0.43, 0.05))
            _ = add(SCNCylinder(radius: CGFloat(0.085 * b), height: 0.08), L.accent.lighter(0.15), to: knee, at: SIMD3(0, -0.32, 0))
        }

        // Spine / torso
        let spine = joint(.spine, parent: hips, at: SIMD3(0, 0.07, 0))
        _ = add(SCNBox(width: CGFloat(0.3 * b), height: 0.22, length: 0.2, chamferRadius: 0.07), L.primary.darker(0.06), to: spine, at: SIMD3(0, 0.1, 0))
        _ = add(SCNBox(width: CGFloat(0.35 * b), height: 0.07, length: 0.235, chamferRadius: 0.025), L.accent, to: spine, at: SIMD3(0, 0.0, 0), outline: 0.008)
        _ = add(SCNBox(width: CGFloat(0.44 * b), height: 0.34, length: CGFloat(0.26 * min(b, 1.1)), chamferRadius: 0.09), L.primary, to: spine, at: SIMD3(0, 0.36, 0))
        // Collar V
        _ = add(SCNBox(width: 0.17, height: 0.12, length: 0.02, chamferRadius: 0.01), L.skin, to: spine, at: SIMD3(0, 0.47, Float(0.12 * min(b, 1.1))),
                outline: 0, euler: SIMD3(0, 0, .pi / 4))
        // Chest crest (original crescent emblem)
        _ = add(SCNTorus(ringRadius: 0.035, pipeRadius: 0.011), L.aura, to: spine, at: SIMD3(-0.09 * b, 0.4, Float(0.135 * min(b, 1.1))),
                outline: 0, euler: SIMD3(.pi / 2, 0, 0), rim: false)

        if L.shoulderPads {
            for x in [Float(0.27), Float(-0.27)] {
                _ = add(SCNSphere(radius: 0.12), L.accent, to: spine, at: SIMD3(x * b, 0.5, 0), scale: SIMD3(1.15, 0.75, 1.1))
            }
        }
        if L.scarf {
            _ = add(SCNTorus(ringRadius: 0.11, pipeRadius: 0.045), L.accent.lighter(0.1), to: spine, at: SIMD3(0, 0.55, 0))
            let tail = add(SCNBox(width: 0.1, height: 0.42, length: 0.03, chamferRadius: 0.015), L.accent.lighter(0.1), to: spine,
                           at: SIMD3(0.06, 0.4, -0.17), euler: SIMD3(0.35, 0, 0.15))
            tail.runAction(.repeatForever(.sequence([
                .rotateTo(x: 0.55, y: 0, z: 0.25, duration: 0.5, usesShortestUnitArc: true),
                .rotateTo(x: 0.3, y: 0, z: 0.05, duration: 0.5, usesShortestUnitArc: true),
            ])))
        }
        if L.coat {
            for x in [Float(0.1), Float(-0.1)] {
                let t = add(SCNBox(width: 0.17, height: 0.62, length: 0.03, chamferRadius: 0.012), L.primary.darker(0.12), to: spine,
                            at: SIMD3(x * b, -0.22, -0.13), euler: SIMD3(0.18, 0, x > 0 ? -0.06 : 0.06))
                t.runAction(.repeatForever(.sequence([
                    .rotateTo(x: 0.32, y: 0, z: CGFloat(x > 0 ? -0.1 : 0.1), duration: 0.6, usesShortestUnitArc: true),
                    .rotateTo(x: 0.16, y: 0, z: CGFloat(x > 0 ? -0.04 : 0.04), duration: 0.6, usesShortestUnitArc: true),
                ])))
            }
        }

        // Arms
        for (s, e, x, fist) in [(Joint.shoulderL, Joint.elbowL, Float(1), fistL), (Joint.shoulderR, Joint.elbowR, Float(-1), fistR)] {
            let shoulder = joint(s, parent: spine, at: SIMD3(0.275 * b * x, 0.47, 0))
            _ = add(SCNSphere(radius: CGFloat(0.085 * b)), L.primary, to: shoulder, at: .zero)
            _ = add(SCNCapsule(capRadius: CGFloat(0.074 * b), height: 0.34), L.primary, to: shoulder, at: SIMD3(0, -0.15, 0))
            let elbow = joint(e, parent: shoulder, at: SIMD3(0, -0.3, 0))
            _ = add(SCNCapsule(capRadius: CGFloat(0.064 * b), height: 0.3), L.skin, to: elbow, at: SIMD3(0, -0.13, 0))
            _ = add(SCNCylinder(radius: CGFloat(0.073 * b), height: 0.075), L.accent, to: elbow, at: SIMD3(0, -0.22, 0), outline: 0.008)
            fist.simdPosition = SIMD3(0, -0.32, 0.01)
            elbow.addChildNode(fist)
            _ = add(SCNSphere(radius: CGFloat(0.085 * b)), L.skin, to: fist, at: .zero, scale: SIMD3(0.95, 0.9, 1.1))
        }

        // Neck + head
        _ = add(SCNCylinder(radius: 0.062, height: 0.14), L.skin.darker(0.08), to: spine, at: SIMD3(0, 0.58, 0))
        let head = joint(.head, parent: spine, at: SIMD3(0, 0.74, 0.01))
        buildHead(head)

        auraNode.simdPosition = SIMD3(0, 0.95, 0)
        auraNode.addParticleSystem(aura)
        body.addChildNode(auraNode)
    }

    private func buildHead(_ head: SCNNode) {
        let L = def.look
        _ = add(SCNSphere(radius: 0.165), L.skin, to: head, at: .zero, scale: SIMD3(0.95, 1.05, 1.0))
        // Jaw / chin
        _ = add(SCNSphere(radius: 0.11), L.skin, to: head, at: SIMD3(0, -0.075, 0.045), outline: 0, scale: SIMD3(1.0, 0.85, 1.0))
        // Ears
        for x in [Float(0.158), Float(-0.158)] {
            _ = add(SCNSphere(radius: 0.035), L.skin.darker(0.05), to: head, at: SIMD3(x, -0.005, -0.01), outline: 0.006, scale: SIMD3(0.6, 1, 0.9))
        }
        // Anime eyes: sclera, iris, highlight, angled brow
        for x in [Float(0.064), Float(-0.064)] {
            let tilt: Float = x > 0 ? -0.12 : 0.12
            _ = add(SCNBox(width: 0.068, height: 0.056, length: 0.02, chamferRadius: 0.012), .white, to: head,
                    at: SIMD3(x, -0.005, 0.145), outline: 0.005, euler: SIMD3(0, x * 2.2, tilt), rim: false)
            _ = add(SCNBox(width: 0.036, height: 0.054, length: 0.022, chamferRadius: 0.01), L.eyes, to: head,
                    at: SIMD3(x * 0.96, -0.006, 0.152), outline: 0, euler: SIMD3(0, x * 2.2, 0), rim: false)
            _ = add(SCNSphere(radius: 0.009), .white, to: head, at: SIMD3(x * 0.92 + 0.008, 0.012, 0.165), outline: 0, rim: false)
            _ = add(SCNBox(width: 0.075, height: 0.016, length: 0.02, chamferRadius: 0.006), L.hair.darker(0.4), to: head,
                    at: SIMD3(x, 0.052, 0.148), outline: 0, euler: SIMD3(0, x * 2.2, x > 0 ? 0.22 : -0.22))
        }
        _ = add(SCNBox(width: 0.045, height: 0.008, length: 0.01, chamferRadius: 0.003), L.skin.darker(0.55), to: head,
                at: SIMD3(0, -0.095, 0.135), outline: 0)
        buildHair(head)
        headTop.simdPosition = SIMD3(0, 0.3, 0)
        head.addChildNode(headTop)
    }

    private struct Spike {
        let dir: SIMD3<Float>
        let length: Float
        let radius: Float
        var anchor: SIMD3<Float>? = nil
    }

    private func spike(_ s: Spike, on parent: SCNNode, center: SIMD3<Float>, capRadius: Float) {
        let d = simd_normalize(s.dir)
        let holder = SCNNode()
        holder.simdPosition = s.anchor ?? (center + d * capRadius * 0.72)
        holder.simdOrientation = simd_quatf(from: SIMD3(0, 1, 0), to: d)
        parent.addChildNode(holder)
        _ = add(SCNCone(topRadius: 0, bottomRadius: CGFloat(s.radius), height: CGFloat(s.length)), def.look.hair, to: holder,
                at: SIMD3(0, s.length / 2, 0), outline: 0.01)
    }

    private func buildHair(_ head: SCNNode) {
        let L = def.look
        let center = SIMD3<Float>(0, 0.06, -0.04)
        let capR: Float = 0.178
        _ = add(SCNSphere(radius: CGFloat(capR)), L.hair, to: head, at: center, outline: 0.012, scale: SIMD3(1.04, 1.0, 1.02))

        var spikes: [Spike] = []
        // Front bangs (shared)
        let bangs = [
            Spike(dir: SIMD3(0.05, -0.75, 0.65), length: 0.15, radius: 0.05, anchor: SIMD3(0.0, 0.14, 0.11)),
            Spike(dir: SIMD3(0.35, -0.75, 0.55), length: 0.14, radius: 0.048, anchor: SIMD3(0.075, 0.13, 0.1)),
            Spike(dir: SIMD3(-0.35, -0.75, 0.55), length: 0.14, radius: 0.048, anchor: SIMD3(-0.075, 0.13, 0.1)),
        ]
        switch L.hairStyle {
        case 1: // long flowing
            spikes = bangs + [
                Spike(dir: SIMD3(0, -1, -0.18), length: 0.62, radius: 0.15, anchor: SIMD3(0, 0.02, -0.12)),
                Spike(dir: SIMD3(0.25, -1, -0.1), length: 0.5, radius: 0.08, anchor: SIMD3(0.1, 0.0, -0.08)),
                Spike(dir: SIMD3(-0.25, -1, -0.1), length: 0.5, radius: 0.08, anchor: SIMD3(-0.1, 0.0, -0.08)),
                Spike(dir: SIMD3(0.15, -1, 0.1), length: 0.34, radius: 0.045, anchor: SIMD3(0.15, 0.02, 0.06)),
                Spike(dir: SIMD3(-0.15, -1, 0.1), length: 0.34, radius: 0.045, anchor: SIMD3(-0.15, 0.02, 0.06)),
            ]
        case 2: // flat top
            _ = add(SCNBox(width: 0.36, height: 0.16, length: 0.34, chamferRadius: 0.04), L.hair, to: head,
                    at: SIMD3(0, 0.18, -0.02), outline: 0.012)
            spikes = [
                Spike(dir: SIMD3(0, -0.6, 0.8), length: 0.08, radius: 0.04, anchor: SIMD3(0.05, 0.13, 0.13)),
                Spike(dir: SIMD3(0, -0.6, 0.8), length: 0.08, radius: 0.04, anchor: SIMD3(-0.05, 0.13, 0.13)),
            ]
        case 3: // ponytail
            _ = add(SCNSphere(radius: 0.05), L.accent, to: head, at: SIMD3(0, 0.1, -0.19), outline: 0.008)
            spikes = bangs + [
                Spike(dir: SIMD3(0, -0.45, -0.9), length: 0.42, radius: 0.1, anchor: SIMD3(0, 0.1, -0.2)),
                Spike(dir: SIMD3(0, -1, -0.35), length: 0.38, radius: 0.08, anchor: SIMD3(0, -0.06, -0.48)),
                Spike(dir: SIMD3(0.2, -1, 0.1), length: 0.22, radius: 0.04, anchor: SIMD3(0.15, 0.03, 0.07)),
                Spike(dir: SIMD3(-0.2, -1, 0.1), length: 0.22, radius: 0.04, anchor: SIMD3(-0.15, 0.03, 0.07)),
            ]
        case 4: // swept back blades
            spikes = [
                Spike(dir: SIMD3(0.0, 0.25, -1), length: 0.42, radius: 0.08),
                Spike(dir: SIMD3(0.45, 0.2, -1), length: 0.36, radius: 0.07),
                Spike(dir: SIMD3(-0.45, 0.2, -1), length: 0.36, radius: 0.07),
                Spike(dir: SIMD3(0.2, 0.6, -1), length: 0.38, radius: 0.07),
                Spike(dir: SIMD3(-0.2, 0.6, -1), length: 0.38, radius: 0.07),
                Spike(dir: SIMD3(0.7, -0.1, -0.8), length: 0.28, radius: 0.06),
                Spike(dir: SIMD3(-0.7, -0.1, -0.8), length: 0.28, radius: 0.06),
                Spike(dir: SIMD3(0.4, -0.7, 0.6), length: 0.17, radius: 0.045, anchor: SIMD3(0.06, 0.13, 0.1)),
            ]
        case 5: // flame crest
            spikes = bangs + [
                Spike(dir: SIMD3(0, 1, -0.1), length: 0.42, radius: 0.09),
                Spike(dir: SIMD3(0.4, 1, -0.15), length: 0.34, radius: 0.08),
                Spike(dir: SIMD3(-0.4, 1, -0.15), length: 0.34, radius: 0.08),
                Spike(dir: SIMD3(0, 0.8, -0.6), length: 0.36, radius: 0.08),
                Spike(dir: SIMD3(0.7, 0.6, -0.4), length: 0.26, radius: 0.07),
                Spike(dir: SIMD3(-0.7, 0.6, -0.4), length: 0.26, radius: 0.07),
                Spike(dir: SIMD3(0, 0.3, -1), length: 0.28, radius: 0.08),
            ]
        default: // swept spikes
            spikes = bangs + [
                Spike(dir: SIMD3(0, 1, -0.35), length: 0.3, radius: 0.08),
                Spike(dir: SIMD3(0.5, 0.8, -0.4), length: 0.27, radius: 0.075),
                Spike(dir: SIMD3(-0.5, 0.8, -0.4), length: 0.27, radius: 0.075),
                Spike(dir: SIMD3(0.85, 0.3, -0.5), length: 0.22, radius: 0.065),
                Spike(dir: SIMD3(-0.85, 0.3, -0.5), length: 0.22, radius: 0.065),
                Spike(dir: SIMD3(0, 0.45, -1), length: 0.3, radius: 0.08),
                Spike(dir: SIMD3(0.45, 0.1, -1), length: 0.25, radius: 0.07),
                Spike(dir: SIMD3(-0.45, 0.1, -1), length: 0.25, radius: 0.07),
                Spike(dir: SIMD3(0.25, 1, 0.25), length: 0.2, radius: 0.06),
                Spike(dir: SIMD3(-0.25, 1, 0.25), length: 0.2, radius: 0.06),
            ]
        }
        for s in spikes { spike(s, on: head, center: center, capRadius: capR) }
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
        aura.birthRate = [0, 18, 160, 320][max(0, min(3, level))]
    }

    func flash() {
        for m in materials { m.emission.contents = UIColor(white: 0.75, alpha: 1) }
        Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 70_000_000)
            self?.materials.forEach { $0.emission.contents = UIColor.black }
        }
    }

    func afterimage(in parent: SCNNode) {
        let ghost = root.clone()
        ghost.simdTransform = root.simdWorldTransform
        ghost.opacity = 0.45
        parent.addChildNode(ghost)
        ghost.runAction(.sequence([.fadeOut(duration: 0.3), .removeFromParentNode()]))
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
            let g = Toon.glowSprite(UIColor(hex: 0xFF4A3A), size: 2.6)
            g.simdPosition = SIMD3(0, 1.0, -0.2)
            g.opacity = 0.5
            body.addChildNode(g)
            powerGlow = g
        } else if !on, let g = powerGlow {
            g.removeFromParentNode()
            powerGlow = nil
        }
    }

    var handWorld: SIMD3<Float> { fistR.simdWorldPosition }
    var chestWorld: SIMD3<Float> { root.simdWorldPosition + SIMD3(0, 1.35 * def.look.height, 0) }
}
