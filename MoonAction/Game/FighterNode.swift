import SpriteKit

/// A fighter built entirely from vector shapes (original procedural art).
/// Rig space: facing right, origin at the feet.
@MainActor
final class FighterNode: SKNode {
    let def: FighterDef
    let rig = SKNode()
    let body = SKNode()
    let armF = SKNode()
    let armB = SKNode()
    let legF = SKNode()
    let legB = SKNode()
    let headNode = SKNode()
    let aura = SKEmitterNode()
    let chargeGlow = SKSpriteNode(texture: Tex.glow)
    let shadow = SKShapeNode(ellipseOf: CGSize(width: 96, height: 20))
    private(set) var facing: CGFloat = 1
    private var charging = false

    static let hoverY: CGFloat = 14

    init(def: FighterDef) {
        self.def = def
        super.init()
        setScale(def.bodyScale)

        shadow.fillColor = UIColor(white: 0, alpha: 0.35)
        shadow.strokeColor = .clear
        shadow.zPosition = -3
        addChild(shadow)

        setupAura()
        addChild(aura)

        chargeGlow.color = def.aura
        chargeGlow.colorBlendFactor = 1
        chargeGlow.blendMode = .add
        chargeGlow.position = CGPoint(x: 0, y: 85)
        chargeGlow.size = CGSize(width: 260, height: 300)
        chargeGlow.alpha = 0
        chargeGlow.zPosition = -2.5
        addChild(chargeGlow)

        addChild(rig)
        rig.addChild(body)
        body.position = CGPoint(x: 0, y: FighterNode.hoverY)
        FighterNode.buildBody(def: def, into: body, armF: armF, armB: armB, legF: legF, legB: legB, head: headNode)
        stance(animated: false)
        startIdle()
    }

