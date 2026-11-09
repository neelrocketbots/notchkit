import CoreGraphics
import Foundation

/// Where the island docks on a Dynamic Island display: centred on the camera (the default), or
/// `NotchGeometry.dockInset` from the left or the right edge. A notch or a plain display ignores it.
public enum NotchDockPosition: String, Codable, Sendable, CaseIterable { case centre, left, right }

/// The island's sizes on one display, all derived from its notch: the hardware notch, a plain display's
/// virtual notch or a Dynamic Island display's pill. Rects are in the panel's content, with a
/// top-left origin. A client adds its own sizes in an extension; the island's height past its own (an open reply, a
/// growing field) is the client's `growth` (`panelSize(growth:)`).
public struct NotchGeometry: Equatable, Sendable {
    /// The hardware notch, the virtual notch (the built-in's width, else 200, × the menu bar height) or the 200 × 32 pill.
    public var notch: CGSize
    public var hasHardwareNotch: Bool
    /// notch.w + 260, notch.h + 250.
    public var expandedSize: CGSize
    /// notch.w + 260, 200.
    public var idleSize: CGSize
    /// The expanded island plus room for the glow and the spring's overshoot: + 104 wide, + 52 tall (below the pill's gap).
    public var panelSize: CGSize
    /// The folded island: the notch rect, the pill (never filled), or `.zero` on a plain display (nothing drawn).
    public var collapsedRect: CGRect
    /// Where the pointer peeks the folded island: the notch rect or the pill, else the 1 pt top-centre strip plus 6 pt.
    public var hoverTarget: CGRect
    public var kind: NotchDisplayKind
    /// The display takes touch: hit areas of at least `minTouchTarget`.
    public var touch: Bool
    /// Read only on a Dynamic Island display.
    public var position: NotchDockPosition
    /// The panel's top below the display's top: the menu bar's height on a Dynamic Island display, else 0.
    public var panelTop: Double
    /// The island's top inside the panel: `pillGap` on a Dynamic Island display, `NotchFloat.margin` floating, else 0.
    public var islandTop: Double
    /// Floating: no shoulders, four 26 pt corners, frosted all over; folded, the floating pill.
    public var isFloating = false
    /// Floating, where the folded pill sits off the expanded island's top centre (the expanded island is kept on screen,
    /// so near an edge it opens away from it).
    public var pillOffset: CGSize = .zero

    public static let extraWidth: Double = 260, extraHeight: Double = 250, idleHeight: Double = 200
    /// A touch display's ears are this much wider each, for touch-sized hit areas.
    public static let touchEarExtra: Double = 26
    /// The glow's backlight outset, its blur and the spring's overshoot: the panel's margin round the expanded island.
    public static let outset: Double = 8, blur: Double = 24, overshoot: Double = 20
    public static let plainNotchWidth: Double = 200, stripHeight: Double = 1, stripHoverBelow: Double = 6
    /// The menu bar's height at least: a hidden menu bar (auto-hide, a full-screen Space, a secondary display without
    /// one) reads 0, which would leave a virtual notch no band and put a Dynamic Island display's pill over Apple's island.
    public static let minMenuBarHeight: Double = 24

    /// The bottom corners, 9 pt folded to 26 pt expanded.
    public static func cornerRadius(expansion: Double) -> Double { 9 + 17 * expansion }
    /// The nested-radius rule: a shape inset `inset` inside one with radius `outer` takes `outer − inset`, so the two
    /// curves stay parallel; never under `minNestedRadius` (the inset can exceed the outer radius).
    public static func nested(outer: Double, inset: Double) -> Double { max(minNestedRadius, outer - inset) }
    public static let minNestedRadius: Double = 6
    /// The concave shoulders, none folded (the island is the notch: straight sides, no flare) to 12 pt expanded.
    public static func shoulder(expansion: Double) -> Double { 12 * expansion }

    /// The body is inset 12 pt from the island's outer edge (the shoulders are drawn inside it), from 2 pt below the band
    /// to 8 pt above the bottom.
    public static let bodyInset: Double = 12, bodyTop: Double = 2, bodyBottom: Double = 8
    /// The folded notch's ears during a session: this wide each side of the notch.
    public static let earWidth: Double = 64

