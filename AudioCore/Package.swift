// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "AudioCore",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "AudioCore", targets: ["AudioCore"]),
    ],
    targets: [
        .target(name: "AudioCore"),
        .testTarget(name: "AudioCoreTests", dependencies: ["AudioCore"]),
    ]
)
