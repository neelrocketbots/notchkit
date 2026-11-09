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
        // A minimal client: a floating island with the default configuration (`swift run NotchKitDemo`).
        .executableTarget(name: "NotchKitDemo", dependencies: ["NotchKit"], path: "Examples/NotchKitDemo"),
        // The docs' figures, rendered from NotchKit's views and values into docs/images (`swift run NotchKitDocImages`).
        .executableTarget(name: "NotchKitDocImages", dependencies: ["NotchKit"], path: "Examples/NotchKitDocImages"),
    ]
)
