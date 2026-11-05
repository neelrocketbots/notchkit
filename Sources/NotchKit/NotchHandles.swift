import AppKit
import SwiftUI

/// What the island's handles drive: the client's model, which resizes and moves the island on their input
/// (`NotchHandleInput`) and says whether it is floating or being moved.
@MainActor public protocol NotchHandleDriver: AnyObject {
    var geometry: NotchGeometry { get }
    var isMoving: Bool { get }
    var isFloating: Bool { get }
    func resize(_ input: NotchHandleInput)
    func move(_ input: NotchHandleInput)
}

/// The pointer in AppKit screen coordinates: the handles read it, not the gesture's local translation, because the panel
/// moves or grows under the pointer while they drag.
@MainActor func notchPointer() -> CGPoint { NSEvent.mouseLocation }

/// The resize grab line: a 32 × 2 pt capsule 5 pt above the island's bottom edge (`Handle.lineRest`); over the bottom 12 pt
/// band it grows to 56 × 3 (`Handle.lineHover`) with the up-down resize pointer. Dragging the band changes the expanded
/// height (`NotchHandleDriver.resize`), a double-click goes back to the default, and VoiceOver adjusts the height (the
/// configured `Strings.height`) by 40 pt.
public struct NotchResizeHandle: View {
    let driver: any NotchHandleDriver
    /// On the island's top edge (a floating island held against the screen's bottom grows upward).
    var top: Bool
    @State private var hovering = false
    @State private var dragging = false
    @Environment(\.notchConfiguration) private var configuration

    public init(driver: any NotchHandleDriver, top: Bool = false) { self.driver = driver; self.top = top }

    public var body: some View {
        let lit = hovering || dragging
        let line = lit ? NotchResize.lineHover : NotchResize.lineRest
        let handle = configuration.appearance.handle, strings = configuration.strings
        ZStack(alignment: top ? .top : .bottom) {
            Capsule()
                .fill((lit ? handle.lineHover : handle.lineRest).color)
                .frame(width: line.width, height: line.height)
                .padding(top ? .top : .bottom, NotchResize.lineBottom - line.height / 2)
        }
        .frame(maxWidth: .infinity, minHeight: NotchResize.hitBand, maxHeight: NotchResize.hitBand, alignment: top ? .top : .bottom)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .pointerStyle(.frameResize(position: top ? .top : .bottom))
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .global)
                .onChanged { _ in
                    if !dragging { dragging = true; driver.resize(.began(notchPointer())) }
                    driver.resize(.changed(notchPointer()))
                }
                .onEnded { _ in
                    dragging = false
                    driver.resize(.ended)
                }
        )
        .simultaneousGesture(TapGesture(count: 2).onEnded { driver.resize(.reset) })
        .onDisappear { if dragging { dragging = false; driver.resize(.cancel) } }
        .accessibilityElement()
        .accessibilityLabel(strings.height)
        .accessibilityValue(strings.heightValue(driver.geometry.expandedSize.height))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: driver.resize(.step(1))
            case .decrement: driver.resize(.step(-1))
            @unknown default: break
            }
        }
    }
}

/// A drag on the grip or the header's empty space moves the island (`NotchHandleDriver.move`); the client lets go of the
/// notch after 6 pt, so a click is still a click. A double-click docks it.
public struct NotchMoveGesture: ViewModifier {
    let driver: any NotchHandleDriver
    @State private var dragging = false

    public init(driver: any NotchHandleDriver) { self.driver = driver }

    public func body(content: Content) -> some View {
        content
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { _ in
                        if !dragging { dragging = true; driver.move(.began(notchPointer())) }
                        driver.move(.changed(notchPointer()))
                    }
                    .onEnded { _ in
                        dragging = false
                        driver.move(.ended)
                    }
            )
            .simultaneousGesture(TapGesture(count: 2).onEnded { driver.move(.reset) })
            // The view going away mid-drag (the fold) never leaves the drag stuck.
            .onDisappear { if dragging { dragging = false; Self.disappeared(driver) } }
    }

    /// The drag's view went away before its end: the drag is cancelled.
    public static func disappeared(_ driver: any NotchHandleDriver) { driver.move(.cancel) }
}

