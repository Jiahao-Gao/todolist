// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "TodoList",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "TodoList", targets: ["TodoList"]),
        .library(name: "TodoCore", targets: ["TodoCore"])
    ],
    targets: [
        .target(name: "TodoCore"),
        .executableTarget(
            name: "TodoList",
            dependencies: ["TodoCore"]
        ),
        .testTarget(
            name: "TodoCoreTests",
            dependencies: ["TodoCore"]
        )
    ]
)
