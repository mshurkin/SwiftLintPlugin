//
//  SwiftLintFixCommand.swift
//
//  Copyright © 2022 Maxim Shurkin
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in all
//  copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
//  SOFTWARE.
//

import Foundation
import PackagePlugin

@main
struct SwiftLintFixCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let (targets, arguments) = parse(
            arguments: arguments,
            targets: context.package.targets.map(\.name),
            cache: context.pluginWorkDirectory
        )
        let swiftlint = try context.tool(named: "swiftlint")

        let packageConfig = configurationFile(at: context.package.directory)
        let packageArguments = arguments
            .appending(configuration: packageConfig)
            .appending(path: context.package.directory.appending("Package.swift"))
        try swiftlint.run(with: packageArguments)

        for target in context.package.targets {
            guard let target = target as? SourceModuleTarget, targets.contains(target.name) else {
                continue
            }

            let arguments = arguments
                .appending(configuration: configurationFile(at: target.directory) ?? packageConfig)
                .appending(path: target.directory)
            try swiftlint.run(with: arguments, for: target.name)
        }
    }
}

private extension SwiftLintFixCommand {
    typealias Arguments = [String]

    func parse(
        arguments: [String],
        targets allTargets: @autoclosure () -> [String],
        cache: Path
    ) -> (targets: [String], arguments: Arguments) {
        var extractor = ArgumentExtractor(arguments)
        var targets = extractor.extractOption(named: "target")
        var arguments = extractor.remainingArguments

        if targets.isEmpty {
            targets = allTargets()
        }
        if arguments.isEmpty {
            arguments = ["--fix", "--cache-path", "\(cache)"]
        }

        return (targets, arguments)
    }

    func configurationFile(at path: Path) -> Path? {
        let path = path.appending("swiftlint.yml")
        guard FileManager.default.fileExists(atPath: path.string) else {
            return nil
        }
        return path
    }
}

private extension SwiftLintFixCommand.Arguments {
    func appending(configuration: Path?) -> SwiftLintFixCommand.Arguments {
        contains("--config") ? self : self + ["--config", configuration?.string].compactMap { $0 }
    }

    func appending(path: Path) -> SwiftLintFixCommand.Arguments {
        self + [path.string]
    }
}

private extension PluginContext.Tool {
    func run(with arguments: [String], for targetName: String? = nil) throws {
        var environment = [String: String]()
        if let targetName {
            environment["TARGET_NAME"] = targetName
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: path.string)
        process.arguments = arguments
        process.environment = environment

        try process.run()
        process.waitUntilExit()

        if process.terminationReason != .exit || process.terminationStatus != 0 {
            let problem = "\(process.terminationReason):\(process.terminationStatus)"
            Diagnostics.error("swiftlint invocation failed: \(problem)")
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintFixCommand: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let (targets, arguments) = parse(
            arguments: arguments,
            targets: context.xcodeProject.targets.map(\.displayName),
            cache: context.pluginWorkDirectory
        )
        let swiftlint = try context.tool(named: "swiftlint")

        let args = arguments.appending(configuration: configurationFile(at: context.xcodeProject.directory))
        for target in context.xcodeProject.targets {
            guard targets.contains(target.displayName) else {
                continue
            }

            let arguments = args.appending(path: context.xcodeProject.directory.appending(target.displayName))
            try swiftlint.run(with: arguments, for: target.displayName)
        }
    }
}
#endif

