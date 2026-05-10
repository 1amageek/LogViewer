// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "LogViewer",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(name: "LogViewer", targets: ["LogViewer"]),
    ],
    targets: [
        .target(name: "LogViewer"),
        .testTarget(
            name: "LogViewerTests",
            dependencies: ["LogViewer"]
        ),
    ]
)
