// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Skeletons",
    platforms: [.iOS(.v17)],
    products: [
        .library(name: "Skeletons", targets: ["Skeletons"]),
    ],
    targets: [
        .target(name: "Skeletons"),
        .testTarget(name: "SkeletonsTests", dependencies: ["Skeletons"]),
    ],
    swiftLanguageModes: [.v5]
)
