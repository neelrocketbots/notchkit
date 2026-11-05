import CoreGraphics
import Foundation

/// Where the island takes the mouse. The panel is larger than the island (room for the glow and the spring's
/// overshoot), so it ignores mouse events except while the pointer is over the open island plus a small margin;
/// everywhere else clicks and scrolls reach the app below. A folded island's hover target
/// (`NotchGeometry.hoverTarget`) is tested with no margin.
public enum NotchHitRect {
    public static let margin: Double = 6

    /// Edge-inclusive on every side (unlike `CGRect.contains`, which leaves out `maxX`/`maxY`): the collapsed hover
    /// target's top edge is the screen's top edge, and a pointer pushed against the top of the screen sits exactly on it.
    public static func contains(point: CGPoint, islandRect: CGRect, margin: Double = margin) -> Bool {
        guard !islandRect.isEmpty else { return false }
        let r = islandRect.insetBy(dx: -margin, dy: -margin)
        return point.x >= r.minX && point.x <= r.maxX && point.y >= r.minY && point.y <= r.maxY
    }

    public static func acceptsMouse(visible: Bool, pointer: CGPoint, islandRect: CGRect, margin: Double = margin) -> Bool {
        visible && contains(point: pointer, islandRect: islandRect, margin: margin)
    }

    /// Hover over an open island: inside its frame (+ margin), or inside the collapsed hover target (no margin) when
    /// one is given, so a pointer held on the notch row after a hover-expand does not start the leave grace.
    public static func hovering(pointer: CGPoint, islandRect: CGRect, hoverTargetRect: CGRect?) -> Bool {
        if contains(point: pointer, islandRect: islandRect) { return true }
        guard let hoverTargetRect else { return false }
        return contains(point: pointer, islandRect: hoverTargetRect, margin: 0)
    }

    /// The island's frame (top-left origin, in the panel's content) in AppKit screen coordinates (bottom-left origin).
    public static func screenRect(of island: CGRect, inPanel panel: CGRect) -> CGRect {
        guard !island.isEmpty else { return .zero }
        return CGRect(x: panel.minX + island.minX, y: panel.maxY - island.maxY, width: island.width, height: island.height)
    }
}
