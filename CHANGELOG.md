# Changelog

All notable changes to NotchKit. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). There are no tagged versions yet.

## Planned

- **Neutral defaults.** Today the defaults are the source app's look: the coral-to-marigold glow and its sizes.
- **Sizes and behaviour into `NotchConfiguration`** (`metrics`, `behaviour`). This comes after the controller, panel, content slots and demo steps (PR4–PR7). Today they are `static let`s.

## [Unreleased]

### Added
- A standalone SwiftPM package (`NotchKit` library, `NotchKitTests`), extracted from the app it was built in, with the history of its NotchKit sources and tests.
- `Examples/NotchKitDemo`: an executable that shows a floating island with the default configuration. You can drag it, resize it and light its glow.
- The MIT license.
- `NotchStringsTests`. VoiceOver's words (the resize handle's label and value, the move grip's label, Dock and the corner actions) come from `NotchConfiguration.strings`. The defaults keep the island wording, a client's words replace every label, and a source scan keeps literals out of the views.
- Docs: README, `docs/Architecture.md`, `docs/Configuration.md` and `docs/Geometry.md`.

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
