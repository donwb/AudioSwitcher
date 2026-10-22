// swift-tools-version:5.3
import PackageDescription

let package = Package(
    name: "AudioCore",
    platforms: [.macOS(.v11)],
    products: [
        .library(name: "AudioCore", targets: ["AudioCore"]),
    ],
    targets: [
        .target(name: "AudioCore"),
        .testTarget(name: "AudioCoreTests", dependencies: ["AudioCore"]),
    ]
)
