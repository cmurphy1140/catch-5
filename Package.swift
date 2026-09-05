// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "CatchFive",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "CatchFive", targets: ["CatchFive"]),
        .executable(name: "catch-five-demo", targets: ["CatchFiveDemo"])
    ],
    targets: [
        .target(name: "CatchFive"),
        .executableTarget(name: "CatchFiveDemo", dependencies: ["CatchFive"]),
        .testTarget(name: "CatchFiveTests", dependencies: ["CatchFive"])
    ]
)
