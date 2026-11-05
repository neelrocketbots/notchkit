import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

/// Drag the bottom edge to resize: the pure rules.
@Suite struct NotchResizeTests {
    private let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38)

    /// Resizing changes the expanded height only: the width, the idle island and the folded notch keep their sizes, and the
    /// panel and the body grow with it, the top fixed.
    @Test func resizingChangesTheExpandedHeightOnly() {
        let r = g.resized(toHeight: 440)
        #expect(r.expandedSize == CGSize(width: 480, height: 440))
        #expect(r.idleSize == g.idleSize && r.collapsedRect == g.collapsedRect && r.hoverTarget == g.hoverTarget)
        #expect(r.panelSize == CGSize(width: g.panelSize.width, height: g.panelSize.height + 152))
        #expect(r.bodyRect.minY == g.bodyRect.minY && r.bodyRect.height == g.bodyRect.height + 152)
        #expect(r.defaultExpandedHeight == 288, "the default stays the notch's")
        #expect(g.resized(toHeight: 288) == g)
    }


    /// The maximum leaves 80 pt clear above the Dock; never under the minimum.
    @Test func theMaximumLeaves80PointsAboveTheDock() {
        let minimum = 210.0
        let display = NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 220, height: 38), isMain: true,
                              isBuiltIn: true, menuBarHeight: 38, visibleInsets: NotchVisibleInsets(left: 0, bottom: 70, right: 0))
        #expect(NotchResize.maxHeight(top: 0, display: display, min: minimum) == 982 - 70 - 80)
        #expect(NotchResize.maxHeight(top: 600, display: display, min: minimum) == 982 - 70 - 80 - 600)
        #expect(NotchResize.maxHeight(top: 800, display: display, min: minimum) == minimum, "never below the minimum")
    }


    /// Past the minimum the edge resists (about 12 pt of travel at most), then springs back on release; Reduce Motion stops
    /// it at the minimum. The maximum is a hard stop.
    @Test func belowTheMinimumTheEdgeRubberBands() {
        let min = 210.0, max = 800.0
        #expect(NotchResize.live(proposed: 300, min: min, max: max, reduceMotion: false) == 300)
        let pulled = NotchResize.live(proposed: 150, min: min, max: max, reduceMotion: false)
        #expect(pulled < min && pulled > min - NotchResize.rubberBand, "resists, never more than 12 pt")
        #expect(NotchResize.live(proposed: 0, min: min, max: max, reduceMotion: false) > min - NotchResize.rubberBand)
        #expect(NotchResize.live(proposed: 205, min: min, max: max, reduceMotion: false) > 205, "a little resistance at once")
        #expect(NotchResize.live(proposed: 150, min: min, max: max, reduceMotion: true) == min, "Reduce Motion: no rubber band")
        #expect(NotchResize.live(proposed: 900, min: min, max: max, reduceMotion: false) == max)
        #expect(NotchResize.settled(150, min: min, max: max) == min && NotchResize.settled(900, min: min, max: max) == max)
    }


    /// VoiceOver's adjustable height: ↑/↓ change it by 40 pt, inside the limits.
    @Test func theAdjustableStepIs40Points() {
        #expect(NotchResize.step == 40)
        #expect(NotchResize.stepped(300, by: 1, min: 210, max: 800) == 340)
        #expect(NotchResize.stepped(230, by: -1, min: 210, max: 800) == 210)
        #expect(NotchResize.stepped(790, by: 1, min: 210, max: 800) == 800)
    }

}
