// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Meridian",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Meridian",
            path: "Sources/Meridian"
        )
    ]
)
