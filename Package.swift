// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "PandyDoc",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(
            name: "PandyDoc",
            targets: ["DocManager"]
        ),
        .executable(
            name: "SaveToPandyDoc",
            targets: ["SaveToPandyDoc"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.15.0")
    ],
    targets: [
        .executableTarget(
            name: "DocManager",
            dependencies: [
                .product(name: "SQLite", package: "SQLite.swift")
            ],
            path: "Sources/DocManager",
            resources: [
                .copy("../../Resources/PandaIcon.icns")
            ],
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        ),
        .target(
            name: "PrinterExtension",
            dependencies: [],
            path: "Sources/PrinterExtension"
        ),
        .target(
            name: "Shared",
            dependencies: [],
            path: "Sources/Shared"
        ),
        .executableTarget(
            name: "SaveToPandyDoc",
            dependencies: [],
            path: "Sources/SaveToPandyDoc",
            linkerSettings: [
                .linkedFramework("AppKit")
            ]
        )
    ]
)
