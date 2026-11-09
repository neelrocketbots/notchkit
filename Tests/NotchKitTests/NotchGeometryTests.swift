import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

@Suite struct NotchGeometryTests {
    /// Every size derives from the notch; a 14" (220 × 38) gives 480 × 288 expanded, 480 × 200 idle; corners 9 → 26, shoulders 6 → 12.
    @Test func sizesDeriveFromTheNotch() {
        let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 24)
        #expect(g.hasHardwareNotch && g.notch == CGSize(width: 220, height: 38))
        #expect(g.expandedSize == CGSize(width: 480, height: 288) && g.idleSize == CGSize(width: 480, height: 200))
        #expect(g.panelSize == CGSize(width: 584, height: 340))
        #expect(g.collapsedRect == CGRect(x: (584 - 220) / 2, y: 0, width: 220, height: 38) && g.hoverTarget == g.collapsedRect)
        #expect(NotchGeometry.cornerRadius(expansion: 0) == 9 && NotchGeometry.cornerRadius(expansion: 1) == 26 && NotchGeometry.cornerRadius(expansion: 0.5) == 17.5)
        #expect(NotchGeometry.shoulder(expansion: 0) == 0 && NotchGeometry.shoulder(expansion: 1) == 12, "Folded is the notch, no flare")
        let thirteen = NotchGeometry.make(notch: Notch(width: 200, height: 32), builtInNotchWidth: 200, menuBarHeight: 24)
        #expect(thirteen.expandedSize == CGSize(width: 460, height: 282) && thirteen.expandedSize.height / 956 < 0.3, "within the top 30% of the 13.6\" Air's 956 pt")
        #expect(g.bodyRect == CGRect(x: 52 + 12, y: 38 + 2, width: 480 - 24, height: 288 - 38 - 2 - 8), "the body: inset 12 from the island's edge, 2 under the band, 8 above the bottom, in panel coordinates")
        #expect(NotchGeometry.fallback == NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24))
    }


    /// From IslandViewTests: the collapsed cover is the notch rect itself, 9 pt corners, no inset.
    @Test func theCollapsedCoverIsTheNotchRect() {
        let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38)
        #expect(g.collapsedRect.size == CGSize(width: 220, height: 38) && g.collapsedRect.minY == 0 && g.collapsedRect.midX == g.panelSize.width / 2)
        #expect(NotchGeometry.make(notch: nil, builtInNotchWidth: 220, menuBarHeight: 24).collapsedRect == .zero, "a plain display folds to nothing")
    }


    /// A plain display gets a virtual notch (the built-in's width, else 200) × the menu bar height; folded draws nothing; the strip is the hover target.
    @Test func aPlainDisplayGetsAVirtualNotchAndAStrip() {
        let g = NotchGeometry.make(notch: nil, builtInNotchWidth: 220, menuBarHeight: 25)
        #expect(!g.hasHardwareNotch && g.notch == CGSize(width: 220, height: 25) && g.expandedSize == CGSize(width: 480, height: 275))
        #expect(g.collapsedRect == .zero && g.hoverTarget == CGRect(x: (g.panelSize.width - 220) / 2, y: 0, width: 220, height: 7))
        let noBuiltIn = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24)
        #expect(noBuiltIn.notch == CGSize(width: 200, height: 24) && noBuiltIn.hoverTarget.width == 200)
    }


    /// A Dynamic Island display gets its own pill under the system island: 200 × 32, its top 6 pt below the menu bar, expanded by the notch's +260/+250 and, on touch, +26 pt per ear; the notch and plain numbers are unchanged.
    @Test func aDynamicIslandDisplayGetsAPillUnderTheSystemIsland() {
        let g = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, touch: true)
        #expect(g.kind == .dynamicIsland && !g.hasHardwareNotch && g.touch && g.position == .centre, "Centre is the default")
        #expect(g.notch == CGSize(width: 200, height: 32) && g.expandedSize == CGSize(width: 460 + 52, height: 282))
        #expect(g.panelTop == 37 && g.islandTop == 6, "the panel starts at the menu bar's bottom edge, the pill 6 pt below it")
        #expect(g.panelSize == CGSize(width: 616, height: 6 + 282 + 52))
        #expect(g.collapsedRect == CGRect(x: (616 - 200) / 2, y: 6, width: 200, height: 32) && g.hoverTarget == g.collapsedRect, "the folded pill, never filled, is the target")
        #expect(g.bodyRect == CGRect(x: 52 + 12, y: 6 + 32 + 2, width: 512 - 24, height: 282 - 32 - 2 - 8))
        #expect(NotchGeometry.pillSize == CGSize(width: 200, height: 32) && NotchGeometry.pillGap == 6)
        #expect(NotchGeometry.pillCornerRadius(expansion: 0) == 16 && NotchGeometry.pillCornerRadius(expansion: 1) == 26, "a capsule folded, the notch island's 26 pt expanded")
        let notched = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38)
        #expect(notched.kind == .notch && notched.panelTop == 0 && notched.islandTop == 0 && !notched.touch)
        #expect(NotchGeometry.make(notch: nil, builtInNotchWidth: 220, menuBarHeight: 25).kind == .plain)
    }


    /// Position docks the pill and the expanded island at the same top: Centre on the camera, Left 12 pt from the left edge (growing right), Right 12 pt from the right edge (growing left); a notch ignores it.
    @Test func thePillDocksCentreLeftOrRight() {
        #expect(NotchDockPosition.allCases == [.centre, .left, .right] && NotchGeometry.dockInset == 12)
        let centre = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, position: .centre)
        #expect(centre.collapsedRect.midX == 564 / 2 && centre.islandRect(size: centre.expandedSize) == CGRect(x: 52, y: 6, width: 460, height: 282))
        let left = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, position: .left)
        #expect(left.collapsedRect == CGRect(x: 12, y: 6, width: 200, height: 32) && left.hoverTarget == left.collapsedRect)
        #expect(left.islandRect(size: left.expandedSize) == CGRect(x: 12, y: 6, width: 460, height: 282) && left.bodyRect.minX == 12 + 12, "it grows right and down from the pill's corner")
        let right = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, position: .right)
        #expect(right.collapsedRect == CGRect(x: 564 - 12 - 200, y: 6, width: 200, height: 32))
        #expect(right.islandRect(size: right.expandedSize) == CGRect(x: 564 - 12 - 460, y: 6, width: 460, height: 282), "it grows left and down")
        #expect(NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38, position: .left).collapsedRect.midX == CGFloat(584) / 2, "Position is the Dynamic Island display's alone")
    }


    /// A hidden menu bar (auto-hide, a full-screen Space, a display without one) reads 0 pt: the band keeps 24 pt and a
    /// Dynamic Island display's pill stays below where the menu bar would be, never over Apple's island.
    @Test func aMissingMenuBarStillGivesABand() {
        #expect(NotchGeometry.minMenuBarHeight == 24)
        let plain = NotchGeometry.make(notch: nil, builtInNotchWidth: 220, menuBarHeight: 0)
        #expect(plain.notch == CGSize(width: 220, height: 24) && plain.expandedSize.height == 274 && plain.bodyRect.minY == 24 + 2)
        let di = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 0, dynamicIsland: true)
        #expect(di.panelTop == 24, "never over Apple's island")
        #expect(NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true).panelTop == 37, "a real bar is kept")
    }


    /// The nested-radius rule: inner = outer − the gap, floored at 6.
    @Test func nestedRadiiFollowTheGap() {
        #expect(NotchGeometry.nested(outer: 26, inset: 18) == 8 && NotchGeometry.nested(outer: 10, inset: 8) == NotchGeometry.minNestedRadius)
        #expect(NotchGeometry.minNestedRadius == 6)
    }

    /// A touch display's hit areas are at least 36 pt round an unchanged drawing.
    @Test func touchHitAreasAreThirtySixPoints() {
        #expect(NotchGeometry.minTouchTarget == 36)
        #expect(NotchGeometry.hitSize(26, touch: true) == 36 && NotchGeometry.hitSize(26, touch: false) == 26 && NotchGeometry.hitSize(40, touch: true) == 40)
    }
}
