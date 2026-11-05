import Foundation
import Testing

/// NotchKit is the island's chrome for any client (owner 2026-11-05): it imports only Apple's frameworks, names nothing of
/// Hiccup's (Core, Overlay, DesignSystem, the island's tokens and copy, the app's defaults) and reads no environment or
/// defaults of its own; a client injects everything.
@Suite struct NotchKitSourceScanTests {
    static let allowedImports: Set<String> = ["AppKit", "SwiftUI", "Observation", "os", "CoreGraphics", "Foundation"]
    /// Hiccup's modules and names, and the process-wide inputs NotchKit must not read.
    static let banned = ["Hiccup", "HICCUP_", "IslandTokens", "IslandCopy", "IslandModel", "IslandPanel", "AppSupportLocation",
                         "ProcessInfo", "UserDefaults", "CFPreferences", "DesignSystem", "io.saynomore"]

    static var sourceDir: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/NotchKit")
    }

    static func sources() throws -> [(name: String, text: String)] {
        let files = try FileManager.default.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "swift" }
        return try files.map { ($0.lastPathComponent, try String(contentsOf: $0, encoding: .utf8)) }
    }

    @Test func notchKitDependsOnNothingOfHiccups() throws {
        let sources = try Self.sources()
        #expect(!sources.isEmpty, "NotchKit's sources are found")
        for (name, text) in sources {
            for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                for prefix in ["import ", "@_exported import ", "@testable import ", "public import ", "internal import "] where trimmed.hasPrefix(prefix) {
                    let module = String(trimmed.dropFirst(prefix.count)).split(separator: " ").first.map(String.init) ?? ""
                    #expect(Self.allowedImports.contains(module), "\(name) imports \(module)")
                }
            }
            for word in Self.banned { #expect(!text.contains(word), "\(name) mentions \(word)") }
        }
    }

    /// The scan itself: it catches a client's module, a Hiccup name and an environment read.
    @Test func theScanCatchesWhatItBans() {
        let bad = "import Core\nlet x = ProcessInfo.processInfo.environment[\"HICCUP_X\"]\n"
        #expect(!Self.allowedImports.contains("Core"))
        #expect(Self.banned.contains { bad.contains($0) })
    }
}
