import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

/// Snap and unsnap, variation C (owner 2026-11-04): squash and stretch on the island's own view.
@Suite struct NotchDockMotionRuleTests {
    @Test func theStretchIsTheMockupsSquash() {
        #expect(NotchDockMotion.scale(stretch: 0) == CGSize(width: 1, height: 1))
        let full = NotchDockMotion.scale(stretch: 1)
        #expect(abs(full.width - 0.96) < 1e-9 && abs(full.height - 1.06) < 1e-9)
        let over = NotchDockMotion.scale(stretch: -0.3)
        #expect(over.width > 1 && over.height < 1, "the overshoot squashes the other way")
    }

    /// Floating, there are never shoulders (so the docked shape never shows at the floating spot); the top corners go from
    /// 6 pt to the card's 26. Docked, the shoulders grow back and the top squares off.
    @Test func theOutlineMorphsWithoutADockedShapeAtTheFloatingSpot() {
        let f0 = NotchDockMotion.outline(floating: true, expansion: 1, morph: 0)
        #expect(f0.shoulder == 0 && f0.topRadius == 6 && f0.bottomRadius == 26)
        let f1 = NotchDockMotion.outline(floating: true, expansion: 1, morph: 1)
        #expect(f1.shoulder == 0 && f1.topRadius == 26)
        let fOver = NotchDockMotion.outline(floating: true, expansion: 1, morph: 1.2)
        #expect(fOver.topRadius == 26, "the spring's overshoot never passes the settled shape")
        let d0 = NotchDockMotion.outline(floating: false, expansion: 1, morph: 0)
        #expect(d0.shoulder == 0 && d0.topRadius == 6)
        let d1 = NotchDockMotion.outline(floating: false, expansion: 1, morph: 1)
        #expect(d1.shoulder == 12 && d1.topRadius == 0 && d1.bottomRadius == 26)
        #expect(NotchDockMotion.outline(floating: false, expansion: 0, morph: 0).topRadius == 0, "the folded notch keeps a square top")
    }

    @Test func theDragDrivesTheStretch() {
        #expect(NotchDockMotion.pullStretch(distance: 0) == 0 && NotchDockMotion.pullStretch(distance: 3) == 0.5)
        #expect(NotchDockMotion.pullStretch(distance: 12) == 1)
        #expect(NotchDockMotion.pushStretch(proposedTop: 200, dockTop: 38) == 0)
        #expect(NotchDockMotion.pushStretch(proposedTop: 58, dockTop: 38) == 0.5)
        #expect(NotchDockMotion.pushStretch(proposedTop: 20, dockTop: 38) == 1)
    }
}


/// #124 review P3-1: the stretch stays inside the panel's margin below the island: at most 12 pt of extra height.
@Suite struct NotchStretchCapTests {
    @Test func aTallIslandStretchesAtMostTwelvePoints() {
        let short = NotchDockMotion.scale(stretch: 1, height: 100)
        #expect(abs(short.height - 1.06) < 1e-9, "a short island: the full 6 %")
        let tall = NotchDockMotion.scale(stretch: 1, height: 600)
        #expect(abs((tall.height - 1) * 600 - NotchDockMotion.maxStretchPoints) < 1e-9, "a tall one: 12 pt, not 36")
        #expect(NotchDockMotion.maxStretchPoints < NotchGeometry.outset + NotchGeometry.blur + NotchGeometry.overshoot - NotchGeometry.outset,
                "inside the panel's bottom margin, less the glow's own room")
        let over = NotchDockMotion.scale(stretch: -0.5, height: 600)
        #expect(over.height < 1 && over.height > 0.98, "the overshoot's squash scales the same way")
    }
}


/// The notch's black bleeding into a floating island as it nears the notch: proximity → bleed, and the ink.
@Suite struct NotchBleedRuleTests {
    @Test func proximityMapsToBleed() {
        let dockTop = 38.0
        #expect(NotchDockMotion.bleed(proposedTop: 300, dockTop: dockTop) == 0, "far: none")
        #expect(NotchDockMotion.bleed(proposedTop: dockTop + NotchDockMotion.bleedReach, dockTop: dockTop) == 0, "at the reach's edge: none")
        #expect(abs(NotchDockMotion.bleed(proposedTop: dockTop + 20, dockTop: dockTop) - 0.225) < 1e-9,
                "near (20 pt): faint, eased in (owner 2026-11-05: more subtle)")
        #expect(NotchDockMotion.bleed(proposedTop: dockTop + 0.5, dockTop: dockTop) < NotchDockMotion.nearCap,
                "a hair away: still under the cap; only contact is full")
        #expect(NotchDockMotion.bleed(proposedTop: dockTop, dockTop: dockTop) == 1, "touching: full")
        #expect(NotchDockMotion.bleed(proposedTop: 0, dockTop: dockTop) == 1, "pushed past the top: still full")
        var last = 0.0
        for top in stride(from: dockTop + 60, through: dockTop, by: -2) {
            let b = NotchDockMotion.bleed(proposedTop: top, dockTop: dockTop)
            #expect(b >= last, "the bleed only grows as the top nears the notch")
            last = b
        }
    }


    /// Before contact the ink is shallow and faint (at most 60 % of the band's depth, 70 % of the way to black); it grows
    /// on, continuously, into the docked look only between the cap and contact.
    @Test func theInkIsSubtleUntilContact() {
        let none = NotchDockMotion.ink(bleed: 0), cap = NotchDockMotion.ink(bleed: NotchDockMotion.nearCap)
        let full = NotchDockMotion.ink(bleed: 1)
        #expect(none.depth == 0 && none.strength == 0)
        #expect(abs(cap.depth - 0.6) < 1e-9 && abs(cap.strength - 0.7) < 1e-9)
        #expect(full.depth == 1 && full.strength == 1)
        var last = none
        for b in stride(from: 0.0, through: 1, by: 0.01) {
            let i = NotchDockMotion.ink(bleed: b)
            #expect(i.depth >= last.depth - 1e-12 && i.strength >= last.strength - 1e-12)
            #expect(i.depth - last.depth < 0.05 && i.strength - last.strength < 0.05, "continuous at \(b): no pop at contact")
            last = i
        }
    }

}
