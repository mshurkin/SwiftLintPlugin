// swift-tools-version: 5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftLintPlugin",
    products: [
        .plugin(name: "SwiftLint", targets: ["SwiftLint"]),
        .plugin(name: "SwiftLintPlugin", targets: ["SwiftLintPlugin"])
    ],
    targets: [
        .plugin(
            name: "SwiftLintPlugin",
            capability: .buildTool(),
            dependencies: ["SwiftLintBinary"]
        ),
        .plugin(
            name: "SwiftLint",
            capability: .command(intent: .custom(verb: "swiftlint", description: "SwiftLint")),
            dependencies: ["SwiftLintBinary"]
        ),
        .binaryTarget(
            name: "SwiftLintBinary",
            url: "https://github.com/realm/SwiftLint/releases/download/0.49.1/SwiftLintBinary-macos.artifactbundle.zip",
            checksum: "227258fdb2f920f8ce90d4f08d019e1b0db5a4ad2090afa012fd7c2c91716df3"
        )
    ]
)
