// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "NovexaGeneralsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "NovexaLauncher", targets: ["NovexaLauncher"]),
        .library(name: "NovexaCore", targets: ["NovexaCore"]),
    ],
    targets: [
        .target(name: "NovexaCore"),
        .executableTarget(name: "NovexaLauncher", dependencies: ["NovexaCore"], exclude: ["Resources"]),
        .testTarget(name: "NovexaCoreTests", dependencies: ["NovexaCore"]),
    ]
)
