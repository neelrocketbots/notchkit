import SwiftUI

/// What the glow shows (the client decides when): nothing, turning (a task runs), or one sweep (each serial restarts it).
public enum NotchGlowState: Equatable, Sendable { case off, turning, sweep(serial: Int) }

/// The glow's opacity, folded (expansion 0) and expanded (expansion 1); in between it interpolates with the expansion.
public struct NotchGlowLevel: Equatable, Sendable {
    public var folded: Double, expanded: Double
    public init(folded: Double, expanded: Double) { self.folded = folded; self.expanded = expanded }
    public init(_ both: Double) { self.init(folded: both, expanded: both) }
    public static let zero = NotchGlowLevel(0)

    /// The opacity at this expansion (clamped to 0…1).
    public func at(expansion: Double) -> Double {
        let t = min(1, max(0, expansion))
        return folded + (expanded - folded) * t
    }
}

/// What the glow does for a state. Only its opacity ever moves:
/// - `none`: nothing is drawn (the light fades out, then leaves the view tree);
/// - `hold`: it eases to a level over `fade` seconds and stays there, still;
/// - `flash`: it rises to a peak over `rise` seconds, then fades out over `fall`. A new serial starts a new flash.
public enum NotchGlowMotion: Equatable, Sendable {
    case none
    case hold(NotchGlowLevel, fade: Double)
    case flash(peak: NotchGlowLevel, rise: Double, fall: Double)

    /// Whether anything is lit.
    public var isLit: Bool { self != .none }
}

/// The glow's values (the colours are `NotchConfiguration.Glow`, the sweep's length `NotchConfiguration.Motion.glowSweep`).
///
/// The glow is light, not a line: a blurred ellipse in the gradient, behind the island, that shows round and below it.
/// It is rasterised once and only its opacity animates. A client can ask for the 2.6 pt trace along the outline as well
/// (for example under Increase Contrast, where a soft light alone is a weak signal).
public enum NotchGlow {
    // MARK: The ellipse

    /// The ellipse's blur radius.
    public static let ellipseBlur: CGFloat = 24
    /// How far past the ellipse's edge its blurred light reaches before it is gone: 2.5 blur radii. Measured offscreen, a
    /// 24 pt blur of an opaque edge leaves nothing (under one step of 255) beyond about 55 pt.
    public static let blurReach: CGFloat = 60
    /// Expanded: the ellipse is inset this far from the island's sides, its bottom this far below the island's, and it is
    /// at most `expandedMaxHeight` tall. Its top stays `blurReach` below the island's top, so no light shows above an
    /// expanded island.
    public static let expandedInset: CGFloat = 32, expandedBelow: CGFloat = 14, expandedMaxHeight: CGFloat = 260
    /// Folded at a notch (or a plain display's strip): wider than the island by `foldedOverhang` each side, `foldedHeight`
    /// tall, its bottom `foldedBelow` under the island's: a pool of light round and under the notch.
    public static let foldedOverhang: CGFloat = 20, foldedHeight: CGFloat = 80, foldedBelow: CGFloat = 32
    /// Folded as a pill (floating, or a Dynamic Island display): as wide as the pill, `pillHeight` tall, its bottom
    /// `pillBelow` under the pill's.
    public static let pillOverhang: CGFloat = 0, pillHeight: CGFloat = 50, pillBelow: CGFloat = 20

    /// The ellipse for an island drawn in `island` (the rect the glow view fills) at this expansion (0 folded, 1 expanded;
    /// clamped, though the island's own rect carries a spring's overshoot). Folded it is the notch's or the pill's pool;
    /// between the two it interpolates with the expansion.
    public static func ellipseRect(island r: CGRect, shape: NotchGlowShape, expansion: Double) -> CGRect {
        let t = CGFloat(min(1, max(0, expansion)))
        let pill = if case .pill = shape { true } else { false }
        let foldedOver = pill ? pillOverhang : foldedOverhang
        let foldedTall = pill ? pillHeight : foldedHeight
        let foldedUnder = pill ? pillBelow : foldedBelow
        let expandedTall = max(0, min(expandedMaxHeight, r.height + expandedBelow - blurReach))
        let over = foldedOver + (-expandedInset - foldedOver) * t
        let below = foldedUnder + (expandedBelow - foldedUnder) * t
        let height = max(0, foldedTall + (expandedTall - foldedTall) * t)
        return CGRect(x: r.minX - over, y: r.maxY + below - height, width: max(0, r.width + 2 * over), height: height)
    }

