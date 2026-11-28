import UIKit
import SwiftUI
import BattleCore

/// Hosts a SwiftUI view full-screen over the arena backdrop.
@MainActor
class SwiftUIScreen: Screen {
    private var hc: UIViewController?

    func install<V: View>(_ view: V) {
        let hc = UIHostingController(rootView: view)
        hc.view.backgroundColor = .clear
        hc.view.translatesAutoresizingMaskIntoConstraints = false
        host?.addChild(hc)
        ui.addSubview(hc.view)
        hc.didMove(toParent: host)
        NSLayoutConstraint.activate([
            hc.view.leadingAnchor.constraint(equalTo: safe.leadingAnchor),
            hc.view.trailingAnchor.constraint(equalTo: safe.trailingAnchor),
            hc.view.topAnchor.constraint(equalTo: safe.topAnchor),
            hc.view.bottomAnchor.constraint(equalTo: safe.bottomAnchor),
        ])
        self.hc = hc
    }

    override func willDisappear() {
        hc?.willMove(toParent: nil)
        hc?.view.removeFromSuperview()
        hc?.removeFromParent()
        hc = nil
    }

    func backdrop() {
        let arena = Arena(theme: 0)
        scene = arena.scene
        pointOfView = arena.camera
        arena.camera.simdPosition = SIMD3(0, 2.2, -7)
        arena.camera.simdLook(at: SIMD3(0, 1.4, 0), up: SIMD3(0, 1, 0), localFront: SIMD3(0, 0, -1))
        let dim = UIView()
        dim.backgroundColor = UIColor(white: 0, alpha: 0.35)
        dim.isUserInteractionEnabled = false
        dim.translatesAutoresizingMaskIntoConstraints = false
        ui.addSubview(dim)
        pin(dim, edges: ui)
    }
}

/// Out-of-battle hub: team select (leader + 3, difficulty), fighter level / stars / equipment, equipment forge.
@MainActor
final class ProgressionScreen: SwiftUIScreen {
    override func build() {
        backdrop()
        install(ProgressionRootView(save: CoreSave.shared,
                                    onBattle: { [weak self] in self?.startBattle() },
                                    onBack: { [weak self] in self?.go(HomeScreen()) }))
    }

    private func startBattle() {
        let save = CoreSave.shared
        let seed = UInt64.random(in: 1...UInt64.max)
        go(CoreBattleScreen(playerLoadouts: save.data.teamLoadouts, enemyLoadouts: save.enemyLoadouts(seed: seed),
                            difficulty: save.difficulty, seed: seed, progression: true))
    }
}

/// Battle result with rewards granted into the save.
@MainActor
final class CoreResultScreen: SwiftUIScreen {
    private let won: Bool
    private let legendary: Bool
    private let damage: Int

    init(won: Bool, legendary: Bool, damage: Int) {
        self.won = won
        self.legendary = legendary
        self.damage = damage
        super.init()
    }

    override func build() {
        backdrop()
        var rng = SplitMix64(seed: UInt64.random(in: 1...UInt64.max))
        let rewards = CoreSave.shared.data.reward(won: won, rng: &rng)
        if won { Haptics.success() }
        install(VStack {
            Spacer()
            CoreResultView(won: won, legendary: legendary, rewards: rewards, damage: damage) { [weak self] in
                self?.go(ProgressionScreen())
            }
            Spacer()
        })
    }
}
