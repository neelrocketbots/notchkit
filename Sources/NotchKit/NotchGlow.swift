import SwiftUI

/// What the glow shows (the client decides when): nothing, turning (a task runs), or one sweep (each serial restarts it).
public enum NotchGlowState: Equatable, Sendable { case off, turning, sweep(serial: Int) }

/// The glow's values (Decisions 21 and 53; the colours are `NotchConfiguration.Glow`).
public enum NotchGlow {
    /// The trace along the outline; the backlight is the island's own shape, 8 pt out, blurred 24 pt (expanded).
    public static let traceWidth: CGFloat = 2.6
    public static let haloBlur: CGFloat = 24, haloOutset: CGFloat = 8
    /// Folded (expansion 0) the backlight spreads a little wider and softer; between the two it interpolates.
    public static let foldedHaloBlur: CGFloat = 32, foldedHaloOutset: CGFloat = 10

    /// The backlight's blur at this expansion (0 folded, 1 expanded; clamped).
    public static func haloBlur(expansion: Double) -> CGFloat {
        let t = CGFloat(min(1, max(0, expansion)))
        return foldedHaloBlur + (haloBlur - foldedHaloBlur) * t
    }
    /// The backlight's outset at this expansion (0 folded, 1 expanded; clamped).
    public static func haloOutset(expansion: Double) -> CGFloat {
        let t = CGFloat(min(1, max(0, expansion)))
        return foldedHaloOutset + (haloOutset - foldedHaloOutset) * t
    }
    /// The room the glow's drawing and masks keep round the island: the outset and three blur radii at this expansion.
    public static func drawingPadding(expansion: Double) -> CGFloat {
        haloOutset(expansion: expansion) + 3 * haloBlur(expansion: expansion)
    }
    /// The room round the trace's offscreen pass: more than the stroke's half-width and its antialiasing.
    static let traceRoom: CGFloat = 2 * traceWidth
    /// The backlight: 30%, 35% while the gradient turns.
    public static func haloOpacity(turning: Bool) -> Double { turning ? 0.35 : 0.30 }

    /// What each state draws (Decision 53). The client decides the state, so there is no hover or scroll input here. A sweep runs the trace once round and does not turn; under
    /// Reduce Motion nothing moves, and a sweep shows still at full. Glow off in Settings: the plain outline instead.
    public static func appearance(for state: NotchGlowState, on: Bool, reduceMotion: Bool) -> NotchGlowAppearance {
        switch state {
        case .off: .none
        case .turning, .sweep:
            if !on { .whiteOutline }
            else if reduceMotion { .gradient(turning: false, halo: haloOpacity(turning: false)) }
            else if state == .turning { .gradient(turning: true, halo: haloOpacity(turning: true)) }
            else { .sweep(halo: haloOpacity(turning: false)) }
        }
    }

    /// A sweep's gradient angle `elapsed` seconds in: once round from `start` (the turn's angle when it began, so a sweep
    /// over a turn carries on from where the gradient was), linear, over `sweep`, then it stays.
    public static func sweepAngle(elapsed: TimeInterval, from start: Double = 0, sweep: Duration = NotchConfiguration.Motion().glowSweep) -> Double {
        let progress = elapsed / (sweep / .seconds(1))
        return start + min(max(progress, 0), 1) * 360
    }

    /// The turning gradient is redrawn this often: the 24 pt blurred backlight is the cost, and a 6 s turn is smooth at 30 fps.
    static let turnFrameInterval: Double = 1.0 / 30
    /// The sweep is redrawn at most this often (60 fps, not ProMotion's 120 Hz). The angle comes
    /// from the clock, so the sweep's speed and look do not depend on the frame rate.
    static let sweepFrameInterval: Double = 1.0 / 60

    /// The timeline's minimum interval for an appearance: the turn's 30 fps, the sweep's 60 fps, nil for a still glow.
    public static func frameInterval(for appearance: NotchGlowAppearance) -> Double? {
        switch appearance {
        case .gradient(true, _): turnFrameInterval
        case .sweep: sweepFrameInterval
        default: nil
        }
    }

