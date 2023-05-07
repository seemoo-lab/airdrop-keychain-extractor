//
//  Codesign.swift
//
//
//  Created by Kyle on 2023/5/3.
//

import Foundation
import PackagePlugin

@main
struct Codesign: CommandPlugin {
    func performCommand(context: PluginContext, arguments: [String]) async throws {
        // Ask the plugin host (SwiftPM or an IDE) to build our product.
        let result = try packageManager.build(
            .product("KeychainExtractor"),
            parameters: .init(configuration: .release, logging: .concise)
        )
        // Check the result. Ideally this would report more details.
        guard result.succeeded,
              let keychainExtractor = result.builtArtifacts.filter({ $0.kind == .executable }).first else {
            Diagnostics.error("Couldn't build product \(result.logText)")

            return
        }
    
        let inputPath = keychainExtractor.path.string
        let outputPath = context.package.directory.string + "/airdrop-secret-extractor"
        
        // Task 1: Copy the artifact
        do {
            let tool = try context.tool(named: "cp")
            let args = [inputPath, outputPath]
            let toolURL = URL(fileURLWithPath: tool.path.string)
            let process = try Process.run(toolURL, arguments: args)
            process.waitUntilExit()
            
            // Check whether the subprocess invocation was successful.
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("cp invocation failed: \(problem)")
                return
            }
            Diagnostics.remark("cp executable from \(inputPath) to \(outputPath)")
        }
        
        // Task 2: Replacing existing signature (Need to disable swift-package sandbox via '--disable-sandbox')
        do {
            let entitlementPath = context.package.directory.string + "/entitlements.plist"
            let tool = try context.tool(named: "codesign")
            let certificate = arguments.first ?? "Apple Development"
            let args = ["-f", "-s", certificate, "--entitlements", entitlementPath, outputPath]
            let toolURL = URL(fileURLWithPath: tool.path.string)
            let process = try Process.run(toolURL, arguments: args)
            process.waitUntilExit()

            // Check whether the subprocess invocation was successful.
            guard process.terminationReason == .exit, process.terminationStatus == 0 else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("codesign invocation failed: \(problem)")
                return
            }
            Diagnostics.remark("Created codesigned executable at \(outputPath)")
        }
    }
}