    required init?(coder aDecoder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: Construction

    private static func part(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, r: CGFloat = 6) -> SKShapeNode {
        let n = SKShapeNode(rect: CGRect(x: x, y: y, width: w, height: h), cornerRadius: r)
        n.fillColor = color
        n.strokeColor = color.darker(0.5)
        n.lineWidth = 2
        return n
    }

    private static func buildArm(_ arm: SKNode, def: FighterDef, sleeve: UIColor, skin: UIColor) {
        arm.addChild(part(-6, -48, 12, 26, skin, r: 5))
        arm.addChild(part(-7.5, -27, 15, 30, sleeve, r: 6))
        arm.addChild(part(-7, -44, 14, 6, def.secondary, r: 2))
        let fist = SKShapeNode(circleOfRadius: 9.5)
        fist.position = CGPoint(x: 0, y: -51)
        fist.fillColor = skin
        fist.strokeColor = skin.darker(0.5)
        fist.lineWidth = 2
        arm.addChild(fist)
    }

    private static func buildLeg(_ leg: SKNode, def: FighterDef, pants: UIColor) {
        leg.addChild(part(-9.5, -60, 19, 64, pants, r: 7))
        leg.addChild(part(-10, -66, 25, 15, def.secondary.darker(0.55), r: 6))
    }

    static func buildBody(def: FighterDef, into body: SKNode, armF: SKNode, armB: SKNode, legF: SKNode, legB: SKNode, head: SKNode) {
        let pants = def.secondary
        legB.position = CGPoint(x: -7, y: 62)
        legB.zPosition = 0
        buildLeg(legB, def: def, pants: pants.darker(0.25))
        body.addChild(legB)

        legF.position = CGPoint(x: 8, y: 62)
        legF.zPosition = 1
        buildLeg(legF, def: def, pants: pants)
        body.addChild(legF)

        armB.position = CGPoint(x: -6, y: 113)
        armB.zPosition = -1
        buildArm(armB, def: def, sleeve: def.primary.darker(0.25), skin: def.skin.darker(0.2))
        body.addChild(armB)

        let neck = part(-6, 110, 12, 16, def.skin.darker(0.1), r: 3)
        neck.zPosition = 1.8
        body.addChild(neck)

        let torso = part(-23, 57, 46, 64, def.primary, r: 13)
        torso.zPosition = 2
        body.addChild(torso)

        let collar = SKShapeNode(path: {
            let p = CGMutablePath()
            p.move(to: CGPoint(x: -14, y: 121))
            p.addLine(to: CGPoint(x: 6, y: 100))
            p.addLine(to: CGPoint(x: 20, y: 121))
            return p
        }())
        collar.strokeColor = def.secondary
        collar.lineWidth = 5
        collar.zPosition = 2.1
        body.addChild(collar)

        let belt = part(-23, 57, 46, 10, def.secondary.darker(0.35), r: 4)
        belt.zPosition = 2.2
        body.addChild(belt)

        // Original crest: a small crescent.
        let crest = SKShapeNode(path: crescentPath(radius: 7))
        crest.fillColor = def.aura
        crest.strokeColor = def.aura.darker(0.4)
        crest.lineWidth = 1.5
        crest.position = CGPoint(x: -8, y: 92)
        crest.zPosition = 2.3
        body.addChild(crest)

        head.position = CGPoint(x: 2, y: 142)
        head.zPosition = 3
        buildHead(def: def, into: head)
        body.addChild(head)

        armF.position = CGPoint(x: 7, y: 113)
        armF.zPosition = 5
        buildArm(armF, def: def, sleeve: def.primary, skin: def.skin)
        body.addChild(armF)
    }

    static func buildHead(def: FighterDef, into head: SKNode) {
        let longBack = def.hairStyle == 1 || def.hairStyle == 3
        if longBack {
            let back = SKShapeNode(path: hairBackPath(def.hairStyle))
            back.fillColor = def.hair.darker(0.15)
            back.strokeColor = def.hair.darker(0.55)
            back.lineWidth = 2
            back.zPosition = -1
            head.addChild(back)
        }
        let face = SKShapeNode(circleOfRadius: 20)
        face.fillColor = def.skin
        face.strokeColor = def.skin.darker(0.5)
        face.lineWidth = 2
        head.addChild(face)

        let ear = SKShapeNode(ellipseOf: CGSize(width: 7, height: 10))
        ear.position = CGPoint(x: -4, y: -2)
        ear.fillColor = def.skin.darker(0.1)
        ear.strokeColor = def.skin.darker(0.5)
        ear.lineWidth = 1.5
        head.addChild(ear)

        for (x, w) in [(CGFloat(5), CGFloat(7)), (CGFloat(14), CGFloat(5.5))] {
            let eye = SKShapeNode(rect: CGRect(x: x, y: -3, width: w, height: 8), cornerRadius: 2)
            eye.fillColor = .white
            eye.strokeColor = UIColor(white: 0.1, alpha: 1)
            eye.lineWidth = 1.2
            head.addChild(eye)
            let pupil = SKShapeNode(rect: CGRect(x: x + w - 3.5, y: -2, width: 3, height: 6), cornerRadius: 1)
            pupil.fillColor = def.aura.darker(0.45)
            pupil.strokeColor = .clear
            head.addChild(pupil)
            let brow = SKShapeNode(rect: CGRect(x: x - 1, y: 6.5, width: w + 2, height: 2.5), cornerRadius: 1)
            brow.fillColor = def.hair.darker(0.35)
            brow.strokeColor = .clear
            head.addChild(brow)
        }
        let mouth = SKShapeNode(rect: CGRect(x: 10, y: -12, width: 7, height: 2), cornerRadius: 1)
        mouth.fillColor = def.skin.darker(0.5)
        mouth.strokeColor = .clear
        head.addChild(mouth)

        let hair = SKShapeNode(path: hairPath(def.hairStyle))
        hair.fillColor = def.hair
        hair.strokeColor = def.hair.darker(0.55)
        hair.lineWidth = 2
        hair.zPosition = 1
        head.addChild(hair)
    }

    static func crescentPath(radius r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.addArc(center: .zero, radius: r, startAngle: .pi * 0.3, endAngle: .pi * 1.7, clockwise: false)
        p.addArc(center: CGPoint(x: r * 0.45, y: 0), radius: r * 0.72, startAngle: .pi * 1.55, endAngle: .pi * 0.45, clockwise: true)
        p.closeSubpath()
        return p
    }

    private static func poly(_ pts: [(CGFloat, CGFloat)]) -> CGPath {
        let p = CGMutablePath()
        p.addLines(between: pts.map { CGPoint(x: $0.0, y: $0.1) })
        p.closeSubpath()
        return p
    }

    static func hairPath(_ style: Int) -> CGPath {
        switch style {
        case 1: // long, smooth with side fringe
            return poly([(21, 4), (23, 15), (12, 23), (-4, 25), (-17, 19), (-23, 6), (-21, -6), (-12, 2), (-4, 10), (8, 12), (14, 6)])
        case 2: // flat top
            return poly([(21, 6), (21, 24), (15, 31), (-14, 31), (-22, 23), (-23, 2), (-16, -2), (-11, 11), (10, 12)])
        case 3: // ponytail
            return poly([(21, 5), (19, 18), (6, 25), (-10, 23), (-20, 14), (-22, 0), (-14, 6), (0, 12), (10, 11)])
        case 4: // swept back blades
            return poly([(22, 4), (15, 15), (27, 19), (5, 27), (-12, 27), (-42, 22), (-26, 14), (-46, 6), (-28, 2), (-38, -10),
                         (-20, -6), (-12, 8), (6, 12)])
        case 5: // flame crest
            return poly([(20, 6), (27, 22), (15, 19), (15, 41), (3, 27), (-3, 49), (-12, 27), (-25, 41), (-22, 18), (-33, 20),
                         (-23, 4), (-10, 10), (4, 12)])
        default: // swept spikes
            return poly([(20, 6), (25, 16), (12, 20), (16, 31), (2, 26), (0, 39), (-10, 27), (-23, 33), (-21, 18), (-35, 16),
                         (-24, 6), (-32, -6), (-20, -4), (-22, -14), (-14, -6), (-6, 10), (8, 10)])
        }
    }

    static func hairBackPath(_ style: Int) -> CGPath {
        if style == 3 {
            return poly([(-14, 16), (-30, 20), (-46, 10), (-40, -6), (-50, -22), (-32, -12), (-18, -2)])
        }
        return poly([(-6, 20), (-22, 14), (-28, -18), (-32, -50), (-18, -40), (-8, -22), (0, -10)])
    }

    /// Head-and-hair bust for HUD portraits.
    static func portrait(_ def: FighterDef) -> SKNode {
        let n = SKNode()
        buildHead(def: def, into: n)
        return n
    }

    private func setupAura() {
        aura.particleTexture = Tex.glow
        aura.particleBirthRate = 0
        aura.particleLifetime = 0.55
        aura.particleLifetimeRange = 0.2
        aura.particlePositionRange = CGVector(dx: 80, dy: 60)
        aura.position = CGPoint(x: 0, y: 70)
        aura.emissionAngle = .pi / 2
        aura.emissionAngleRange = 0.5
        aura.particleSpeed = 170
        aura.particleSpeedRange = 60
        aura.particleAlpha = 0.6
        aura.particleAlphaSpeed = -1.1
        aura.particleScale = 0.9
        aura.particleScaleRange = 0.4
        aura.particleScaleSpeed = -0.9
        aura.particleColor = def.aura
        aura.particleColorBlendFactor = 1
        aura.particleBlendMode = .add
        aura.zPosition = -2
    }

    // MARK: Facing / helpers

    func setFacing(_ f: CGFloat) {
        guard f != facing else { return }
        facing = f
        rig.xScale = f
    }

    /// Approximate position of the leading fist in parent space.
    var handPoint: CGPoint {
        CGPoint(x: position.x + facing * 58 * xScale, y: position.y + 118 * yScale)
    }

    var chestPoint: CGPoint {
        CGPoint(x: position.x, y: position.y + 100 * yScale)
    }

    /// Attach an effect (beam etc.) that should face the same way as the fighter.
    func attachFront(_ n: SKNode, at p: CGPoint) {
        n.position = p
        rig.addChild(n)
    }

    func removeAttachments() {
        rig.children.filter { $0.name == "fx" }.forEach { $0.removeFromParent() }
    }

    // MARK: Poses

    private func restAngle(_ limb: SKNode) -> CGFloat {
        if limb === armF { return 1.1 }
        if limb === armB { return 0.75 }
        if limb === legF { return 0.2 }
        return -0.2
    }

    func stance(animated: Bool = true) {
        for limb in [armF, armB, legF, legB] {
            limb.removeAction(forKey: "pose")
            if animated {
                limb.run(.rotate(toAngle: restAngle(limb), duration: 0.12, shortestUnitArc: true), withKey: "pose")
            } else {
                limb.zRotation = restAngle(limb)
            }
        }
        body.removeAction(forKey: "lean")
        if animated {
            body.run(.rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true), withKey: "lean")
        } else {
            body.zRotation = 0
        }
    }