    /// start → end → start around the island, centred a little above the middle, starting at `angle` degrees.
    static func gradient(angle: Double, glow: NotchConfiguration.Glow) -> AngularGradient {
        AngularGradient(colors: [glow.start.color, glow.end.color, glow.start.color], center: UnitPoint(x: 0.5, y: 0.4), angle: .degrees(angle))
    }

    /// The gradient's angle while it turns (one turn per `turn` seconds).
    public static func turnAngle(at date: Date, turn: Double = NotchConfiguration.Motion().glowTurn) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: turn) / turn * 360
    }
}

/// What the glow draws for a state: nothing, the gradient trace and backlight (turning or still), one sweep of the trace
/// round the outline, or the plain white outline when Settings turns the glow off.
public enum NotchGlowAppearance: Equatable, Sendable {
    case none, gradient(turning: Bool, halo: Double), sweep(halo: Double), whiteOutline
}

/// What the glow follows (Decision 53, Decision 71): the notch island's edge, a plain display's folded 1 pt strip, or
/// the pill (on a Dynamic Island display, or floating).
public enum NotchGlowShape: Equatable, Sendable {
    case notch(shoulder: Double, bottomRadius: Double)
    case strip
    case pill(cornerRadius: Double)

    /// The shape of `geometry`'s island at `expansion` (0 folded, 1 expanded). A plain display folded is the strip; a
    /// Dynamic Island display is the pill at every expansion (folded too: nothing is filled there, the glow alone traces it).
    public static func of(_ geometry: NotchGeometry, expansion: Double) -> NotchGlowShape {
        if geometry.isFloating { return .pill(cornerRadius: NotchFloat.cornerRadius(expansion: expansion)) }
        return switch geometry.kind {
        case .dynamicIsland: .pill(cornerRadius: NotchGeometry.pillCornerRadius(expansion: expansion))
        case .plain where expansion <= 0: .strip
        default: .notch(shoulder: NotchGeometry.shoulder(expansion: expansion), bottomRadius: NotchGeometry.cornerRadius(expansion: expansion))
        }
    }

    /// The strip: 1 pt tall, as wide as the notch, at the panel's top centre.
    public static func stripRect(_ geometry: NotchGeometry) -> CGRect {
        CGRect(x: (geometry.panelSize.width - geometry.notch.width) / 2, y: 0, width: geometry.notch.width, height: NotchGeometry.stripHeight)
    }
}

/// The glow as the island's indicator (Decision 53): a 2.6 pt trace of the configured gradient along the outline and
/// the island's shape, blurred, behind it as a backlight. It fills the frame it is given (the island's rect) and draws
/// outside the island's edge only (the trace's full 2.6 pt lies outside it, so the island's black over the glow does not
/// hide any of it, and an unfilled pill or strip shows the same width), so the caller fills the island's black over it. Off draws nothing; a sweep runs the
/// gradient once round over 1.6 s (each serial restarts it); turning, it goes round once every 6 s; Reduce Motion holds
/// it still. When its state ends it fades out over 200 ms. Colours, timing and a calibration come from the environment's
/// `notchConfiguration`.
public struct NotchGlowView: View {
    let state: NotchGlowState
    let shape: NotchGlowShape
    let on: Bool
    let reduceMotion: Bool
    /// 0 folded, 1 expanded: the backlight's blur and outset follow it (`NotchGlow.haloBlur(expansion:)`).
    let expansion: Double
    /// The last appearance drawn, kept while the glow fades out.
    @State private var held: NotchGlowAppearance = .none
    @State private var sweepStart: Date?
    @Environment(\.notchConfiguration) private var configuration

    public init(state: NotchGlowState, shape: NotchGlowShape, on: Bool, reduceMotion: Bool, expansion: Double = 1) {
        self.state = state; self.shape = shape; self.on = on; self.reduceMotion = reduceMotion; self.expansion = expansion
    }

    /// The calibration in effect (the client's `Debug.glowCalibration`); nil in a normal run.
    var calibration: NotchGlowCalibration?

