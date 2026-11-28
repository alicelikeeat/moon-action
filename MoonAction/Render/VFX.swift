import SceneKit
import UIKit
import simd

/// Anime-style visual effects built from procedural textures + particles.
/// Energy materials use high emission so the camera's bloom makes them glow.
@MainActor
enum VFX {
    // MARK: - Procedural textures

    private static func render(_ size: CGFloat, _ draw: (CGContext, CGFloat) -> Void) -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: size, height: size)).image { ctx in draw(ctx.cgContext, size) }
    }

    /// Sharp anime impact star.
    static let starburst: UIImage = render(256) { c, s in
        let center = CGPoint(x: s / 2, y: s / 2)
        let glow = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                              colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 1])!
        c.drawRadialGradient(glow, startCenter: center, startRadius: 0, endCenter: center, endRadius: s * 0.22, options: [])
        c.setFillColor(UIColor.white.cgColor)
        let spikes = 12
        for i in 0..<spikes {
            let a = CGFloat(i) / CGFloat(spikes) * 2 * .pi + (i % 2 == 0 ? 0 : 0.12)
            let len = s * (i % 2 == 0 ? 0.49 : 0.3)
            let w: CGFloat = s * 0.035
            c.move(to: CGPoint(x: center.x + cos(a + .pi / 2) * w, y: center.y + sin(a + .pi / 2) * w))
            c.addLine(to: CGPoint(x: center.x + cos(a) * len, y: center.y + sin(a) * len))
            c.addLine(to: CGPoint(x: center.x + cos(a - .pi / 2) * w, y: center.y + sin(a - .pi / 2) * w))
            c.closePath()
        }
        c.fillPath()
    }

    /// Thin soft ring (shockwaves).
    static let ring: UIImage = render(256) { c, s in
        let center = CGPoint(x: s / 2, y: s / 2)
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor,
                                    UIColor.white.withAlphaComponent(0).cgColor] as CFArray,
                           locations: [0.72, 0.86, 1])!
        c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: s / 2, options: [])
    }

    /// Teardrop flame for auras.
    static let flame: UIImage = render(128) { c, s in
        let path = UIBezierPath()
        path.move(to: CGPoint(x: s * 0.5, y: s * 0.02))
        path.addCurve(to: CGPoint(x: s * 0.5, y: s * 0.98), controlPoint1: CGPoint(x: s * 0.95, y: s * 0.5),
                      controlPoint2: CGPoint(x: s * 0.85, y: s * 0.98))
        path.addCurve(to: CGPoint(x: s * 0.5, y: s * 0.02), controlPoint1: CGPoint(x: s * 0.15, y: s * 0.98),
                      controlPoint2: CGPoint(x: s * 0.05, y: s * 0.5))
        c.saveGState()
        c.addPath(path.cgPath)
        c.clip()
        let center = CGPoint(x: s / 2, y: s * 0.7)
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.25).cgColor] as CFArray, locations: [0, 1])!
        c.drawRadialGradient(g, startCenter: center, startRadius: 0, endCenter: center, endRadius: s * 0.6, options: [.drawsAfterEndLocation])
        c.restoreGState()
    }

    /// Soft noisy puff for smoke and fireballs.
    static let smoke: UIImage = render(128) { c, s in
        var gen = UInt64(7)
        func rnd() -> CGFloat {
            gen = gen &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat((gen >> 33) & 0xFFFF) / CGFloat(0xFFFF)
        }
        for _ in 0..<26 {
            let r = s * (0.12 + rnd() * 0.2)
            let p = CGPoint(x: s / 2 + (rnd() - 0.5) * s * 0.45, y: s / 2 + (rnd() - 0.5) * s * 0.45)
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                               colors: [UIColor(white: 1, alpha: 0.35).cgColor, UIColor(white: 1, alpha: 0).cgColor] as CFArray, locations: [0, 1])!
            c.drawRadialGradient(g, startCenter: p, startRadius: 0, endCenter: p, endRadius: r, options: [])
        }
    }

    /// Thin vertical light streak (teleport).
    static let streak: UIImage = UIGraphicsImageRenderer(size: CGSize(width: 32, height: 256)).image { ctx in
        let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor,
                                    UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.5, 1])!
        ctx.cgContext.drawLinearGradient(g, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 0, y: 256), options: [])
        ctx.cgContext.setBlendMode(.destinationIn)
        let h = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                           colors: [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor,
                                    UIColor.white.withAlphaComponent(0).cgColor] as CFArray, locations: [0, 0.5, 1])!
        ctx.cgContext.drawLinearGradient(h, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 32, y: 0), options: [])
    }

    // MARK: - Building blocks

    static func billboard(_ image: UIImage, color: UIColor, size: CGFloat, additive: Bool = true, intensity: CGFloat = 2) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let m = SCNMaterial()
        m.diffuse.contents = image
        m.multiply.contents = color
        m.emission.contents = image
        m.emission.intensity = intensity
        m.lightingModel = .constant
        m.blendMode = additive ? .add : .alpha
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        let n = SCNNode(geometry: plane)
        n.constraints = [SCNBillboardConstraint()]
        return n
    }

    static func colorRamp(_ colors: [UIColor], _ times: [NSNumber]) -> SCNParticlePropertyController {
        let a = CAKeyframeAnimation()
        a.values = colors
        a.keyTimes = times
        return SCNParticlePropertyController(animation: a)
    }

    static func ramp(_ values: [NSNumber], _ times: [NSNumber]? = nil) -> SCNParticlePropertyController {
        let a = CAKeyframeAnimation()
        a.values = values
        a.keyTimes = times
        return SCNParticlePropertyController(animation: a)
    }

    /// Place a temporary effect node that removes itself.
    private static func spawn(_ n: SCNNode, at p: SIMD3<Float>, in parent: SCNNode, life: Double) {
        n.simdPosition = p
        parent.addChildNode(n)
        n.runAction(.sequence([.wait(duration: life), .removeFromParentNode()]))
    }

    private static func emitter(_ ps: SCNParticleSystem, at p: SIMD3<Float>, in parent: SCNNode, life: Double = 1.5) {
        let n = SCNNode()
        n.addParticleSystem(ps)
        spawn(n, at: p, in: parent, life: life)
    }

    // MARK: - Particle systems

    static func sparks(_ color: UIColor, count: CGFloat, speed: CGFloat, size: CGFloat = 0.1, life: CGFloat = 0.3) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = Toon.sparkImage
        p.birthRate = count / 0.04
        p.emissionDuration = 0.04
        p.loops = false
        p.particleLifeSpan = life
        p.particleLifeSpanVariation = life * 0.4
        p.particleVelocity = speed
        p.particleVelocityVariation = speed * 0.6
        p.spreadingAngle = 180
        p.particleSize = size
        p.particleSizeVariation = size * 0.5
        p.stretchFactor = 0.035
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.particleColor = .white
        p.dampingFactor = 2.5
        p.propertyControllers = [
            .color: colorRamp([.white, color.lighter(0.3), color], [0, 0.35, 1]),
            .opacity: ramp([1, 1, 0], [0, 0.6, 1]),
        ]
        return p
    }

    static func auraSystem(_ color: UIColor) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = flame
        p.birthRate = 0
        p.emitterShape = SCNCylinder(radius: 0.38, height: 1.7)
        p.birthLocation = .volume
        p.particleLifeSpan = 0.5
        p.particleLifeSpanVariation = 0.15
        p.particleVelocity = 2.0
        p.particleVelocityVariation = 0.8
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 8
        p.particleSize = 0.13
        p.particleSizeVariation = 0.05
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.acceleration = SCNVector3(0, 2.5, 0)
        p.orientationMode = .billboardViewAligned
        p.propertyControllers = [
            .color: colorRamp([color.lighter(0.5), color, color.darker(0.2)], [0, 0.4, 1]),
            .opacity: ramp([0, 0.55, 0.35, 0], [0, 0.15, 0.6, 1]),
            .size: ramp([0.6, 1.0, 0.4], [0, 0.4, 1]),
        ]
        return p
    }

    static func chargeSparks(_ color: UIColor) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = Toon.sparkImage
        p.birthRate = 0
        p.emitterShape = SCNSphere(radius: 1.3)
        p.birthLocation = .surface
        p.birthDirection = .surfaceNormal
        p.particleVelocity = -3.2
        p.particleLifeSpan = 0.35
        p.particleSize = 0.08
        p.stretchFactor = 0.05
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.propertyControllers = [
            .color: colorRamp([color, .white], [0, 1]),
            .opacity: ramp([0, 1, 0.8], [0, 0.3, 1]),
        ]
        return p
    }

    // MARK: - Effects

    /// Hit impact: star flash + shockwave ring + sparks (+ debris for heavy).
    /// `scale` shrinks the flash for impacts close to the camera (hits on the player's own fighter).
    static func impact(at p: SIMD3<Float>, color: UIColor, heavy: Bool, in parent: SCNNode, dir: SIMD3<Float>? = nil, scale k: CGFloat = 1) {
        if let dir { directional(at: p, dir: dir, color: color, heavy: heavy, in: parent, scale: k) }
        let star = billboard(starburst, color: color.lighter(0.5), size: (heavy ? 1.4 : 0.8) * k, intensity: 2.2 * min(1, k + 0.2))
        star.simdEulerAngles.z = Float.random(in: 0..<(2 * .pi))
        star.scale = SCNVector3(0.3, 0.3, 0.3)
        star.runAction(.sequence([.scale(to: 1, duration: 0.05), .group([.scale(to: 1.25, duration: 0.12), .fadeOut(duration: 0.12)])]))
        spawn(star, at: p, in: parent, life: 0.3)

        let ringNode = billboard(ring, color: color, size: (heavy ? 1.2 : 0.7) * k, intensity: 2.5 * min(1, k + 0.2))
        ringNode.scale = SCNVector3(0.2, 0.2, 0.2)
        ringNode.runAction(.group([.scale(to: heavy ? 2.6 : 1.8, duration: 0.25), .fadeOut(duration: 0.25)]))
        spawn(ringNode, at: p, in: parent, life: 0.4)

        emitter(sparks(color, count: heavy ? 40 : 16, speed: heavy ? 11 : 7, size: (heavy ? 0.12 : 0.08) * k), at: p, in: parent, life: 0.8)
        if heavy {
            let debris = SCNParticleSystem()
            debris.particleImage = Toon.glowImage
            debris.birthRate = 500
            debris.emissionDuration = 0.04
            debris.loops = false
            debris.particleLifeSpan = 0.6
            debris.particleVelocity = 4
            debris.particleVelocityVariation = 2
            debris.spreadingAngle = 70
            debris.emittingDirection = SCNVector3(0, 1, 0)
            debris.particleSize = 0.05
            debris.particleColor = color.lighter(0.4)
            debris.blendMode = .additive
            debris.isLightingEnabled = false
            debris.acceleration = SCNVector3(0, -9, 0)
            debris.propertyControllers = [.opacity: ramp([1, 0], [0.5, 1])]
            emitter(debris, at: p, in: parent)
        }
    }

    /// Fighting-game style hit sparks: fast streaks sprayed along the hit direction + a flat slash flash.
    static func directional(at p: SIMD3<Float>, dir: SIMD3<Float>, color: UIColor, heavy: Bool, in parent: SCNNode, scale k: CGFloat = 1) {
        let s = SCNParticleSystem()
        s.particleImage = Toon.sparkImage
        s.birthRate = heavy ? 900 : 420
        s.emissionDuration = 0.03
        s.loops = false
        s.particleLifeSpan = heavy ? 0.22 : 0.16
        s.particleLifeSpanVariation = 0.06
        s.particleVelocity = heavy ? 18 : 12
        s.particleVelocityVariation = 6
        s.emittingDirection = SCNVector3(dir.x, dir.y, dir.z)
        s.spreadingAngle = heavy ? 32 : 24
        s.particleSize = (heavy ? 0.09 : 0.06) * k
        s.stretchFactor = 0.07
        s.blendMode = .additive
        s.isLightingEnabled = false
        s.propertyControllers = [.color: colorRamp([.white, color.lighter(0.4), color], [0, 0.35, 1]), .opacity: ramp([1, 0])]
        emitter(s, at: p, in: parent, life: 0.5)
        // Flat elongated flash across the impact, oriented by the hit direction.
        let slash = billboard(Toon.glowImage, color: .white, size: (heavy ? 1.6 : 1.0) * k, intensity: 2.2 * min(1, k + 0.2))
        slash.scale = SCNVector3(1.0, 0.16, 1)
        slash.eulerAngles.z = Float.random(in: -0.6...0.6)
        slash.runAction(.sequence([.wait(duration: 0.03), .group([.scale(to: 0.01, duration: 0.1), .fadeOut(duration: 0.1)])]))
        spawn(slash, at: p, in: parent, life: 0.25)
    }

    static func muzzleSparks(at p: SIMD3<Float>, dir: SIMD3<Float>, color: UIColor, in parent: SCNNode) {
        let s = SCNParticleSystem()
        s.particleImage = Toon.sparkImage
        s.birthRate = 300
        s.emissionDuration = 0.03
        s.loops = false
        s.particleLifeSpan = 0.14
        s.particleVelocity = 10
        s.particleVelocityVariation = 4
        s.emittingDirection = SCNVector3(dir.x, dir.y, dir.z)
        s.spreadingAngle = 35
        s.particleSize = 0.05
        s.stretchFactor = 0.06
        s.blendMode = .additive
        s.isLightingEnabled = false
        s.propertyControllers = [.color: colorRamp([.white, color], [0, 1]), .opacity: ramp([1, 0])]
        emitter(s, at: p, in: parent, life: 0.4)
    }

    static func muzzle(at p: SIMD3<Float>, color: UIColor, size: CGFloat, in parent: SCNNode) {
        let star = billboard(starburst, color: color.lighter(0.4), size: size, intensity: 3)
        star.runAction(.group([.scale(to: 1.4, duration: 0.12), .fadeOut(duration: 0.12)]))
        spawn(star, at: p, in: parent, life: 0.2)
    }

    /// Energy ball for blasts.
    static func projectile(color: UIColor, radius: Float) -> SCNNode {
        let n = SCNNode()
        let core = SCNNode(geometry: SCNSphere(radius: CGFloat(radius * 0.5)))
        let cm = SCNMaterial()
        cm.diffuse.contents = UIColor.white
        cm.emission.contents = UIColor.white
        cm.emission.intensity = 3
        cm.lightingModel = .constant
        core.geometry?.materials = [cm]
        n.addChildNode(core)
        let corona = billboard(Toon.glowImage, color: color, size: CGFloat(radius * 2.6), intensity: 1.3)
        n.addChildNode(corona)
        let spin = billboard(ring, color: color.lighter(0.3), size: CGFloat(radius * 2.6), intensity: 2)
        spin.runAction(.repeatForever(.sequence([.scale(to: 1.25, duration: 0.08), .scale(to: 0.9, duration: 0.08)])))
        n.addChildNode(spin)
        let trail = SCNParticleSystem()
        trail.particleImage = Toon.glowImage
        trail.birthRate = 160
        trail.particleLifeSpan = 0.22
        trail.particleSize = CGFloat(radius * 2.2)
        trail.emitterShape = SCNSphere(radius: CGFloat(radius * 0.3))
        trail.birthLocation = .volume
        trail.blendMode = .additive
        trail.isLightingEnabled = false
        trail.propertyControllers = [
            .color: colorRamp([.white, color, color.darker(0.3)], [0, 0.3, 1]),
            .size: ramp([1, 0.1]),
            .opacity: ramp([0.9, 0]),
        ]
        n.addParticleSystem(trail)
        return n
    }

    /// Soft-edged cylinder material (fresnel falloff) for beams.
    static func beamMaterial(_ color: UIColor, intensity: CGFloat) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.emission.contents = color
        m.emission.intensity = intensity
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = false
        m.shaderModifiers = [.fragment: """
        float f = abs(dot(normalize(_surface.normal), normalize(_surface.view)));
        _output.color.rgb *= pow(f, 1.4);
        """]
        return m
    }

    /// Layered energy beam pointing along +Y of the returned holder (length `length`).
    static func beam(color: UIColor, radius: Float, length: Float) -> SCNNode {
        let holder = SCNNode()
        let outer = SCNNode(geometry: SCNCylinder(radius: CGFloat(radius * 1.25), height: CGFloat(length)))
        outer.geometry?.materials = [beamMaterial(color, intensity: 2)]
        outer.simdPosition = SIMD3(0, length / 2, 0)
        let mid = SCNNode(geometry: SCNCylinder(radius: CGFloat(radius * 0.75), height: CGFloat(length)))
        mid.geometry?.materials = [beamMaterial(color.lighter(0.5), intensity: 2.5)]
        mid.simdPosition = SIMD3(0, length / 2, 0)
        let core = SCNNode(geometry: SCNCylinder(radius: CGFloat(radius * 0.32), height: CGFloat(length)))
        core.geometry?.materials = [beamMaterial(.white, intensity: 4)]
        core.simdPosition = SIMD3(0, length / 2, 0)
        for n in [outer, mid, core] { holder.addChildNode(n) }
        outer.runAction(.repeatForever(.sequence([.scale(to: 1.1, duration: 0.04), .scale(to: 0.94, duration: 0.04)])))

        // Spiralling energy along the beam
        let swirl = SCNParticleSystem()
        swirl.particleImage = Toon.sparkImage
        swirl.birthRate = 260
        swirl.particleLifeSpan = 0.3
        swirl.emitterShape = SCNCylinder(radius: CGFloat(radius * 1.3), height: CGFloat(length * 0.4))
        swirl.birthLocation = .surface
        swirl.particleVelocity = 14
        swirl.emittingDirection = SCNVector3(0, 1, 0)
        swirl.spreadingAngle = 8
        swirl.particleSize = CGFloat(radius * 0.35)
        swirl.stretchFactor = 0.08
        swirl.blendMode = .additive
        swirl.isLightingEnabled = false
        swirl.propertyControllers = [.color: colorRamp([.white, color], [0, 1]), .opacity: ramp([1, 0])]
        let swirlNode = SCNNode()
        swirlNode.simdPosition = SIMD3(0, length * 0.2, 0)
        swirlNode.addParticleSystem(swirl)
        holder.addChildNode(swirlNode)

        let flare = billboard(starburst, color: color.lighter(0.4), size: CGFloat(radius * 6), intensity: 3)
        flare.runAction(.repeatForever(.sequence([.scale(to: 1.15, duration: 0.05), .scale(to: 0.9, duration: 0.05)])))
        holder.addChildNode(flare)
        return holder
    }

    /// Particles converging into the hand while charging a beam.
    static func chargeIn(color: UIColor, radius: CGFloat) -> SCNNode {
        let n = SCNNode()
        let p = SCNParticleSystem()
        p.particleImage = Toon.sparkImage
        p.birthRate = 140
        p.emitterShape = SCNSphere(radius: radius)
        p.birthLocation = .surface
        p.birthDirection = .surfaceNormal
        p.particleVelocity = -radius * 3.2
        p.particleLifeSpan = 0.3
        p.particleSize = 0.09
        p.stretchFactor = 0.06
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.propertyControllers = [.color: colorRamp([color, .white], [0, 1]), .opacity: ramp([0, 1], [0, 0.4])]
        n.addParticleSystem(p)
        let orb = billboard(Toon.glowImage, color: color.lighter(0.3), size: 0.5, intensity: 3)
        orb.name = "orb"
        n.addChildNode(orb)
        return n
    }

    /// Big explosion: flash, fireball, smoke, ground shockwave, debris. No full-screen whiteout.
    static func explosion(at p: SIMD3<Float>, color: UIColor, in parent: SCNNode) {
        let flash = billboard(starburst, color: color.lighter(0.6), size: 6, intensity: 4)
        flash.runAction(.group([.scale(to: 1.6, duration: 0.18), .fadeOut(duration: 0.18)]))
        spawn(flash, at: p, in: parent, life: 0.3)

        let fire = SCNParticleSystem()
        fire.particleImage = smoke
        fire.birthRate = 1600
        fire.emissionDuration = 0.08
        fire.loops = false
        fire.particleLifeSpan = 0.8
        fire.particleLifeSpanVariation = 0.3
        fire.particleVelocity = 5
        fire.particleVelocityVariation = 3
        fire.spreadingAngle = 180
        fire.particleSize = 1.1
        fire.particleSizeVariation = 0.5
        fire.particleAngleVariation = 180
        fire.particleAngularVelocityVariation = 90
        fire.dampingFactor = 3
        fire.blendMode = .additive
        fire.isLightingEnabled = false
        fire.propertyControllers = [
            .color: colorRamp([.white, UIColor(hex: 0xFFE7A0), color, color.darker(0.6)], [0, 0.15, 0.5, 1]),
            .size: ramp([0.4, 1.6, 2.2], [0, 0.5, 1]),
            .opacity: ramp([1, 0.8, 0], [0, 0.5, 1]),
        ]
        emitter(fire, at: p, in: parent, life: 1.5)

        let smk = SCNParticleSystem()
        smk.particleImage = smoke
        smk.birthRate = 300
        smk.emissionDuration = 0.12
        smk.loops = false
        smk.particleLifeSpan = 1.6
        smk.particleVelocity = 2.5
        smk.particleVelocityVariation = 1.5
        smk.spreadingAngle = 90
        smk.emittingDirection = SCNVector3(0, 1, 0)
        smk.particleSize = 1.4
        smk.particleSizeVariation = 0.6
        smk.particleAngleVariation = 180
        smk.dampingFactor = 1.5
        smk.blendMode = .alpha
        smk.isLightingEnabled = false
        smk.particleColor = UIColor(white: 0.15, alpha: 1)
        smk.propertyControllers = [.opacity: ramp([0, 0.55, 0], [0, 0.2, 1]), .size: ramp([0.6, 2.2])]
        emitter(smk, at: p, in: parent, life: 2.2)

        let shock = SCNNode(geometry: SCNPlane(width: 2, height: 2))
        let sm = SCNMaterial()
        sm.diffuse.contents = ring
        sm.multiply.contents = color.lighter(0.3)
        sm.emission.contents = ring
        sm.emission.intensity = 2.5
        sm.lightingModel = .constant
        sm.blendMode = .add
        sm.writesToDepthBuffer = false
        sm.isDoubleSided = true
        shock.geometry?.materials = [sm]
        shock.simdEulerAngles = SIMD3(-.pi / 2, 0, 0)
        shock.runAction(.group([.scale(to: 7, duration: 0.5), .fadeOut(duration: 0.5)]))
        spawn(shock, at: SIMD3(p.x, 0.06, p.z), in: parent, life: 0.6)

        emitter(sparks(color, count: 80, speed: 16, size: 0.16, life: 0.5), at: p, in: parent)
        dust(at: SIMD3(p.x, 0.1, p.z), scale: 2.2, in: parent)
    }

    /// Ground dust puff (dashes, knockdowns, landings).
    static func dust(at p: SIMD3<Float>, scale: CGFloat = 1, in parent: SCNNode) {
        let d = SCNParticleSystem()
        d.particleImage = smoke
        d.birthRate = 260 * scale
        d.emissionDuration = 0.06
        d.loops = false
        d.particleLifeSpan = 0.7
        d.particleVelocity = 2.2 * scale
        d.particleVelocityVariation = 1
        d.emittingDirection = SCNVector3(0, 1, 0)
        d.spreadingAngle = 85
        d.particleSize = 0.45 * scale
        d.particleAngleVariation = 180
        d.dampingFactor = 3
        d.blendMode = .alpha
        d.isLightingEnabled = false
        d.particleColor = UIColor(white: 0.85, alpha: 1)
        d.propertyControllers = [.opacity: ramp([0.5, 0]), .size: ramp([0.6, 1.6])]
        emitter(d, at: p, in: parent)
    }

    /// Teleport: vertical light streak + ripple ring + sparks.
    static func vanish(at base: SIMD3<Float>, height: Float, color: UIColor, in parent: SCNNode) {
        let plane = SCNPlane(width: 0.5, height: CGFloat(height * 1.4))
        let m = SCNMaterial()
        m.diffuse.contents = streak
        m.multiply.contents = color.lighter(0.4)
        m.emission.contents = streak
        m.emission.intensity = 3
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        let s = SCNNode(geometry: plane)
        let bb = SCNBillboardConstraint()
        bb.freeAxes = .Y
        s.constraints = [bb]
        s.runAction(.group([.scaleX(to: 0.05, duration: 0.22), .fadeOut(duration: 0.22)]))
        spawn(s, at: base + SIMD3(0, height * 0.55, 0), in: parent, life: 0.3)

        let r = billboard(ring, color: color, size: 0.6, intensity: 2.5)
        r.runAction(.group([.scale(to: 3, duration: 0.25), .fadeOut(duration: 0.25)]))
        spawn(r, at: base + SIMD3(0, height * 0.5, 0), in: parent, life: 0.35)
        emitter(sparks(color, count: 14, speed: 4, size: 0.07, life: 0.25), at: base + SIMD3(0, height * 0.5, 0), in: parent)
    }
}

extension SCNNode {
    func scaleX(_ x: Float) { simdScale = SIMD3(x, simdScale.y, simdScale.z) }
}

extension SCNAction {
    static func scaleX(to x: CGFloat, duration: TimeInterval) -> SCNAction {
        SCNAction.customAction(duration: duration) { node, t in
            let k = Float(duration > 0 ? t / CGFloat(duration) : 1)
            node.simdScale = SIMD3(1 + (Float(x) - 1) * k, node.simdScale.y, node.simdScale.z)
        }
    }
}
