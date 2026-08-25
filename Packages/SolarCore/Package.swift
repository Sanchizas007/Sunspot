// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SolarCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SolarCore", targets: ["SolarCore"]),
        // What a spot is, where it is kept, and how its numbers are worded. Shared because
        // the widget is a separate process and cannot see the app's own code, and two copies
        // of a stored format drift apart the first time one of them is edited.
        .library(name: "SpotKit", targets: ["SpotKit"])
    ],
    targets: [
        .target(name: "SolarCore"),
        .target(name: "SpotKit", dependencies: ["SolarCore"]),
        .testTarget(name: "SolarCoreTests", dependencies: ["SolarCore"]),
        .testTarget(name: "SpotKitTests", dependencies: ["SpotKit"])
    ]
)
