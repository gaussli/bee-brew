// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "beebrew",
    defaultLocalization: "en",
    platforms: [
        // NFR-004：仅支持 macOS 14 (Sonoma) 及以上，使用三栏 NavigationSplitView 等新 API
        .macOS(.v14)
    ],
    products: [
        .executable(name: "beebrew", targets: ["beebrew"]),
    ],
    dependencies: [
        // 零外部依赖（NFR），仅使用系统框架
    ],
    targets: [
        .executableTarget(
            name: "beebrew",
            dependencies: [],
            path: "beebrew",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "beebrewTests",
            dependencies: ["beebrew"],
            resources: [
                // 服务层 JSON fixture（NFR-013：数据与 brew --json=v2 严格一致）
                .process("TestFixtures")
            ]
        ),
    ]
)
