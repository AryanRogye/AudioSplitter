// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioUI",
    platforms: [.iOS(.v18)],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AudioUI",
            targets: ["AudioUI"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/kewlbear/FFmpeg-iOS-Lame", from: "0.0.6-b20230730-000000")
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AudioUI"
        ),

    ]
)
