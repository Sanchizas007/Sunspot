// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SolarCore",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "SolarCore", targets: ["SolarCore"])
    ],
    targets: [
        .target(name: "SolarCore"),
        .testTarget(name: "SolarCoreTests", dependencies: ["SolarCore"])
    ]
)
