import AppKit
import ImageIO
import NotchKit
import SwiftUI
import UniformTypeIdentifiers

// NotchKitDocImages: the figures in docs/images, rendered from NotchKit's own views and values at 2x, so every picture
// in the docs is the code it documents. `swift run NotchKitDocImages` rewrites them all; add a figure here when a doc
// needs one. Offscreen renders cannot blur what is behind a window, so the frosted body is drawn with `.tint`.

let imagesDir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
    .appending(path: "docs/images")

/// A 14" MacBook Pro's notch, the docs' worked example: 220 × 38, with the menu bar as tall as the notch.
let notch = Notch(width: 220, height: 38)
let notched = NotchGeometry.make(notch: notch, builtInNotchWidth: notch.width, menuBarHeight: notch.height)
let plain = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 24)
let dynamicIsland = NotchGeometry.make(notch: nil, builtInNotchWidth: 0, menuBarHeight: 37, dynamicIsland: true)

// MARK: - Pieces

/// A patch of desktop: a gradient, and a menu bar strip when asked.
struct Desktop<Content: View>: View {
    var menuBar: Double = 0
    var width: Double
    var height: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .top) {
            // A flat desktop: a gradient here quadruples the PNGs, and dependents clone this repository.
            Color(red: 0.36, green: 0.42, blue: 0.52)
            if menuBar > 0 {
                Color.white.opacity(0.14).frame(height: menuBar)
            }
            content()
        }
        .frame(width: width, height: height)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

struct Caption: View {
    let text: String
    init(_ text: String) { self.text = text }
    var body: some View {
        Text(text).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.92))
            .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
    }
}

/// A docked island drawn by NotchKit at an expansion: its size, shape, backdrop and glow all from the geometry.
struct Docked: View {
    var geometry: NotchGeometry
    var expansion: Double
    var rendering: NotchBackdrop.Rendering = .solid
    var glow: NotchGlowState = .off
    /// The idle island: the expanded shape at `NotchGeometry.idleHeight`.
    var idle = false

