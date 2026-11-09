import AppKit
import NotchKit
import SwiftUI

// NotchKitDemo: a floating island with NotchKit's default configuration, in a borderless non-activating panel.
// Drag it by its header, resize it from its bottom edge, double-click the header to send it back to the top centre, and
// click Sweep or Turn to light the glow. `swift run NotchKitDemo`; quit from the island or with Control-C.

/// The demo's model: the island's geometry and placement, and the panel it drives. It is the handles' driver.
@MainActor @Observable final class DemoIsland: NotchHandleDriver {
    var geometry: NotchGeometry
    var isMoving = false
    let isFloating = true
    var glow: NotchGlowState = .off
    private var sweeps = 0
    weak var panel: NSPanel?

    private var moveStart: (pointer: CGPoint, origin: CGPoint)?
    private var resizeStart: (pointer: CGPoint, height: Double, top: Double)?

    init(display: NotchDisplay?) {
        var g = NotchGeometry.make(notch: display?.notch, builtInNotchWidth: 0, menuBarHeight: display?.menuBarHeight ?? 24)
        g.isFloating = true
        geometry = g
    }

    var size: CGSize { geometry.expandedSize }
    /// The panel: the island plus room for the shadow and the glow on every side.
    var panelSize: CGSize { CGSize(width: size.width + 2 * NotchFloat.margin, height: size.height + 2 * NotchFloat.margin) }
    var minHeight: Double { NotchGeometry.idleHeight }
    var maxHeight: Double { Double(panel?.screen?.visibleFrame.height ?? 900) - NotchResize.dockClearance }

    func sweep() { sweeps += 1; glow = .sweep(serial: sweeps) }
    func toggleTurning() { glow = glow == .turning ? .off : .turning }

    // MARK: NotchHandleDriver

    func move(_ input: NotchHandleInput) {
        guard let panel else { return }
        switch input {
        case .began(let p):
            moveStart = (p, panel.frame.origin)
        case .changed(let p):
            guard let s = moveStart else { return }
            if !isMoving, hypot(p.x - s.pointer.x, p.y - s.pointer.y) < NotchFloat.dragThreshold { return }
            isMoving = true
            var frame = panel.frame
            frame.origin = CGPoint(x: s.origin.x + p.x - s.pointer.x, y: s.origin.y + p.y - s.pointer.y)
            panel.setFrame(frame, display: true)
        case .ended:
            moveStart = nil; isMoving = false
        case .cancel:
            if let s = moveStart { panel.setFrameOrigin(s.origin) }
            moveStart = nil; isMoving = false
        case .reset:
            placeAtTopCentre()
        case .corner(let corner):
            guard let visible = panel.screen?.visibleFrame else { return }
            let inset = NotchFloat.cornerInset - NotchFloat.margin
            let x = corner == .topLeft || corner == .bottomLeft ? visible.minX + inset : visible.maxX - inset - panel.frame.width
            let y = corner == .bottomLeft || corner == .bottomRight ? visible.minY + inset : visible.maxY - inset - panel.frame.height
            panel.setFrameOrigin(CGPoint(x: x, y: y))
        case .step:
            break
        }
    }

    func resize(_ input: NotchHandleInput) {
        guard let panel else { return }
        switch input {
        case .began(let p):
            resizeStart = (p, size.height, panel.frame.maxY)
        case .changed(let p):
            guard let s = resizeStart else { return }
            // AppKit's y grows upward: dragging the bottom edge down makes the island taller.
            let proposed = s.height + (s.pointer.y - p.y)
            setHeight(NotchResize.live(proposed: proposed, min: minHeight, max: maxHeight, reduceMotion: false), top: s.top)
        case .ended, .cancel:
            if let s = resizeStart {
                setHeight(NotchResize.settled(size.height, min: minHeight, max: maxHeight), top: s.top)
            }
            resizeStart = nil
        case .reset:
            setHeight(geometry.defaultExpandedHeight, top: panel.frame.maxY)
        case .step(let direction):
            setHeight(NotchResize.stepped(size.height, by: direction, min: minHeight, max: maxHeight), top: panel.frame.maxY)
        case .corner:
            break
        }
    }

    /// The island's height, its top edge (and so the panel's) kept where it was.
    private func setHeight(_ height: Double, top: Double) {
        geometry.expandedSize.height = height.rounded()
        guard let panel else { return }
        let s = panelSize
        panel.setFrame(CGRect(x: panel.frame.minX, y: top - s.height, width: s.width, height: s.height), display: true)
    }

