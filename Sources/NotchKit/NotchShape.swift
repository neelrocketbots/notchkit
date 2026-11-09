import SwiftUI

/// The island's outline: hangs from the top edge like the notch, with concave shoulders that flare into
/// the screen edge and continuous (squircle) corners at the bottom. The shoulders live in the outer
/// `shoulder` points on each side of `rect`, so callers pad the content horizontally by that amount. Both are
/// interpolated with the expansion (`NotchGeometry.shoulder(expansion:)`, `cornerRadius(expansion:)`).
public struct NotchShape: Shape {
    public var shoulder: CGFloat
    public var bottomRadius: CGFloat
    /// The top corners: square under the notch; rounded as a floating island, or while it snaps or unsnaps
    /// (`NotchDockMotion.outline`).
    public var topRadius: CGFloat

    public init(shoulder: CGFloat = 12, bottomRadius: CGFloat = 20, topRadius: CGFloat = 0) {
        self.shoulder = shoulder; self.bottomRadius = bottomRadius; self.topRadius = topRadius
    }

    public func path(in rect: CGRect) -> Path {
        let body = rect.insetBy(dx: shoulder, dy: 0)
        var p = bodyPath(body)
        let l = leftShoulder(rect), r = rightShoulder(rect)
        // Left shoulder: top edge from the outer corner to the body, down the body's edge, then back along a concave arc.
        var left = Path()
        left.move(to: CGPoint(x: rect.minX, y: rect.minY))
        left.addLine(to: CGPoint(x: body.minX, y: rect.minY))
        left.addLine(to: l.foot)
        left.addCurve(to: l.tip, control1: l.footControl, control2: l.tipControl)
        left.closeSubpath()
        var right = Path()
        right.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        right.addLine(to: CGPoint(x: body.maxX, y: rect.minY))
        right.addLine(to: r.foot)
        right.addCurve(to: r.tip, control1: r.footControl, control2: r.tipControl)
        right.closeSubpath()
        p = p.union(left).union(right)
        return p
    }

    /// The visible edge as one open path, for the outline: from the top-left shoulder tip, along the concave
    /// arc and down the left side, along the bottom through both continuous corners, up the right side and out along
    /// the right arc to the top-right tip. It reuses `path(in:)`'s pieces: the body's rounded rectangle with its top
    /// edge removed, joined to the same shoulder arcs, so the two always match.
    public func outline(in rect: CGRect) -> Path {
        let body = rect.insetBy(dx: shoulder, dy: 0)
        let l = leftShoulder(rect), r = rightShoulder(rect)
        // The body's rim, top edge dropped, as a chain from its top-left corner round to its top-right corner.
        var chain = Segment.loop(of: bodyPath(body)).filter { !$0.isDegenerate && !$0.lies(onY: body.minY) }
        if let start = chain.firstIndex(where: { abs($0.start.y - body.minY) < 0.001 }) {
            chain = Array(chain[start...] + chain[..<start])
        }
        if let first = chain.first, first.start.x > body.midX {
            chain = chain.reversed().map(\.reversed)   // the rim ran clockwise from the top right: flip it
        }
        var p = Path()
        p.move(to: l.tip)
        p.addCurve(to: l.foot, control1: l.tipControl, control2: l.footControl)
        for (i, segment) in chain.enumerated() {
            var s = segment
            // The sides are straight: start below the left arc's foot and stop at the right arc's foot.
            if i == 0, case .line = s.kind, s.end.y > l.foot.y { s.start = l.foot }
            if i == chain.count - 1, case .line = s.kind, s.start.y > r.foot.y { s.end = r.foot }
            s.add(to: &p)
        }
        p.addCurve(to: r.tip, control1: r.footControl, control2: r.tipControl)
        return p
    }

    private func bodyPath(_ body: CGRect) -> Path {
        UnevenRoundedRectangle(topLeadingRadius: topRadius, bottomLeadingRadius: bottomRadius, bottomTrailingRadius: bottomRadius,
                               topTrailingRadius: topRadius, style: .continuous)
            .path(in: body)
    }

    /// A concave shoulder arc: from the tip on the top edge to the foot on the body's side, `shoulder` below the top.
    private struct Arc { var tip, tipControl, footControl, foot: CGPoint }

