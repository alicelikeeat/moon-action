import SceneKit
import UIKit

/// Procedural 3D battle stage: sky dome, moon, terrain, mesas, rocks, lights.
@MainActor
final class Arena {
    struct Theme {
        let skyTop: UInt32, horizon: UInt32, ground: UInt32, rock: UInt32, mesa: UInt32
        let key: UInt32, ambient: UInt32, moon: UInt32
    }

    static let themes: [Theme] = [
        Theme(skyTop: 0x0A0F2E, horizon: 0x5A4A9A, ground: 0x4A4560, rock: 0x3A3550, mesa: 0x2E2A48, key: 0xDCE3FF, ambient: 0x58608F, moon: 0xF4F1DE),
        Theme(skyTop: 0x2A0F2E, horizon: 0xE07A4A, ground: 0x7A5040, rock: 0x5A3A34, mesa: 0x4A2C30, key: 0xFFD0A0, ambient: 0x80506A, moon: 0xFFE2B0),
        Theme(skyTop: 0x05213A, horizon: 0x3FA3B5, ground: 0x4B6A6A, rock: 0x355252, mesa: 0x264248, key: 0xE0FFF8, ambient: 0x4A7A88, moon: 0xE5FBFF),
        Theme(skyTop: 0x16161E, horizon: 0x6E6E8A, ground: 0x55555E, rock: 0x45454E, mesa: 0x36363F, key: 0xF0F0FF, ambient: 0x606075, moon: 0xE8E8FF),
    ]

    let scene = SCNScene()
    let world = SCNNode()
    let camera = SCNNode()
    let theme: Theme

    init(theme index: Int) {
        theme = Arena.themes[abs(index) % Arena.themes.count]
        scene.rootNode.addChildNode(world)
        buildSky()
        buildLights()
        buildGround()
        buildScenery()

        let cam = SCNCamera()
        cam.fieldOfView = 58
        cam.zNear = 0.1
        cam.zFar = 400
        cam.wantsHDR = true
        cam.wantsExposureAdaptation = false
        cam.exposureOffset = 0
        cam.bloomIntensity = 1.1
        cam.bloomThreshold = 0.85
        cam.bloomBlurRadius = 14
        cam.vignettingIntensity = 0.45
        cam.vignettingPower = 0.8
        cam.saturation = 1.08
        cam.contrast = 0.06
        camera.camera = cam
        camera.simdPosition = SIMD3(0, 2.2, -6)
        scene.rootNode.addChildNode(camera)
    }