    func placeAtTopCentre() {
        guard let panel, let visible = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
        let s = panelSize
        panel.setFrame(CGRect(x: visible.midX - s.width / 2, y: visible.maxY - s.height + NotchFloat.margin - 12,
                              width: s.width, height: s.height), display: true)
    }
}

/// The floating island: frost, border and shadow, the glow behind, a header that drags, the grip, the resize line.
struct DemoIslandView: View {
    let island: DemoIsland
    @State private var gripHover = false

    var body: some View {
        let shape = NotchPillShape(cornerRadius: NotchFloat.cornerRadius)
        let band = island.geometry.notch.height
        ZStack {
            NotchGlowView(state: island.glow, shape: .pill(cornerRadius: NotchFloat.cornerRadius), on: true, reduceMotion: false)
            NotchBackdrop(shape: AnyShape(shape), rendering: .material, height: island.size.height,
                          expandedHeight: island.geometry.defaultExpandedHeight, floating: true)
                .modifier(NotchFloatShadow(on: true))
            VStack(spacing: 0) {
                ZStack {
                    NotchMoveArea(driver: island)
                    NotchGripDots(lit: gripHover || island.isMoving)
                        .frame(width: NotchGrip.hitSize.width, height: NotchGrip.hitSize.height)
                        .contentShape(Rectangle())
                        .onHover { gripHover = $0 }
                        .notchMoveGesture(island)
                        .notchMoveGripAccessibility(island)
                }
                .frame(height: band)
                VStack(alignment: .leading, spacing: 10) {
                    Text("NotchKit").font(.headline).foregroundStyle(.white)
                    Text("A floating island with the default NotchConfiguration. Drag the header, resize from the bottom edge, double-click the header to recentre.")
                        .font(.callout).foregroundStyle(.white.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Sweep") { island.sweep() }
                        Button(island.glow == .turning ? "Stop" : "Turn") { island.toggleTurning() }
                        Spacer()
                        Button("Quit") { NSApp.terminate(nil) }
                    }
                    .controlSize(.small)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, NotchGeometry.bodyInset + 6)
                .padding(.top, NotchGeometry.bodyTop)
                NotchResizeHandle(driver: island)
            }
            .clipShape(shape)
        }
        .frame(width: island.size.width, height: island.size.height)
        .padding(NotchFloat.margin)
        .environment(\.colorScheme, .dark)
    }
}

/// A borderless panel that never activates the app: it takes clicks without stealing the keyboard.
final class DemoPanel: NSPanel {
    init(size: CGSize) {
        super.init(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .none
        isMovableByWindowBackground = false
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
    /// The panel goes exactly where it is put, under the menu bar too.
    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }
}

@MainActor final class DemoDelegate: NSObject, NSApplicationDelegate {
    private var panel: DemoPanel?
    private var island: DemoIsland?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let displays = NotchScreens.displays()
        let island = DemoIsland(display: displays.first { $0.isBuiltIn } ?? displays.first)
        let panel = DemoPanel(size: island.panelSize)
        // The host sits inside a plain container and never sizes the window: the panel has one frame owner.
        let host = NSHostingView(rootView: DemoIslandView(island: island))
        host.sizingOptions = []
        host.safeAreaRegions = []
        let container = NSView(frame: CGRect(origin: .zero, size: island.panelSize))
        host.frame = container.bounds
        host.autoresizingMask = [.width, .height]
        container.addSubview(host)
        panel.contentView = container
        island.panel = panel
        island.placeAtTopCentre()
        panel.orderFrontRegardless()
        self.panel = panel
        self.island = island
        lightGlowIfAsked(island, panel: panel)
    }

    /// `--glow sweep|turn`, for the docs' recordings: a sweep every 2.5 s or a steady turn from launch, and the panel's
    /// frame printed in top-left screen points (`panel x y w h`) so a recorder can frame it.
    private func lightGlowIfAsked(_ island: DemoIsland, panel: NSPanel) {
        let args = CommandLine.arguments
        guard let i = args.firstIndex(of: "--glow"), i + 1 < args.count else { return }
        switch args[i + 1] {
        case "turn": island.toggleTurning()
        case "sweep":
            island.sweep()
            Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in Task { @MainActor in island.sweep() } }
        default: break
        }
        if let primary = NSScreen.screens.first {
            let f = panel.frame
            print("panel \(Int(f.minX)) \(Int(primary.frame.maxY - f.maxY)) \(Int(f.width)) \(Int(f.height))")
            fflush(stdout)
        }
    }
}

let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
