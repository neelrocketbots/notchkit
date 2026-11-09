import CoreGraphics
import Foundation
@testable import NotchKit
import SwiftUI
import Testing

@Suite struct NotchGlowTests {
    /// Owner ruling 2026-10-31: the sweep redraws at most 60 times a second (not ProMotion's 120 Hz), the turn at 30; a
    /// still glow has no timeline rate. The angle is read from the clock, so the cap does not change the sweep's speed.
    @Test func theSweepIsCappedAtSixtyFramesASecond() {
        let halo = NotchGlow.haloOpacity(turning: false)
        #expect(NotchGlow.frameInterval(for: .sweep(halo: halo)) == 1.0 / 60)
        #expect(NotchGlow.frameInterval(for: .gradient(turning: true, halo: halo)) == 1.0 / 30)
        #expect(NotchGlow.frameInterval(for: .gradient(turning: false, halo: halo)) == nil)
        #expect(NotchGlow.frameInterval(for: .whiteOutline) == nil && NotchGlow.frameInterval(for: .none) == nil)
        #expect(abs(NotchGlow.sweepAngle(elapsed: 0.4) - 90) < 0.001, "time-based: a quarter of the sweep is 90 degrees at any frame rate")
    }

    /// Review Focus 3: what each state draws.
    @Test func theGlowTurnsForALookupAndSweepsOnceForACardOrMarker() {
        #expect(NotchGlow.appearance(for: .off, on: true, reduceMotion: false) == .none)
        #expect(NotchGlow.appearance(for: .turning, on: true, reduceMotion: false) == .gradient(turning: true, halo: 0.35))
        #expect(NotchGlow.appearance(for: .sweep(serial: 1), on: true, reduceMotion: false) == .sweep(halo: 0.30), "A sweep runs the trace once and does not turn; the halo stays at 30%")
        #expect(NotchGlow.appearance(for: .turning, on: true, reduceMotion: true) == .gradient(turning: false, halo: 0.30), "Reduce Motion: still")
        #expect(NotchGlow.appearance(for: .sweep(serial: 2), on: true, reduceMotion: true) == .gradient(turning: false, halo: 0.30), "Reduce Motion: a sweep shows still at full and fades")
    }


    @Test func quietDrawsNoGlowAndRestHoverScrollDrawNone() {
        // the client decides the state; the view's mapping has no hover or scroll input at all
        #expect(NotchGlow.appearance(for: .off, on: true, reduceMotion: false) == .none)
        #expect(NotchGlow.appearance(for: .off, on: false, reduceMotion: false) == .none)
        #expect(NotchGlow.appearance(for: .off, on: true, reduceMotion: true) == .none)
    }


    @Test func glowOffIsAPlainWhiteOutline() {
        #expect(NotchGlow.appearance(for: .turning, on: false, reduceMotion: false) == .whiteOutline)
        #expect(NotchGlow.appearance(for: .sweep(serial: 1), on: false, reduceMotion: true) == .whiteOutline)
    }


    /// A sweep's gradient runs once round, 0 to 360 degrees over 1.6 s, linear, and stops there.
    @Test func aSweepRunsOnceRoundOver1600Milliseconds() {
        #expect(NotchConfiguration.Motion().glowSweep == .milliseconds(1600))
        #expect(NotchGlow.sweepAngle(elapsed: 0) == 0 && abs(NotchGlow.sweepAngle(elapsed: 0.8) - 180) < 0.001 && abs(NotchGlow.sweepAngle(elapsed: 1.6) - 360) < 0.001)
        #expect(NotchGlow.sweepAngle(elapsed: 5) == 360 && NotchGlow.sweepAngle(elapsed: -1) == 0, "it stops at one turn, and never runs back")
    }


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


    @Test func theBacklightFollowsTheExpansion() {
        #expect(NotchGlow.haloBlur(expansion: 0) == 32 && NotchGlow.haloOutset(expansion: 0) == 10)
        #expect(NotchGlow.haloBlur(expansion: 1) == 24 && NotchGlow.haloOutset(expansion: 1) == 8)
        #expect(NotchGlow.haloBlur(expansion: 0.5) == 28 && NotchGlow.haloOutset(expansion: 0.5) == 9)
        #expect(NotchGlow.haloBlur(expansion: 1.2) == 24 && NotchGlow.haloBlur(expansion: -0.2) == 32, "the springs' overshoot clamps")
        #expect(NotchGlow.drawingPadding(expansion: 1) == 80, "the expanded padding is today's")
        #expect(NotchGlow.drawingPadding(expansion: 0) == 106)
    }


    // MARK: Calibration

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
