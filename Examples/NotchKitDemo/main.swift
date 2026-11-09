import AppKit
import NotchKit
import SwiftUI

// NotchKitDemo: an island with NotchKit's default configuration in a borderless non-activating panel. It starts docked
// under the notch (a virtual one on a plain display). Drag the header past 6 pt to pull it out as a floating card; push
// it back against the top over the notch and let go to snap it in; double-click the header to dock it; resize it from its
// bottom edge; click Sweep or Turn to light the glow. `swift run NotchKitDemo`; quit from the island or with Control-C.
//
// Flags, for the docs' recordings: `--floating` starts floating; `--glow sweep|turn` lights the glow from launch;
// `--snap` floats the island out and snaps it back in a loop. Any flag prints the panel's frame (`panel x y w h`, top-left
// screen points) so a recorder can frame it.

/// The panel's margin round the island on every side: room for the glow, the shadow and the snap's overshoot.
let margin = NotchGeometry.outset + NotchGeometry.blur + NotchGeometry.overshoot

/// The demo's model: the island's geometry, placement, snap state and the panel it drives. It is the handles' driver.
@MainActor @Observable final class DemoIsland: NotchHandleDriver {
    let display: NotchDisplay
    let screen: NSScreen
    var geometry: NotchGeometry
    var isFloating = false
    var isMoving = false
    /// The snap's progress: 0 at a flip of the placement, 1 settled (`NotchDockMotion.outline`, the backdrop's morph).
    var morph: Double = 1
    /// The squash and stretch toward the notch (`NotchDockMotion.scale`).
    var stretch: Double = 0
    /// The notch's black bled into a floating island near the dock (`NotchDockMotion.bleed`).
    var bleed: Double = 0
    /// The pointer is on the notch region, so the docked grip shows.
    var gripShown = false
    var glow: NotchGlowState = .off
    private var sweeps = 0
    weak var panel: NSPanel?

    private var moveStart: (pointer: CGPoint, origin: CGPoint)?
    private var resizeStart: (pointer: CGPoint, height: Double, top: Double)?
    /// The dragged island's top-left rect in screen points, before clamping: what decides the dock on release.
    private var proposed: CGRect?

    init(display: NotchDisplay, screen: NSScreen) {
        self.display = display
        self.screen = screen
        geometry = NotchGeometry.make(notch: display.notch, builtInNotchWidth: display.notch?.width ?? 0,
                                      menuBarHeight: display.menuBarHeight)
    }

    var size: CGSize { geometry.expandedSize }
    var panelSize: CGSize { CGSize(width: size.width + 2 * margin, height: size.height + 2 * margin) }
    var minHeight: Double { NotchGeometry.idleHeight }
    var maxHeight: Double { screen.visibleFrame.height - NotchResize.dockClearance }
    /// The top edge a floating island stops at: the menu bar's bottom, in top-left screen points.
    var dockTop: Double { display.y + display.menuBarHeight }

    func sweep() { sweeps += 1; glow = .sweep(serial: sweeps) }
    func toggleTurning() { glow = glow == .turning ? .off : .turning }

    // MARK: Placement

    /// The docked frame: the island's top on the screen's top edge, centred on the notch.
    var dockedFrame: CGRect {
        let s = panelSize
        return CGRect(x: screen.frame.midX - s.width / 2, y: screen.frame.maxY + margin - s.height, width: s.width, height: s.height)
    }

    func placeDocked() {
        isFloating = false
        morph = 1; bleed = 0; stretch = 0
        panel?.setFrame(dockedFrame, display: true)
    }

    func placeFloatingAtTopCentre() {
        guard let panel else { return }
        isFloating = true
        morph = 1; bleed = 0; stretch = 0
        let island = CGRect(x: display.x + (display.width - size.width) / 2, y: dockTop + 12, width: size.width, height: size.height)
        panel.setFrame(frame(forIsland: island), display: true)
    }

    /// Let go of the notch: the card at once, the shape springing into it.
    func detach() {
        isFloating = true
        morph = 0
        withAnimation(NotchDockMotion.snapSpring()) { morph = 1; stretch = 0 }
    }

    /// Snap into the notch: the panel moves at once, only the view springs (the shoulders grow back, the frost and the
    /// shadow fade, the stretch overshoots).
    func dock() {
        isFloating = false
        morph = 0
        bleed = 0
        proposed = nil
        panel?.setFrame(dockedFrame, display: true)
        withAnimation(NotchDockMotion.snapSpring()) { morph = 1; stretch = 0 }
    }

