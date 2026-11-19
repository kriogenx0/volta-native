// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "VoltaNative",
    platforms: [.macOS(.v14)],
    products: [
        // Swift apps: `import VoltaNative`.
        .library(name: "VoltaNative", targets: ["VoltaNative"]),
        // C apps: link libVoltaNativeC.dylib and include include/volta_native.h.
        .library(name: "VoltaNativeC", type: .dynamic, targets: ["VoltaNativeC"]),
        // A small app that shows every component.
        .executable(name: "VoltaGallery", targets: ["VoltaGallery"]),
    ],
    targets: [
        .target(name: "VoltaNative"),
        .target(name: "VoltaNativeC", dependencies: ["VoltaNative"]),
        .executableTarget(name: "VoltaGallery", dependencies: ["VoltaNative"]),
        .testTarget(name: "VoltaNativeTests", dependencies: ["VoltaNative"]),
    ]
)
