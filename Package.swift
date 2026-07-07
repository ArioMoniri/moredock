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
    targets: [
        .executableTarget(name: "MoreDock")
    ]
)
