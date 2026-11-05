import CoreGraphics
import Foundation

/// Where the island is: docked at the notch, or floating with its top centre at `anchor`
/// (points, top-left origin at the main display, as `NotchDisplay`). The anchor is the folded pill's top centre; the expanded
/// island opens downward from it, or upward where it would leave the screen.
public enum NotchPlacement: Equatable, Sendable {
    case docked
    case floating(anchor: CGPoint)

    public var anchor: CGPoint? { if case .floating(let a) = self { a } else { nil } }
}

/// A floating island's position on one display, as fractions of the display's visible rect (`NotchDisplay.visibleRect`), so
/// it survives a resolution change.
public struct NotchOrigin: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double
    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// The user's island sizes and positions, per display id (`NotchDisplay.id`): the expanded height, and the floating position
/// (absent: docked). The client keeps them in its own settings.
public struct NotchLayoutPrefs: Equatable, Sendable {
    public var heights: [UInt32: Double]
    public var origins: [UInt32: NotchOrigin]
    public init(heights: [UInt32: Double] = [:], origins: [UInt32: NotchOrigin] = [:]) { self.heights = heights; self.origins = origins }

    /// The tallest height kept from settings; anything taller is not a height (the layout clamps the rest to the display).
    public static let maxStoredHeight: Double = 100_000

    /// From settings' string-keyed maps (hand-editable JSON), never trapping: an entry is skipped when its key is not a
    /// canonical display id (digits only, no sign, no leading zero, within UInt32: so "1", "+1" and "01" can never collide),
    /// or its value is not a finite, positive height up to `maxStoredHeight`, or an origin with finite fractions (clamped
    /// into 0…1).
    public init(storedHeights: [String: Double], storedOrigins: [String: NotchOrigin]) {
        var heights: [UInt32: Double] = [:], origins: [UInt32: NotchOrigin] = [:]
        for (key, value) in storedHeights {
            guard let id = Self.displayID(key), value.isFinite, value > 0, value <= Self.maxStoredHeight else { continue }
            heights[id] = value
        }
        for (key, value) in storedOrigins {
            guard let id = Self.displayID(key), value.x.isFinite, value.y.isFinite else { continue }
            origins[id] = NotchOrigin(x: min(1, max(0, value.x)), y: min(1, max(0, value.y)))
        }
        self.init(heights: heights, origins: origins)
    }

    /// A settings key as a display id: only its canonical decimal spelling.
    public static func displayID(_ key: String) -> UInt32? {
        guard let id = UInt32(key), String(id) == key else { return nil }
        return id
    }

    /// The maps settings keep, keyed by the canonical spelling.
    public var storedHeights: [String: Double] { Dictionary(heights.map { (String($0.key), $0.value) }, uniquingKeysWith: { a, _ in a }) }
    public var storedOrigins: [String: NotchOrigin] { Dictionary(origins.map { (String($0.key), $0.value) }, uniquingKeysWith: { a, _ in a }) }
}

/// A handle's input: a drag (`began`, `changed`, `ended`, pointer points in AppKit screen coordinates), a double-click
/// (`reset`: the default height, or docked), VoiceOver's adjustable step (±1) or a corner (Move island's actions).
public enum NotchHandleInput: Equatable, Sendable {
    /// `cancel`: a drag ends without a drop (the phase changed, the view went away): its state is cleared and the island
    /// goes back where the drag started, so nothing moves.
    case began(CGPoint), changed(CGPoint), ended, reset, step(Double), corner(NotchCorner), cancel
}

/// Move island's VoiceOver actions: dock, or float in a corner of the visible rect.
public enum NotchCorner: String, CaseIterable, Sendable { case topLeft, topRight, bottomLeft, bottomRight }

/// The pure rules of a floating island: kept fully on screen, saved as fractions, docking on touching the top.
public enum NotchFloat {
    /// A drag starts after this much movement, so a click is still a click.
    public static let dragThreshold: Double = 6
    /// The floating folded pill's default size; a client with another pill passes its own `pillSize`.
    public static let pillSize = CGSize(width: 132, height: 30)
    /// The floating card's corners, all four; the pill is a capsule.
    public static let cornerRadius: Double = 26
    /// Room round a floating island in its panel for the shadow and the glow (and above it, unlike a docked one).
    public static let margin: Double = NotchGeometry.outset + NotchGeometry.blur
    /// The corner a VoiceOver action floats the island to sits this far in from the visible rect's edges.
    public static let cornerInset: Double = 16

    /// The island's corner radius at an expansion: the pill's capsule folded, 26 pt open.
    public static func cornerRadius(expansion e: Double, pillHeight: Double = pillSize.height) -> Double {
        pillHeight / 2 + (cornerRadius - pillHeight / 2) * max(0, min(1, e))
    }