    /// The room the ellipse and its light take past the island on any side (the drawing's offscreen pass and the masks'
    /// padding): the farthest it hangs past the island, plus `blurReach`.
    public static let ellipseRoom: CGFloat = max(foldedBelow, pillBelow, expandedBelow, foldedOverhang, pillOverhang) + blurReach

    /// How far the light reaches past an island `islandHeight` tall at rest, for a client's panel margins: beside it, below
    /// it and above it; a notch island (`pill` false) or a pill, folded (`expansion` 0) or expanded (1).
    public static func reach(pill: Bool, expansion: Double, islandHeight: CGFloat) -> (side: CGFloat, below: CGFloat, above: CGFloat) {
        let island = CGRect(x: 0, y: 0, width: 400, height: islandHeight)
        let shape: NotchGlowShape = pill ? .pill(cornerRadius: 0) : .notch(shoulder: 0, bottomRadius: 0)
        let e = ellipseRect(island: island, shape: shape, expansion: expansion)
        return (max(0, island.minX - e.minX + blurReach), max(0, e.maxY - island.maxY + blurReach), max(0, island.minY - e.minY + blurReach))
    }

    // MARK: Opacity

    /// A lookup (turning): held still at 50 %.
    public static let turningLevel = NotchGlowLevel(0.5)
    /// A sweep's peak: 75 % expanded, 90 % folded (the folded pool is small, so it is brighter).
    public static let sweepPeak = NotchGlowLevel(folded: 0.9, expanded: 0.75)
    /// An alarm's sweeps peak at 90 %, folded or expanded.
    public static let alarmPeak = NotchGlowLevel(0.9)
    /// Under Reduce Motion a lookup or a sweep holds still at 50 % (an alarm at `alarmPeak`).
    public static let reduceMotionLevel = NotchGlowLevel(0.5)
    /// A hold eases in over 0.6 s; the light fades out over 0.6 s; under Reduce Motion every change is a 0.2 s cross-fade.
    public static let holdFade: Double = 0.6, fadeOut: Double = 0.6, crossFade: Double = 0.2
    /// A sweep rises over this share of `glowSweep` (0.48 s of 1.6 s) and fades out over the rest (1.12 s).
    public static let riseShare: Double = 0.3

    /// What the glow does for a state. Off, or the client's glow switch off: nothing. Turning: held at 50 %. A sweep: a
    /// flash to 75 % (90 % folded) and out again over `sweep`; an alarm's to 90 %. Reduce Motion: held still (50 %, an
    /// alarm 90 %) with 0.2 s cross-fades, for as long as the state lasts. Nothing repeats by itself: a client that wants
    /// another sweep (an alarm) sends a new serial.
    public static func motion(for state: NotchGlowState, on: Bool, reduceMotion: Bool, alarm: Bool = false,
                              sweep: Duration = NotchConfiguration.Motion().glowSweep) -> NotchGlowMotion {
        guard on else { return .none }
        switch state {
        case .off:
            return .none
        case .turning:
            return reduceMotion ? .hold(reduceMotionLevel, fade: crossFade) : .hold(turningLevel, fade: holdFade)
        case .sweep:
            if reduceMotion { return .hold(alarm ? alarmPeak : reduceMotionLevel, fade: crossFade) }
            let seconds = sweep / .seconds(1)
            return .flash(peak: alarm ? alarmPeak : sweepPeak, rise: seconds * riseShare, fall: seconds * (1 - riseShare))
        }
    }

    /// How long the light takes to go when its state ends.
    public static func fadeOut(reduceMotion: Bool) -> Double { reduceMotion ? crossFade : fadeOut }

    // MARK: The trace (opt-in)

    /// The trace along the outline, when the client asks for it: `traceWidth` outside the island's edge.
    public static let traceWidth: CGFloat = 2.6
    /// The room round the trace's offscreen pass: more than the stroke's half-width and its antialiasing.
    static let traceRoom: CGFloat = 2 * traceWidth

    /// The room the glow's drawing and masks keep round the island: the ellipse's (`ellipseRoom`) at every expansion.
    public static func drawingPadding(expansion: Double) -> CGFloat { ellipseRoom }

    /// start → end → start around the island, centred a little above the middle, starting at `angle` degrees: the
    /// trace's gradient.
    static func gradient(angle: Double, glow: NotchConfiguration.Glow) -> AngularGradient {
        AngularGradient(colors: [glow.start.color, glow.end.color, glow.start.color], center: UnitPoint(x: 0.5, y: 0.4), angle: .degrees(angle))
    }

    // MARK: 0.1's turning trace and backlight (kept for source compatibility; nothing in NotchKit draws them)

