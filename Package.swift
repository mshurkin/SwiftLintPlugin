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
        .binaryTarget(name: "SwiftLintBinary", path: "Binaries/SwiftLintBinary-macos.artifactbundle.zip")
    ]
)
