//
//  SwiftLintBuildTool.swift
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
struct SwiftLintBuildTool: BuildToolPlugin {
    func createBuildCommands(context: PluginContext, target: Target) async throws -> [Command] {
        guard let target = target as? SourceModuleTarget else {
            return []
        }

        guard let configuration = configurationFile(project: context.package.directory, target: target.directory) else {
            Diagnostics.error("No SwiftLint configurations found for target \(target.name).")
            return []
        }

        let packageFile = context.package.directory.appending("Package.swift").string
        let tests = context.package.targets.compactMap {
            $0.name.hasPrefix(target.name) && $0.name.contains("Tests") ? $0.directory.string : nil
        }

        var arguments = [
            "lint",
            "--cache-path", "\(context.pluginWorkDirectory)",
            "--config", "\(configuration.string)",
            packageFile,
            target.directory.string
        ]
        arguments += tests

        return [
            .prebuildCommand(
                displayName: "Run SwiftLint for \(target.name)",
                executable: try context.tool(named: "swiftlint").path,
                arguments: arguments,
                environment: ["TARGET_NAME": target.name],
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}

private extension SwiftLintBuildTool {
    func configurationFile(project: Path, target: Path? = nil) -> Path? {
        [target, project]
            .compactMap { $0?.appending("swiftlint.yml") }
            .first { FileManager.default.fileExists(atPath: $0.string) }
    }
}

#if canImport(XcodeProjectPlugin)
import XcodeProjectPlugin

extension SwiftLintBuildTool: XcodeBuildToolPlugin {
    func createBuildCommands(context: XcodePluginContext, target: XcodeTarget) throws -> [Command] {
        guard let configuration = configurationFile(project: context.xcodeProject.directory) else {
            Diagnostics.error("No SwiftLint configurations found for project \(context.xcodeProject.displayName).")
            return []
        }

        let tests: [String] = context.xcodeProject.targets.compactMap {
            let name = $0.displayName
            guard name.hasPrefix(target.displayName), name.contains("Tests") else {
                return nil
            }
            return context.xcodeProject.directory.appending(name).string
        }

        var arguments = [
            "lint",
            "--cache-path", "\(context.pluginWorkDirectory)",
            "--config", "\(configuration.string)",
            context.xcodeProject.directory.appending(target.displayName).string
        ]
        arguments += tests

        return [
            .prebuildCommand(
                displayName: "Run SwiftLint for \(target.displayName)",
                executable: try context.tool(named: "swiftlint").path,
                arguments: arguments,
                environment: ["TARGET_NAME": target.displayName],
                outputFilesDirectory: context.pluginWorkDirectory
            )
        ]
    }
}
#endif

