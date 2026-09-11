// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MusicPlayer",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "MusicPlayer", targets: ["MusicPlayer"]),
    ],
    targets: [
        .target(name: "MusicPlayer"),
    ],
    swiftLanguageModes: [.v6]
)
