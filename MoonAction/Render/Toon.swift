import SceneKit
import UIKit

/// Cel-shading materials, outlines and particle factories (all procedural).
@MainActor
enum Toon {
    /// Two-band cel shading + a soft rim, applied via a SceneKit lighting-model shader modifier.
    static let celLighting = """
    float ndl = dot(_surface.normal, _light.direction);
    float band = 0.42 + 0.38 * smoothstep(0.02, 0.08, ndl) + 0.2 * smoothstep(0.6, 0.66, ndl);
    _lightingContribution.diffuse += _light.intensity.rgb * band;
    """

    static let rimFragment = """
    float rim = 1.0 - max(0.0, dot(normalize(_surface.normal), normalize(_surface.view)));
    _output.color.rgb += pow(rim, 4.0) * 0.28;
    """

    static func material(_ color: UIColor, rim: Bool = true, emission: UIColor? = nil) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color
        m.lightingModel = .lambert
        var mods: [SCNShaderModifierEntryPoint: String] = [.lightingModel: celLighting]
        if rim { mods[.fragment] = rimFragment }
        m.shaderModifiers = mods
        if let emission { m.emission.contents = emission }
        return m
    }

    static let outline: SCNMaterial = {
        let m = SCNMaterial()
        m.diffuse.contents = UIColor(white: 0.04, alpha: 1)
        m.lightingModel = .constant
        m.cullMode = .front
        return m
    }()

    /// Unlit glowing material for energy effects.
    static func energy(_ color: UIColor, alpha: CGFloat = 1) -> SCNMaterial {
        let m = SCNMaterial()
        m.diffuse.contents = color.withAlphaComponent(alpha)
        m.emission.contents = color
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        return m
    }

    /// Geometry node with cel material and an inverted-hull outline.
    static func part(_ geo: SCNGeometry, _ color: UIColor, outline thickness: Float = 0.012, rim: Bool = true) -> SCNNode {
        geo.materials = [material(color, rim: rim)]
        let n = SCNNode(geometry: geo)
        if thickness > 0, let hullGeo = geo.copy() as? SCNGeometry {
            hullGeo.materials = [outline]
            let hull = SCNNode(geometry: hullGeo)
            let (minB, maxB) = geo.boundingBox
            let sx = Float(maxB.x - minB.x), sy = Float(maxB.y - minB.y), sz = Float(maxB.z - minB.z)
            func s(_ d: Float) -> Float { d > 0.0001 ? 1 + 2 * thickness / d : 1 }
            hull.simdScale = SIMD3(s(sx), s(sy), s(sz))
            n.addChildNode(hull)
        }
        return n
    }

    // MARK: Textures

    static let glowImage: UIImage = {
        let size = CGSize(width: 64, height: 64)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.cgColor, UIColor.white.withAlphaComponent(0.45).cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.3, 1])!
            ctx.cgContext.drawRadialGradient(g, startCenter: CGPoint(x: 32, y: 32), startRadius: 0,
                                             endCenter: CGPoint(x: 32, y: 32), endRadius: 32, options: [])
        }
    }()

    static let sparkImage: UIImage = {
        let size = CGSize(width: 64, height: 16)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [UIColor.white.withAlphaComponent(0).cgColor, UIColor.white.cgColor,
                          UIColor.white.withAlphaComponent(0).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 64, y: 0), options: [])
        }
    }()

    static func gradientImage(top: UIColor, bottom: UIColor, height: CGFloat = 256) -> UIImage {
        let size = CGSize(width: 4, height: height)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let colors = [top.cgColor, bottom.cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1])!
            ctx.cgContext.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [])
        }
    }

    /// Billboarded glow sprite.
    static func glowSprite(_ color: UIColor, size: CGFloat) -> SCNNode {
        let plane = SCNPlane(width: size, height: size)
        let m = SCNMaterial()
        m.diffuse.contents = glowImage
        m.multiply.contents = color
        m.emission.contents = color
        m.lightingModel = .constant
        m.blendMode = .add
        m.writesToDepthBuffer = false
        m.isDoubleSided = true
        plane.materials = [m]
        let n = SCNNode(geometry: plane)
        n.constraints = [SCNBillboardConstraint()]
        return n
    }

    // MARK: Particles

    static func aura(_ color: UIColor, height: CGFloat) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = glowImage
        p.birthRate = 0
        p.emitterShape = SCNCylinder(radius: 0.42, height: height)
        p.birthLocation = .volume
        p.particleLifeSpan = 0.55
        p.particleLifeSpanVariation = 0.2
        p.particleVelocity = 1.6
        p.particleVelocityVariation = 0.6
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 12
        p.particleSize = 0.2
        p.particleSizeVariation = 0.1
        p.particleColor = color
        p.particleColorVariation = SCNVector4(0.02, 0.05, 0.1, 0)
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.acceleration = SCNVector3(0, 1.5, 0)
        let fade = CAKeyframeAnimation()
        fade.values = [0, 0.85, 0]
        fade.keyTimes = [0, 0.2, 1]
        p.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        return p
    }

    static func burst(_ color: UIColor, count: CGFloat, speed: CGFloat, size: CGFloat, life: CGFloat = 0.35,
                      streaks: Bool = true) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = streaks ? sparkImage : glowImage
        p.birthRate = count / 0.05
        p.emissionDuration = 0.05
        p.loops = false
        p.particleLifeSpan = life
        p.particleLifeSpanVariation = life * 0.3
        p.particleVelocity = speed
        p.particleVelocityVariation = speed * 0.5
        p.spreadingAngle = 180
        p.particleSize = size
        p.particleSizeVariation = size * 0.4
        p.particleColor = color
        p.blendMode = .additive
        p.isLightingEnabled = false
        if streaks {
            p.stretchFactor = 0.06
        }
        let fade = CAKeyframeAnimation()
        fade.values = [1, 1, 0]
        fade.keyTimes = [0, 0.4, 1]
        p.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        return p
    }

    static func trail(_ color: UIColor, size: CGFloat) -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = glowImage
        p.birthRate = 140
        p.particleLifeSpan = 0.25
        p.particleVelocity = 0
        p.particleSize = size
        p.particleColor = color
        p.blendMode = .additive
        p.isLightingEnabled = false
        p.emitterShape = SCNSphere(radius: size * 0.2)
        p.birthLocation = .volume
        let shrink = CAKeyframeAnimation()
        shrink.values = [1, 0]
        p.propertyControllers = [.size: SCNParticlePropertyController(animation: shrink)]
        return p
    }

    static func dust() -> SCNParticleSystem {
        let p = SCNParticleSystem()
        p.particleImage = glowImage
        p.birthRate = 400
        p.emissionDuration = 0.08
        p.loops = false
        p.particleLifeSpan = 0.6
        p.particleVelocity = 2.5
        p.particleVelocityVariation = 1.5
        p.emittingDirection = SCNVector3(0, 1, 0)
        p.spreadingAngle = 80
        p.particleSize = 0.5
        p.particleColor = UIColor(white: 0.85, alpha: 0.5)
        p.isLightingEnabled = false
        p.acceleration = SCNVector3(0, -2, 0)
        let fade = CAKeyframeAnimation()
        fade.values = [0.6, 0]
        p.propertyControllers = [.opacity: SCNParticlePropertyController(animation: fade)]
        return p
    }
}

extension SCNNode {
    /// Plays a one-shot particle system at a world position.
    @MainActor
    static func emit(_ ps: SCNParticleSystem, at p: SIMD3<Float>, in parent: SCNNode, life: TimeInterval = 1.2) {
        let n = SCNNode()
        n.simdPosition = p
        n.addParticleSystem(ps)
        parent.addChildNode(n)
        n.runAction(.sequence([.wait(duration: life), .removeFromParentNode()]))
    }
}
