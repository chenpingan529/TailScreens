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
        ),
        .executable(
            name: "TailScreensApp",
            targets: ["TailScreensApp"]
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
        .executableTarget(
            name: "TailScreensApp",
            dependencies: ["TailScreensCore"],
            path: "Sources/TailScreensApp"
        ),
        .testTarget(
            name: "TailScreensCoreTests",
            dependencies: ["TailScreensCore"],
            path: "Tests/TailScreensCoreTests"
        )
    ]
)
