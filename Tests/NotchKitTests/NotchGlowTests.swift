import CoreGraphics
import Foundation
@testable import NotchKit
import SwiftUI
import Testing

@Suite struct NotchGlowTests {
    // MARK: What each state does

    /// A lookup holds still at 50 %; a sweep flashes to 75 % (90 % folded) in 0.48 s and fades out over 1.12 s; an alarm's
    /// sweeps flash to 90 %. Off, or the client's switch off, draws nothing.
    @Test func eachStateHasItsMotion() {
        #expect(NotchGlow.motion(for: .off, on: true, reduceMotion: false) == .none)
        #expect(NotchGlow.motion(for: .turning, on: true, reduceMotion: false) == .hold(NotchGlowLevel(0.5), fade: 0.6))
        guard case .flash(let peak, let rise, let fall) = NotchGlow.motion(for: .sweep(serial: 1), on: true, reduceMotion: false) else {
            Issue.record("a sweep flashes"); return
        }
        #expect(peak == NotchGlowLevel(folded: 0.9, expanded: 0.75))
        #expect(abs(rise - 0.48) < 1e-9 && abs(fall - 1.12) < 1e-9, "0.48 s up, 1.12 s out: the 1.6 s sweep")
        guard case .flash(let alarm, _, _) = NotchGlow.motion(for: .sweep(serial: 2), on: true, reduceMotion: false, alarm: true) else {
            Issue.record("an alarm's sweep flashes"); return
        }
        #expect(alarm == NotchGlowLevel(0.9), "an alarm peaks at 90 %, folded or expanded: no recolour, no growth")
        #expect(peak.at(expansion: 0) == 0.9 && peak.at(expansion: 1) == 0.75 && abs(peak.at(expansion: 0.5) - 0.825) < 1e-9)
        #expect(peak.at(expansion: 1.2) == 0.75 && peak.at(expansion: -0.2) == 0.9, "the springs' overshoot clamps")
    }

    @Test func theSweepFollowsTheConfiguredLength() {
        guard case .flash(_, let rise, let fall) = NotchGlow.motion(for: .sweep(serial: 1), on: true, reduceMotion: false, sweep: .milliseconds(1000)) else {
            Issue.record("a sweep flashes"); return
        }
        #expect(abs(rise - 0.3) < 1e-9 && abs(fall - 0.7) < 1e-9)
    }

    /// Reduce Motion: held still (50 %, an alarm 90 %) for as long as the state lasts, with 0.2 s cross-fades.
    @Test func reduceMotionHoldsStill() {
        #expect(NotchGlow.motion(for: .turning, on: true, reduceMotion: true) == .hold(NotchGlowLevel(0.5), fade: 0.2))
        #expect(NotchGlow.motion(for: .sweep(serial: 1), on: true, reduceMotion: true) == .hold(NotchGlowLevel(0.5), fade: 0.2))
        #expect(NotchGlow.motion(for: .sweep(serial: 1), on: true, reduceMotion: true, alarm: true) == .hold(NotchGlowLevel(0.9), fade: 0.2))
        #expect(NotchGlow.fadeOut(reduceMotion: true) == 0.2 && NotchGlow.fadeOut(reduceMotion: false) == 0.6)
    }

    /// The client's glow switch off draws nothing, at any moment (no outline in its place).
    @Test func glowOffIsNothing() {
        for state in [NotchGlowState.off, .turning, .sweep(serial: 1)] {
            for reduceMotion in [false, true] {
                #expect(NotchGlow.motion(for: state, on: false, reduceMotion: reduceMotion) == .none)
                #expect(NotchGlow.motion(for: state, on: false, reduceMotion: reduceMotion, alarm: true) == .none)
            }
        }
    }

    // MARK: No repeating animation (performance)

