// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StampFolio",
    platforms: [
        .iOS(.v26)
    ],
    dependencies: [
        // Kingfisher - Image caching and loading
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "StampFolio",
            dependencies: ["Kingfisher"],
            path: "StampFolio",
            resources: [.process("Resources/Documents")]
        )
    ]
)