    private func buildSky() {
        let top = UIColor(hex: theme.skyTop)
        let hor = UIColor(hex: theme.horizon)
        let size = CGSize(width: 1024, height: 512)
        let img = UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            let colors = [top.cgColor, top.blend(hor, 0.45).cgColor, hor.cgColor, hor.darker(0.4).cgColor] as CFArray
            let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.32, 0.5, 0.56])!
            c.drawLinearGradient(g, start: .zero, end: CGPoint(x: 0, y: size.height), options: [.drawsAfterEndLocation])
            for _ in 0..<420 {
                let x = CGFloat.random(in: 0...size.width)
                let y = CGFloat.random(in: 0...(size.height * 0.42))
                let r = CGFloat.random(in: 0.4...1.4)
                c.setFillColor(UIColor(white: 1, alpha: CGFloat.random(in: 0.3...0.95) * (1 - y / (size.height * 0.5))).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * 2))
            }
        }
        scene.background.contents = img
        scene.lightingEnvironment.contents = img
        scene.lightingEnvironment.intensity = 1.3
        scene.fogColor = hor.darker(0.15)
        scene.fogStartDistance = 30
        scene.fogEndDistance = 175
        scene.fogDensityExponent = 1.2

        // Moon with halo
        let moon = SCNNode(geometry: SCNSphere(radius: 9))
        let mm = SCNMaterial()
        mm.diffuse.contents = UIColor(hex: theme.moon)
        mm.emission.contents = UIColor(hex: theme.moon)
        mm.lightingModel = .constant
        moon.geometry?.materials = [mm]
        moon.simdPosition = SIMD3(-50, 62, 95)
        world.addChildNode(moon)
        let halo = Toon.glowSprite(UIColor(hex: theme.moon), size: 70)
        halo.opacity = 0.5
        halo.simdPosition = moon.simdPosition
        world.addChildNode(halo)
    }

    private func buildLights() {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .directional
        key.light?.color = UIColor(hex: theme.key)
        key.light?.intensity = 1050
        key.simdEulerAngles = SIMD3(-0.9, 0.6, 0)
        scene.rootNode.addChildNode(key)

        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.color = UIColor(hex: theme.horizon).lighter(0.3)
        rim.light?.intensity = 380
        rim.simdEulerAngles = SIMD3(-0.4, .pi + 0.5, 0)
        scene.rootNode.addChildNode(rim)

        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.color = UIColor(hex: theme.ambient)
        amb.light?.intensity = 520
        scene.rootNode.addChildNode(amb)
    }

    private func groundTexture() -> UIImage {
        let base = UIColor(hex: theme.ground)
        let size = CGSize(width: 512, height: 512)
        return UIGraphicsImageRenderer(size: size).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(base.cgColor)
            c.fill(CGRect(origin: .zero, size: size))
            for _ in 0..<160 {
                let r = CGFloat.random(in: 12...70)
                let x = CGFloat.random(in: -20...size.width)
                let y = CGFloat.random(in: -20...size.height)
                let shade = chance(0.5) ? base.darker(CGFloat.random(in: 0.05...0.18)) : base.lighter(CGFloat.random(in: 0.04...0.12))
                c.setFillColor(shade.withAlphaComponent(0.55).cgColor)
                c.fillEllipse(in: CGRect(x: x, y: y, width: r * 2, height: r * CGFloat.random(in: 1...2)))
            }
            c.setStrokeColor(base.darker(0.35).withAlphaComponent(0.6).cgColor)
            c.setLineWidth(2)
            for _ in 0..<26 {
                var p = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
                c.move(to: p)
                for _ in 0..<5 {
                    p.x += CGFloat.random(in: -40...40)
                    p.y += CGFloat.random(in: -40...40)
                    c.addLine(to: p)
                }
                c.strokePath()
            }
        }
    }

    private func buildGround() {
        let disc = SCNCylinder(radius: 160, height: 0.2)
        let m = Toon.material(.white, rim: false)
        m.diffuse.contents = groundTexture()
        m.diffuse.wrapS = .repeat
        m.diffuse.wrapT = .repeat
        m.diffuse.contentsTransform = SCNMatrix4MakeScale(40, 40, 1)
        disc.materials = [m]
        let g = SCNNode(geometry: disc)
        g.simdPosition = SIMD3(0, -0.1, 0)
        world.addChildNode(g)

        // Arena ring marking (subtle)
        let ring = SCNNode(geometry: SCNTorus(ringRadius: 13, pipeRadius: 0.05))
        ring.geometry?.materials = [Toon.energy(UIColor(hex: theme.horizon).lighter(0.4), alpha: 0.25)]
        ring.simdPosition = SIMD3(0, 0.02, 0)
        world.addChildNode(ring)
    }

    private func buildScenery() {
        let rockColor = UIColor(hex: theme.rock)
        // Scattered rocks
        for _ in 0..<70 {
            let a = Float.random(in: 0..<(2 * .pi))
            let r = Float.random(in: 15...60)
            let s = CGFloat.random(in: 0.4...2.2)
            let geo: SCNGeometry = chance(0.5)
                ? SCNBox(width: s, height: s * CGFloat.random(in: 0.5...1.2), length: s, chamferRadius: s * 0.2)
                : SCNPyramid(width: s * 1.4, height: s * CGFloat.random(in: 0.8...1.8), length: s * 1.2)
            let n = Toon.part(geo, rockColor.lighter(CGFloat.random(in: 0...0.15)), outline: 0.03, rim: false)
            n.simdPosition = SIMD3(cos(a) * r, 0, sin(a) * r)
            n.simdEulerAngles = SIMD3(Float.random(in: -0.2...0.2), Float.random(in: 0...6), Float.random(in: -0.2...0.2))
            world.addChildNode(n)
        }
        // Mesas / spires on the horizon
        for i in 0..<26 {
            let a = Float(i) / 26 * 2 * .pi + Float.random(in: -0.1...0.1)
            let r = Float.random(in: 70...120)
            let h = CGFloat.random(in: 8...30)
            let w = CGFloat.random(in: 6...16)
            let geo: SCNGeometry = chance(0.6)
                ? SCNCylinder(radius: w, height: h)
                : SCNCone(topRadius: w * 0.35, bottomRadius: w, height: h)
            let n = Toon.part(geo, UIColor(hex: theme.mesa), outline: 0.2, rim: false)
            n.simdPosition = SIMD3(cos(a) * r, Float(h) / 2 - 0.5, sin(a) * r)
            world.addChildNode(n)
            if chance(0.5) {
                let cap = Toon.part(SCNCylinder(radius: w * 1.08, height: 1.2), UIColor(hex: theme.mesa).lighter(0.12), outline: 0.1, rim: false)
                cap.simdPosition = SIMD3(cos(a) * r, Float(h) - 0.6, sin(a) * r)
                world.addChildNode(cap)
            }
        }
        // Floating embers
        let embers = SCNParticleSystem()
        embers.particleImage = Toon.glowImage
        embers.birthRate = 25
        embers.particleLifeSpan = 6
        embers.emitterShape = SCNBox(width: 40, height: 1, length: 40, chamferRadius: 0)
        embers.birthLocation = .volume
        embers.particleVelocity = 0.5
        embers.emittingDirection = SCNVector3(0, 1, 0)
        embers.spreadingAngle = 40
        embers.particleSize = 0.08
        embers.particleColor = UIColor(hex: theme.horizon).lighter(0.5)
        embers.blendMode = .additive
        embers.isLightingEnabled = false
        let emberNode = SCNNode()
        emberNode.simdPosition = SIMD3(0, 0.5, 0)
        emberNode.addParticleSystem(embers)
        world.addChildNode(emberNode)
    }
}
