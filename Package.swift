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
        )
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "DocManager",
            dependencies: [],
            path: "Sources/DocManager",
            resources: [
                .process("../../Resources")
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
        )
    ]
)