    /// A lookup can last a minute: nothing may repeat while it runs. Its motion is a hold (one ease, then still), and the
    /// glow's source has no timeline, no repeating, phase or keyframe animation and no timer; the only timeline is a
    /// calibration run's twice-a-second re-read of the client's values.
    @Test func aLookupRunsNoRepeatingAnimation() throws {
        for reduceMotion in [false, true] {
            guard case .hold = NotchGlow.motion(for: .turning, on: true, reduceMotion: reduceMotion) else {
                Issue.record("a lookup holds still (reduce motion \(reduceMotion))"); continue
            }
        }
        let url = NotchKitSourceScanTests.sourceDir.appending(path: "NotchGlow.swift")
        let code = try String(contentsOf: url, encoding: .utf8).split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("//") }
            .joined(separator: "\n")
        for banned in ["repeatForever", "repeatCount", "phaseAnimator", "keyframeAnimator", "TimelineView(.animation", "Timer", "CADisplayLink"] {
            #expect(!code.contains(banned), "NotchGlow.swift uses \(banned)")
        }
        #expect(code.components(separatedBy: "TimelineView(").count == 2, "one timeline: the calibration's")
        #expect(code.contains("TimelineView(.periodic(from: .now, by: 0.5))"))
    }

    // MARK: The ellipse

    /// Expanded: inset 32 from the sides, its bottom 14 below the island's, at most 260 tall, its top 60 below the island's
    /// top (no light above an expanded island).
    @Test func theExpandedEllipseSitsUnderTheIsland() {
        let island = CGRect(x: 0, y: 0, width: 480, height: 288)
        let e = NotchGlow.ellipseRect(island: island, shape: .notch(shoulder: 12, bottomRadius: 26), expansion: 1)
        #expect(e == CGRect(x: 32, y: 302 - 242, width: 416, height: 242), "\(e)")
        let tall = NotchGlow.ellipseRect(island: CGRect(x: 0, y: 0, width: 480, height: 600), shape: .pill(cornerRadius: 26), expansion: 1)
        #expect(tall.height == 260 && tall.maxY == 614, "capped at 260, hanging from 14 below the bottom")
        let short = NotchGlow.ellipseRect(island: CGRect(x: 10, y: 20, width: 480, height: 200), shape: .pill(cornerRadius: 26), expansion: 1)
        #expect(short.minY == 20 + 60 && short.maxY == 20 + 200 + 14)
    }

    /// Folded at a notch: notch + 40 wide, 80 tall, its bottom 32 below the notch's. A pill (floating or a Dynamic Island
    /// display): as wide as the pill, 50 tall, its bottom 20 below. A plain display's strip is the notch's pool.
    @Test func theFoldedEllipseIsAPoolUnderTheNotchOrThePill() {
        let notch = CGRect(x: 100, y: 0, width: 220, height: 38)
        #expect(NotchGlow.ellipseRect(island: notch, shape: .notch(shoulder: 0, bottomRadius: 9), expansion: 0) == CGRect(x: 80, y: -10, width: 260, height: 80))
        #expect(NotchGlow.ellipseRect(island: CGRect(x: 100, y: 0, width: 220, height: 1), shape: .strip, expansion: 0) == CGRect(x: 80, y: -47, width: 260, height: 80))
        let pill = CGRect(x: 50, y: 60, width: 132, height: 30)
        #expect(NotchGlow.ellipseRect(island: pill, shape: .pill(cornerRadius: 15), expansion: 0) == CGRect(x: 50, y: 60, width: 132, height: 50))
        let half = NotchGlow.ellipseRect(island: CGRect(x: 0, y: 0, width: 300, height: 160), shape: .notch(shoulder: 6, bottomRadius: 17.5), expansion: 0.5)
        #expect(half.minX == 6 && half.width == 288, "the overhang goes from +20 to -32")
        #expect(abs(half.maxY - (160 + 23)) < 1e-9, "the bottom from 32 to 14 below")
        #expect(abs(half.height - (80 + (160 + 14 - 60)) / 2) < 1e-9, "the height from 80 to the expanded rule's")
    }

    /// The drawing's room covers the light's reach past the island on every side, folded and expanded.
    @Test func theRoomCoversTheReach() {
        #expect(NotchGlow.ellipseRoom == 92 && NotchGlow.drawingPadding(expansion: 0) == 92 && NotchGlow.drawingPadding(expansion: 1) == 92)
        for pill in [false, true] {
            for e in stride(from: 0.0, through: 1, by: 0.25) {
                for h in [1.0, 30, 38, 200, 288, 600] {
                    let r = NotchGlow.reach(pill: pill, expansion: e, islandHeight: h)
                    #expect(r.side <= NotchGlow.ellipseRoom && r.below <= NotchGlow.ellipseRoom, "pill \(pill) e \(e) h \(h): \(r)")
                    if pill || e > 0 { #expect(r.above <= NotchGlow.ellipseRoom, "pill \(pill) e \(e) h \(h): \(r)") }
                }
            }
        }
        #expect(NotchGlow.reach(pill: false, expansion: 1, islandHeight: 288).above == 0, "no light above an expanded island")
    }

    // MARK: The panel's room (no hard edge)

    /// The light (the ellipse plus `blurReach`) never reaches a panel's edge, so the window never clips it into a hard
    /// line: docked (sides and bottom; the top is the screen's edge), with the client's growth used up and the spring's
    /// overshoot, and floating (every side), expanded and folded to the pill at any edge of the island.
    @Test(arguments: [
        NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38),
        NotchGeometry.make(notch: Notch(width: 185, height: 32), builtInNotchWidth: 185, menuBarHeight: 32),
        NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24),
        NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, touch: true),
    ])
    func theLightStaysInsideThePanel(_ g: NotchGeometry) {
        func light(_ island: CGRect, _ shape: NotchGlowShape, _ e: Double) -> CGRect {
            NotchGlow.ellipseRect(island: island, shape: shape, expansion: e).insetBy(dx: -NotchGlow.blurReach, dy: -NotchGlow.blurReach)
        }
        for growth in [0.0, 380] {
            let panel = CGRect(origin: .zero, size: g.panelSize(growth: growth))
            let tall = CGSize(width: g.expandedSize.width, height: g.expandedSize.height + growth)
            for overshoot in [0.0, NotchGeometry.overshoot] {
                let island = g.islandRect(size: CGSize(width: tall.width, height: tall.height + overshoot))
                let l = light(island, .of(g, expansion: 1), 1)
                #expect(l.minX >= panel.minX && l.maxX <= panel.maxX && l.maxY <= panel.maxY, "docked \(g.kind), growth \(growth), overshoot \(overshoot): \(l) in \(panel)")
            }
            // (A Dynamic Island display's panel top is the menu bar's bottom, 6 pt above the pill: there the client fades the
            // light toward it, `aDynamicIslandPanelFadesTheLightUnderTheMenuBar`.)
            let folded = light(g.collapsedRect.isEmpty ? NotchGlowShape.stripRect(g) : g.collapsedRect, .of(g, expansion: 0), 0)
            #expect(folded.minX >= 0 && folded.maxX <= panel.maxX && folded.maxY <= panel.maxY, "docked folded \(g.kind): \(folded)")

            // Floating: the pill at the island's top centre, top-left, top-right, and pinned to its bottom.
            let w = g.expandedSize.width, h = tall.height, pw = NotchFloat.pillSize.width, ph = NotchFloat.pillSize.height
            for offset in [CGSize.zero, CGSize(width: -(w - pw) / 2, height: 0), CGSize(width: (w - pw) / 2, height: 0),
                           CGSize(width: -(w - pw) / 2, height: h - ph), CGSize(width: (w - pw) / 2, height: h - ph)] {
                let f = g.floating(pillOffset: offset)
                let fp = CGRect(origin: .zero, size: f.panelSize(growth: growth))
                let pill = light(f.collapsedRect, .of(f, expansion: 0), 0)
                #expect(fp.insetBy(dx: -0.001, dy: -0.001).contains(pill), "floating pill at \(offset), growth \(growth): \(pill) in \(fp)")
                for overshoot in [0.0, NotchGeometry.overshoot] {
                    let open = light(f.islandRect(size: CGSize(width: tall.width, height: tall.height + overshoot)), .of(f, expansion: 1), 1)
                    #expect(fp.insetBy(dx: -0.001, dy: -0.001).contains(open), "floating open, growth \(growth), overshoot \(overshoot): \(open) in \(fp)")
                }
            }
        }
        #expect(NotchGeometry.sideMargin == 60 && NotchGeometry.bottomMargin == 94 && NotchFloat.margin == 60)
    }

    // MARK: Shapes and calibration

    /// Where the glow goes: round the notch's visible edge, along the 1 pt strip on a plain display
    /// folded, round the pill on a Dynamic Island display (folded too: nothing is filled there).
    @Test func theGlowFollowsTheDisplaysIsland() {
        let notched = NotchGeometry.make(notch: Notch(width: 200, height: 38), builtInNotchWidth: 200, menuBarHeight: 38)
        let plain = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24)
        let pill = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, touch: true)
        #expect(NotchGlowShape.of(notched, expansion: 0) == .notch(shoulder: 0, bottomRadius: 9), "folded: the notch rect's edge, no shoulders")
        #expect(NotchGlowShape.of(notched, expansion: 1) == .notch(shoulder: 12, bottomRadius: 26))
        #expect(NotchGlowShape.of(plain, expansion: 0) == .strip, "a plain display folded: the 1 pt strip")
        #expect(NotchGlowShape.of(plain, expansion: 1) == .notch(shoulder: 12, bottomRadius: 26), "expanded it is the island")
        #expect(NotchGlowShape.of(pill, expansion: 0) == .pill(cornerRadius: 16), "the capsule, folded too")
        #expect(NotchGlowShape.of(pill, expansion: 1) == .pill(cornerRadius: 26))
        #expect(NotchGlowShape.stripRect(plain) == CGRect(x: (plain.panelSize.width - plain.notch.width) / 2, y: 0, width: plain.notch.width, height: 1),
                "a 1 x notch.w rectangle at the top centre")
    }

    @Test func calibrationMovesAndResizesTheFoldedRect() {
        let notch = CGRect(x: 182, y: 0, width: 220, height: 38)
        #expect(NotchGlowCalibration().apply(to: notch) == notch)
        #expect(NotchGlowCalibration(inset: 1).apply(to: notch) == CGRect(x: 183, y: 0, width: 218, height: 37), "in on the sides and the bottom, top flush")
        #expect(NotchGlowCalibration(widthDelta: 4, heightDelta: 2).apply(to: notch) == CGRect(x: 180, y: 0, width: 224, height: 40), "wider about the centre")
        #expect(NotchGlowCalibration(xOffset: 0.5, yOffset: -1).apply(to: notch) == CGRect(x: 182.5, y: -1, width: 220, height: 38))
    }

    /// The calibrated path moves only the folded notch (no shoulder); the expanded island's is untouched.
    @Test func calibrationAppliesToTheFoldedNotchOnly() {
        let rect = CGRect(x: 0, y: 0, width: 220, height: 38)
        let c = NotchGlowCalibration(widthDelta: 4, bottomRadius: 12)
        var folded = NotchGlowPath(shape: .notch(shoulder: 0, bottomRadius: 9), edge: true)
        folded.calibration = c
        #expect(folded.path(in: rect) == NotchShape(shoulder: 0, bottomRadius: 12).outline(in: CGRect(x: -2, y: 0, width: 224, height: 38)))
        var expanded = NotchGlowPath(shape: .notch(shoulder: 12, bottomRadius: 26), edge: true)
        expanded.calibration = c
        #expect(expanded.path(in: rect) == NotchGlowPath(shape: .notch(shoulder: 12, bottomRadius: 26), edge: true).path(in: rect))
    }
}

