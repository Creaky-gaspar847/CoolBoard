// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "CoolBoard",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .library(name: "CoolBoardCore", targets: ["CoolBoardCore"]),
        .executable(name: "CoolBoard", targets: ["CoolBoard"]),
        .executable(name: "CoolBoardHelper", targets: ["CoolBoardHelper"]),
        .executable(name: "CoolBoardXPCProbe", targets: ["CoolBoardXPCProbe"])
    ],
    targets: [
        .target(
            name: "CoolBoardCore",
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        ),
        .executableTarget(
            name: "CoolBoard",
            dependencies: ["CoolBoardCore"],
            resources: [
                .process("Resources")
            ],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("SwiftUI")
            ]
        ),
        .executableTarget(
            name: "CoolBoardHelper",
            dependencies: ["CoolBoardCore"]
        ),
        .executableTarget(
            name: "CoolBoardXPCProbe",
            dependencies: ["CoolBoardCore"]
        ),
        .testTarget(
            name: "CoolBoardCoreTests",
            dependencies: ["CoolBoardCore"]
        )
    ]
)
