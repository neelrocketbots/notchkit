import SwiftUI

/// What the island draws: nothing, the folded notch (or pill), the idle island or the expanded one.
public enum NotchDrawn: Hashable, Sendable {
    case nothing, folded, idle, expanded

    public var isOpen: Bool { self == .idle || self == .expanded }
}

/// The expanded island's body (the frosted island): a backdrop blur of what is behind the panel under the black overlay
/// (`NotchConfiguration.Frost.overlay`), so the notch band stays black and the body below it is a light frost darkening
/// toward the bottom. The folded island, the idle island and the notch band are solid black. Reduce Transparency and
/// Increase Contrast draw the whole body solid black.
///
/// This is the only place in NotchKit that uses a material. The blur is SwiftUI's material in the dark scheme
/// (`NotchConfiguration.Frost.material`, the ultra-thin by default): in the island's clear, non-activating panel it blurs
/// what is behind the window (an `NSVisualEffectView` with `.behindWindow` blending drew flat in the same panel).
public struct NotchBackdrop: View {
    /// How the body's backdrop is drawn: the system material (the island's own panel), the frost's tint in the
    /// material's place (an offscreen render, which cannot see behind its window), or solid black (every other host).
    public enum Rendering: Sendable, Equatable { case material, tint, solid }

    /// The body's look for a drawn state: frosted only while the island is open and neither Reduce Transparency nor
    /// Increase Contrast is on (`raised` is either), and only where the host asks for it.
    public enum Look: Equatable, Sendable { case solid, frosted }

    public static func look(drawn: NotchDrawn, rendering: Rendering, raised: Bool, reduceTransparency: Bool, floating: Bool = false) -> Look {
        // Floating, the folded pill is frosted too.
        let open = drawn == .expanded || (floating && drawn == .folded)
        return open && rendering != .solid && !raised && !reduceTransparency ? .frosted : .solid
    }

    /// The body's look at a point of the animation: while the island folds (drawn closed, the animated expansion still
    /// above 0) it keeps the look of the open state it folds out of, so a fold out of the expanded island animates frosted
    /// and only the fully folded notch is solid, as the grow mirrors.
    public static func look(drawn: NotchDrawn, lastOpen: NotchDrawn?, expansion: Double, rendering: Rendering, raised: Bool,
                            reduceTransparency: Bool, floating: Bool = false) -> Look {
        let folding = !drawn.isOpen && expansion > 0 ? lastOpen : nil
        return look(drawn: folding ?? drawn, rendering: rendering, raised: raised, reduceTransparency: reduceTransparency, floating: floating)
    }

    /// The overlay's stops in the drawn height: each stop sits at its fraction of the expanded height from the top, so
    /// while the island grows it stays black down to the notch band, and the last stop is the overlay where the drawn
    /// height ends.
    public static func overlayStops(height: Double, expandedHeight: Double, frost: NotchConfiguration.Frost = .init())
        -> [(location: Double, opacity: Double)] {
        guard height > 0, expandedHeight > 0 else { return [(0, 1), (1, 1)] }
        let scale = expandedHeight / height
        var stops = frost.overlay.map { (location: $0.location * scale, opacity: $0.opacity) }.filter { $0.location < 1 }
        stops.append((1, frost.overlayOpacity(at: height / expandedHeight)))
        return stops
    }

    /// The overlay's stops with the notch's black bled in and through a snap's morph:
    /// - floating, settled: the flat floating tint (`Floating.overlay`), with the docked band and its ramp bled down from
    ///   the top edge, never lighter than the tint: before contact faint and shallow (`NotchDockMotion.ink`), at contact
    ///   (1) the docked band;
    /// - docked, settled: exactly the docked stops (`overlayStops(height:expandedHeight:)`), whatever the bleed;
    /// - mid-snap (`morph` < 1): docking, from the contact look (bleed 1) into the docked one; undocking, from the docked
    ///   look into the floating one at `bleed`.
    /// Every look is linear between its breakpoints, so the stops are exact at the union of them.
    public static func overlayStops(height: Double, expandedHeight: Double, floating: Bool, bleed: Double, morph: Double,
                                    appearance: NotchConfiguration.Appearance = .init()) -> [(location: Double, opacity: Double)] {
        let frost = appearance.frost
        let m = min(1, max(0, morph)), b = min(1, max(0, bleed))
        if !floating && m >= 1 { return overlayStops(height: height, expandedHeight: expandedHeight, frost: frost) }
        let base = appearance.floating.overlay
        if floating && m >= 1 && b <= 0 { return [(0, base), (1, base)] }
        guard height > 0, expandedHeight > 0 else { return [(0, 1), (1, 1)] }
        // Docking, the ink the island touched the notch with (full); undocking, the drag's.
        let ink = NotchDockMotion.ink(bleed: floating ? b : 1)
        func docked(_ y: Double) -> Double { frost.overlayOpacity(at: y / expandedHeight) }
        func bled(_ y: Double) -> Double {
            guard ink.depth > 0 else { return base }
            return base + (max(base, frost.overlayOpacity(at: y / (expandedHeight * ink.depth))) - base) * ink.strength
        }
        func opacity(_ y: Double) -> Double {
            floating ? docked(y) + (bled(y) - docked(y)) * m : bled(y) + (docked(y) - bled(y)) * m
        }
        // The breakpoints, in points: the docked stops, the bled stops and where the bled ramp meets the tint.
        let tokens = frost.overlay.map { $0.location }
        var points = tokens.map { $0 * expandedHeight } + tokens.map { $0 * expandedHeight * ink.depth }
        if let meet = Self.locationWhereOverlay(reaches: base, frost: frost) { points.append(meet * expandedHeight * ink.depth) }
        let locations = Set(([0, 1] + points.map { $0 / height }).filter { $0 >= 0 && $0 <= 1 }).sorted()
        return locations.map { (location: $0, opacity: opacity($0 * height)) }
    }

