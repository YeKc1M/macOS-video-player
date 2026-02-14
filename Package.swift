// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "SuperpowersPlayer",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "SuperpowersPlayer",
            path: "Sources/SuperpowersPlayer"
        ),
    ]
)
