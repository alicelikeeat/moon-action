import UIKit
import SceneKit

final class GameViewController: UIViewController {
    let scnView = SCNView(frame: .zero, options: nil)
    private let touchLayer = TouchLayer()
    private(set) var current: Screen?
    private var link: CADisplayLink?
    private var lastTime: CFTimeInterval = 0
    private var started = false

    override func loadView() {
        view = UIView(frame: UIScreen.main.bounds)
        view.backgroundColor = .black
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        scnView.frame = view.bounds
        scnView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        scnView.backgroundColor = .black
        scnView.antialiasingMode = .multisampling4X
        scnView.preferredFramesPerSecond = 60
        scnView.rendersContinuously = true
        scnView.isUserInteractionEnabled = false
        view.addSubview(scnView)
        touchLayer.frame = view.bounds
        touchLayer.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        touchLayer.host = self
        view.addSubview(touchLayer)
        view.isMultipleTouchEnabled = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        Sound.shared.enabled = Save.shared.data.soundOn
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-lang"), i + 1 < args.count { L10n.setting = args[i + 1] }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
        show(Demo.initialScreen())
    }

    func show(_ next: Screen) {
        let old = current
        var fade: UIImageView?
        if old != nil {
            let iv = UIImageView(image: scnView.snapshot())
            iv.frame = view.bounds
            view.insertSubview(iv, aboveSubview: touchLayer)
            fade = iv
            old?.willDisappear()
            old?.ui.removeFromSuperview()
        }
        next.host = self
        next.ui.frame = view.bounds
        next.ui.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(next.ui)
        next.build()
        scnView.scene = next.scene
        scnView.pointOfView = next.pointOfView
        current = next
        next.ui.alpha = 0
        UIView.animate(withDuration: 0.35, delay: 0.05, options: [.curveEaseOut]) {
            next.ui.alpha = 1
            fade?.alpha = 0
        } completion: { _ in fade?.removeFromSuperview() }
        next.didAppear()
    }

    @objc private func tick(_ link: CADisplayLink) {
        let t = link.timestamp
        let dt = lastTime == 0 ? 1.0 / 60 : min(1.0 / 20, t - lastTime)
        lastTime = t
        current?.update(dt: dt)
        FighterModel.syncImported()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .portrait }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { .bottom }
}

/// Launch-argument driven demo mode (used by CI to capture screenshots).
@MainActor
enum Demo {
    static var mode: String? {
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-demo"), i + 1 < args.count { return args[i + 1] }
        return nil
    }

    static func initialScreen() -> Screen {
        switch mode {
        case "team": return TeamScreen()
        case "summon": return SummonScreen()
        case "battle", "ultimate", "special":
            let ids = ["kai", "luna", "rook"]
            return BattleScreen(playerIDs: ids, enemyIDs: ["nyx", "blaze", "ivy"], enemyLevel: 3, stage: 3)
        case "result": return ResultScreen(won: true, teamIDs: ["kai", "luna", "rook"], stage: 1)
        default: return HomeScreen()
        }
    }
}
