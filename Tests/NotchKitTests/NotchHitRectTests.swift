import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

@Suite struct NotchHitRectTests {
    @Test func thePointerCountsOnlyOverTheIslandPlusAMargin() {
        let island = CGRect(x: 100, y: 800, width: 404, height: 160)   // screen coordinates
        #expect(NotchHitRect.contains(point: CGPoint(x: 300, y: 900), islandRect: island, margin: 6))
        #expect(NotchHitRect.contains(point: CGPoint(x: 96, y: 900), islandRect: island, margin: 6), "within the margin")
        #expect(!NotchHitRect.contains(point: CGPoint(x: 90, y: 900), islandRect: island, margin: 6))
        #expect(!NotchHitRect.contains(point: CGPoint(x: 300, y: 700), islandRect: island, margin: 6),
                "the transparent panel below the island passes clicks through")
        #expect(!NotchHitRect.contains(point: CGPoint(x: 300, y: 900), islandRect: .zero, margin: 6), "no island yet")
    }


    /// A pointer pushed against the top of the screen sits exactly on the hover target's top edge: it counts; 1 pt
    /// beyond any edge does not.
    @Test func theHitRectIncludesItsEdges() {
        let notch = CGRect(x: 656, y: 982 - 39, width: 200, height: 39)   // screen top at y = 982
        #expect(NotchHitRect.contains(point: CGPoint(x: 756, y: 982), islandRect: notch, margin: 0), "on maxY (the screen top)")
        #expect(!NotchHitRect.contains(point: CGPoint(x: 756, y: 983), islandRect: notch, margin: 0), "1 pt above maxY")
        #expect(NotchHitRect.contains(point: CGPoint(x: 756, y: 943), islandRect: notch, margin: 0), "on minY")
        #expect(!NotchHitRect.contains(point: CGPoint(x: 756, y: 942), islandRect: notch, margin: 0), "1 pt below minY")
        #expect(NotchHitRect.contains(point: CGPoint(x: 856, y: 960), islandRect: notch, margin: 0), "on maxX")
        #expect(!NotchHitRect.contains(point: CGPoint(x: 857, y: 960), islandRect: notch, margin: 0), "1 pt beyond maxX")
        #expect(NotchHitRect.contains(point: CGPoint(x: 656, y: 982), islandRect: notch, margin: 0), "the top-left corner")
    }


    @Test func theIslandFrameMapsToTheScreen() {
        // The panel's frame in AppKit screen coordinates (bottom-left origin); the island's frame in the hosting view (top-left).
        let panel = CGRect(x: 1000, y: 1329 - 300, width: 440, height: 300)
        let island = CGRect(x: 18, y: 0, width: 404, height: 160)
        #expect(NotchHitRect.screenRect(of: island, inPanel: panel) == CGRect(x: 1018, y: 1329 - 160, width: 404, height: 160))
    }
}
