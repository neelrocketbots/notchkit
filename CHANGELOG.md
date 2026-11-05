# Changelog

All notable changes to NotchKit. The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/). There are no tagged versions yet.

## [Unreleased]

### Added
- A standalone SwiftPM package (`NotchKit` library, `NotchKitTests`), extracted from Hiccup with the history of its NotchKit sources and tests.
- `Examples/NotchKitDemo`: an executable that shows a floating island with the default configuration. You can drag it, resize it and light its glow.
- The MIT license.
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
