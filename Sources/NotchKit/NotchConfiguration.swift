import SwiftUI

/// A colour as sRGB components, the way NotchKit's configuration names every colour it draws.
public struct NotchColor: Sendable, Equatable {
    public var r: Double, g: Double, b: Double, a: Double
    public init(r: Double, g: Double, b: Double, a: Double = 1) { self.r = r; self.g = g; self.b = b; self.a = a }
    public init(hex: UInt32, alpha: Double = 1) {
        self.init(r: Double((hex >> 16) & 0xFF) / 255, g: Double((hex >> 8) & 0xFF) / 255, b: Double(hex & 0xFF) / 255, a: alpha)
    }
    public var color: Color { Color(.sRGB, red: r, green: g, blue: b, opacity: a) }
}

/// A point of a vertical gradient: where (0 the top, 1 the bottom) and how opaque.
public struct NotchStop: Sendable, Equatable {
    public var location: Double, opacity: Double
    public init(_ location: Double, _ opacity: Double) { self.location = location; self.opacity = opacity }
}

/// The system material behind the frosted body.
public enum NotchFrostMaterial: String, Sendable, Equatable, CaseIterable { case ultraThin, regular, thick }

/// What a client tells NotchKit about its island's look, words and timing. Every default is the island's shipped look, so
/// a client passes only what differs. NotchKit reads no environment variables and no defaults of its own: a client's
/// debug switches arrive here too. Views read it from the environment (`notchConfiguration`).
public struct NotchConfiguration: Sendable {
    public var appearance: Appearance
    public var strings: Strings
    public var motion: Motion
    public var debug: Debug

    public init(appearance: Appearance = Appearance(), strings: Strings = Strings(), motion: Motion = Motion(), debug: Debug = Debug()) {
        self.appearance = appearance; self.strings = strings; self.motion = motion; self.debug = debug
    }

    public struct Appearance: Sendable, Equatable {
        /// The island's own fill (the notch's black).
        public var fill: NotchColor
        public var frost: Frost
        public var floating: Floating
        public var handle: Handle
        public var glow: Glow

        public init(fill: NotchColor = NotchColor(hex: 0x000000), frost: Frost = Frost(), floating: Floating = Floating(),
                    handle: Handle = Handle(), glow: Glow = Glow()) {
            self.fill = fill; self.frost = frost; self.floating = floating; self.handle = handle; self.glow = glow
        }
    }

    /// The frosted body: the material under a black overlay, solid to 15 % of the expanded height (the band under the
    /// notch), then a linear ramp to 25.3 % at 82 % and 18.7 % at the bottom.
    public struct Frost: Sendable, Equatable {
        /// The material's tint in an offscreen render, which cannot see behind its window.
        public var tint: NotchColor
        /// The black overlay, top to bottom, as (location in the expanded island's height, black's opacity).
        public var overlay: [NotchStop]
        public var material: NotchFrostMaterial

        public init(tint: NotchColor = NotchColor(r: 18 / 255, g: 18 / 255, b: 20 / 255, a: 0.12),
                    overlay: [NotchStop] = [NotchStop(0, 1), NotchStop(0.15, 1), NotchStop(0.82, 0.46 * 0.55), NotchStop(1, 0.34 * 0.55)],
                    material: NotchFrostMaterial = .ultraThin) {
            self.tint = tint; self.overlay = overlay; self.material = material
        }

        /// The overlay's black at `location` (0 the top, 1 the bottom of the expanded island), linear between the stops.
        public func overlayOpacity(at location: Double) -> Double {
            let t = min(1, max(0, location))
            for (a, b) in zip(overlay, overlay.dropFirst()) where t <= b.location {
                let span = b.location - a.location
                return span <= 0 ? b.opacity : a.opacity + (b.opacity - a.opacity) * (t - a.location) / span
            }
            return overlay[overlay.count - 1].opacity
        }
    }

    /// The floating island: frosted all over under a black tint, a subtle border and a soft shadow.
    public struct Floating: Sendable, Equatable {
        public var overlay: Double
        public var border: NotchColor
        public var shadow: NotchShadow

