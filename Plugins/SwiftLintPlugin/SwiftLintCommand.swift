//
//  SwiftLintCommand.swift
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
struct SwiftLintCommand: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        let (targets, arguments) = parse(
            arguments: arguments,
            targets: context.package.targets.map(\.name),
            cache: context.pluginWorkDirectory
        )
        let swiftlint = try context.tool(named: "swiftlint").path

        let packageConfig = configurationFile(at: context.package.directory)
        var packageArguments = addConfiguration(packageConfig, to: arguments)
        let packageEnvironment = addEnvironment(
            arguments: &packageArguments,
            files: [context.package.directory.appending("Package.swift").string]
        )
        try run(swiftlint, with: packageArguments, environment: packageEnvironment)

        for target in context.package.targets {
            guard let target = target as? SourceModuleTarget, targets.contains(target.name) else {
                continue
            }

            let configuration = configurationFile(at: target.directory) ?? packageConfig
            var arguments = addConfiguration(configuration, to: arguments)
            let environment = addEnvironment(
                arguments: &arguments,
                files: target.sourceFiles(withSuffix: "swift").map(\.path.string)
            )
            try run(swiftlint, with: arguments, environment: environment)
        }
    }
}

private extension SwiftLintCommand {
    func parse(
        arguments: [String],
        targets allTargets: @autoclosure () -> [String],
        cache: Path
    ) -> (targets: [String], arguments: [String]) {
        var extractor = ArgumentExtractor(arguments)
        var targets = extractor.extractOption(named: "target")
        var arguments = extractor.remainingArguments

        if targets.isEmpty {
            targets = allTargets()
        }
        if arguments.isEmpty {
            arguments = ["lint", "--cache-path", "\(cache)"]
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

    func addConfiguration(_ configuration: Path?, to arguments: [String]) -> [String] {
        arguments.contains("--config")
            ? arguments
            : arguments + ["--config", configuration?.string].compactMap { $0 }
    }

    func addEnvironment(arguments: inout [String], files: @autoclosure () -> [String]) -> [String: String] {
        var environment: [String: String] = [:]
        if !arguments.contains("--use-script-input-files") {
            arguments.append("--use-script-input-files")
            let files = files()
            environment["SCRIPT_INPUT_FILE_COUNT"] = String(files.count)
            files.enumerated().forEach { (index, file) in
                environment["SCRIPT_INPUT_FILE_\(index)"] = file
            }
        }
        return environment
    }

    func run(_ exec: Path, with arguments: [String], environment: [String: String]) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: exec.string)
        process.arguments = arguments
        process.environment = environment

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        guard
            let outputData = try pipe.fileHandleForReading.readToEnd(),
            let output = String(data: outputData, encoding: .utf8)
        else {
            return
        }

        for line in output.split(separator: "\n").map(String.init) {
            let components = line.split(separator: ":", maxSplits: 4).map(String.init)
            if components.count == 5 {
                let severity = components[3].trimmingCharacters(in: .whitespaces)
                switch severity {
                case "warning":
                    Diagnostics.warning(line, file: components[0], line: Int(components[1]))
                    continue
                case "error":
                    Diagnostics.error(line, file: components[0], line: Int(components[1]))
                    continue
                default:
                    break
                }
            }
            Diagnostics.remark(line)
        }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintCommand: XcodeCommandPlugin {
    func performCommand(context: XcodePluginContext, arguments: [String]) throws {
        let (targets, arguments) = parse(
            arguments: arguments,
            targets: context.xcodeProject.targets.map(\.displayName),
            cache: context.pluginWorkDirectory
        )
        let swiftlint = try context.tool(named: "swiftlint").path

        let configuration = configurationFile(at: context.xcodeProject.directory)
        let args = addConfiguration(configuration, to: arguments)
        for target in context.xcodeProject.targets {
            guard targets.contains(target.displayName) else {
                continue
            }

            var arguments = args
            let environment = addEnvironment(
                arguments: &arguments,
                files: target.inputFiles.filter({ $0.path.extension == "swift" }).map(\.path.string)
            )
            try run(swiftlint, with: arguments, environment: environment)
        }
    }
}
#endif
