// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "LyricsKit",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(
            name: "LyricsKit",
            targets: ["LyricsCore", "LyricsService"]),
    ],
    dependencies: [
        .package(url: "https://github.com/1024jp/GzipSwift", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "LyricsCore"),
        .target(
            name: "LyricsService",
            dependencies: [
                "LyricsCore",
                .product(name: "Gzip", package: "GzipSwift"),
            ]),
        .testTarget(
            name: "LyricsKitTests",
            dependencies: ["LyricsCore", "LyricsService"]),
    ],
    swiftLanguageModes: [.v6]
)