        public init(overlay: Double = 0.42, border: NotchColor = NotchColor(r: 1, g: 1, b: 1, a: 0.14),
                    shadow: NotchShadow = NotchShadow(color: NotchColor(r: 0, g: 0, b: 0, a: 0.16), radius: 8, x: 0, y: 6)) {
            self.overlay = overlay; self.border = border; self.shadow = shadow
        }
    }

    /// The resize grab line and the move grip, at rest and lit.
    public struct Handle: Sendable, Equatable {
        public var lineRest: NotchColor, lineHover: NotchColor, gripRest: NotchColor, gripHover: NotchColor

        public init(lineRest: NotchColor = NotchColor(r: 1, g: 1, b: 1, a: 0.28), lineHover: NotchColor = NotchColor(r: 1, g: 1, b: 1, a: 0.70),
                    gripRest: NotchColor = NotchColor(r: 1, g: 1, b: 1, a: 0.35), gripHover: NotchColor = NotchColor(r: 1, g: 1, b: 1, a: 0.85)) {
            self.lineRest = lineRest; self.lineHover = lineHover; self.gripRest = gripRest; self.gripHover = gripHover
        }
    }

    /// The glow's gradient (start → end → start round the island) and the plain outline's white when the glow is off.
    public struct Glow: Sendable, Equatable {
        public var start: NotchColor, end: NotchColor
        public var offOutline: Double

        public init(start: NotchColor = NotchColor(hex: 0xD9704F), end: NotchColor = NotchColor(hex: 0xF2B65A), offOutline: Double = 0.85) {
            self.start = start; self.end = end; self.offOutline = offOutline
        }
    }

    /// The words NotchKit's own controls speak (VoiceOver labels, values and actions).
    public struct Strings: Sendable, Equatable {
        public var height: String, heightUnit: String
        public var move: String, dock: String
        public var topLeft: String, topRight: String, bottomLeft: String, bottomRight: String

        public init(height: String = "Island height", heightUnit: String = "points", move: String = "Move island", dock: String = "Dock",
                    topLeft: String = "Top Left", topRight: String = "Top Right", bottomLeft: String = "Bottom Left", bottomRight: String = "Bottom Right") {
            self.height = height; self.heightUnit = heightUnit; self.move = move; self.dock = dock
            self.topLeft = topLeft; self.topRight = topRight; self.bottomLeft = bottomLeft; self.bottomRight = bottomRight
        }

        /// The height's value: "288 points".
        public func heightValue(_ height: Double) -> String { "\(Int(height.rounded())) \(heightUnit)" }

        /// A corner action's name.
        public func corner(_ c: NotchCorner) -> String {
            switch c {
            case .topLeft: topLeft
            case .topRight: topRight
            case .bottomLeft: bottomLeft
            case .bottomRight: bottomRight
            }
        }
    }

    /// The glow's timing: a sweep runs once round in `glowSweep`; a turn takes `glowTurn` seconds.
    public struct Motion: Sendable, Equatable {
        public var glowSweep: Duration
        public var glowTurn: Double

        public init(glowSweep: Duration = .milliseconds(1600), glowTurn: Double = 6) { self.glowSweep = glowSweep; self.glowTurn = glowTurn }
    }

    /// A client's debug switches, read by the client and passed in (none by default).
    public struct Debug: Sendable {
        /// When set, the glow is lit steadily and its folded outline is calibrated by the values this returns, read twice
        /// a second (a by-eye match to the physical notch).
        public var glowCalibration: (@MainActor @Sendable () -> NotchGlowCalibration)?

        public init(glowCalibration: (@MainActor @Sendable () -> NotchGlowCalibration)? = nil) { self.glowCalibration = glowCalibration }
    }
}

/// A drop shadow: its colour, blur radius and offset.
public struct NotchShadow: Sendable, Equatable {
    public var color: NotchColor, radius: Double, x: Double, y: Double
    public init(color: NotchColor, radius: Double, x: Double, y: Double) { self.color = color; self.radius = radius; self.x = x; self.y = y }
}

private struct NotchConfigurationKey: EnvironmentKey { static let defaultValue = NotchConfiguration() }

extension EnvironmentValues {
    /// The island's configuration (`NotchConfiguration`); the shipped look unless the client sets one.
    public var notchConfiguration: NotchConfiguration {
        get { self[NotchConfigurationKey.self] }
        set { self[NotchConfigurationKey.self] = newValue }
    }
}
