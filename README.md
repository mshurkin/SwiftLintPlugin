# SwiftLintPlugin

[![Swift 5.7](https://img.shields.io/badge/Swift-5.7-orange.svg)](https://developer.apple.com/swift/)
[![SPM Plugin](https://img.shields.io/badge/SPM-Plugin-brightgreen.svg)](https://swift.org/package-manager/)
[![License MIT](https://img.shields.io/github/license/mshurkin/SwiftLintPlugin)](https://opensource.org/licenses/MIT)

A Swift Package Manager Plugin for [SwiftLint](https://github.com/realm/SwiftLint/) that will run it before each build

SwiftLint has its own [implementation](https://github.com/realm/SwiftLint/)

## Add to Package

Add the package as a dependency to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/mshurkin/SwiftLintPlugin", from: "0.49.1"),
]
```

Then add `SwiftLintPlugin` plugin to your targets:

```swift
targets: [
    .target(
        name: "YOUR_TARGET",
        dependencies: [],
        plugins: [
            .plugin(name: "SwiftLintBuildPlugin", package: "SwiftLintPlugin")
        ]
    ),
```

## Add to Project

Add this package to your project dependencies. Select a target and open the `Build Phases` inspector. Open `Run Build Tool Plug-ins` and add `SwiftLintBuildPlugin` from the list.

## SwiftGen config

Plugin look for a `swiftlint.yml` configuration file in the root of your package (in the same folder as `Package.swift`) and in the target's folder. If files are found in both places, the file in the target's folder is preferred.

## Author
[Maxim Shurkin](https://github.com/mshurkin)

## License
SwiftGenPlugin is released under the MIT license. See [LICENSE](LICENSE) file for more info.

