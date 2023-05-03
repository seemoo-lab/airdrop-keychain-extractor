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
        
        let cpTool = try context.tool(named: "cp")
        let cpArgs = [inputPath, outputPath]
        let cpToolURL = URL(fileURLWithPath: cpTool.path.string)
        do {
            let process = try Process.run(cpToolURL, arguments: cpArgs)
            process.waitUntilExit()
            
            // Check whether the subprocess invocation was successful.
            guard process.terminationReason == .exit && process.terminationStatus == 0 else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("codesign invocation failed: \(problem)")
                return
            }
            Diagnostics.remark("cp executable from \(inputPath) to \(outputPath)")
        }
        
        let entitlementPath = context.package.directory.string + "/entitlements.plist"
        let codesignTool = try context.tool(named: "codesign")
        let certificate = arguments.first ?? "Apple Development"
        let codesignArgs = ["-f", "-s", certificate, "--entitlements", entitlementPath, outputPath]
        let codesignToolURL = URL(fileURLWithPath: codesignTool.path.string)
        
        do {
           let process = try Process.run(codesignToolURL, arguments: codesignArgs)
            process.waitUntilExit()
        
            // Check whether the subprocess invocation was successful.
            guard process.terminationReason == .exit && process.terminationStatus == 0 else {
                let problem = "\(process.terminationReason):\(process.terminationStatus)"
                Diagnostics.error("codesign invocation failed: \(problem)")
                return
            }
            Diagnostics.remark("Created codesigned executable at \(outputPath)")
        }
    }
}