    /// The pill under a Dynamic Island display's system island: its folded size, its gap below the menu bar, and how far
    /// Left and Right dock from the display's edge.
    public static let pillSize = CGSize(width: 200, height: 32), pillGap: Double = 6, dockInset: Double = 12
    /// A capsule folded (16 pt on the 32 pt pill), the notch island's 26 pt expanded; continuous.
    public static func pillCornerRadius(expansion: Double) -> Double { 16 + 10 * expansion }

    public static let minTouchTarget: Double = 36
    /// A control's hit area round its unchanged drawing: at least 36 pt on a touch display.
    public static func hitSize(_ drawn: Double, touch: Bool) -> Double { touch ? max(drawn, minTouchTarget) : drawn }

    /// Before the first layout: a plain display with no built-in notch.
    public static let fallback = make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24)

    /// `dynamicIsland` ignores `notch`; `position` places only a Dynamic Island display's island; `touch` is kept as given;
    /// `menuBarHeight` is floored at `minMenuBarHeight`.
    public static func make(notch: Notch?, builtInNotchWidth: Double, menuBarHeight: Double, dynamicIsland: Bool = false,
                            touch: Bool = false, position: NotchDockPosition = .centre) -> NotchGeometry {
        let bar = max(menuBarHeight, minMenuBarHeight)
        let kind: NotchDisplayKind
        let size: CGSize
        if dynamicIsland {
            kind = .dynamicIsland; size = pillSize
        } else if let notch {
            kind = .notch; size = CGSize(width: notch.width, height: notch.height)
        } else {
            kind = .plain; size = CGSize(width: builtInNotchWidth > 0 ? builtInNotchWidth : plainNotchWidth, height: bar)
        }
        let islandTop = kind == .dynamicIsland ? pillGap : 0
        let expanded = CGSize(width: size.width + extraWidth + (touch ? 2 * touchEarExtra : 0), height: size.height + extraHeight)
        let margin = outset + blur + overshoot
        var g = NotchGeometry(notch: size, hasHardwareNotch: kind == .notch, expandedSize: expanded,
                              idleSize: CGSize(width: expanded.width, height: idleHeight),
                              panelSize: CGSize(width: expanded.width + 2 * margin, height: islandTop + expanded.height + margin),
                              collapsedRect: .zero, hoverTarget: .zero, kind: kind, touch: touch, position: position,
                              panelTop: kind == .dynamicIsland ? bar : 0, islandTop: islandTop)
        if kind == .plain {
            g.hoverTarget = CGRect(x: (g.panelSize.width - size.width) / 2, y: 0, width: size.width, height: stripHeight + stripHoverBelow)
        } else {
            g.collapsedRect = g.islandRect(size: size)
            g.hoverTarget = g.collapsedRect
        }
        return g
    }

    /// The panel with the island `growth` points taller than its height: its top where it was.
    public func panelSize(growth: Double) -> CGSize {
        CGSize(width: panelSize.width, height: panelSize.height + growth)
    }

    /// The island's rect at a drawn size: centred and hung from the top under a notch or on a plain display; on a Dynamic
    /// Island display `islandTop` down, centred or `dockInset` from the panel's left or right edge (Position).
    public func islandRect(size: CGSize) -> CGRect {
        var x = (panelSize.width - size.width) / 2
        if kind == .dynamicIsland, !isFloating {
            switch position {
            case .centre: break
            case .left: x = Self.dockInset
            case .right: x = panelSize.width - Self.dockInset - size.width
            }
        }
        return CGRect(x: x, y: islandTop, width: size.width, height: size.height)
    }

    /// The body's rect at expansion 1: inside the expanded island by the body insets, below the header band.
    public var bodyRect: CGRect {
        let island = islandRect(size: expandedSize)
        return CGRect(x: island.minX + Self.bodyInset, y: island.minY + notch.height + Self.bodyTop,
                      width: expandedSize.width - 2 * Self.bodyInset,
                      height: expandedSize.height - notch.height - Self.bodyTop - Self.bodyBottom)
    }
}
