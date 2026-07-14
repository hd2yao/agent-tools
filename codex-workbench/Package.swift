// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CodexWorkbench",
    platforms: [.macOS(.v13)],
    products: [
        .library(name: "CodexWorkbenchCore", targets: ["CodexWorkbenchCore"]),
        .executable(name: "CodexWorkbenchApp", targets: ["CodexWorkbenchApp"]),
    ],
    targets: [
        .target(name: "CodexWorkbenchCore"),
        .executableTarget(
            name: "CodexWorkbenchApp",
            dependencies: ["CodexWorkbenchCore"]
        ),
        .executableTarget(
            name: "CodexWorkbenchCoreTests",
            dependencies: ["CodexWorkbenchCore"],
            path: "Tests/CodexWorkbenchCoreTests"
        ),
    ]
)
