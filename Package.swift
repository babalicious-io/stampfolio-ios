// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "StampFolio",
    platforms: [
        .iOS(.v17)
    ],
    dependencies: [
        // Kingfisher - Image caching and loading
        .package(url: "https://github.com/onevcat/Kingfisher.git", from: "7.0.0")
    ],
    targets: [
        .target(
            name: "StampFolio",
            dependencies: ["Kingfisher"]
        )
    ]
)
