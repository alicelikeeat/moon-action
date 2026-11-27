import SceneKit
import UIKit
import Metal

/// Renders fighter busts / full bodies offscreen into UIImages (for HUD, tiles, cut-ins).
@MainActor
enum Portraits {
    private static var cache: [String: UIImage] = [:]
    private static let renderer: SCNRenderer? = {
        guard let device = MTLCreateSystemDefaultDevice() else { return nil }
        return SCNRenderer(device: device, options: nil)
    }()

    enum Framing { case bust, body }

    static func invalidate(_ id: String) {
        cache = cache.filter { !$0.key.hasPrefix(id + "-") }
    }

    static func image(_ def: FighterDef, _ framing: Framing, size: CGSize, background: UIColor? = nil) -> UIImage? {
        let key = "\(def.id)-\(framing)-\(Int(size.width))x\(Int(size.height))-\(background == nil)"
        if let c = cache[key] { return c }
        guard let renderer else { return nil }
        let scene = SCNScene()
        scene.background.contents = background ?? UIColor.clear
        let model = FighterModel(def: def)
        model.body.removeAllActions()
        model.setAura(0)
        model.syncPose()
        scene.rootNode.addChildNode(model.root)
        scene.lightingEnvironment.contents = Toon.gradientImage(top: UIColor(white: 0.95, alpha: 1), bottom: UIColor(white: 0.35, alpha: 1))
        scene.lightingEnvironment.intensity = 1.2
        let h = def.look.height
        let cam = SCNNode()
        cam.camera = SCNCamera()
        cam.camera?.zNear = 0.05
        switch framing {
        case .bust:
            cam.camera?.fieldOfView = 26
            cam.simdPosition = SIMD3(0.32, 2.05 * h, 1.35)
            cam.simdLook(at: SIMD3(0, 1.97 * h, 0), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
        case .body:
            cam.camera?.fieldOfView = 34
            cam.simdPosition = SIMD3(1.3, 1.5 * h, 4.2)
            cam.simdLook(at: SIMD3(0, 1.22 * h, 0), up: SIMD3<Float>(0, 1, 0), localFront: SIMD3<Float>(0, 0, -1))
        }
        scene.rootNode.addChildNode(cam)
        let key1 = SCNNode()
        key1.light = SCNLight()
        key1.light?.type = .directional
        key1.light?.intensity = 1100
        key1.simdEulerAngles = SIMD3(-0.5, 0.5, 0)
        scene.rootNode.addChildNode(key1)
        let rim = SCNNode()
        rim.light = SCNLight()
        rim.light?.type = .directional
        rim.light?.intensity = 500
        rim.light?.color = def.look.aura
        rim.simdEulerAngles = SIMD3(-0.3, .pi - 0.6, 0)
        scene.rootNode.addChildNode(rim)
        let amb = SCNNode()
        amb.light = SCNLight()
        amb.light?.type = .ambient
        amb.light?.intensity = 550
        scene.rootNode.addChildNode(amb)

        renderer.scene = scene
        renderer.pointOfView = cam
        let img = renderer.snapshot(atTime: 0, with: CGSize(width: size.width * 2, height: size.height * 2),
                                    antialiasingMode: .multisampling4X)
        cache[key] = img
        return img
    }
}
