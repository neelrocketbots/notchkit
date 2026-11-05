import CoreGraphics
import Foundation

/// Drag the bottom edge to resize: only the expanded island's height changes, the width stays tied to the notch. The
/// height is the user's per display (`NotchLayoutPrefs.heights`), between the client's minimum and `maxHeight` (80 pt
/// clear above the Dock).
public enum NotchResize {
    /// Past the minimum the edge gives at most this much (the rubber band), then springs back on release.
    public static let rubberBand: Double = 12
    /// The maximum leaves this much clear above the Dock (or the display's bottom edge).
    public static let dockClearance: Double = 80
    /// VoiceOver's ↑/↓ on the height.
    public static let step: Double = 40
    /// The grab line: 32 × 2 at rest, 56 × 3 on hover, 5 pt above the bottom edge; the hit band is the bottom 12 pt.
    public static let lineRest = CGSize(width: 32, height: 2), lineHover = CGSize(width: 56, height: 3)
    public static let lineBottom: Double = 5, hitBand: Double = 12

    /// The tallest the island may be with its top `top` points below the display's top: 80 pt clear above the Dock; never
    /// under `min`.
    public static func maxHeight(top: Double, display: NotchDisplay, min: Double) -> Double {
        Swift.max(min, display.height - display.visibleInsets.bottom - dockClearance - top)
    }

    /// The height drawn while dragging: the pointer's height inside the limits; below `min` the edge resists (an
    /// exponential approach to `rubberBand` short of it), or stops at `min` under Reduce Motion. `max` is a hard stop.
    public static func live(proposed: Double, min: Double, max: Double, reduceMotion: Bool) -> Double {
        if proposed >= min { return Swift.min(proposed, max) }
        if reduceMotion { return min }
        let over = min - proposed
        return min - rubberBand * (1 - exp(-over / (2 * rubberBand)))
    }

    /// The height kept on release: inside the limits (the rubber band springs back).
    public static func settled(_ height: Double, min: Double, max: Double) -> Double { Swift.min(Swift.max(height, min), max) }

    /// VoiceOver's increment (`direction` 1) or decrement (-1).
    public static func stepped(_ height: Double, by direction: Double, min: Double, max: Double) -> Double {
        settled(height + direction * step, min: min, max: max)
    }
}

public extension NotchGeometry {
    /// The default expanded height: the notch's height + 250.
    var defaultExpandedHeight: Double { notch.height + Self.extraHeight }

    /// This geometry with the expanded island `height` tall: the panel (and so the body) grows or shrinks with it, its top
    /// fixed; the width, the idle island and the folded shapes are unchanged.
    func resized(toHeight height: Double) -> NotchGeometry {
        var g = self
        let delta = height - expandedSize.height
        g.expandedSize.height = height
        g.panelSize.height += delta
        return g
    }

    /// This geometry floating: the island `NotchFloat.margin` down in a panel that much taller (room for the shadow and
    /// the glow above it too), folded to the pill (`pillSize`), which sits `pillOffset` off the expanded island's top centre
    /// and is the hover target (a click or a drag; a floating pill never peeks on hover).
    func floating(pillOffset: CGSize = .zero, topMargin: Double = NotchFloat.margin, pillSize: CGSize = NotchFloat.pillSize) -> NotchGeometry {
        var g = self
        let margin = Swift.max(0, Swift.min(NotchFloat.margin, topMargin))
        g.isFloating = true
        g.pillOffset = pillOffset
        g.panelSize.height += margin - islandTop
        g.panelTop = 0
        g.islandTop = margin
        g.collapsedRect = g.islandRect(size: pillSize).offsetBy(dx: pillOffset.width, dy: pillOffset.height)
        g.hoverTarget = g.collapsedRect
        return g
    }
}
