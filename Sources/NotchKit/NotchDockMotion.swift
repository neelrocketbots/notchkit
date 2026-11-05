import CoreGraphics
import SwiftUI

/// Snapping to and unsnapping from the notch (variation C, "squash and stretch"). While dragged, the island stretches
/// toward the notch: from where a pull begins to the 6 pt detach, and as a floating island is pushed against the screen's
/// top (0…1, up to 0.96 × 1.06 about its top). When it lets go or docks, the shape takes the new placement at once (no
/// shoulders floating, so a docked shape never shows at the floating spot) and springs into it: the top corners from 6 pt
/// to the floating card's radius (or to the notch's square top, its shoulders growing back), the frost and the shadow
/// fading in, and the stretch springing back with an overshoot. Only the island's own SwiftUI view animates; the panel's
/// frame moves at once (its single owner). Reduce Motion: instant.
public enum NotchDockMotion {
    /// The pop's spring: response 0.32, damping 0.62.
    public static let response: Double = 0.32, damping: Double = 0.62
    /// The pop's spring, `slowdown` times slower (frame captures; 1 everywhere else).
    public static func snapSpring(slowdown: Double = 1) -> Animation { .spring(response: response * slowdown, dampingFraction: damping) }
    /// At full stretch the island is this narrow and this tall.
    public static let stretchX: Double = 0.96, stretchY: Double = 1.06
    /// The top corners as the island lets go of (or meets) the notch.
    public static let popRadius: Double = 6
    /// A floating island pushed this close to the screen's top starts to stretch toward it, fully at the top.
    public static let dockReach: Double = 40

    /// The stretch never adds more than this many points of height, so a tall island stays inside its panel's margin below
    /// it (52 pt, less the glow's own room).
    public static let maxStretchPoints: Double = 12

    /// The island's scale at a stretch (negative: the overshoot's squash). `height` is the island's drawn height: the extra
    /// height is 6 % of it, at most `maxStretchPoints`.
    public static func scale(stretch s: Double, height: Double = 0) -> CGSize {
        let full = stretchY - 1
        let y = height > 0 ? min(full, maxStretchPoints / height) : full
        return CGSize(width: 1 - (1 - stretchX) * s, height: 1 + y * s)
    }

    /// The outline at a point of the morph (0: just snapped or unsnapped, 1: settled), at an expansion: floating, no
    /// shoulders and the top corners from `popRadius` to the card's (or the pill's) radius; docked, the shoulders growing
    /// back and the top corners from `popRadius` to square. `pillHeight` is the floating folded pill's.
    public static func outline(floating: Bool, expansion e: Double, morph m: Double, pillHeight: Double = NotchFloat.pillSize.height)
        -> (shoulder: Double, topRadius: Double, bottomRadius: Double) {
        let t = min(1, max(0, m))
        if floating {
            let r = NotchFloat.cornerRadius(expansion: e, pillHeight: pillHeight)
            return (0, min(r, popRadius) + (r - min(r, popRadius)) * t, r)
        }
        let open = min(1, max(0, e))
        return (NotchGeometry.shoulder(expansion: e) * t, popRadius * (1 - t) * open, NotchGeometry.cornerRadius(expansion: e))
    }

    /// The pull's stretch while docked: how far toward the detach the pointer has gone.
    public static func pullStretch(distance: Double) -> Double { min(1, max(0, distance / NotchFloat.dragThreshold)) }

    /// The push's stretch while floating: how far into the last `dockReach` points above the dock the top has come.
    public static func pushStretch(proposedTop: Double, dockTop: Double) -> Double {
        min(1, max(0, (dockTop + dockReach - proposedTop) / dockReach))
    }

    /// The notch's black bleeds into a floating island over the last this many points above the dock: the same reach as
    /// the push's stretch, so the ink and the stretch start together.
    public static let bleedReach: Double = dockReach

    /// How far the notch's black has bled into a floating island dragged toward it: the top edge's proximity over the last
    /// `bleedReach` points, eased in (squared) and capped at `nearCap` until contact, so it stays faint until close (0.225
    /// at 20 pt); 1 only with its top against the screen's top, where it docks on release. The panel sets it only while the
    /// island overlaps the notch (or a display's virtual notch strip) horizontally.
    public static func bleed(proposedTop: Double, dockTop: Double) -> Double {
        let p = min(1, max(0, (dockTop + bleedReach - proposedTop) / bleedReach))
        return p >= 1 ? 1 : nearCap * p * p
    }

    /// The bleed's ceiling before contact; from it to 1 (contact, sprung by the view) the ink grows into the docked look.
    public static let nearCap: Double = 0.9
    /// Before contact the ink reaches at most this much of the docked band's depth, and at most this much of the way
    /// from the floating tint to the notch's black.
    public static let nearDepth: Double = 0.6, nearPeak: Double = 0.7

    /// The ink drawn at a bleed: how deep the docked band and its ramp reach (a fraction of their docked depth) and how
    /// much of the notch's black it carries (0 the floating tint, 1 the docked black). Up to `nearCap` it grows to
    /// `nearDepth` and `nearPeak`; from there to contact (1) it grows on into the full docked look, continuously, so the
    /// view's spring at contact never pops.
    public static func ink(bleed: Double) -> (depth: Double, strength: Double) {
        let b = min(1, max(0, bleed))
        if b <= nearCap { return (nearDepth * b / nearCap, nearPeak * b / nearCap) }
        let t = (b - nearCap) / (1 - nearCap)
        return (nearDepth + (1 - nearDepth) * t, nearPeak + (1 - nearPeak) * t)
    }
}
