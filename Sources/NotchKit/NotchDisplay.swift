import CoreGraphics
import Foundation

/// A display's hardware notch, in points.
public struct Notch: Sendable, Equatable {
    public var width: Double
    public var height: Double
    public init(width: Double, height: Double) { self.width = width; self.height = height }
}

/// A display in points, top-left origin at the main display.
public struct NotchDisplay: Sendable, Equatable {
    public var id: UInt32
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    /// The hardware notch; only on a `.notch` display.
    public var notch: Notch?
    public var isMain: Bool
    /// The Mac's own screen (`CGDisplayIsBuiltin`).
    public var isBuiltIn: Bool
    /// The menu bar's height: a virtual notch's height on a plain display, the panel's top on a Dynamic Island one.
    public var menuBarHeight: Double
    public var kind: NotchDisplayKind
    /// The screen takes touch (`NSScreen.touchCapabilities`, macOS 27).
    public var multiTouch: Bool
    /// What the Dock takes from the display's edges (`NSScreen.visibleFrame` against `frame`, the menu bar aside).
    public var visibleInsets: NotchVisibleInsets

    /// A nil `kind` follows the notch (`.notch` with one, else `.plain`).
    public init(id: UInt32, x: Double, y: Double, width: Double, height: Double, notch: Notch?, isMain: Bool,
                isBuiltIn: Bool = false, menuBarHeight: Double = 24, kind: NotchDisplayKind? = nil, multiTouch: Bool = false,
                visibleInsets: NotchVisibleInsets = NotchVisibleInsets()) {
        self.id = id; self.x = x; self.y = y; self.width = width; self.height = height
        self.notch = notch; self.isMain = isMain
        self.isBuiltIn = isBuiltIn; self.menuBarHeight = menuBarHeight
        self.kind = kind ?? (notch != nil ? .notch : .plain)
        self.multiTouch = multiTouch
        self.visibleInsets = visibleInsets
    }

    /// The part of the display a floating island may use, in the same top-left points: below the menu bar, clear of the
    /// Dock.
    public var visibleRect: CGRect {
        let i = visibleInsets
        let w: Double = width - i.left - i.right
        let h: Double = height - menuBarHeight - i.bottom
        return CGRect(x: x + i.left, y: y + menuBarHeight, width: w, height: h)
    }
}

/// The Dock's share of a display's left, bottom and right edges (0 where it is not, or hidden).
public struct NotchVisibleInsets: Sendable, Equatable {
    public var left: Double
    public var bottom: Double
    public var right: Double
    public init(left: Double = 0, bottom: Double = 0, right: Double = 0) { self.left = left; self.bottom = bottom; self.right = right }
}

/// What sits at the top of a display: a hardware notch, a Dynamic Island camera cutout (no notch, a touchscreen), or
/// nothing (an external display, a Mac without a notch).
public enum NotchDisplayKind: String, Sendable, Equatable, CaseIterable {
    case notch, dynamicIsland, plain

    /// A gap between the auxiliary top areas narrower than this is a camera cutout, not a notch (which measures 185–220 pt).
    public static let minNotchGap: Double = 100

    /// The one rule, in order: an external display is plain (touch or not, it has no camera island); a built-in touch
    /// display is a Dynamic Island one; a built-in with a safe area that is not split by a notch-wide gap is too; a
    /// built-in with that gap has a notch; anything else is plain.
    public static func classify(isBuiltIn: Bool, safeAreaTop: Double, auxiliaryLeftWidth: Double?, auxiliaryRightWidth: Double?,
                                screenWidth: Double, multiTouch: Bool) -> NotchDisplayKind {
        guard isBuiltIn else { return .plain }
        if multiTouch { return .dynamicIsland }
        guard safeAreaTop > 0 else { return .plain }
        guard let left = auxiliaryLeftWidth, let right = auxiliaryRightWidth, screenWidth - left - right >= minNotchGap else {
            return .dynamicIsland
        }
        return .notch
    }
}