    /// A floating island asked to sit at `island` (top-left screen points): it is kept inside the visible rect, and near
    /// the dock over the notch it takes the notch's black and stretches toward it.
    func moveFloating(to island: CGRect) {
        guard let panel else { return }
        proposed = island
        let overNotch = island.maxX > display.x + (display.width - geometry.notch.width) / 2
            && island.minX < display.x + (display.width + geometry.notch.width) / 2
        bleed = overNotch ? NotchDockMotion.bleed(proposedTop: island.minY, dockTop: dockTop) : 0
        stretch = overNotch ? NotchDockMotion.pushStretch(proposedTop: island.minY, dockTop: dockTop) : 0
        panel.setFrame(frame(forIsland: NotchFloat.clamp(island, in: display.visibleRect)), display: true)
    }

    /// Whether a release here docks: the top pressed against the menu bar over the notch.
    var touchesDock: Bool {
        guard let p = proposed else { return false }
        return NotchFloat.touchesDock(proposedTop: p.minY, left: p.minX, right: p.maxX, display: display, notchWidth: geometry.notch.width)
    }

    /// The panel frame (AppKit, bottom-left) that puts the island at `island` (top-left screen points).
    private func frame(forIsland island: CGRect) -> CGRect {
        let primary = NSScreen.screens.first?.frame ?? screen.frame
        return CGRect(x: island.minX - margin, y: primary.maxY - island.maxY - margin, width: panelSize.width, height: panelSize.height)
    }

    /// The island's rect in top-left screen points for a panel frame.
    private func island(in frame: CGRect) -> CGRect {
        let primary = NSScreen.screens.first?.frame ?? screen.frame
        return CGRect(x: frame.minX + margin, y: primary.maxY - frame.maxY + margin, width: size.width, height: size.height)
    }

    // MARK: NotchHandleDriver