    func startIdle() {
        body.removeAction(forKey: "idle")
        let up = SKAction.moveTo(y: FighterNode.hoverY + 6, duration: 0.5)
        up.timingMode = .easeInEaseOut
        let down = SKAction.moveTo(y: FighterNode.hoverY, duration: 0.5)
        down.timingMode = .easeInEaseOut
        body.run(.repeatForever(.sequence([up, down])), withKey: "idle")
    }

    func strikePose(_ i: Int) {
        let kick = i % 3 == 2
        let limb: SKNode = kick ? legF : (i % 2 == 0 ? armF : armB)
        let ext: CGFloat = kick ? 1.5 : 1.65
        limb.removeAction(forKey: "pose")
        limb.run(.sequence([
            .rotate(toAngle: ext, duration: 0.035, shortestUnitArc: true),
            .wait(forDuration: 0.07),
            .rotate(toAngle: restAngle(limb), duration: 0.09, shortestUnitArc: true),
        ]), withKey: "pose")
        body.removeAction(forKey: "lean")
        body.run(.sequence([
            .rotate(toAngle: kick ? 0.25 : -0.2, duration: 0.035, shortestUnitArc: true),
            .wait(forDuration: 0.07),
            .rotate(toAngle: -0.1, duration: 0.09, shortestUnitArc: true),
        ]), withKey: "lean")
    }

