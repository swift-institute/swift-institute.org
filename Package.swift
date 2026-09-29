// swift-tools-version: 6.4

import PackageDescription

let package = Package(
    name: "swift-institute",
    platforms: [
        .macOS(.v27),
        .iOS(.v27),
        .tvOS(.v27),
        .watchOS(.v27),
        .visionOS(.v27),
    ],
    products: [
        .library(name: "Swift Institute", targets: ["Swift Institute"]),
    ],
    targets: [
        .target(name: "Swift Institute"),
    ]
)