    private var appearance: NotchGlowAppearance {
        if calibration != nil { return .gradient(turning: false, halo: NotchGlow.haloOpacity(turning: false)) }
        return NotchGlow.appearance(for: state, on: on, reduceMotion: reduceMotion)
    }

    public var body: some View {
        if calibration == nil, let calibrate = configuration.debug.glowCalibration {
            // Lit steadily whatever the state, re-reading the client's values twice a second so a change shows live.
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in calibrated(calibrate()) }
        } else {
            live
        }
    }

    private func calibrated(_ c: NotchGlowCalibration) -> NotchGlowView {
        var view = self
        view.calibration = c
        return view
    }

    /// The glow's path, calibrated in a calibration run.
    private func path(edge: Bool) -> NotchGlowPath {
        var p = NotchGlowPath(shape: shape, edge: edge)
        p.calibration = calibration
        return p
    }

    @ViewBuilder private var live: some View {
        let appearance = appearance
        let shown = appearance == .none ? held : appearance
        let visible = appearance != .none
        let interval = NotchGlow.frameInterval(for: shown)
        TimelineView(.animation(minimumInterval: interval, paused: !(visible && Self.moves(shown)))) { context in
            let angle = angle(shown, at: context.date)
            drawing(shown, angle: angle)
        }
        .opacity(visible ? 1 : 0)
        .animation(visible ? nil : .easeOut(duration: 0.2), value: visible)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: appearance, initial: true) { _, new in if new != .none { held = new } }
        .onChange(of: state, initial: true) { _, new in
            if case .sweep = new { sweepStart = Date() }
        }
    }

    /// The backlight and the trace. A pill or a strip is never filled, so its inside is cut out: only the glow round it
    /// shows (the notch island is filled black over it by the caller).
    @ViewBuilder private func drawing(_ appearance: NotchGlowAppearance, angle: Double) -> some View {
        let layers = Color.clear
            .overlay { halo(appearance, angle: angle) }
            .overlay { trace(appearance, angle: angle) }
        if case .notch = shape {
            layers
        } else {
            layers.mask {
                ZStack {
                    Rectangle().padding(-NotchGlow.drawingPadding(expansion: expansion))
                    path(edge: false).blendMode(.destinationOut)
                }
                .compositingGroup()
            }
        }
    }

    private static func moves(_ appearance: NotchGlowAppearance) -> Bool {
        switch appearance {
        case .gradient(let turning, _): turning
        case .sweep: true
        case .none, .whiteOutline: false
        }
    }

    private func angle(_ appearance: NotchGlowAppearance, at date: Date) -> Double {
        let motion = configuration.motion
        switch appearance {
        case .gradient(let turning, _): return turning ? NotchGlow.turnAngle(at: date, turn: motion.glowTurn) : 0
        case .sweep:
            return NotchGlow.sweepAngle(elapsed: date.timeIntervalSince(sweepStart ?? date),
                                        from: NotchGlow.turnAngle(at: sweepStart ?? date, turn: motion.glowTurn), sweep: motion.glowSweep)
        case .none, .whiteOutline: return 0
        }
    }

    private func style(_ appearance: NotchGlowAppearance, angle: Double) -> AnyShapeStyle {
        let glow = configuration.appearance.glow
        return appearance == .whiteOutline ? AnyShapeStyle(Color.white.opacity(glow.offOutline)) : AnyShapeStyle(NotchGlow.gradient(angle: angle, glow: glow))
    }

    /// The backlight: the island's shape in the gradient, 8 pt out and 24 pt blurred expanded (10 and 32 folded).
    @ViewBuilder private func halo(_ appearance: NotchGlowAppearance, angle: Double) -> some View {
        switch appearance {
        case .gradient(_, let opacity), .sweep(let opacity):
            // Rasterised offscreen by Metal: CoreGraphics shades an angular gradient on the CPU, per pixel, every frame
            // the gradient turns (41% of the app's CPU over a replayed call, x20). The fill stays inside its frame.
            path(edge: false).fill(style(appearance, angle: angle))
                .drawingGroup()
                .padding(-NotchGlow.haloOutset(expansion: expansion))
                .blur(radius: NotchGlow.haloBlur(expansion: expansion))
                .opacity(opacity)
        case .none, .whiteOutline:
            EmptyView()
        }
    }

    /// The trace: the full outline, no trim, `traceWidth` wide outside the island's edge. It is stroked twice that wide
    /// on the edge, and the inner half is the island's own black (a notch island is always filled) or cut out (a pill or
    /// a strip, by `drawing`).
    @ViewBuilder private func trace(_ appearance: NotchGlowAppearance, angle: Double) -> some View {
        if appearance != .none {
            // Rasterised offscreen like the halo. The stroke keeps the island's frame (its path and its gradient's centre
            // land where CoreGraphics drew them, byte for byte); only the offscreen pass is `traceRoom` larger on every
            // side, so the half of the stroke outside the island's edge is not clipped.
            path(edge: true).stroke(style(appearance, angle: angle), lineWidth: 2 * NotchGlow.traceWidth)
                .padding(NotchGlow.traceRoom)
                .drawingGroup()
                .padding(-NotchGlow.traceRoom)
        }
    }
}

