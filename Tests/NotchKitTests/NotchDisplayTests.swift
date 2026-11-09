import CoreGraphics
import Foundation
import NotchKit
import Testing

@Suite struct NotchDisplayTests {
    /// One pure rule, a case per kind; a display's default kind follows its notch.
    @Test func classifiesEachDisplayKind() {
        // a hardware notch: built in, a safe area, a notch-wide gap between the auxiliary areas (1512 − 646 − 646 = 220)
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 38, auxiliaryLeftWidth: 646, auxiliaryRightWidth: 646, screenWidth: 1512, multiTouch: false) == .notch)
        // a Dynamic Island: built in with the safe area not split, or multi-touch (macOS 27)
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 37, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, screenWidth: 1512, multiTouch: false) == .dynamicIsland)
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 37, auxiliaryLeftWidth: 750, auxiliaryRightWidth: 750, screenWidth: 1512, multiTouch: false) == .dynamicIsland, "a 12 pt gap is the camera cutout, not a notch")
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, screenWidth: 1512, multiTouch: true) == .dynamicIsland, "multi-touch alone")
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 38, auxiliaryLeftWidth: 646, auxiliaryRightWidth: 646, screenWidth: 1512, multiTouch: true) == .dynamicIsland, "a touch built-in is a Dynamic Island display whatever its safe area says")
        // plain: an external display, touch or not; a built-in with no safe area and no touch
        #expect(NotchDisplayKind.classify(isBuiltIn: false, safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, screenWidth: 1920, multiTouch: false) == .plain)
        #expect(NotchDisplayKind.classify(isBuiltIn: false, safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, screenWidth: 1920, multiTouch: true) == .plain, "an external touch screen has no camera island")
        #expect(NotchDisplayKind.classify(isBuiltIn: true, safeAreaTop: 0, auxiliaryLeftWidth: nil, auxiliaryRightWidth: nil, screenWidth: 1440, multiTouch: false) == .plain, "a built-in without a notch")
        #expect(NotchDisplayKind.minNotchGap == 100)
        let plain = NotchDisplay(id: 2, x: 0, y: 0, width: 1920, height: 1080, notch: nil, isMain: true)
        #expect(NotchDisplay(id: 1, x: 0, y: 0, width: 1512, height: 982, notch: Notch(width: 220, height: 38), isMain: true).kind == .notch && plain.kind == .plain && !plain.multiTouch, "a nil kind follows the notch")
    }

    /// The visible rect: below the menu bar, clear of the Dock's edges, in the display's own top-left points.
    @Test func theVisibleRectLeavesTheMenuBarAndTheDock() {
        let d = NotchDisplay(id: 1, x: 100, y: -50, width: 1512, height: 982, notch: nil, isMain: false, menuBarHeight: 38,
                             visibleInsets: NotchVisibleInsets(left: 10, bottom: 70, right: 20))
        #expect(d.visibleRect == CGRect(x: 110, y: -12, width: 1482, height: 874))
        #expect(NotchDisplay(id: 1, x: 0, y: 0, width: 800, height: 600, notch: nil, isMain: true).visibleRect == CGRect(x: 0, y: 24, width: 800, height: 576),
                "no Dock: the menu bar alone (24 pt by default)")
    }

    /// A client's calibration log gets the raw values in one line.
    @Test func aMeasurementReadsAsOneLine() {
        let m = NotchMeasurement(screenWidth: 1512, left: CGRect(x: 0, y: 0, width: 646, height: 38), right: CGRect(x: 866, y: 0, width: 646, height: 38),
                                 safeAreaTop: 38, scale: 2)
        #expect(m.line == "notch from screen width 1512.0 left 0.0…646.0 (646.0) right 866.0…1512.0 (646.0) safeAreaTop 38.0 scale 2.0: notch 220.0 × 38.0")
    }

    /// The real screens: whatever this Mac has, every display is classified, and a notch only on a `.notch` display.
    @MainActor @Test func thisMacsScreensAreConsistent() {
        for d in NotchScreens.displays() {
            #expect((d.notch != nil) == (d.kind == .notch), "display \(d.id)")
            #expect(d.menuBarHeight >= 0 && d.width > 0 && d.height > 0)
        }
    }
}
