import Foundation
import NotchKit
import Testing

/// The words NotchKit's controls speak to VoiceOver come from `NotchConfiguration.strings`: the island wording by
/// default, any client's words when set, and never a literal in a view.
@Suite struct NotchStringsTests {
    @Test func theDefaultsAreTheIslandWording() {
        let s = NotchConfiguration().strings
        #expect(s.height == "Island height" && s.heightUnit == "points")
        #expect(s.move == "Move island" && s.dock == "Dock")
        #expect(NotchCorner.allCases.map(s.corner) == ["Top Left", "Top Right", "Bottom Left", "Bottom Right"])
        #expect(s.heightValue(287.6) == "288 points")
    }

    @Test func aClientsWordsReplaceEveryLabel() {
        var config = NotchConfiguration()
        config.strings = .init(height: "Hauteur du panneau", heightUnit: "points", move: "Déplacer le panneau", dock: "Ancrer",
                               topLeft: "En haut à gauche", topRight: "En haut à droite", bottomLeft: "En bas à gauche",
                               bottomRight: "En bas à droite")
        let s = config.strings
        #expect(s.height == "Hauteur du panneau" && s.move == "Déplacer le panneau" && s.dock == "Ancrer")
        #expect(s.corner(.topLeft) == "En haut à gauche" && s.corner(.bottomRight) == "En bas à droite")
        #expect(s.heightValue(300) == "300 points")
        #expect(config.strings != NotchConfiguration().strings)
    }

    /// Every VoiceOver label, value and action name in NotchKit's views reads the configuration: no view passes a
    /// string literal to an accessibility modifier or an action's Button.
    @Test func noViewSpeaksALiteral() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Sources/NotchKit")
        let files = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil).filter { $0.pathExtension == "swift" }
        #expect(!files.isEmpty)
        let spoken = [".accessibilityLabel(\"", ".accessibilityValue(\"", ".accessibilityHint(\"", "Button(\"", "Text(\""]
        for file in files {
            let text = try String(contentsOf: file, encoding: .utf8)
            for literal in spoken { #expect(!text.contains(literal), "\(file.lastPathComponent) speaks a literal: \(literal)") }
        }
    }
}
