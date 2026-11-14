// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "ClaudeTipsMenuBar",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "ClaudeTipsMenuBar", targets: ["ClaudeTipsMenuBar"]),
        .library(name: "TipsCore", targets: ["TipsCore"]),
    ],
    targets: [
        // Model, loading, merging, search and the skill scan. No UI, testable.
        .target(name: "TipsCore"),
        // The menu bar app: AppKit shell with SwiftUI content.
        .executableTarget(name: "ClaudeTipsMenuBar", dependencies: ["TipsCore"]),
        .testTarget(name: "TipsCoreTests", dependencies: ["TipsCore"]),
    ]
)
