// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ObsidianSetup",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "ObsidianSetup",
            path: "Sources/ObsidianSetup",
            resources: [
                .copy("Resources/AppIcon.icns"),
                .copy("Resources/AppIcon.png"),
            ]
        )
    ]
)
