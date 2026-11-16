// swift-tools-version: 6.2
import PackageDescription

// RaincoatTokens and RaincoatThemeBase use Foundation only, so they also build and test on Linux.
// Raincoat is the SwiftUI layer; its sources compile to nothing where SwiftUI is unavailable.
let package = Package(
    name: "Raincoat",
    // The components speak a few words to assistive technology. They are translated in
    // Sources/Raincoat/Resources, and English is used for any other language.
    defaultLocalization: "en",
    platforms: [.iOS(.v17), .macOS(.v14)],
    products: [
        .library(name: "Raincoat", targets: ["Raincoat"]),
        .library(name: "RaincoatTokens", targets: ["RaincoatTokens"]),
        .library(name: "RaincoatThemeBase", targets: ["RaincoatThemeBase"]),
    ],
    targets: [
        .target(name: "RaincoatTokens"),
        .target(name: "RaincoatThemeBase", dependencies: ["RaincoatTokens"]),
        .target(
            name: "Raincoat",
            dependencies: ["RaincoatTokens", "RaincoatThemeBase"],
            resources: [.process("Resources")]
        ),
        .testTarget(name: "RaincoatTokensTests", dependencies: ["RaincoatTokens"]),
        .testTarget(name: "RaincoatThemeBaseTests", dependencies: ["RaincoatThemeBase"]),
        .testTarget(name: "RaincoatTests", dependencies: ["Raincoat"]),
    ]
)