/// The glow's pixels, rendered offscreen (`ImageRenderer`: no window). Each render is over a transparent background, so a
/// pixel's alpha is the light there.
@Suite struct NotchGlowRenderTests {
    struct Pixels {
        let width: Int, height: Int
        let bytes: [UInt8]
        func rgba(_ x: Int, _ y: Int) -> [UInt8] { Array(bytes[(y * width + x) * 4 ..< (y * width + x) * 4 + 4]) }
        func alpha(_ x: Int, _ y: Int) -> UInt8 { bytes[(y * width + x) * 4 + 3] }
        /// The most opaque pixel along the panel's left, right and bottom edges (and the top, if asked).
        func edgeAlpha(top: Bool) -> UInt8 {
            var m: UInt8 = 0
            for y in 0..<height { m = max(m, alpha(0, y), alpha(width - 1, y)) }
            for x in 0..<width { m = max(m, alpha(x, height - 1)); if top { m = max(m, alpha(x, 0)) } }
            return m
        }
    }

    @MainActor static func render(_ view: some View, size: CGSize, scale: CGFloat = 1) throws -> Pixels {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height, alignment: .topLeading))
        renderer.scale = scale
        let image = try #require(renderer.cgImage)
        let w = image.width, h = image.height
        var bytes = [UInt8](repeating: 0, count: w * h * 4)
        bytes.withUnsafeMutableBytes { raw in
            let ctx = CGContext(data: raw.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            ctx?.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return Pixels(width: w, height: h, bytes: bytes)
    }

    /// The light at the glow's highest peak (90 %), placed at `island` in a panel `panel` big.
    @MainActor static func peak(_ island: CGRect, _ shape: NotchGlowShape, expansion: Double, panel: CGSize, topRoom: CGFloat? = nil) -> some View {
        NotchGlowEllipse(shape: shape, expansion: expansion)
            .opacity(NotchGlow.alarmPeak.folded)
            .frame(width: island.width, height: island.height)
            .notchGlowTopFade(room: topRoom)
            .padding(.leading, island.minX).padding(.top, island.minY)
            .frame(width: panel.width, height: panel.height, alignment: .topLeading)
    }

    /// `blurReach` holds: at full opacity, nothing is left `blurReach` past the ellipse's edge.
    @MainActor @Test func theLightIsGoneByItsReach() throws {
        let island = CGRect(x: 120, y: 120, width: 132, height: 30)
        let e = NotchGlow.ellipseRect(island: island, shape: .pill(cornerRadius: 15), expansion: 0)
        let size = CGSize(width: 400, height: 400)
        let p = try Self.render(NotchGlowEllipse(shape: .pill(cornerRadius: 15), expansion: 0)
            .frame(width: island.width, height: island.height).padding(.leading, island.minX).padding(.top, island.minY)
            .frame(width: size.width, height: size.height, alignment: .topLeading), size: size)
        let reach = Int(NotchGlow.blurReach)
        #expect(p.alpha(Int(e.midX), Int(e.maxY) + reach) == 0 && p.alpha(Int(e.midX), Int(e.minY) - reach) == 0, "above and below")
        #expect(p.alpha(Int(e.minX) - reach, Int(e.midY)) == 0 && p.alpha(Int(e.maxX) + reach, Int(e.midY)) == 0, "beside it")
        #expect(p.alpha(Int(e.midX), Int(e.midY)) > 128, "lit inside")
    }

    /// At the glow's peak the panel's edge rows stay transparent, so the window never cuts the light into a hard edge:
    /// docked (the top is the screen's edge) with the client's growth used up, and floating, expanded and with the pill at
    /// the island's corner.
    @MainActor @Test(arguments: [0.0, 380])
    func thePanelsEdgesStayClearAtThePeak(growth: Double) throws {
        let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38)
        let tall = CGSize(width: g.expandedSize.width, height: g.expandedSize.height + growth)
        let panel = g.panelSize(growth: growth)
        let docked = try Self.render(Self.peak(g.islandRect(size: tall), .of(g, expansion: 1), expansion: 1, panel: panel), size: panel)
        #expect(docked.edgeAlpha(top: false) == 0, "docked, growth \(growth): edge alpha \(docked.edgeAlpha(top: false))")
        let folded = try Self.render(Self.peak(g.collapsedRect, .of(g, expansion: 0), expansion: 0, panel: panel), size: panel)
        #expect(folded.edgeAlpha(top: false) == 0)

        let pw = NotchFloat.pillSize.width, ph = NotchFloat.pillSize.height
        for offset in [CGSize.zero, CGSize(width: -(tall.width - pw) / 2, height: 0), CGSize(width: (tall.width - pw) / 2, height: tall.height - ph)] {
            let f = g.floating(pillOffset: offset)
            let fp = f.panelSize(growth: growth)
            let open = try Self.render(Self.peak(f.islandRect(size: tall), .of(f, expansion: 1), expansion: 1, panel: fp), size: fp)
            #expect(open.edgeAlpha(top: true) == 0, "floating open, growth \(growth): \(open.edgeAlpha(top: true))")
            let pill = try Self.render(Self.peak(f.collapsedRect, .of(f, expansion: 0), expansion: 0, panel: fp), size: fp)
            #expect(pill.edgeAlpha(top: true) == 0, "floating pill at \(offset), growth \(growth): \(pill.edgeAlpha(top: true))")
        }
    }

    /// Where the window's top is not the screen's edge and the room above the island is short (a floating panel kept out
    /// of the menu bar: 16 pt at a VoiceOver corner, 0 after a drag to the top; a Dynamic Island display's panel, 6 pt
    /// under the menu bar), `notchGlowTopFade` fades the light out toward that top: the top row stays clear at the peak,
    /// and the light under the island still shows.
    @MainActor @Test(arguments: [0.0, 16, 59])
    func aShortTopFadesTheLightOut(topMargin: Double) throws {
        let g = NotchGeometry.make(notch: Notch(width: 220, height: 38), builtInNotchWidth: 220, menuBarHeight: 38).floating(topMargin: topMargin)
        let panel = g.panelSize
        for (island, e) in [(g.collapsedRect, 0.0), (g.islandRect(size: g.expandedSize), 1.0)] {
            let p = try Self.render(Self.peak(island, .of(g, expansion: e), expansion: e, panel: panel, topRoom: island.minY), size: panel)
            #expect(p.edgeAlpha(top: true) <= 1, "top margin \(topMargin), expansion \(e): edge alpha \(p.edgeAlpha(top: true))")
            #expect(p.alpha(Int(island.midX), Int(island.maxY) + 10) > 20, "the light under the island still shows")
        }
        let unfaded = try Self.render(Self.peak(g.collapsedRect, .of(g, expansion: 0), expansion: 0, panel: panel), size: panel)
        if topMargin < 30 { #expect(unfaded.edgeAlpha(top: true) > 2, "without the fade the top edge would cut the light") }
    }

    @MainActor @Test func aDynamicIslandPanelFadesTheLightUnderTheMenuBar() throws {
        let g = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true, touch: true)
        #expect(g.islandTop < NotchGlow.blurReach, "the panel's top is the menu bar's bottom, 6 pt above the pill")
        let p = try Self.render(Self.peak(g.collapsedRect, .of(g, expansion: 0), expansion: 0, panel: g.panelSize, topRoom: g.collapsedRect.minY), size: g.panelSize)
        #expect(p.edgeAlpha(top: true) <= 1, "edge alpha \(p.edgeAlpha(top: true))")
        #expect(p.alpha(Int(g.collapsedRect.midX), Int(g.collapsedRect.maxY) + 10) > 10)
    }

    private static let island = CGSize(width: 300, height: 120)
    private static let panel = CGSize(width: 300 + 2 * 92, height: 120 + 92)

    @MainActor private func glow(_ state: NotchGlowState, on: Bool = true, reduceMotion: Bool = false, trace: Bool = false) -> some View {
        NotchGlowView(state: state, shape: .notch(shoulder: 12, bottomRadius: 26), on: on, reduceMotion: reduceMotion, trace: trace)
            .frame(width: Self.island.width, height: Self.island.height)
            .padding(.leading, 92)
            .frame(width: Self.panel.width, height: Self.panel.height, alignment: .topLeading)
    }

    private func lit(_ p: Pixels) -> Int { stride(from: 3, to: p.bytes.count, by: 4).filter { p.bytes[$0] > 0 }.count }

    /// Off draws nothing; the glow switch off draws nothing even mid-lookup; a lookup's light shows below the island,
    /// coral to marigold, soft (no line on the edge) unless the trace is asked for.
    @MainActor @Test func theLightAndTheOptInTrace() throws {
        #expect(lit(try Self.render(glow(.off), size: Self.panel)) == 0, "off: nothing")
        #expect(lit(try Self.render(glow(.turning, on: false), size: Self.panel)) == 0, "the glow switched off: nothing, no outline")
        let lookup = try Self.render(glow(.turning), size: Self.panel)
        let x = 92 + Int(Self.island.width / 2), bottom = Int(Self.island.height)
        let under = lookup.rgba(x, bottom + 10)
        #expect(under[3] > 40 && under[0] > under[2], "warm light under the island, got \(under)")
        let edge = Int(lookup.alpha(x, bottom)), out = Int(lookup.alpha(x, bottom + 3))
        #expect(abs(edge - out) < 12, "no line on the edge: \(edge) at it, \(out) 3 pt out")
        let traced = try Self.render(glow(.turning, trace: true), size: Self.panel)
        let line = traced.rgba(x, bottom + 1)
        #expect(line[3] > 230 && line[0] > 180, "the trace, opaque on the edge, got \(line)")
        #expect(abs(Int(traced.alpha(x, bottom + 12)) - Int(lookup.alpha(x, bottom + 12))) <= 1, "the light under it is the same")
    }

    /// A pill's inside stays clear: nothing is filled there, so the light shows round it only.
    @MainActor @Test func thePillsInsideIsCutOut() throws {
        let size = CGSize(width: 400, height: 200)
        let p = try Self.render(NotchGlowView(state: .turning, shape: .pill(cornerRadius: 16), on: true, reduceMotion: false, expansion: 0)
            .frame(width: 200, height: 32).padding(.leading, 100).padding(.top, 40)
            .frame(width: size.width, height: size.height, alignment: .topLeading), size: size)
        #expect(p.alpha(200, 56) == 0 && p.alpha(120, 50) == 0, "inside the pill: clear")
        #expect(p.alpha(200, 80) > 20, "below it: light")
    }

    /// Reduce Motion: a sweep holds at the lookup's 50 %.
    @MainActor @Test func reduceMotionHoldsTheSweepAtTheLookupsLevel() throws {
        let still = try Self.render(glow(.sweep(serial: 1), reduceMotion: true), size: Self.panel)
        let lookup = try Self.render(glow(.turning, reduceMotion: true), size: Self.panel)
        let off = zip(still.bytes, lookup.bytes).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(off <= 1 && lit(still) > 0, "the still sweep is the still lookup, off by \(off)")
    }
}
