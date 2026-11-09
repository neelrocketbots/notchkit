import CoreGraphics
import Foundation
import NotchKit
import SwiftUI
import Testing

@Suite struct NotchShapeTests {
    private let rect = CGRect(x: 0, y: 0, width: 404, height: 120)
    private let shape = NotchShape(shoulder: 12, bottomRadius: 20)

    @Test func theOutlineRunsFromTheLeftShoulderTipToTheRightOne() {
        let outline = shape.outline(in: rect)
        var first: CGPoint?, last: CGPoint?
        outline.forEach { element in
            switch element {
            case .move(let p): first = first ?? p; last = p
            case .line(let p), .quadCurve(let p, _), .curve(let p, _, _): last = p
            case .closeSubpath: Issue.record("the outline is open")
            }
        }
        #expect(first == CGPoint(x: 0, y: 0))
        #expect(last == CGPoint(x: 404, y: 0))
    }

    @Test func theOutlineTracesTheFilledShape() {
        let outline = shape.outline(in: rect).boundingRect
        let fill = shape.path(in: rect).boundingRect
        #expect(abs(outline.minX - fill.minX) < 0.01 && abs(outline.maxX - fill.maxX) < 0.01)
        #expect(abs(outline.maxY - fill.maxY) < 0.01 && abs(outline.minY - fill.minY) < 0.01)
    }

    @Test func theOutlineGoesDownTheLeftSideFirstAndIsSymmetric() {
        let outline = shape.outline(in: rect)
        let quarter = outline.trimmedPath(from: 0, to: 0.2).boundingRect
        #expect(quarter.maxX < rect.midX, "the first fifth stays on the left")
        let half = outline.trimmedPath(from: 0, to: 0.5).currentPoint!
        #expect(abs(half.x - rect.midX) < 0.5 && abs(half.y - rect.maxY) < 0.5, "halfway is the middle of the bottom edge")
    }

    /// The pill on a Dynamic Island display is a continuous rounded rect with no shoulders: a
    /// capsule at radius 16 on the 32 pt pill, the notch island's 26 pt expanded.
    @Test func thePillIsAContinuousRoundedRectWithoutShoulders() {
        let pill = CGRect(x: 0, y: 0, width: 200, height: 32)
        let path = NotchPillShape(cornerRadius: 16).path(in: pill)
        #expect(path == RoundedRectangle(cornerRadius: 16, style: .continuous).path(in: pill))
        #expect(path.boundingRect == pill, "it fills its rect and nothing flares past it")
        #expect(!path.contains(CGPoint(x: 0.5, y: 0.5)) && !path.contains(CGPoint(x: 199.5, y: 0.5)), "its top corners are round: no shoulders reach the top edge's ends")
        #expect(path.contains(CGPoint(x: 100, y: 0.5)) && path.contains(CGPoint(x: 100, y: 16)))
        let expanded = CGRect(x: 0, y: 0, width: 460, height: 282)
        #expect(NotchPillShape(cornerRadius: NotchGeometry.pillCornerRadius(expansion: 1)).path(in: expanded)
                == RoundedRectangle(cornerRadius: 26, style: .continuous).path(in: expanded))
    }
}
