// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.
import Foundation
import PackageDescription

let isXcodeEnv = ProcessInfo.processInfo.environment["__CFBundleIdentifier"] == "com.apple.dt.Xcode"
// Xcode use clang as linker which supports "-iframework" while SwiftPM use swiftc as linker which supports "-Fsystem"
let systemFrameworkSearchFlag = isXcodeEnv ? "-iframework" : "-Fsystem"

let package = Package(
    name: "KeychainExtractor",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "KeychainExtractor",
            targets: ["KeychainExtractor"]
        ),
    ],
    targets: [
        .target(name: "Sharing"),
        .executableTarget(
            name: "KeychainExtractor",
            dependencies: ["Sharing"],
            linkerSettings: [
                .unsafeFlags([systemFrameworkSearchFlag, "/System/Library/PrivateFrameworks/"]),
                .linkedFramework("Sharing"),
            ]
        ),
        .plugin(
            name: "Codesign",
            capability: .command(
                intent: .custom(verb: "codesign", description: "codesign the executable with entitlements"),
                permissions: [.writeToPackageDirectory(reason: "Codesign the executable")]
            )
        ),
    ]
)
