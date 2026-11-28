// swift-tools-version:5.9
import PackageDescription

/// Pure-Swift, deterministic battle rules (no UIKit / SceneKit / SpriteKit). Testable with `swift test`.
let package = Package(
    name: "BattleCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [.library(name: "BattleCore", targets: ["BattleCore"])],
    targets: [
        .target(name: "BattleCore", path: "Sources/BattleCore",
                swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]),
        .testTarget(name: "BattleCoreTests", dependencies: ["BattleCore"], path: "Tests/BattleCoreTests"),
    ]
)
