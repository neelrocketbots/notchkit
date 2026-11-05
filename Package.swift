// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "NotchKit",
    platforms: [.macOS("26.0")],
    products: [
        .library(name: "NotchKit", targets: ["NotchKit"]),
    ],
    targets: [
        // AppKit and SwiftUI only: NotchKit reads no environment variables or defaults of its own, and a client injects
        // everything through NotchConfiguration (NotchKitSourceScanTests guards it).
        .target(name: "NotchKit"),
        .testTarget(name: "NotchKitTests", dependencies: ["NotchKit"]),
    ]
)
