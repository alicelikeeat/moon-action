import UIKit
import SpriteKit

final class GameViewController: UIViewController {
    private var skView: SKView { view as! SKView }
    private var presented = false

    override func loadView() {
        view = SKView(frame: UIScreen.main.bounds)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        skView.isMultipleTouchEnabled = true
        skView.ignoresSiblingOrder = false
        skView.preferredFramesPerSecond = 60
        view.backgroundColor = .black
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let b = view.bounds
        guard !presented, b.width > 0, b.height > 0, b.width >= b.height else { return }
        presented = true
        let scale = 750 / b.height
        GameSize.size = CGSize(width: (b.width * scale).rounded(), height: 750)
        let insets = view.safeAreaInsets
        Layout.safeLeft = max(16, insets.left * scale)
        Layout.safeRight = max(16, insets.right * scale)
        Layout.safeBottom = max(10, insets.bottom * scale)
        _ = Sound.shared
        let scene = HomeScene(size: GameSize.size)
        scene.scaleMode = .aspectFit
        skView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .all }
}
