// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "MoreDock",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "MoreDock", targets: ["MoreDock"])
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.9.4")
    ],
    targets: [
        .executableTarget(
            name: "MoreDock",
            dependencies: [
                .product(name: "Sparkle", package: "Sparkle")
            ]
        )
    ]
)
