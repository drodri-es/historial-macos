// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Historial",
    defaultLocalization: "en",
    platforms: [.macOS(.v15)],
    products: [.executable(name: "Historial", targets: ["Historial"])],
    targets: [.executableTarget(name: "Historial", path: "Sources/Historial", resources: [.process("Resources")])]
)
