import CoreGraphics
import Foundation
@testable import NotchKit
import SwiftUI
import Testing

/// The frosted body, the floating shadow and the grip, under the default configuration (the shipped look). On the main
/// actor: the backdrop and the shadow are SwiftUI types, so their statics are main-actor isolated.
@MainActor @Suite struct NotchBackdropTests {
    @Test func theBodyIsFrostedOnlyWhileOpenAndAsked() {
        #expect(NotchBackdrop.look(drawn: .expanded, rendering: .material, raised: false, reduceTransparency: false) == .frosted)
        #expect(NotchBackdrop.look(drawn: .expanded, rendering: .tint, raised: false, reduceTransparency: false) == .frosted)
        for d in [NotchDrawn.nothing, .folded, .idle] {
            #expect(NotchBackdrop.look(drawn: d, rendering: .material, raised: false, reduceTransparency: false) == .solid, "\(d): solid black")
        }
        #expect(NotchBackdrop.look(drawn: .folded, rendering: .material, raised: false, reduceTransparency: false, floating: true) == .frosted, "the floating pill")
        #expect(NotchBackdrop.look(drawn: .expanded, rendering: .material, raised: false, reduceTransparency: true) == .solid, "Reduce Transparency")
        #expect(NotchBackdrop.look(drawn: .expanded, rendering: .material, raised: true, reduceTransparency: false) == .solid, "Increase Contrast")
        #expect(NotchBackdrop.look(drawn: .expanded, rendering: .solid, raised: false, reduceTransparency: false) == .solid, "a host that does not ask")
    }

    /// x23f: the fold mirrors the grow. Folding out of the expanded island the body stays frosted while the animated
    /// expansion is above 0, so only the fully folded notch is solid; folding out of the idle island stays solid.
    @Test func theFrostHoldsWhileTheIslandFolds() {
        func look(_ drawn: NotchDrawn, _ lastOpen: NotchDrawn?, _ e: Double, rendering: NotchBackdrop.Rendering = .material,
                  raised: Bool = false, rt: Bool = false) -> NotchBackdrop.Look {
            NotchBackdrop.look(drawn: drawn, lastOpen: lastOpen, expansion: e, rendering: rendering, raised: raised, reduceTransparency: rt)
        }
        for e in [0.8, 0.3, 0.01] { #expect(look(.folded, .expanded, e) == .frosted, "mid-fold at \(e): still frosted") }
        #expect(look(.nothing, .expanded, 0.5) == .frosted, "folding into nothing as well")
        #expect(look(.folded, .expanded, 0) == .solid, "fully folded: solid black")
        #expect(look(.folded, .idle, 0.8) == .solid && look(.folded, nil, 0.8) == .solid, "the idle island folds solid")
        #expect(look(.expanded, .expanded, 0.2) == .frosted && look(.expanded, nil, 0) == .frosted, "the grow, as before")
        #expect(look(.idle, .expanded, 1) == .solid, "an open idle island is solid whatever came before")
        #expect(look(.folded, .expanded, 0.8, raised: true) == .solid && look(.folded, .expanded, 0.8, rt: true) == .solid, "Increase Contrast, Reduce Transparency")
        #expect(look(.folded, .expanded, 0.8, rendering: .solid) == .solid, "a host that does not ask")
    }

    /// The overlay is black to the notch band, then fades; while the island grows the stops stay at their points.
    @Test func theOverlayIsBlackToTheBandThenFades() {
        let frost = NotchConfiguration.Frost()
        #expect(frost.overlay == [NotchStop(0, 1), NotchStop(0.15, 1), NotchStop(0.82, 0.46 * 0.55), NotchStop(1, 0.34 * 0.55)])
        #expect(frost.overlayOpacity(at: 0.1) == 1 && frost.overlayOpacity(at: 1) == 0.34 * 0.55)
        #expect(abs(frost.overlayOpacity(at: 0.485) - (1 + 0.46 * 0.55) / 2) < 0.001, "halfway down the fade")
        let full = NotchBackdrop.overlayStops(height: 288, expandedHeight: 288)
        #expect(full.map(\.location) == [0, 0.15, 0.82, 1] && full.map(\.opacity) == [1, 1, 0.46 * 0.55, 0.34 * 0.55])
        let half = NotchBackdrop.overlayStops(height: 144, expandedHeight: 288)
        #expect(half.map(\.location) == [0, 0.3, 1] && abs(half[2].opacity - frost.overlayOpacity(at: 0.5)) < 1e-9)
        // Floating and settled, with no bleed: the flat tint; docked and settled: the docked stops whatever the bleed.
        #expect(NotchBackdrop.overlayStops(height: 288, expandedHeight: 288, floating: true, bleed: 0, morph: 1).map(\.opacity) == [0.42, 0.42])
        #expect(NotchBackdrop.overlayStops(height: 288, expandedHeight: 288, floating: false, bleed: 0.5, morph: 1).map(\.location) == full.map(\.location))
    }

    /// Another client's frost: the stops follow its configuration, not the defaults.
    @Test func aClientsFrostDrivesTheStops() {
        let frost = NotchConfiguration.Frost(overlay: [NotchStop(0, 0.8), NotchStop(1, 0.2)])
        let stops = NotchBackdrop.overlayStops(height: 100, expandedHeight: 100, frost: frost)
        #expect(stops.map(\.location) == [0, 1] && stops[0].opacity == 0.8 && abs(stops[1].opacity - 0.2) < 1e-9)
        var appearance = NotchConfiguration.Appearance()
        appearance.floating.overlay = 0.3
        #expect(NotchBackdrop.overlayStops(height: 288, expandedHeight: 288, floating: true, bleed: 0, morph: 1, appearance: appearance).map(\.opacity) == [0.3, 0.3])
    }

    /// The shadow is always applied, nothing docked, so the fill keeps its identity across a flip.
    @Test func dockedTheShadowIsZeroNotRemoved() {
        let shadow = NotchConfiguration.Floating().shadow
        let docked = NotchFloatShadow.values(on: false, amount: 1)
        #expect(docked.opacity == 0 && docked.radius == 0 && docked.y == 0)
        let half = NotchFloatShadow.values(on: true, amount: 0.5)
        #expect(half.opacity == 0.5 && half.radius == shadow.radius / 2)
        let full = NotchFloatShadow.values(on: true, amount: 1.4)
        #expect(full.opacity == 1 && full.y == shadow.y, "the spring's overshoot never passes the configured shadow")
    }

    @Test func theModifierHasNoBranch() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/NotchKit/NotchBackdrop.swift")
        let source = try String(contentsOf: file, encoding: .utf8)
        let body = try #require(source.range(of: "struct NotchFloatShadow").map { String(source[$0.lowerBound...].prefix(1400)) })
        #expect(!body.contains("if on {"), "no identity-changing branch in the shadow modifier")
    }

