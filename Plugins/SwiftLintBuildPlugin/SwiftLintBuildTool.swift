//
//  SwiftLintBuildTool.swift
//
//  Created by Максим Шуркин on 27.10.2022.
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

        let inputFiles = target.sourceFiles(withSuffix: "swift").map(\.path)
        if inputFiles.isEmpty {
            return []
        }

        return [
            .buildCommand(
                displayName: "Run SwiftLint",
                executable: try context.tool(named: "swiftlint").path,
                arguments: [
                    "lint",
                    "--cache-path", "\(context.pluginWorkDirectory)",
                    "--config", "\(configuration.string)",
                    "--use-script-input-files"
                ],
                inputFiles: inputFiles
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

        let inputFiles = context.xcodeProject.filePaths.filter { $0.extension == "swift" }
        if inputFiles.isEmpty {
            return []
        }

        return [
            .buildCommand(
                displayName: "Run SwiftLint",
                executable: try context.tool(named: "swiftlint").path,
                arguments: [
                    "lint",
                    "--cache-path", "\(context.pluginWorkDirectory)",
                    "--config", "\(configuration.string)",
                    "--use-script-input-files"
                ],
                inputFiles: inputFiles
            )
        ]
    }
}
#endif