    func move(_ input: NotchHandleInput) {
        guard let panel else { return }
        switch input {
        case .began(let p):
            moveStart = (p, panel.frame.origin)
        case .changed(let p):
            guard let s = moveStart else { return }
            let distance = hypot(p.x - s.pointer.x, p.y - s.pointer.y)
            if !isMoving {
                if !isFloating { stretch = NotchDockMotion.pullStretch(distance: distance) }
                if distance < NotchFloat.dragThreshold { return }
                isMoving = true
                if !isFloating { detach() }
            }
            var frame = panel.frame
            frame.origin = CGPoint(x: s.origin.x + p.x - s.pointer.x, y: s.origin.y + p.y - s.pointer.y)
            moveFloating(to: island(in: frame))
        case .ended:
            if isMoving, touchesDock {
                dock()
            } else {
                withAnimation(NotchDockMotion.snapSpring()) { bleed = 0; stretch = 0 }
            }
            moveStart = nil; isMoving = false
        case .cancel:
            if let s = moveStart, isFloating { panel.setFrameOrigin(s.origin) }
            withAnimation(NotchDockMotion.snapSpring()) { bleed = 0; stretch = 0 }
            moveStart = nil; isMoving = false
        case .reset:
            if isFloating { dock() }
        case .corner(let corner):
            if !isFloating { detach() }
            let anchor = NotchFloat.anchor(corner: corner, size: size, visible: display.visibleRect)
            moveFloating(to: CGRect(x: anchor.x - size.width / 2, y: anchor.y, width: size.width, height: size.height))
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
            let proposedHeight = s.height + (s.pointer.y - p.y)
            setHeight(NotchResize.live(proposed: proposedHeight, min: minHeight, max: maxHeight, reduceMotion: false), top: s.top)
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

    // MARK: Scripted snap (`--snap`)

    /// Floats the island out 120 pt and snaps it back, over and over: the drag's own code path, no pointer needed.
    func loopSnap() {
        Task { @MainActor in
            while true {
                try? await Task.sleep(for: .seconds(1.6))
                let docked = island(in: dockedFrame)
                detach()
                await glide(from: docked.minY, to: docked.minY + 120, over: 0.55, at: docked)
                try? await Task.sleep(for: .seconds(1.4))
                await glide(from: docked.minY + 120, to: docked.minY - 1, over: 0.7, at: docked)
                if touchesDock { dock() }
            }
        }
    }

    /// Moves the floating island's top from one y to another, eased, as a drag would.
    private func glide(from: Double, to: Double, over seconds: Double, at island: CGRect) async {
        let steps = Int(seconds * 60)
        for i in 1...steps {
            let t = Double(i) / Double(steps), eased = t < 0.5 ? 2 * t * t : 1 - pow(-2 * t + 2, 2) / 2
            var r = island
            r.origin.y = from + (to - from) * eased
            moveFloating(to: r)
            try? await Task.sleep(for: .milliseconds(1000 / 60))
        }
    }
}

/// The island: frost, border and shadow, the glow behind, a header that drags, the grip, the resize line. Docked it is
/// the notch's shape; floating, the card; the snap morphs between them.
struct DemoIslandView: View {
    let island: DemoIsland
    @State private var gripHover = false

    var body: some View {
        let o = NotchDockMotion.outline(floating: island.isFloating, expansion: 1, morph: island.morph)
        let shape = NotchShape(shoulder: o.shoulder, bottomRadius: o.bottomRadius, topRadius: o.topRadius)
        let band = island.geometry.notch.height
        let glowShape: NotchGlowShape = island.isFloating ? .pill(cornerRadius: NotchFloat.cornerRadius)
            : .notch(shoulder: o.shoulder, bottomRadius: o.bottomRadius)
        ZStack {
            NotchGlowView(state: island.glow, shape: glowShape, on: true, reduceMotion: false)
            NotchBackdrop(shape: AnyShape(shape), rendering: .material, height: island.size.height,
                          expandedHeight: island.geometry.defaultExpandedHeight, floating: island.isFloating,
                          bleed: island.bleed, morph: island.morph)
                .modifier(NotchFloatShadow(on: island.isFloating, amount: island.morph))
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    NotchMoveArea(driver: island)
                    NotchGripDots(lit: gripHover || island.isMoving)
                        .frame(width: NotchGrip.hitSize.width, height: NotchGrip.hitSize.height)
                        .contentShape(Rectangle())
                        .onHover { gripHover = $0 }
                        .notchMoveGesture(island)
                        .notchMoveGripAccessibility(island)
                        .offset(y: island.isFloating ? (band - NotchGrip.hitSize.height) / 2
                                : NotchGrip.dockedTop(band: band, shown: island.gripShown || island.isMoving, reduceMotion: false))
                        .animation(.easeOut(duration: 0.18), value: island.gripShown)
                }
                .frame(height: band)
                .onHover { island.gripShown = $0 }
                VStack(alignment: .leading, spacing: 10) {
                    Text("NotchKit").font(.headline).foregroundStyle(.white)
                    Text("Drag the header to pull the island out of the notch; push it back against the top and let go to snap it in. Double-click the header to dock it, resize from the bottom edge.")
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
        .scaleEffect(NotchDockMotion.scale(stretch: island.stretch, height: island.size.height), anchor: .top)
        .padding(margin)
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
        guard let display = displays.first(where: { $0.isMain }) ?? displays.first, let screen = NSScreen.screens.first else {
            fatalError("no display")
        }
        let island = DemoIsland(display: display, screen: screen)
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
        let args = CommandLine.arguments
        if args.contains("--floating") { island.placeFloatingAtTopCentre() } else { island.placeDocked() }
        panel.orderFrontRegardless()
        self.panel = panel
        self.island = island
        runFlags(args, island: island, panel: panel)
    }

    /// `--glow sweep|turn` and `--snap`, for the docs' recordings, and the panel's frame printed for the recorder.
    private func runFlags(_ args: [String], island: DemoIsland, panel: NSPanel) {
        guard args.count > 1 else { return }
        if let i = args.firstIndex(of: "--glow"), i + 1 < args.count {
            switch args[i + 1] {
            case "turn": island.toggleTurning()
            case "sweep":
                island.sweep()
                Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { _ in Task { @MainActor in island.sweep() } }
            default: break
            }
        }
        if args.contains("--snap") { island.loopSnap() }
        if let primary = NSScreen.screens.first {
            // The frame while docked plus the snap's 120 pt travel, so a recording of the loop keeps the island in view.
            let f = panel.frame, extra = args.contains("--snap") ? 120.0 : 0
            print("panel \(Int(f.minX)) \(Int(primary.frame.maxY - f.maxY)) \(Int(f.width)) \(Int(f.height + extra))")
            fflush(stdout)
        }
    }
}

let app = NSApplication.shared
let delegate = DemoDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
