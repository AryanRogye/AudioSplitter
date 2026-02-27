// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "AudioHelper",
    platforms: [
        .iOS(.v26)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "AudioHelper",
            targets: ["AudioHelper"]
        ),
    ],
    dependencies: [
        .package(
            url: "https://github.com/FluidInference/FluidAudio.git",
            revision: "8e830ab2dbaf89b62659d37428b47a47056d1449"
        ),
        .package(
            url: "https://github.com/kewlbear/YoutubeDL-iOS.git",
            from: "0.0.2"
        ),
        .package(
            url: "https://github.com/pvieito/PythonKit.git",
            from: "0.3.1"
        ),
        .package(
            url: "https://github.com/kewlbear/Python-iOS.git",
            from: "0.1.1-b"
        ),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "AudioHelper",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "YoutubeDL", package: "YoutubeDL-iOS"),
                .product(name: "PythonKit", package: "PythonKit"),
                .product(name: "Python-iOS", package: "Python-iOS")
            ],
            resources: [
                .process("Resources")
            ]
        ),
    ]
)
