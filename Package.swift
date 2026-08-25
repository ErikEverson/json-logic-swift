// swift-tools-version:6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "jsonlogic",
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .visionOS(.v2)
    ],
    products: [
        .library(
            name: "jsonlogic",
            targets: ["jsonlogic"]),
        .library(
            name: "JSON",
            targets: ["JSON"]),
        .executable(
            name: "jsonlogic-cli",
            targets: ["jsonlogic-cli"]),
    ],
    targets: [
        .executableTarget(
            name: "jsonlogic-cli",
            dependencies: ["jsonlogic"]),
        .target(
            name: "jsonlogic",
            dependencies: ["JSON"]),
        .target(
            name: "JSON",
            dependencies: []),
        .testTarget(
            name: "jsonlogicTests",
            dependencies: ["jsonlogic"],
            resources: [.copy("Resources/tests.json")]),
        .testTarget(
            name: "JSONTests",
            dependencies: ["JSON"])
    ],
    swiftLanguageModes: [.v6]
)
