// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "MusicPlayer",
    platforms: [
        .macOS("26.0"),
    ],
    products: [
        .library(name: "MusicPlayer", targets: ["MusicPlayer"]),
        .library(name: "LXMusicPlayer", targets: ["LXMusicPlayer"]),
    ],
    targets: [
        .target(
            name: "MusicPlayer",
            dependencies: [
                "LXMusicPlayer",
                "MediaRemotePrivate",
            ],
            cSettings: [
                .define("TARGET_OS_MAC", to: "1"),
            ]),
        .target(
            name: "LXMusicPlayer",
            cSettings: [
                .define("TARGET_OS_MAC", to: "1"),
                .headerSearchPath("private"),
                .headerSearchPath("BridgingHeader"),
            ]),
        .target(
            name: "MediaRemotePrivate",
            cSettings: [
                .define("TARGET_OS_MAC", to: "1"),
            ]),
    ],
    swiftLanguageModes: [.v6]
)
