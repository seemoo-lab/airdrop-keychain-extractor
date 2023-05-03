// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KeychainExtractor",
    platforms: [.macOS(.v11)],
    products: [
        .executable(
            name: "KeychainExtractor",
            targets: ["KeychainExtractor"]),
    ],
    targets: [
        .target(name: "Sharing"),
        .executableTarget(
            name: "KeychainExtractor",
            dependencies: ["Sharing"],
            linkerSettings: [
               .unsafeFlags(["-iframework", "/System/Library/PrivateFrameworks/"]),
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