    func dashPose() {
        body.removeAction(forKey: "lean")
        body.run(.rotate(toAngle: -0.42, duration: 0.06, shortestUnitArc: true), withKey: "lean")
        armB.removeAction(forKey: "pose")
        armB.run(.rotate(toAngle: -0.6, duration: 0.06, shortestUnitArc: true), withKey: "pose")
        legB.removeAction(forKey: "pose")
        legB.run(.rotate(toAngle: -0.7, duration: 0.06, shortestUnitArc: true), withKey: "pose")
    }

    func blastPose(hold: TimeInterval) {
        armF.removeAction(forKey: "pose")
        armF.run(.sequence([
            .rotate(toAngle: 1.62, duration: 0.06, shortestUnitArc: true),
            .wait(forDuration: hold),
            .rotate(toAngle: restAngle(armF), duration: 0.12, shortestUnitArc: true),
        ]), withKey: "pose")
        armB.removeAction(forKey: "pose")
        armB.run(.sequence([
            .rotate(toAngle: 1.45, duration: 0.06, shortestUnitArc: true),
            .wait(forDuration: hold),
            .rotate(toAngle: restAngle(armB), duration: 0.12, shortestUnitArc: true),
        ]), withKey: "pose")
        body.removeAction(forKey: "lean")
        body.run(.sequence([
            .rotate(toAngle: 0.12, duration: 0.06, shortestUnitArc: true),
            .wait(forDuration: hold),
            .rotate(toAngle: 0, duration: 0.12, shortestUnitArc: true),
        ]), withKey: "lean")
    }

    func powerUpPose(_ t: TimeInterval) {
        armF.removeAction(forKey: "pose")
        armB.removeAction(forKey: "pose")
        armF.run(.rotate(toAngle: 0.35, duration: 0.1, shortestUnitArc: true), withKey: "pose")
        armB.run(.rotate(toAngle: -0.35, duration: 0.1, shortestUnitArc: true), withKey: "pose")
        body.removeAction(forKey: "lean")
        body.run(.rotate(toAngle: 0.08, duration: 0.1, shortestUnitArc: true), withKey: "lean")
        burstAura(t)
    }

