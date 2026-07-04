// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AIMailComposer",
    platforms: [
        .macOS(.v14),
    ],
    targets: [
        .executableTarget(
            name: "AIMailComposer",
            path: "AIMailComposer",
            exclude: ["Resources/Assets.xcassets"],
            resources: [
                .copy("Resources/AppIcon.icns"),
            ]
        ),
    ]
)