extension View {
    /// Moves the island by this view.
    public func notchMoveGesture(_ driver: any NotchHandleDriver) -> some View { modifier(NotchMoveGesture(driver: driver)) }

    /// The move grip's VoiceOver element: the configured `Strings.move`, a button that docks while floating (its default
    /// action), with Dock and the four corners as actions.
    public func notchMoveGripAccessibility(_ driver: any NotchHandleDriver) -> some View {
        modifier(NotchMoveGripAccessibility(driver: driver))
    }
}

private struct NotchMoveGripAccessibility: ViewModifier {
    let driver: any NotchHandleDriver
    @Environment(\.notchConfiguration) private var configuration

    func body(content: Content) -> some View {
        let strings = configuration.strings
        content
            .accessibilityElement()
            .accessibilityLabel(strings.move)
            // Floating, its default action (VO-Space) docks the island; docked there is nothing to press, so it is no
            // button then, only the corner actions.
            .accessibilityAddTraits(driver.isFloating ? .isButton : [])
            .accessibilityAction { if driver.isFloating { driver.move(.reset) } }
            .accessibilityActions {
                if driver.isFloating { Button(strings.dock) { driver.move(.reset) } }
                ForEach(NotchCorner.allCases, id: \.self) { corner in
                    Button(strings.corner(corner)) { driver.move(.corner(corner)) }
                }
            }
    }
}

/// The header's empty space: drags the island too. Behind the header's buttons, which take their own clicks.
public struct NotchMoveArea: View {
    let driver: any NotchHandleDriver

    public init(driver: any NotchHandleDriver) { self.driver = driver }

    public var body: some View {
        Color.clear
            .contentShape(Rectangle())
            .notchMoveGesture(driver)
            .accessibilityHidden(true)
    }
}

/// The ::: grip's metrics: 3 × 2 dots centred just below the notch (in the header's middle when floating, where no notch
/// hides it).
public enum NotchGrip {
    public static let dot: Double = 2.5, gap: Double = 2.5
    /// The grip's hit area round its dots.
    public static let hitSize = CGSize(width: 44, height: 12)
    /// The notch region reaches this far below the grip's shown spot, so moving onto the grip keeps it out.
    public static let revealSlack: Double = 6

    /// Where the docked grip sits (its top inside the island): shown, just below the notch band; hidden, up inside the band,
    /// behind the notch. Under Reduce Motion it never moves; it fades where it shows.
    public static func dockedTop(band: Double, shown: Bool, reduceMotion: Bool) -> Double {
        shown || reduceMotion ? band - 2 : (band - hitSize.height) / 2
    }
}

/// The ::: grip's 3 × 2 dots, at rest and `lit` (`Handle.gripRest`, `gripHover`): the open island's grip and the floating
/// folded pill's hint, one look.
public struct NotchGripDots: View {
    let lit: Bool
    @Environment(\.notchConfiguration) private var configuration

    public init(lit: Bool) { self.lit = lit }

    public static var size: CGSize {
        CGSize(width: 3 * NotchGrip.dot + 2 * NotchGrip.gap, height: 2 * NotchGrip.dot + NotchGrip.gap)
    }

    public var body: some View {
        let handle = configuration.appearance.handle
        let ink = (lit ? handle.gripHover : handle.gripRest).color
        VStack(spacing: NotchGrip.gap) {
            ForEach(0..<2, id: \.self) { _ in
                HStack(spacing: NotchGrip.gap) {
                    ForEach(0..<3, id: \.self) { _ in Circle().fill(ink).frame(width: NotchGrip.dot, height: NotchGrip.dot) }
                }
            }
        }
        .accessibilityHidden(true)
    }
}
