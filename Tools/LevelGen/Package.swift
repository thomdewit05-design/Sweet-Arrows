// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LevelGen",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "levelgen", targets: ["levelgen"])
    ],
    dependencies: [
        .package(path: "../../Packages/SweetArrowsCore")
    ],
    targets: [
        .target(name: "LevelGenKit", dependencies: ["SweetArrowsCore"]),
        .executableTarget(name: "levelgen", dependencies: ["LevelGenKit", "SweetArrowsCore"]),
        .testTarget(name: "LevelGenKitTests", dependencies: ["LevelGenKit", "SweetArrowsCore"])
    ]
)
