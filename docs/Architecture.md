# Architecture

## Layers

NotchKit is one SwiftPM library target, `NotchKit`. It imports Apple's frameworks only: AppKit, SwiftUI, Observation, os, CoreGraphics and Foundation.

| Layer | Files | What it holds |
|---|---|---|
| Displays | `NotchDisplay.swift`, `NotchScreens.swift` | `Notch`, `NotchDisplay`, `NotchVisibleInsets` and `NotchDisplayKind.classify`, which are pure. `NotchScreens.displays(measured:)` is the one `NSScreen` reader. |
| Pure maths | `NotchGeometry.swift`, `NotchFloat.swift`, `NotchResize.swift`, `NotchDockMotion.swift`, `NotchHitRect.swift` | Sizes from the notch, placement and prefs, dock tests, resize limits, snap and bleed curves, and hit tests. These are values and static functions, `Sendable`, with no state. |
| Shapes | `NotchShape.swift` | `NotchShape`, `NotchOutline` and `NotchPillShape`: SwiftUI `Shape`s. |
| Look | `NotchGlow.swift`, `NotchBackdrop.swift`, `NotchHandles.swift` | The glow view and its values, the frosted backdrop and the floating shadow, and the handles (resize line, move gesture and area, grip dots, grip accessibility). |
| Configuration | `NotchConfiguration.swift` | `NotchConfiguration`, its colour, stop and shadow types, and the `notchConfiguration` environment value. |

## What NotchKit owns and what the client owns

**NotchKit owns:**
- how big the island is on each display
- what shape it has
- how it looks: frost, glow, shadow, handles
- the maths of dragging, docking, resizing and snapping
- the words its own controls speak, which the client can override

**The client owns:**
- **State.** Whether the island is folded, open or idle; its placement; whether it is moving or resizing; the current height. The client's model conforms to `NotchHandleDriver`, and the handles call it with `NotchHandleInput`.
- **The panel.** A borderless, non-activating `NSPanel`, sized to `NotchGeometry.panelSize`, hung from the display's top edge. It also owns the hover-target panel over the folded notch and the pointer monitors.
- **Policy.** When to open and fold, when to glow (`NotchGlowState`), and what goes inside the island.
- **Persistence.** It stores `NotchLayoutPrefs` as string-keyed maps (`storedHeights`, `storedOrigins`) and loads them back through the tolerant initialiser.
- **Debug switches.** It reads its own debug inputs and passes them in through `NotchConfiguration.debug`.

The planned controller, panel and content-slot layers (see the README's Status) will move most of this client work into NotchKit. The client will then keep only policy and content.

## Rules the package keeps

- **No hidden inputs.** No `ProcessInfo` environment reads, no `UserDefaults` or `CFPreferences`, and no logging of its own. `NotchKitSourceScanTests` scans every source file. It checks that imports are on the allowed list and that no name of the source app appears.
- **One material.** `NotchBackdrop` is the only view that uses a material (`NotchBackdropTests.theDefaultFrostIsTheUltraThinMaterial`).
- **Defaults are the shipped look.** `NotchConfiguration()` reproduces the source app's island exactly. The source app checks that its own configuration equals the defaults.
- **No identity-changing branches in animated modifiers.** `NotchFloatShadow` always applies a shadow, at opacity 0 when docked. The fill then keeps one identity across a dock/float flip and morphs instead of cross-fading. A test checks the source for it.

## Client-side invariants (from the source app)

The planned `NotchPanel` will carry these. A client that builds its own panel today should keep them; `Examples/NotchKitDemo` does.

1. **One frame owner.** Put the `NSHostingView` inside a plain container view, with `sizingOptions = []` and `safeAreaRegions = []`. The panel's frame is then set only by the client. Otherwise SwiftUI's sizing grew the window to about 1,540 pt, and AppKit threw "needing another Update Constraints in Window pass".
2. **No window animation.** Set `animationBehavior = .none`. Override `constrainFrameRect(_:to:)` to return the frame as is, so the island can sit under the menu bar.
3. **Only the view animates.** On a dock or float flip the panel's frame moves at once. The SwiftUI view springs: the morph, the stretch and the bleed.
4. **Mouse only over the island.** The panel is larger than the island. It ignores the mouse outside `NotchHitRect.acceptsMouse`, so clicks and scrolls reach the apps below.
5. **Lay out the body at the open size.** Do this through the whole expand and fold spring, and let the shape clip it. Laying out a scrolling list at the animated size re-wraps lines every frame. SwiftUI then logs "OnScrollGeometryChange tried to update multiple times per frame" or "Geometry action is cycling".
6. **Apply measured heights on the next run-loop turn.** A content height measured inside a geometry action is applied on the next turn, and only when it moves by a whole point.
7. **The folded hover target is the notch's own rect.** Even when the folded island is drawn wider, for example with ears beside the notch, the hover target stays the notch. The menu bar's items beside the notch must stay clickable.

## Tests

`Tests/NotchKitTests` uses Swift Testing. Every pure rule has a test. The views are tested through their static value functions (`look`, `overlayStops`, `values`, `dockedTop`, `appearance`), plus two source scans.