    func burstAura(_ t: TimeInterval) {
        aura.removeAction(forKey: "burst")
        aura.particleBirthRate = 260
        aura.run(.sequence([.wait(forDuration: t), .run { [weak self] in
            guard let self else { return }
            self.aura.particleBirthRate = self.charging ? 160 : 0
        }]), withKey: "burst")
    }

    func setCharging(_ on: Bool) {
        guard on != charging else { return }
        charging = on
        aura.particleBirthRate = on ? 160 : 0
        chargeGlow.removeAllActions()
        if on {
            chargeGlow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.55, duration: 0.25), .fadeAlpha(to: 0.3, duration: 0.25)])))
            armF.removeAction(forKey: "pose")
            armB.removeAction(forKey: "pose")
            armF.run(.rotate(toAngle: 0.3, duration: 0.15, shortestUnitArc: true), withKey: "pose")
            armB.run(.rotate(toAngle: -0.3, duration: 0.15, shortestUnitArc: true), withKey: "pose")
        } else {
            chargeGlow.run(.fadeOut(withDuration: 0.15))
            stance()
        }
    }

    func hurt(heavy: Bool) {
        body.removeAction(forKey: "lean")
        body.run(.sequence([
            .rotate(toAngle: heavy ? 0.6 : 0.3, duration: 0.04, shortestUnitArc: true),
            .wait(forDuration: heavy ? 0.3 : 0.12),
            .rotate(toAngle: 0, duration: 0.15, shortestUnitArc: true),
        ]), withKey: "lean")
        rig.removeAction(forKey: "flash")
        rig.run(.sequence([.fadeAlpha(to: 0.35, duration: 0.03), .fadeAlpha(to: 1, duration: 0.07)]), withKey: "flash")
        armF.removeAction(forKey: "pose")
        armF.run(.sequence([
            .rotate(toAngle: -0.5, duration: 0.04, shortestUnitArc: true),
            .wait(forDuration: 0.15),
            .rotate(toAngle: restAngle(armF), duration: 0.15, shortestUnitArc: true),
        ]), withKey: "pose")
    }

    func koAnim() {
        setCharging(false)
        aura.particleBirthRate = 0
        body.removeAllActions()
        for limb in [armF, armB, legF, legB] { limb.removeAllActions() }
        body.run(.group([
            .rotate(toAngle: 1.45, duration: 0.45, shortestUnitArc: true),
            .moveTo(y: -2, duration: 0.45),
        ]))
        armF.run(.rotate(toAngle: 2.6, duration: 0.45, shortestUnitArc: true))
        legF.run(.rotate(toAngle: 0.6, duration: 0.45, shortestUnitArc: true))
        rig.run(.fadeAlpha(to: 0.7, duration: 0.6))
    }

    func enterEffect() {
        rig.alpha = 0
        rig.run(.fadeIn(withDuration: 0.25))
        burstAura(0.5)
        let ring = SKShapeNode(circleOfRadius: 60)
        ring.strokeColor = def.aura
        ring.lineWidth = 6
        ring.glowWidth = 6
        ring.position = CGPoint(x: 0, y: 90)
        ring.setScale(0.2)
        addChild(ring)
        ring.run(.sequence([.group([.scale(to: 2.2, duration: 0.35), .fadeOut(withDuration: 0.35)]), .removeFromParent()]))
    }

    func spawnAfterimage(in parent: SKNode) {
        guard let ghost = rig.copy() as? SKNode else { return }
        ghost.removeAllActions()
        ghost.position = position
        ghost.xScale = rig.xScale * xScale
        ghost.yScale = yScale
        ghost.alpha = 0.55
        ghost.zPosition = zPosition - 1
        parent.addChild(ghost)
        ghost.run(.sequence([.fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    func dodgeFlicker() {
        rig.removeAction(forKey: "flash")
        rig.alpha = 0.25
        rig.run(.sequence([.wait(forDuration: 0.12), .fadeAlpha(to: 1, duration: 0.15)]), withKey: "flash")
    }

    /// Cancels the fighter's current move (combo, beam…) and returns to stance.
    func cancelAction() {
        removeAction(forKey: "act")
        removeAttachments()
        stance()
    }
}