    @available(*, deprecated, message: "The backlight is now the ellipse (ellipseBlur).")
    public static let haloBlur: CGFloat = 24, haloOutset: CGFloat = 8
    @available(*, deprecated, message: "The backlight is now the ellipse (ellipseBlur).")
    public static let foldedHaloBlur: CGFloat = 32, foldedHaloOutset: CGFloat = 10

    @available(*, deprecated, message: "The backlight is now the ellipse (ellipseBlur).")
    public static func haloBlur(expansion: Double) -> CGFloat {
        let t = CGFloat(min(1, max(0, expansion)))
        return 32 + (24 - 32) * t
    }
    @available(*, deprecated, message: "The backlight is now the ellipse (ellipseRect).")
    public static func haloOutset(expansion: Double) -> CGFloat {
        let t = CGFloat(min(1, max(0, expansion)))
        return 10 + (8 - 10) * t
    }
    @available(*, deprecated, message: "The glow's opacity is now motion(for:on:reduceMotion:alarm:sweep:).")
    public static func haloOpacity(turning: Bool) -> Double { turning ? 0.35 : 0.30 }

    @available(*, deprecated, message: "The glow is now light, not a line: motion(for:on:reduceMotion:alarm:sweep:).")
    public static func appearance(for state: NotchGlowState, on: Bool, reduceMotion: Bool) -> NotchGlowAppearance {
        switch state {
        case .off: .none
        case .turning, .sweep:
            if !on { .whiteOutline }
            else if reduceMotion { .gradient(turning: false, halo: 0.30) }
            else if state == .turning { .gradient(turning: true, halo: 0.35) }
            else { .sweep(halo: 0.30) }
        }
    }

    @available(*, deprecated, message: "The glow no longer sweeps round the outline.")
    public static func sweepAngle(elapsed: TimeInterval, from start: Double = 0, sweep: Duration = NotchConfiguration.Motion().glowSweep) -> Double {
        let progress = elapsed / (sweep / .seconds(1))
        return start + min(max(progress, 0), 1) * 360
    }

    @available(*, deprecated, message: "The glow has no timeline: only its opacity animates.")
    public static func frameInterval(for appearance: NotchGlowAppearance) -> Double? {
        switch appearance {
        case .gradient(true, _): 1.0 / 30
        case .sweep: 1.0 / 60
        default: nil
        }
    }

    @available(*, deprecated, message: "The glow no longer turns.")
    public static func turnAngle(at date: Date, turn: Double = NotchConfiguration.Motion().glowTurn) -> Double {
        date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: turn) / turn * 360
    }
}

/// 0.1's glow appearances (the turning trace and backlight, or a white outline). Kept for source compatibility.
@available(*, deprecated, message: "The glow is now light, not a line: NotchGlowMotion.")
public enum NotchGlowAppearance: Equatable, Sendable {
    case none, gradient(turning: Bool, halo: Double), sweep(halo: Double), whiteOutline
}

/// What the glow follows: the notch island's edge, a plain display's folded 1 pt strip, or
/// the pill (on a Dynamic Island display, or floating).
public enum NotchGlowShape: Equatable, Sendable {
    case notch(shoulder: Double, bottomRadius: Double)
    case strip
    case pill(cornerRadius: Double)

    /// The shape of `geometry`'s island at `expansion` (0 folded, 1 expanded). A plain display folded is the strip; a
    /// Dynamic Island display is the pill at every expansion (folded too: nothing is filled there, the glow alone shows it).
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

/// The glow's light, still: a blurred ellipse in the configured gradient (start → end, leading to trailing), placed by
/// `NotchGlow.ellipseRect`. It fills the frame it is given (the island's rect) and draws past it, up to
/// `NotchGlow.ellipseRoom`. The ellipse and its blur are rasterised once into one bitmap (Metal, `drawingGroup`), so an
/// opacity change reuses it; it is redrawn only when the island's size changes. The caller draws the island over it (or
/// cuts the island's shape out of it).
public struct NotchGlowEllipse: View {
    let shape: NotchGlowShape
    let expansion: Double
    @Environment(\.notchConfiguration) private var configuration

    public init(shape: NotchGlowShape, expansion: Double = 1) { self.shape = shape; self.expansion = expansion }

