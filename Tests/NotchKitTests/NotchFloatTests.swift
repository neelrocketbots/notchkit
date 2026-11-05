import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

/// Drag the island anywhere (owner decisions 2026-11-04, `.worktrees/_bench/island-mockups/DECISIONS.md` § Position).
@Suite struct NotchFloatRuleTests {
    private let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 220, height: 38), isMain: true,
                                  isBuiltIn: true, menuBarHeight: 38, visibleInsets: NotchVisibleInsets(bottom: 70))

    /// Always fully on screen: never under the menu bar or the Dock, never past an edge.
    @Test func aFloatingIslandStaysInsideTheVisibleRect() {
        let visible = display.visibleRect
        #expect(visible == CGRect(x: 0, y: 38, width: 1512, height: 982 - 38 - 70))
        let r = NotchFloat.clamp(CGRect(x: -50, y: 0, width: 480, height: 288), in: visible)
        #expect(r == CGRect(x: 0, y: 38, width: 480, height: 288))
        let low = NotchFloat.clamp(CGRect(x: 1400, y: 900, width: 480, height: 288), in: visible)
        #expect(low.maxX == 1512 && low.maxY == 982 - 70)
    }

    /// The pill opens downward from where it sits, or upward near the bottom of the screen.
    @Test func theExpandedIslandOpensAwayFromTheBottom() {
        let visible = display.visibleRect
        let size = CGSize(width: 480, height: 288)
        let high = NotchFloat.expandedRect(anchor: CGPoint(x: 700, y: 200), size: size, visible: visible)
        #expect(high.minY == 200 && high.midX == 700)
        let low = NotchFloat.expandedRect(anchor: CGPoint(x: 700, y: 850), size: size, visible: visible)
        #expect(low.maxY == visible.maxY && low.minY < 850, "near the bottom it opens upward")
    }

    /// It docks only when its top edge is pressed against the screen's top while it overlaps the notch.
    @Test func itDocksOnlyTouchingTheTopUnderTheNotch() {
        // the notch spans 646…866
        #expect(NotchFloat.touchesDock(proposedTop: 20, left: 600, right: 1080, display: display, notchWidth: 220))
        #expect(!NotchFloat.touchesDock(proposedTop: 56, left: 600, right: 1080, display: display, notchWidth: 220), "18 pt short of the edge: floats")
        #expect(!NotchFloat.touchesDock(proposedTop: 10, left: 900, right: 1380, display: display, notchWidth: 220), "beside the notch: floats")
    }

    /// The position is saved as fractions of the visible rect, so it survives a resolution change.
    @Test func thePositionIsKeptAsFractions() {
        let visible = display.visibleRect
        let anchor = CGPoint(x: 400, y: 300)
        let origin = NotchFloat.origin(of: anchor, visible: visible)
        #expect((0...1).contains(origin.x) && (0...1).contains(origin.y))
        let back = NotchFloat.anchor(of: origin, visible: visible)
        #expect(abs(back.x - 400) < 0.001 && abs(back.y - 300) < 0.001)
        let bigger = CGRect(x: 0, y: 25, width: 1920, height: 1055)
        let moved = NotchFloat.anchor(of: origin, visible: bigger)
        #expect(bigger.contains(moved))
    }

    /// The pill's corners are a capsule, the card's 26 pt.
    @Test func theCornersGoFromCapsuleTo26() {
        #expect(NotchFloat.cornerRadius(expansion: 0) == 15 && NotchFloat.cornerRadius(expansion: 1) == 26)
        #expect(NotchFloat.pillSize == CGSize(width: 132, height: 30) && NotchFloat.dragThreshold == 6)
    }

    /// The floating geometry: the island sits a margin down in a taller panel, no shoulders, the pill its hover target.
    @Test func theFloatingGeometry() {
        let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38)
        let f = g.floating(pillOffset: CGSize(width: 0, height: 40))
        #expect(f.isFloating && f.islandTop == NotchFloat.margin && f.panelSize.height == g.panelSize.height + NotchFloat.margin)
        #expect(f.collapsedRect.size == NotchFloat.pillSize && f.collapsedRect.minY == NotchFloat.margin + 40 && f.hoverTarget == f.collapsedRect)
        #expect(Double(f.collapsedRect.midX) == Double(f.panelSize.width) / 2)
    }
}


/// #124 review P3-6 (must-fix): settings' island maps never trap. A bad, signed, zero-padded or out-of-range key, a NaN,
/// infinite, zero, negative or absurd height, or an origin with a non-finite fraction drops only that entry.
@Suite struct NotchStoredPrefsTests {
    @Test func badKeysAndValuesAreSkippedNeverTrap() {
        let prefs = NotchLayoutPrefs(
            storedHeights: ["1": 400, "+1": 500, "01": 600, "-2": 300, "x": 300, "4294967296": 300, "5": .nan, "6": .infinity,
                            "7": 0, "8": -10, "9": 1e9, "10": 520],
            storedOrigins: ["1": NotchOrigin(x: 0.2, y: 0.3), "+1": NotchOrigin(x: 0.9, y: 0.9), "2": NotchOrigin(x: .nan, y: 0.5),
                            "3": NotchOrigin(x: 1.5, y: -0.2), "": NotchOrigin(x: 0.5, y: 0.5)])
        #expect(prefs.heights == [1: 400, 10: 520], "only canonical keys with finite, positive, sane heights: \(prefs.heights)")
        #expect(prefs.origins == [1: NotchOrigin(x: 0.2, y: 0.3), 3: NotchOrigin(x: 1, y: 0)], "non-finite skipped, out of range clamped")
        #expect(NotchLayoutPrefs.displayID("1") == 1 && NotchLayoutPrefs.displayID("+1") == nil && NotchLayoutPrefs.displayID("01") == nil)
        #expect(NotchLayoutPrefs.displayID("4294967295") == UInt32.max && NotchLayoutPrefs.displayID(" 1") == nil)
    }

    @Test func theStoredMapsRoundTrip() {
        let prefs = NotchLayoutPrefs(heights: [1: 400, 5: 300], origins: [5: NotchOrigin(x: 0.5, y: 0.5)])
        #expect(NotchLayoutPrefs(storedHeights: prefs.storedHeights, storedOrigins: prefs.storedOrigins) == prefs)
        #expect(prefs.storedHeights == ["1": 400, "5": 300])
    }
}