    /// `rect` moved (never resized) to lie inside `visible`; when it is taller or wider it keeps the top or left edge.
    public static func clamp(_ rect: CGRect, in visible: CGRect) -> CGRect {
        var r = rect
        r.origin.x = min(max(r.minX, visible.minX), max(visible.minX, visible.maxX - r.width))
        r.origin.y = min(max(r.minY, visible.minY), max(visible.minY, visible.maxY - r.height))
        return r
    }

    /// The expanded island's rect for a pill anchored at `anchor`: centred under it, opening downward, kept on screen.
    public static func expandedRect(anchor: CGPoint, size: CGSize, visible: CGRect) -> CGRect {
        clamp(CGRect(x: anchor.x - size.width / 2, y: anchor.y, width: size.width, height: size.height), in: visible)
    }

    /// The pill's rect at `anchor`, kept on screen.
    public static func pillRect(anchor: CGPoint, visible: CGRect, pillSize: CGSize = NotchFloat.pillSize) -> CGRect {
        clamp(CGRect(x: anchor.x - pillSize.width / 2, y: anchor.y, width: pillSize.width, height: pillSize.height), in: visible)
    }

    /// The display under `point` (top-left points), else the nearest one.
    public static func display(at point: CGPoint, in displays: [NotchDisplay]) -> NotchDisplay? {
        func rect(_ d: NotchDisplay) -> CGRect { CGRect(x: d.x, y: d.y, width: d.width, height: d.height) }
        if let d = displays.first(where: { rect($0).contains(point) }) { return d }
        return displays.min { distance(point, rect($0)) < distance(point, rect($1)) }
    }

    private static func distance(_ p: CGPoint, _ r: CGRect) -> Double {
        let dx = max(r.minX - p.x, 0, p.x - r.maxX), dy = max(r.minY - p.y, 0, p.y - r.maxY)
        return dx * dx + dy * dy
    }

    /// Whether a dragged island docks on release: its top edge pressed against the screen's top (a floating island
    /// stops at the menu bar's bottom, so `proposedTop` at or above it) while it overlaps the notch horizontally.
    public static func touchesDock(proposedTop: Double, left: Double, right: Double, display: NotchDisplay, notchWidth: Double) -> Bool {
        let notchLeft = display.x + (display.width - notchWidth) / 2
        return touchesDock(proposedTop: proposedTop, left: left, right: right, display: display, dockedLeft: notchLeft, dockedRight: notchLeft + notchWidth)
    }

    /// As above, against where the docked island really sits (`dockedLeft`…`dockedRight`, top-left points): the notch, or a
    /// Dynamic Island display's pill at its dock position, Left or Right as well as Centre.
    public static func touchesDock(proposedTop: Double, left: Double, right: Double, display: NotchDisplay, dockedLeft: Double, dockedRight: Double) -> Bool {
        proposedTop <= display.y + display.menuBarHeight && right > dockedLeft && left < dockedRight
    }

    /// The anchor as fractions of the visible rect (the room the pill's top centre can take).
    public static func origin(of anchor: CGPoint, visible: CGRect, pillSize: CGSize = NotchFloat.pillSize) -> NotchOrigin {
        let w = max(1, visible.width - pillSize.width), h = max(1, visible.height - pillSize.height)
        return NotchOrigin(x: min(1, max(0, (anchor.x - pillSize.width / 2 - visible.minX) / w)),
                            y: min(1, max(0, (anchor.y - visible.minY) / h)))
    }

    /// The anchor saved as `origin` on a display with this visible rect.
    public static func anchor(of origin: NotchOrigin, visible: CGRect, pillSize: CGSize = NotchFloat.pillSize) -> CGPoint {
        CGPoint(x: visible.minX + origin.x * max(0, visible.width - pillSize.width) + pillSize.width / 2,
                y: visible.minY + origin.y * max(0, visible.height - pillSize.height))
    }

    /// A VoiceOver corner's anchor for an island `size` (the expanded one) on the visible rect.
    public static func anchor(corner: NotchCorner, size: CGSize, visible: CGRect) -> CGPoint {
        let left = visible.minX + cornerInset + size.width / 2, right = visible.maxX - cornerInset - size.width / 2
        let top = visible.minY + cornerInset, bottom = visible.maxY - cornerInset - size.height
        return switch corner {
        case .topLeft: CGPoint(x: left, y: top)
        case .topRight: CGPoint(x: right, y: top)
        case .bottomLeft: CGPoint(x: left, y: bottom)
        case .bottomRight: CGPoint(x: right, y: bottom)
        }
    }
}