    public var body: some View {
        let glow = configuration.appearance.glow
        let room = NotchGlow.ellipseRoom
        GeometryReader { proxy in
            let r = NotchGlow.ellipseRect(island: CGRect(origin: .zero, size: proxy.size), shape: shape, expansion: expansion)
            Ellipse()
                .fill(LinearGradient(colors: [glow.start.color, glow.end.color], startPoint: .leading, endPoint: .trailing))
                .frame(width: r.width, height: r.height)
                .offset(x: r.minX, y: r.minY)
        }
        .padding(room)
        .blur(radius: NotchGlow.ellipseBlur)
        .drawingGroup()
        .padding(-room)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The glow as the island's indicator: light behind the island (`NotchGlowEllipse`) whose opacity alone moves
/// (`NotchGlow.motion`): held at 50 % while a task turns, a flash to 75 % (90 % folded) and out for each sweep serial, a
/// flash to 90 % for each of an alarm's sweeps. It fills the frame it is given (the island's rect) and draws outside it,
/// so the caller fills the island over it (or masks the island out). A pill's or a strip's inside is cut out here, since
/// nothing fills it.
///
/// - `on` false (the client's glow switch off): nothing is drawn at all, at any moment.
/// - `trace`: the 2.6 pt gradient trace along the outline as well, still, while the glow is lit (for example under
///   Increase Contrast).
/// - `alarm`: each sweep peaks at 90 %.
/// - `topRoom`: the room above the frame inside the host's window, when its top is not the screen's edge (a floating
///   panel kept out of the menu bar, a panel under the menu bar). Under `blurReach` the light fades out toward that top,
///   so the window's edge never cuts it into a line (`notchGlowTopFade(room:)`).
/// - Reduce Motion: held still with 0.2 s cross-fades.
///
/// There is no timeline: nothing redraws per frame except while the island's size changes. When nothing is lit the
/// ellipse fades out and leaves the view tree. Colours, timing and a calibration come from the environment's
/// `notchConfiguration`; a calibration lights the glow steadily, with the trace.
public struct NotchGlowView: View {
    let state: NotchGlowState
    let shape: NotchGlowShape
    let on: Bool
    let reduceMotion: Bool
    /// 0 folded, 1 expanded: where the ellipse sits and how bright a sweep's peak is.
    let expansion: Double
    let trace: Bool
    let alarm: Bool
    /// The room above the frame's top inside the host's window (nil: the frame's top is the screen's edge).
    let topRoom: CGFloat?
    /// The light's opacity now (animated) and whether it is in the view tree.
    @State private var level: NotchGlowLevel
    @State private var present: Bool
    /// The trace's opacity (0 or 1, cross-faded).
    @State private var traceLit: Bool
    /// The motion in flight: a newer one makes an older flash's fade-out, or a fade's removal, a no-op.
    @State private var token = 0
    @Environment(\.notchConfiguration) private var configuration

    public init(state: NotchGlowState, shape: NotchGlowShape, on: Bool, reduceMotion: Bool, expansion: Double = 1,
                trace: Bool = false, alarm: Bool = false, topRoom: CGFloat? = nil) {
        self.state = state; self.shape = shape; self.on = on; self.reduceMotion = reduceMotion; self.expansion = expansion
        self.trace = trace; self.alarm = alarm; self.topRoom = topRoom
        // A still state shows from the first frame; a flash starts from nothing and rises once the view is up.
        let motion = NotchGlow.motion(for: state, on: on, reduceMotion: reduceMotion, alarm: alarm)
        if case .hold(let l, _) = motion { _level = State(initialValue: l) } else { _level = State(initialValue: .zero) }
        _present = State(initialValue: motion.isLit)
        _traceLit = State(initialValue: motion.isLit)
    }

    /// The calibration in effect (the client's `Debug.glowCalibration`); nil in a normal run.
    var calibration: NotchGlowCalibration?

    private struct Key: Equatable { var state: NotchGlowState, reduceMotion: Bool, alarm: Bool }

    public var body: some View {
        if calibration == nil, let calibrate = configuration.debug.glowCalibration {
            // Lit steadily whatever the state, re-reading the client's values twice a second so a change shows live.
            TimelineView(.periodic(from: .now, by: 0.5)) { _ in calibrated(calibrate()) }
        } else if calibration != nil {
            drawing(light: true, still: NotchGlow.turningLevel, trace: true)
        } else if on {
            drawing(light: present, still: nil, trace: trace && present)
                .onChange(of: Key(state: state, reduceMotion: reduceMotion, alarm: alarm), initial: true) { _, key in
                    run(NotchGlow.motion(for: key.state, on: true, reduceMotion: key.reduceMotion, alarm: key.alarm,
                                         sweep: configuration.motion.glowSweep), alarm: key.alarm)
                }
                // Switched off: nothing is kept, so switching back on starts from the state then, not a stale level.
                .onDisappear { token += 1; present = false; level = .zero; traceLit = false }
        }
    }

    private func calibrated(_ c: NotchGlowCalibration) -> NotchGlowView {
        var view = self
        view.calibration = c
        return view
    }

    /// Animates the light (and the trace) to a motion. A flash rises, then, unless another motion took over, fades out
    /// and leaves the view tree (an alarm's keeps its trace lit between beats); once nothing is lit and the fade has run,
    /// the ellipse leaves the view tree. Inserted under the motion's animation, the ellipse rises from nothing (its
    /// `.opacity` transition: an inserted modifier has no earlier value to animate from, so its level shows at once).
    private func run(_ motion: NotchGlowMotion, alarm: Bool) {
        token += 1
        let mine = token
        switch motion {
        case .none:
            withAnimation(.easeOut(duration: NotchGlow.fadeOut(reduceMotion: reduceMotion))) {
                level = .zero; traceLit = false
            } completion: {
                if token == mine { present = false }
            }
        case .hold(let target, let fade):
            withAnimation(.easeOut(duration: fade)) { present = true; level = target; traceLit = true }
        case .flash(let peak, let rise, let fall):
            withAnimation(.easeInOut(duration: rise)) { present = true; level = peak; traceLit = true } completion: {
                guard token == mine else { return }
                withAnimation(.easeInOut(duration: fall)) {
                    level = .zero
                    if !alarm { traceLit = false }
                } completion: {
                    if token == mine, !alarm { present = false }
                }
            }
        }
    }

    /// The light and the trace. A pill or a strip is never filled, so its inside is cut out: only the glow round it shows
    /// (the notch island is filled by the caller). `still` draws the light at that level, unanimated (a calibration).
    @ViewBuilder private func drawing(light: Bool, still: NotchGlowLevel?, trace showTrace: Bool) -> some View {
        let layers = ZStack {
            if light {
                NotchGlowEllipse(shape: shape, expansion: expansion)
                    .modifier(NotchGlowFade(level: still ?? level, expansion: expansion))
                    .transition(.opacity)
            }
            if showTrace {
                traceView.opacity(still != nil || traceLit ? 1 : 0)
            }
        }
        .notchGlowTopFade(room: topRoom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
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

    /// The glow's path, calibrated in a calibration run.
    private func path(edge: Bool) -> NotchGlowPath {
        var p = NotchGlowPath(shape: shape, edge: edge)
        p.calibration = calibration
        return p
    }

    /// The trace: the full outline, no trim, `traceWidth` wide outside the island's edge, in the still gradient. It is
    /// stroked twice that wide on the edge, and the inner half is the island's own fill (a notch island) or cut out (a
    /// pill or a strip, by `drawing`). Rasterised offscreen; the stroke keeps the island's frame, and only the offscreen
    /// pass is `traceRoom` larger on every side, so the half outside the island's edge is not clipped.
    private var traceView: some View {
        path(edge: true).stroke(NotchGlow.gradient(angle: 0, glow: configuration.appearance.glow), lineWidth: 2 * NotchGlow.traceWidth)
            .padding(NotchGlow.traceRoom)
            .drawingGroup()
            .padding(-NotchGlow.traceRoom)
    }
}

extension View {
    /// Fades the glow's light out toward a window's top edge `room` points above this view's frame, so the edge never
    /// cuts the light into a line: clear at that edge, full `NotchGlow.blurReach` below it. Nil, or room enough for the
    /// light (at least `blurReach`): unchanged. For a glow whose host's top is not the screen's edge.
    @ViewBuilder public func notchGlowTopFade(room: CGFloat?) -> some View {
        if let room, room < NotchGlow.blurReach {
            let pad = NotchGlow.ellipseRoom
            mask {
                VStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom).frame(height: NotchGlow.blurReach)
                    Rectangle()
                }
                .padding(.top, -max(0, room))
                .padding([.leading, .trailing, .bottom], -pad)
            }
        } else {
            self
        }
    }
}

/// The light's opacity: the animated level at the island's expansion, read each frame (only the opacity changes; the
/// rasterised ellipse is reused).
struct NotchGlowFade: ViewModifier, Animatable {
    var level: NotchGlowLevel
    var expansion: Double

    nonisolated var animatableData: AnimatablePair<Double, Double> {
        get { .init(level.folded, level.expanded) }
        set { level = NotchGlowLevel(folded: newValue.first, expanded: newValue.second) }
    }

    func body(content: Content) -> some View { content.opacity(level.at(expansion: expansion)) }
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

/// A by-eye match of the folded trace to the physical notch: the folded notch's outline moved in by `inset` on the
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
