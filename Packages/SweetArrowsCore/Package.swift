// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SweetArrowsCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SweetArrowsCore", targets: ["SweetArrowsCore"])
    ],
    targets: [
        .target(name: "SweetArrowsCore"),
        .testTarget(name: "SweetArrowsCoreTests", dependencies: ["SweetArrowsCore"])
    ]
)
