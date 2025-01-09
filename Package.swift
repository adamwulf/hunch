// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "hunch",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(name: "HunchKit", targets: ["HunchKit"]),
        .executable(name: "hunch", targets: ["hunch"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
        .package(url: "https://github.com/adamwulf/SwiftToolbox", branch: "main"),
        .package(url: "https://github.com/adamwulf/Logfmt", branch: "main"),
        .package(url: "https://github.com/adamwulf/ytt", branch: "main")
    ],
    targets: [
        .target(
            name: "HunchKit",
            dependencies: [
                .product(name: "SwiftToolbox", package: "SwiftToolbox"),
                .product(name: "Logfmt", package: "Logfmt"),
                .product(name: "YouTubeTranscriptKit", package: "ytt")
            ]
        ),
        .executableTarget(
            name: "hunch",
            dependencies: [
                "HunchKit",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
                .product(name: "SwiftToolbox", package: "SwiftToolbox"),
                .product(name: "Logfmt", package: "Logfmt"),
                .product(name: "YouTubeTranscriptKit", package: "ytt")
            ]
        ),
        .testTarget(
            name: "HunchKitTests",
            dependencies: ["HunchKit"]
        )
    ]
)