    private var k: CGFloat { 0.5523 * shoulder }   // cubic approximation of a quarter circle

    private func leftShoulder(_ rect: CGRect) -> Arc {
        let x = rect.minX + shoulder
        return Arc(tip: CGPoint(x: rect.minX, y: rect.minY), tipControl: CGPoint(x: rect.minX + k, y: rect.minY),
                   footControl: CGPoint(x: x, y: rect.minY + shoulder - k), foot: CGPoint(x: x, y: rect.minY + shoulder))
    }

    private func rightShoulder(_ rect: CGRect) -> Arc {
        let x = rect.maxX - shoulder
        return Arc(tip: CGPoint(x: rect.maxX, y: rect.minY), tipControl: CGPoint(x: rect.maxX - k, y: rect.minY),
                   footControl: CGPoint(x: x, y: rect.minY + shoulder - k), foot: CGPoint(x: x, y: rect.minY + shoulder))
    }

    /// One piece of a path with its start point made explicit, so a closed path can be cut open and reversed.
    private struct Segment {
        enum Kind { case line, quad(CGPoint), curve(CGPoint, CGPoint) }
        var start: CGPoint
        var kind: Kind
        var end: CGPoint

        var isDegenerate: Bool {
            guard start == end else { return false }
            return switch kind {
            case .line: true
            case .quad(let c): c == start
            case .curve(let c1, let c2): c1 == start && c2 == start
            }
        }

        func lies(onY y: CGFloat) -> Bool {
            let points: [CGPoint] = switch kind {
            case .line: [start, end]
            case .quad(let c): [start, c, end]
            case .curve(let c1, let c2): [start, c1, c2, end]
            }
            return points.allSatisfy { abs($0.y - y) < 0.001 }
        }

        var reversed: Segment {
            switch kind {
            case .line: Segment(start: end, kind: .line, end: start)
            case .quad(let c): Segment(start: end, kind: .quad(c), end: start)
            case .curve(let c1, let c2): Segment(start: end, kind: .curve(c2, c1), end: start)
            }
        }

        func add(to path: inout Path) {
            if path.currentPoint != start { path.addLine(to: start) }
            switch kind {
            case .line: path.addLine(to: end)
            case .quad(let c): path.addQuadCurve(to: end, control: c)
            case .curve(let c1, let c2): path.addCurve(to: end, control1: c1, control2: c2)
            }
        }

        /// The segments of a single closed subpath, including the closing line.
        static func loop(of path: Path) -> [Segment] {
            var segments: [Segment] = []
            var current = CGPoint.zero, first = CGPoint.zero
            path.forEach { element in
                switch element {
                case .move(let p): current = p; first = p
                case .line(let p): segments.append(Segment(start: current, kind: .line, end: p)); current = p
                case .quadCurve(let p, let c): segments.append(Segment(start: current, kind: .quad(c), end: p)); current = p
                case .curve(let p, let c1, let c2): segments.append(Segment(start: current, kind: .curve(c1, c2), end: p)); current = p
                case .closeSubpath:
                    if current != first { segments.append(Segment(start: current, kind: .line, end: first)) }
                    current = first
                }
            }
            return segments
        }
    }
}

/// The outline: `NotchShape`'s visible edge as an open path, to stroke and `trim(to:)`.
public struct NotchOutline: Shape {
    public var shoulder: CGFloat
    public var bottomRadius: CGFloat

    public init(shoulder: CGFloat = 12, bottomRadius: CGFloat = 20) { self.shoulder = shoulder; self.bottomRadius = bottomRadius }

    public func path(in rect: CGRect) -> Path {
        NotchShape(shoulder: shoulder, bottomRadius: bottomRadius).outline(in: rect)
    }
}

/// The island on a Dynamic Island display : an iPhone-style pill, a continuous rounded rect
/// with no concave shoulders (nothing hangs from a screen edge there). Folded it is a capsule (radius 16 on the 32 pt
/// pill), expanded the corners reach the notch island's 26 pt (`NotchGeometry.pillCornerRadius(expansion:)`).
public struct NotchPillShape: Shape {
    public var cornerRadius: Double

    public init(cornerRadius: Double) { self.cornerRadius = cornerRadius }

    public func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}
