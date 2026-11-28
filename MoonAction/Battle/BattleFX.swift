import UIKit
import SceneKit
import simd

extension BattleScreen {
    /// 1 far from the camera, down to ~0.35 for effects right in front of the over-shoulder camera.
    func camScale(_ p: SIMD3<Float>) -> CGFloat {
        guard let cam = pointOfView else { return 1 }
        return CGFloat(max(0.35, min(1, simd_length(p - cam.simdWorldPosition) / 9)))
    }

    func spark(at p: SIMD3<Float>, color: UIColor, big: Bool, dir: SIMD3<Float>? = nil) {
        VFX.impact(at: p, color: color, heavy: big, in: fxRoot, dir: dir, scale: camScale(p))
    }

    func sparkLegacy(at p: SIMD3<Float>, color: UIColor, big: Bool) {
        SCNNode.emit(Toon.burst(.white, count: big ? 26 : 12, speed: big ? 9 : 6, size: big ? 0.5 : 0.32, life: 0.22), at: p, in: fxRoot, life: 0.6)
        SCNNode.emit(Toon.burst(color, count: big ? 30 : 14, speed: big ? 5 : 3, size: big ? 0.6 : 0.4, life: 0.3, streaks: false),
                     at: p, in: fxRoot, life: 0.6)
        let g = Toon.glowSprite(color, size: big ? 2.8 : 1.5)
        g.simdPosition = p
        fxRoot.addChildNode(g)
        g.runAction(.sequence([.group([.scale(to: 1.8, duration: 0.15), .fadeOut(duration: 0.15)]), .removeFromParentNode()]))
        if big {
            // Impact ring
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 0.5, pipeRadius: 0.04))
            ring.geometry?.materials = [Toon.energy(.white)]
            ring.simdPosition = p
            ring.constraints = [SCNBillboardConstraint()]
            ring.simdEulerAngles = SIMD3(.pi / 2, 0, 0)
            fxRoot.addChildNode(ring)
            ring.runAction(.sequence([.group([.scale(to: 3.5, duration: 0.25), .fadeOut(duration: 0.25)]), .removeFromParentNode()]))
        }
    }

    func burst(at p: SIMD3<Float>, color: UIColor, scale: Float) {
        VFX.impact(at: p, color: color, heavy: false, in: fxRoot, scale: camScale(p))
    }

    func burstLegacy(at p: SIMD3<Float>, color: UIColor, scale: Float) {
        let g = Toon.glowSprite(color, size: CGFloat(scale))
        g.simdPosition = p
        fxRoot.addChildNode(g)
        g.runAction(.sequence([.group([.scale(to: 2, duration: 0.2), .fadeOut(duration: 0.2)]), .removeFromParentNode()]))
        SCNNode.emit(Toon.burst(color, count: 16, speed: 4, size: 0.25, life: 0.25), at: p, in: fxRoot, life: 0.5)
    }

    func explosion(at p: SIMD3<Float>, color: UIColor) {
        Sound.play(.explode)
        Haptics.hit(true)
        shake = 0.4
        fovKick = 10
        VFX.explosion(at: p, color: color, in: fxRoot)
        hud.speedLines(0.3)
    }

    func explosionLegacy(at p: SIMD3<Float>, color: UIColor) {
        let ball = SCNNode(geometry: SCNSphere(radius: 1))
        ball.geometry?.materials = [Toon.energy(color.lighter(0.3), alpha: 0.7)]
        ball.simdPosition = p
        fxRoot.addChildNode(ball)
        ball.runAction(.sequence([.group([.scale(to: 6, duration: 0.6), .fadeOut(duration: 0.6)]), .removeFromParentNode()]))
        let core = SCNNode(geometry: SCNSphere(radius: 1))
        core.geometry?.materials = [Toon.energy(.white)]
        core.simdPosition = p
        fxRoot.addChildNode(core)
        core.runAction(.sequence([.group([.scale(to: 3.5, duration: 0.35), .fadeOut(duration: 0.35)]), .removeFromParentNode()]))
        for i in 0..<2 {
            let ring = SCNNode(geometry: SCNTorus(ringRadius: 1, pipeRadius: 0.08))
            ring.geometry?.materials = [Toon.energy(i == 0 ? .white : color)]
            ring.simdPosition = SIMD3(p.x, 0.15, p.z)
            fxRoot.addChildNode(ring)
            ring.runAction(.sequence([.wait(duration: Double(i) * 0.1), .group([.scale(to: 9, duration: 0.6), .fadeOut(duration: 0.6)]),
                                      .removeFromParentNode()]))
        }
        SCNNode.emit(Toon.burst(color, count: 140, speed: 12, size: 0.6, life: 0.6), at: p, in: fxRoot)
        SCNNode.emit(Toon.dust(), at: SIMD3(p.x, 0.1, p.z), in: fxRoot)
        hud.screenFlash(color)
    }

    func showEvade(_ c: Combatant) {
        popup(L("battle.evade"), at: c.chest + SIMD3(0, 0.9, 0), color: Theme.energy, size: 18)
    }

    /// Floating text anchored to a 3D point.
    func popup(_ text: String, at p: SIMD3<Float>, color: UIColor, size: CGFloat) {
        guard let v = host?.scnView else { return }
        let sp = v.projectPoint(SCNVector3(p.x, p.y, p.z))
        guard sp.z > 0 && sp.z < 1 else { return }
        let l = UILabel()
        l.text = text
        l.font = Glass.mono(size, .bold)
        l.textColor = color
        l.layer.shadowColor = UIColor.black.cgColor
        l.layer.shadowOpacity = 0.9
        l.layer.shadowRadius = 2.5
        l.layer.shadowOffset = CGSize(width: 0, height: 1.5)
        l.sizeToFit()
        l.center = CGPoint(x: CGFloat(sp.x), y: CGFloat(sp.y))
        l.isUserInteractionEnabled = false
        hud.fxLayer.addSubview(l)
        l.transform = CGAffineTransform(scaleX: 1.5, y: 1.5)
        UIView.animate(withDuration: 0.12, animations: { l.transform = .identity }) { _ in
            UIView.animate(withDuration: 0.55, delay: 0.15, options: [.curveEaseIn], animations: {
                l.center.y -= 40
                l.alpha = 0
            }, completion: { _ in l.removeFromSuperview() })
        }
    }
}