    var body: some View {
        let e = expansion, g = geometry
        let size = idle ? g.idleSize
            : CGSize(width: g.notch.width + (g.expandedSize.width - g.notch.width) * e,
                     height: g.notch.height + (g.expandedSize.height - g.notch.height) * e)
        let shape = NotchShape(shoulder: NotchGeometry.shoulder(expansion: e), bottomRadius: NotchGeometry.cornerRadius(expansion: e))
        ZStack {
            NotchGlowView(state: glow, shape: .notch(shoulder: shape.shoulder, bottomRadius: shape.bottomRadius), on: true,
                          reduceMotion: true, expansion: e)
            NotchBackdrop(shape: AnyShape(shape), rendering: rendering, height: size.height, expandedHeight: g.expandedSize.height)
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A floating island: the card with frost, border and shadow, and the notch's black bled in from its top edge.
struct Floating: View {
    var size: CGSize
    var bleed: Double = 0
    var glow: NotchGlowState = .off

    var body: some View {
        ZStack {
            NotchGlowView(state: glow, shape: .pill(cornerRadius: NotchFloat.cornerRadius), on: true, reduceMotion: true)
            NotchBackdrop(shape: AnyShape(NotchPillShape(cornerRadius: NotchFloat.cornerRadius)), rendering: .tint,
                          height: size.height, expandedHeight: size.height, floating: true, bleed: bleed, morph: 1)
                .modifier(NotchFloatShadow(on: true))
        }
        .frame(width: size.width, height: size.height)
    }
}

/// A dashed outline for a rect the docs talk about, with its label.
struct Marked: View {
    var rect: CGRect
    var color: Color
    var label: String
    var dash: [CGFloat] = [4, 3]
    var labelAt: Alignment = .bottomLeading

    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .strokeBorder(color, style: StrokeStyle(lineWidth: 1, dash: dash))
            .overlay(alignment: labelAt) {
                Text(label).font(.system(size: 10, weight: .semibold)).foregroundStyle(color)
                    .padding(.horizontal, 4).padding(.vertical, 1)
                    .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                    .padding(3)
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor final class StillDriver: NotchHandleDriver {
    var geometry = notched
    var isMoving = false
    var isFloating = false
    func resize(_ input: NotchHandleInput) {}
    func move(_ input: NotchHandleInput) {}
}

// MARK: - Figures

/// Displays: the folded island on each kind, under its menu bar.
@MainActor func displayKinds() -> some View {
    let w = 330.0, h = 120.0
    return HStack(alignment: .top, spacing: 16) {
        VStack(spacing: 8) {
            Desktop(menuBar: notch.height, width: w, height: h) {
                Docked(geometry: notched, expansion: 0)
            }
            Caption("Notch: the island folded is the 220 × 38 notch itself,\nhung from the top edge")
        }
        VStack(spacing: 8) {
            Desktop(menuBar: 37, width: w, height: h) {
                NotchPillShape(cornerRadius: 12).fill(.black).frame(width: 126, height: 24).padding(.top, 6)
                NotchGlowView(state: .sweep(serial: 1), shape: .pill(cornerRadius: NotchGeometry.pillCornerRadius(expansion: 0)),
                              on: true, reduceMotion: true, expansion: 0)
                    .frame(width: NotchGeometry.pillSize.width, height: NotchGeometry.pillSize.height)
                    .padding(.top, 37 + NotchGeometry.pillGap)
            }
            Caption("Dynamic Island: a 200 × 32 pill 6 pt under the camera island.\nFolded, nothing is filled; the glow alone traces it")
        }
        VStack(spacing: 8) {
            Desktop(menuBar: 24, width: w, height: h) {
                Marked(rect: CGRect(x: (w - plain.notch.width) / 2, y: 0, width: plain.notch.width, height: plain.notch.height),
                       color: .white.opacity(0.8), label: "virtual notch 200 × 24", labelAt: .bottomLeading)
                Color.orange.frame(width: plain.notch.width, height: NotchGeometry.stripHeight + NotchGeometry.stripHoverBelow)
                    .opacity(0.55)
            }
            Caption("Plain: a virtual notch, the built-in's width or 200 pt, by the menu bar.\nFolded draws nothing; the 1 pt strip plus 6 pt is the hover target")
        }
    }
    .padding(16)
    .background(.black)
}

/// Sizes derived from the notch: the expanded island in its panel, with the folded, idle and body rects.
@MainActor func geometry() -> some View {
    let g = notched
    let panel = CGRect(origin: .zero, size: g.panelSize)
    let island = g.islandRect(size: g.expandedSize)
    let idle = g.islandRect(size: g.idleSize)
    let pad = 28.0
    return Desktop(menuBar: notch.height, width: panel.width + 2 * pad, height: panel.height + 48) {
        ZStack(alignment: .topLeading) {
            Color.clear
            Docked(geometry: g, expansion: 1, rendering: .tint).offset(x: island.minX, y: island.minY)
            Marked(rect: panel, color: .white.opacity(0.7),
                   label: "panel \(Int(panel.width)) × \(Int(panel.height)): the island + 52 pt each side and below", labelAt: .bottomTrailing)
            Marked(rect: island, color: .cyan, label: "expanded \(Int(island.width)) × \(Int(island.height)) = (220 + 260) × (38 + 250)",
                   dash: [1, 0], labelAt: .leading)
            Marked(rect: idle, color: .mint, label: "idle \(Int(idle.width)) × \(Int(idle.height))", labelAt: .bottomTrailing)
            Marked(rect: g.collapsedRect, color: .orange, label: "folded = notch 220 × 38, the header band", labelAt: .topLeading)
            Marked(rect: g.bodyRect, color: .yellow, label: "body: inset 12, 2 below the band, 8 above the bottom", labelAt: .topLeading)
        }
        .frame(width: panel.width, height: panel.height)
    }
    .padding(16)
    .background(.black)
}

/// The shape at three expansions: shoulders 12e, bottom corners 9 + 17e, size from the notch to the expanded island.
@MainActor func shapeStates() -> some View {
    HStack(alignment: .top, spacing: 16) {
        ForEach([0.0, 0.5, 1.0], id: \.self) { e in
            let g = notched
            let w = g.notch.width + (g.expandedSize.width - g.notch.width) * e
            let h = g.notch.height + (g.expandedSize.height - g.notch.height) * e
            VStack(spacing: 8) {
                Desktop(menuBar: notch.height, width: 500, height: 310) { Docked(geometry: g, expansion: e) }
                Caption("expansion \(e.formatted()): \(Int(w)) × \(Int(h)), shoulders \(NotchGeometry.shoulder(expansion: e).formatted()) pt, "
                        + "corners \(NotchGeometry.cornerRadius(expansion: e).formatted()) pt")
            }
        }
    }
    .padding(16)
    .background(.black)
}

/// The backdrop in each state: solid folded and idle, frosted expanded, frosted all over floating.
@MainActor func backdropStates() -> some View {
    let g = notched
    let cell = CGSize(width: 520, height: 320)
    return Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        GridRow {
            VStack(spacing: 8) {
                Desktop(menuBar: notch.height, width: cell.width, height: cell.height) { Docked(geometry: g, expansion: 0) }
                Caption("Folded: solid black, the notch's own rect")
            }
            VStack(spacing: 8) {
                Desktop(menuBar: notch.height, width: cell.width, height: cell.height) { Docked(geometry: g, expansion: 1, idle: true) }
                Caption("Idle: solid black at 480 × 200")
            }
        }
        GridRow {
            VStack(spacing: 8) {
                Desktop(menuBar: notch.height, width: cell.width, height: cell.height) { Docked(geometry: g, expansion: 1, rendering: .tint) }
                Caption("Expanded: the material under a black overlay whose stops keep the band black\nand darken the body toward the bottom")
            }
            VStack(spacing: 8) {
                Desktop(menuBar: notch.height, width: cell.width, height: cell.height) {
                    Floating(size: g.expandedSize).padding(.top, 20)
                }
                Caption("Floating: frosted all over under a 42 % black tint, a 14 % white border,\n26 pt corners and the soft shadow")
            }
        }
    }
    .padding(16)
    .background(.black)
}

/// Notch bleed: a floating island approaching the notch takes in its black from the top edge.
@MainActor func bleed() -> some View {
    let g = notched
    let distances: [Double] = [NotchDockMotion.bleedReach, 20, 2, 0]
    let cell = CGSize(width: 520, height: 400)
    return Grid(horizontalSpacing: 16, verticalSpacing: 16) {
        ForEach([0, 2], id: \.self) { row in
            GridRow {
                ForEach(distances[row..<row + 2], id: \.self) { d in
                    let b = NotchDockMotion.bleed(proposedTop: d, dockTop: 0)
                    let ink = NotchDockMotion.ink(bleed: b)
                    VStack(spacing: 8) {
                        Desktop(menuBar: notch.height, width: cell.width, height: cell.height) {
                            Docked(geometry: g, expansion: 0)
                            Floating(size: g.expandedSize, bleed: b).padding(.top, d)
                        }
                        Caption("\(Int(d)) pt from the dock: bleed \(b.formatted(.number.precision(.fractionLength(0...3)))), "
                                + "ink depth \(ink.depth.formatted(.number.precision(.fractionLength(0...2)))), "
                                + "strength \(ink.strength.formatted(.number.precision(.fractionLength(0...2))))")
                    }
                }
            }
        }
    }
    .padding(16)
    .background(.black)
}

/// Where the glow goes: the notch island's edge, a plain display's strip, the pill.
@MainActor func glowShapes() -> some View {
    let w = 520.0, h = 330.0
    return HStack(alignment: .top, spacing: 16) {
        VStack(spacing: 8) {
            Desktop(menuBar: notch.height, width: w, height: h) { Docked(geometry: notched, expansion: 1, rendering: .tint, glow: .sweep(serial: 1)) }
            Caption("Notch: a 2.6 pt trace outside the island's edge, the shape blurred behind it as a backlight")
        }
        VStack(spacing: 8) {
            Desktop(menuBar: notch.height, width: w, height: h) { Docked(geometry: notched, expansion: 0, glow: .sweep(serial: 1)) }
            Caption("Folded: no shoulders, so the trace follows the hardware notch")
        }
        VStack(spacing: 8) {
            Desktop(menuBar: 24, width: w, height: h) {
                NotchGlowView(state: .sweep(serial: 1), shape: .strip, on: true, reduceMotion: true, expansion: 0)
                    .frame(width: plain.notch.width, height: NotchGeometry.stripHeight)
            }
            Caption("Plain display folded: the 1 pt strip at the top centre, nothing filled")
        }
    }
    .padding(16)
    .background(.black)
}

/// The grip and the resize line, at rest and lit.
@MainActor func handles() -> some View {
    let driver = StillDriver()
    let handle = NotchConfiguration().appearance.handle
    return HStack(spacing: 24) {
        VStack(spacing: 10) {
            HStack(spacing: 40) {
                NotchGripDots(lit: false)
                NotchGripDots(lit: true)
            }
            .padding(.horizontal, 40).padding(.vertical, 18)
            .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 12))
            Caption("Grip: 3 × 2 dots of 2.5 pt, at rest (35 %) and lit (85 %); hit area 44 × 12").frame(width: 300)
        }
        VStack(spacing: 10) {
            HStack(spacing: 40) {
                NotchResizeHandle(driver: driver).frame(width: 80)
                // Lit: the hover size and ink the handle takes over the bottom 12 pt band.
                Capsule().fill(handle.lineHover.color)
                    .frame(width: NotchResize.lineHover.width, height: NotchResize.lineHover.height)
                    .frame(width: 80, height: NotchResize.hitBand, alignment: .bottom)
                    .padding(.bottom, NotchResize.lineBottom - NotchResize.lineHover.height / 2)
            }
            .padding(.horizontal, 24).padding(.top, 18).padding(.bottom, 2)
            .background(Color(white: 0.11), in: RoundedRectangle(cornerRadius: 12))
            Caption("Resize line, 5 pt above the bottom edge: 32 × 2 at rest, 56 × 3 lit over the 12 pt band").frame(width: 300)
        }
    }
    .padding(16)
    .background(.black)
}

// MARK: - Render

@MainActor func write(_ name: String, _ view: some View) {
    let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
    renderer.scale = 2
    guard let image = renderer.cgImage else { fatalError("\(name): nothing rendered") }
    let url = imagesDir.appending(path: name)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        fatalError("\(name): cannot create \(url.path)")
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { fatalError("\(name): write failed") }
    print("wrote \(url.lastPathComponent) \(image.width / 2) × \(image.height / 2) pt")
}

_ = NSApplication.shared
try FileManager.default.createDirectory(at: imagesDir, withIntermediateDirectories: true)
write("display-kinds.png", displayKinds())
write("geometry.png", geometry())
write("shape-states.png", shapeStates())
write("backdrop-states.png", backdropStates())
write("bleed.png", bleed())
write("glow-shapes.png", glowShapes())
write("handles.png", handles())
