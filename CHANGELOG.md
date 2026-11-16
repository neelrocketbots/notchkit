# Changelog

All notable changes to NotchKit. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). Versions are git tags (`vX.Y.Z`); the Release workflow publishes each version's section here as its notes.

## Planned

- **Neutral defaults.** Today the defaults are the source app's look: the coral-to-marigold glow and its sizes.
- **Sizes and behaviour into `NotchConfiguration`** (`metrics`, `behaviour`). This comes after the controller, panel, content slots and demo steps (PR4–PR7). Today they are `static let`s.

## [Unreleased]

Nothing yet.

## [0.2.0] - 2026-11-16

The glow is light, not a line.

### Changed
- **The glow is a blurred ellipse behind the island** (`NotchGlowEllipse`), in the configured gradient from start to end, blurred 24 pt and rasterised once. Only its opacity animates, and there is no timeline: nothing redraws per frame except while the island's size changes. `NotchGlowView` holds a turning state still at 50 %. A sweep flashes up to 75 % expanded or 90 % folded, then fades out over `glowSweep`. The ellipse leaves the view tree once nothing is lit. Reduce Motion holds it still with 0.2 s cross-fades.
- **The trace along the outline is opt-in**: `NotchGlowView(…, trace: true)` draws it beside the light, still. A calibration run lights the glow with its trace.
- **A glow turned off draws nothing** (`on: false`). It used to draw a white outline.
- **Panel margins fit the light.** `NotchGeometry.panelSize` is the expanded island plus `sideMargin` (60 pt) each side and `bottomMargin` (94 pt) below; both were 52 pt. `NotchFloat.margin`, the room above a floating island, is 60 pt (was 32). `NotchGlow.drawingPadding(expansion:)` is `ellipseRoom` (92 pt) at every expansion.
- **No floating border by default.** `NotchConfiguration.Floating.border` defaults to clear, and `NotchBackdrop` draws a border only when it has some opacity.

### Added
- `NotchGlowView(state:shape:on:reduceMotion:expansion:trace:alarm:)`: `trace` and `alarm` (each sweep peaks at 90 %).
- `NotchGlowEllipse`, the still light, for a client that animates it itself or renders it.
- `NotchGlow.ellipseRect(island:shape:expansion:)`, `ellipseBlur`, `blurReach`, `ellipseRoom`, `reach(pill:expansion:islandHeight:)` and the ellipse's sizes; `NotchGlow.motion(for:on:reduceMotion:alarm:sweep:)` with `NotchGlowMotion` and `NotchGlowLevel`, the levels and fades.
- `NotchGeometry.sideMargin` and `bottomMargin`.

### Deprecated
- 0.1's backlight and turning trace: `NotchGlow.haloBlur`, `haloOutset`, `foldedHaloBlur`, `foldedHaloOutset`, `haloBlur(expansion:)`, `haloOutset(expansion:)`, `haloOpacity(turning:)`, `appearance(for:on:reduceMotion:)`, `sweepAngle`, `frameInterval(for:)`, `turnAngle(at:turn:)` and `NotchGlowAppearance`. `NotchConfiguration.Glow.offOutline` and `Motion.glowTurn` are no longer read. `NotchGeometry.outset` and `blur` no longer set the margins.

### Removed
- The glow's turn and sweep GIFs from the docs (they showed 0.1's trace).

## [0.1.0] - 2026-11-09

The first tagged version: the displays, the pure maths and the look, extracted from the app NotchKit was built in.

### Added
- A standalone SwiftPM package (`NotchKit` library, `NotchKitTests`), extracted from the app it was built in, with the history of its NotchKit sources and tests.
- `Examples/NotchKitDemo`: an executable that shows the island with the default configuration. You can pull it out of the notch, snap it back, resize it and light its glow.
- The MIT license.
- `NotchStringsTests`. VoiceOver's words (the resize handle's label and value, the move grip's label, Dock and the corner actions) come from `NotchConfiguration.strings`. The defaults keep the island wording, a client's words replace every label, and a source scan keeps literals out of the views.
- Docs: README, `docs/Architecture.md`, `docs/Configuration.md` and `docs/Geometry.md`.
- CI: `swift build` and `swift test` on every pull request and push to `main`, on a macOS 26 runner.
- Release workflow: a `vX.Y.Z` tag runs the tests and publishes a GitHub Release with that version's CHANGELOG section and the merged pull requests.
- Figures in the docs, rendered from NotchKit's views and values by `Examples/NotchKitDocImages` (`swift run NotchKitDocImages`): display kinds, sizes, the shape, the backdrop, the bleed, the glow and the handles.
- `NotchKitDemo` starts docked under the notch, pulls out as a floating card and snaps back: the detach, the pull and push stretch, the bleed, `touchesDock` and the snap spring, all through NotchKit's values. `--floating`, `--glow sweep|turn` and `--snap` set it up for recordings and print the panel's frame. Three GIFs in the docs.

### From the extraction (2026-11-05)
- **Displays.** `Notch`, `NotchDisplay`, `NotchVisibleInsets`, `NotchDisplayKind.classify` and `NotchScreens.displays(measured:)`.
- **Pure maths.**
  - `NotchGeometry`, with `NotchDockPosition`.
  - `NotchShape`, `NotchOutline` and `NotchPillShape`.
  - `NotchDockMotion`, with the notch bleed and its ink.
  - `NotchFloat`, with `NotchPlacement`, `NotchOrigin`, `NotchLayoutPrefs`, `NotchHandleInput` and `NotchCorner`.
  - `NotchResize` and `NotchHitRect`.
- **Look.**
  - The glow: `NotchGlowView`, `NotchGlow`, `NotchGlowShape`, `NotchGlowState` and `NotchGlowCalibration`.
  - The frosted backdrop and the floating shadow: `NotchBackdrop`, `NotchDrawn` and `NotchFloatShadow`.
  - The handles: `NotchResizeHandle`, `NotchMoveGesture`, `NotchMoveArea`, `NotchGrip`, `NotchGripDots` and the grip's VoiceOver actions, all over a `NotchHandleDriver`.
- **Configuration.** `NotchConfiguration` covers appearance, strings, motion and debug, read from the environment. Its defaults are the shipped look.
- **Source scan.** It checks that NotchKit imports only Apple's frameworks and reads no environment variables or defaults.

[Unreleased]: https://github.com/neelrocketbots/notchkit/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/neelrocketbots/notchkit/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/neelrocketbots/notchkit/releases/tag/v0.1.0