    @Test func dockedTheGripSitsBehindTheNotchUntilShown() {
        #expect(NotchGrip.dockedTop(band: 38, shown: true, reduceMotion: false) == 36, "just below the band")
        #expect(NotchGrip.dockedTop(band: 38, shown: false, reduceMotion: false) == 13, "up inside the band, behind the notch")
        #expect(NotchGrip.dockedTop(band: 38, shown: false, reduceMotion: true) == 36, "Reduce Motion: it fades where it shows")
        #expect(NotchGripDots.size == CGSize(width: 12.5, height: 7.5))
    }

    /// NotchKit draws its one material from the configuration: the ultra-thin by default.
    @Test func theDefaultFrostIsTheUltraThinMaterial() throws {
        #expect(NotchConfiguration().appearance.frost.material == .ultraThin)
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/NotchKit")
        for f in try FileManager.default.contentsOfDirectory(at: file, includingPropertiesForKeys: nil) where f.lastPathComponent != "NotchBackdrop.swift" {
            let text = try String(contentsOf: f, encoding: .utf8)
            for b in ["Material)", "Material {", ".ultraThinMaterial", ".thinMaterial", ".regularMaterial", ".thickMaterial", "NSVisualEffectView"] {
                #expect(!text.contains(b), "\(f.lastPathComponent) uses \(b): the backdrop is NotchKit's only material")
            }
        }
    }
}

/// The configuration's defaults are the shipped look, and its words are the controls'.
@Suite struct NotchConfigurationTests {
    @Test func theDefaultsAreTheShippedLook() {
        let a = NotchConfiguration().appearance
        #expect(a.fill == NotchColor(hex: 0x000000) && a.frost.tint == NotchColor(r: 18 / 255, g: 18 / 255, b: 20 / 255, a: 0.12))
        #expect(a.floating.overlay == 0.42 && a.floating.border == NotchColor(r: 1, g: 1, b: 1, a: 0.14))
        #expect(a.floating.shadow == NotchShadow(color: NotchColor(r: 0, g: 0, b: 0, a: 0.16), radius: 8, x: 0, y: 6))
        #expect(a.handle.lineRest.a == 0.28 && a.handle.lineHover.a == 0.70 && a.handle.gripRest.a == 0.35 && a.handle.gripHover.a == 0.85)
        #expect(a.glow.start == NotchColor(hex: 0xD9704F) && a.glow.end == NotchColor(hex: 0xF2B65A) && a.glow.offOutline == 0.85)
        #expect(NotchConfiguration().motion == NotchConfiguration.Motion(glowSweep: .milliseconds(1600), glowTurn: 6))
        #expect(NotchConfiguration().debug.glowCalibration == nil, "no debug switch unless the client passes one")
    }

    @Test func theStringsNameTheControls() {
        let s = NotchConfiguration.Strings()
        #expect(s.height == "Island height" && s.heightValue(287.6) == "288 points" && s.move == "Move island" && s.dock == "Dock")
        #expect(NotchCorner.allCases.map(s.corner) == ["Top Left", "Top Right", "Bottom Left", "Bottom Right"])
        var other = s
        other.heightUnit = "pt"
        #expect(other.heightValue(100) == "100 pt")
    }

    @Test func aHexColourIsItsComponents() {
        #expect(NotchColor(hex: 0xFF8000, alpha: 0.5) == NotchColor(r: 1, g: 128.0 / 255, b: 0, a: 0.5))
    }
}
