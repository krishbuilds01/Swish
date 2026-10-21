// swift-tools-version: 6.4
import PackageDescription

let package = Package(
    name: "Swish",
    platforms: [
        .macOS(.v14)
    ],
    targets: [
        .executableTarget(
            name: "Swish",
            path: "Sources/Swish"
        ),
    ]
)
