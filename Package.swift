// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "TailScreens",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "TailScreensCore",
            targets: ["TailScreensCore"]
        )
    ],
    dependencies: [
        // Pure Swift, zero external dependencies for maximum stability, performance, and security
    ],
    targets: [
        .target(
            name: "TailScreensCore",
            dependencies: [],
            path: "Sources/TailScreensCore"
        ),
        .testTarget(
            name: "TailScreensCoreTests",
            dependencies: ["TailScreensCore"],
            path: "Tests/TailScreensCoreTests"
        )
    ]
)
