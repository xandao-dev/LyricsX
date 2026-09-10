// swift-tools-version:5.2

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
        .package(url: "https://github.com/ddddxxx/Regex", from: "1.0.1"),
        .package(url: "https://github.com/ddddxxx/SwiftCF", .upToNextMinor(from: "0.2.0")),
        .package(name: "Gzip", url: "https://github.com/1024jp/GzipSwift", from: "5.0.0"),
    ],
    targets: [
        .target(
            name: "LyricsCore",
            dependencies: ["Regex", "SwiftCF"]),
        .target(
            name: "LyricsService",
            dependencies: ["LyricsCore", "Regex", "Gzip"]),
        .testTarget(
            name: "LyricsKitTests",
            dependencies: ["LyricsCore", "LyricsService"]),
    ]
)