    /// Where the docked overlay's ramp first falls to `opacity` (as a fraction of the expanded height); nil if it never does.
    public static func locationWhereOverlay(reaches opacity: Double, frost: NotchConfiguration.Frost = .init()) -> Double? {
        for (a, b) in zip(frost.overlay, frost.overlay.dropFirst()) where a.opacity >= opacity && b.opacity < opacity {
            return a.location + (b.location - a.location) * (a.opacity - opacity) / (a.opacity - b.opacity)
        }
        return nil
    }

    let shape: AnyShape
    let rendering: Rendering
    let height: Double
    let expandedHeight: Double
    /// Floating: frosted all over, the overlay's lower black with no band, and a subtle border.
    var floating: Bool
    /// How far the notch's black has bled in from the top edge (0…1, `NotchDockMotion.bleed`), and the snap's morph
    /// (0 at a flip of the placement, 1 settled), both animated by the caller.
    var bleed: Double
    var morph: Double
    @Environment(\.notchConfiguration) private var configuration

    public init(shape: AnyShape, rendering: Rendering, height: Double, expandedHeight: Double, floating: Bool = false,
                bleed: Double = 0, morph: Double = 1) {
        self.shape = shape; self.rendering = rendering; self.height = height; self.expandedHeight = expandedHeight
        self.floating = floating; self.bleed = bleed; self.morph = morph
    }

    public var body: some View {
        let appearance = configuration.appearance
        let black = appearance.fill.color
        ZStack {
            switch rendering {
            case .material: Self.frost(appearance.frost.material).environment(\.colorScheme, .dark)
            case .tint: appearance.frost.tint.color
            case .solid: black
            }
            if floating, morph >= 1, bleed <= 0 {
                black.opacity(appearance.floating.overlay)
            } else {
                LinearGradient(stops: Self.overlayStops(height: height, expandedHeight: expandedHeight, floating: floating,
                                                        bleed: bleed, morph: morph, appearance: appearance).map {
                    Gradient.Stop(color: black.opacity($0.opacity), location: $0.location)
                }, startPoint: .top, endPoint: .bottom)
            }
        }
        .clipShape(shape)
        .overlay { if floating { shape.stroke(appearance.floating.border.color, lineWidth: 1) } }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The material: the system's ultra-thin unless the client picks another.
    private static func frost(_ material: NotchFrostMaterial) -> some View {
        Rectangle().fill(material.material)
    }
}

extension NotchFrostMaterial {
    var material: Material {
        switch self {
        case .ultraThin: .ultraThinMaterial
        case .regular: .regularMaterial
        case .thick: .thickMaterial
        }
    }
}

private struct NotchBackdropRenderingKey: EnvironmentKey { static let defaultValue = NotchBackdrop.Rendering.solid }

extension EnvironmentValues {
    /// How the island's body backdrop is drawn (`NotchBackdrop.Rendering`); solid unless the host asks.
    public var notchBackdrop: NotchBackdrop.Rendering {
        get { self[NotchBackdropRenderingKey.self] }
        set { self[NotchBackdropRenderingKey.self] = newValue }
    }
}

/// The floating island's soft shadow (`NotchConfiguration.Floating.shadow`). None docked.
public struct NotchFloatShadow: ViewModifier {
    let on: Bool
    /// How far the shadow has faded in (the snap's morph).
    var amount: Double
    @Environment(\.notchConfiguration) private var configuration

    public init(on: Bool, amount: Double = 1) { self.on = on; self.amount = amount }

    /// The shadow drawn: the configured one at `amount` floating, nothing docked. Always applied (never an `if`), so the
    /// fill keeps one identity across a flip and morphs from black to frost instead of cross-fading.
    public static func values(on: Bool, amount: Double, shadow s: NotchShadow = NotchConfiguration.Floating().shadow)
        -> (opacity: Double, radius: Double, y: Double) {
        let a = on ? min(1, max(0, amount)) : 0
        return (a, s.radius * a, s.y * a)
    }

    public func body(content: Content) -> some View {
        let s = configuration.appearance.floating.shadow
        let v = Self.values(on: on, amount: amount, shadow: s)
        content.shadow(color: s.color.color.opacity(v.opacity), radius: v.radius, x: s.x, y: v.y)
    }
}