/// The glow's path for a `NotchGlowShape`: the island's whole shape (`edge` false) or its visible edge (`edge` true: the
/// notch island's open outline, else the closed path). The shape's numbers animate with the island's expansion.
struct NotchGlowPath: Shape {
    var shape: NotchGlowShape
    var edge: Bool
    /// Moves and resizes the folded notch's outline (a `.notch` with no shoulder), and its corners (a calibration run).
    var calibration: NotchGlowCalibration?

    var animatableData: AnimatablePair<Double, Double> {
        get {
            switch shape {
            case .notch(let shoulder, let radius): .init(shoulder, radius)
            case .pill(let radius): .init(radius, 0)
            case .strip: .init(0, 0)
            }
        }
        set {
            switch shape {
            case .notch: shape = .notch(shoulder: newValue.first, bottomRadius: newValue.second)
            case .pill: shape = .pill(cornerRadius: newValue.first)
            case .strip: break
            }
        }
    }

    func path(in rect: CGRect) -> Path {
        var rect = rect, shape = shape
        if let calibration, case .notch(let shoulder, let radius) = shape, shoulder == 0 {
            rect = calibration.apply(to: rect)
            shape = .notch(shoulder: 0, bottomRadius: calibration.bottomRadius ?? radius)
        }
        return switch shape {
        case .notch(let shoulder, let radius):
            edge ? NotchOutline(shoulder: shoulder, bottomRadius: radius).path(in: rect)
                 : NotchShape(shoulder: shoulder, bottomRadius: radius).path(in: rect)
        case .pill(let radius): NotchPillShape(cornerRadius: radius).path(in: rect)
        case .strip: Rectangle().path(in: rect)
        }
    }
}

/// A by-eye match of the folded glow to the physical notch (R38): the folded notch's outline moved in by `inset` on the
/// sides and the bottom, `widthDelta` and `heightDelta` points larger (the width centred), `xOffset` and `yOffset` points
/// right and down, with `bottomRadius` corners (nil: the folded radius). A client reads the values (its own debug
/// settings) and passes them in `NotchConfiguration.Debug.glowCalibration`.
public struct NotchGlowCalibration: Equatable, Sendable {
    public var inset: Double, widthDelta: Double, heightDelta: Double, xOffset: Double, yOffset: Double
    public var bottomRadius: Double?

    public init(inset: Double = 0, widthDelta: Double = 0, heightDelta: Double = 0, xOffset: Double = 0, yOffset: Double = 0, bottomRadius: Double? = nil) {
        self.inset = inset; self.widthDelta = widthDelta; self.heightDelta = heightDelta; self.xOffset = xOffset; self.yOffset = yOffset
        self.bottomRadius = bottomRadius
    }

    /// The folded notch's rect, calibrated: the top stays flush with the screen's edge unless `yOffset` moves it.
    public func apply(to rect: CGRect) -> CGRect {
        CGRect(x: rect.minX - widthDelta / 2 + inset + xOffset, y: rect.minY + yOffset,
               width: max(rect.width + widthDelta - 2 * inset, 0), height: max(rect.height + heightDelta - inset, 0))
    }
}
