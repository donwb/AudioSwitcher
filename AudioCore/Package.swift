// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "AudioCore",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "AudioCore", targets: ["AudioCore"]),
    ],
    dependencies: [
        // Test-only: used by ParityTests to compare against our own wrapper.
        // Same requirement as the Xcode project so both resolve to one version.
        .package(url: "https://github.com/rnine/SimplyCoreAudio.git", .branch("develop")),
    ],
    targets: [
        .target(name: "AudioCore"),
        .testTarget(name: "AudioCoreTests", dependencies: [
            "AudioCore",
            .product(name: "SimplyCoreAudio", package: "SimplyCoreAudio"),
        ]),
    ]
)
