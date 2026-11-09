import AppKit

/// The raw values a display's notch is measured from, for a client's own calibration log.
public struct NotchMeasurement: Sendable, Equatable {
    public var screenWidth: Double
    public var left: CGRect
    public var right: CGRect
    public var safeAreaTop: Double
    public var scale: Double

    public init(screenWidth: Double, left: CGRect, right: CGRect, safeAreaTop: Double, scale: Double) {
        self.screenWidth = screenWidth; self.left = left; self.right = right; self.safeAreaTop = safeAreaTop; self.scale = scale
    }

    /// One line with every value, for a log.
    public var line: String {
        "notch from screen width \(screenWidth) left \(left.minX)…\(left.maxX) (\(left.width)) right \(right.minX)…\(right.maxX) (\(right.width)) "
            + "safeAreaTop \(safeAreaTop) scale \(scale): notch \(screenWidth - left.width - right.width) × \(safeAreaTop)"
    }
}

public enum NotchScreens {
    /// Displays in points with a top-left origin at the main display, each with its kind (`NotchDisplayKind.classify`)
    /// and, on a notched display, the notch. `measured`, when given, sees each notch's raw values (a client's calibration
    /// log); NotchKit itself logs nothing.
    @MainActor public static func displays(measured: ((NotchMeasurement) -> Void)? = nil) -> [NotchDisplay] {
        guard let main = NSScreen.screens.first else { return [] }
        let mainHeight = main.frame.height
        return NSScreen.screens.enumerated().map { index, screen in
            let frame = screen.frame
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let isBuiltIn = number.map { CGDisplayIsBuiltin($0.uint32Value) != 0 } ?? false
            // `NSScreen.touchCapabilities` needs the macOS 27 SDK (Xcode 27, Swift 6.4) as well as macOS 27 at run time;
            // built with Xcode 26 the package treats every display as touch-free.
            var multiTouch = false
            #if compiler(>=6.4)
            if #available(macOS 27, *) { multiTouch = screen.touchCapabilities.contains(.multiTouch) }
            #endif
            let left = screen.auxiliaryTopLeftArea, right = screen.auxiliaryTopRightArea
            let kind = NotchDisplayKind.classify(isBuiltIn: isBuiltIn, safeAreaTop: screen.safeAreaInsets.top,
                                                 auxiliaryLeftWidth: left.map { Double($0.width) }, auxiliaryRightWidth: right.map { Double($0.width) },
                                                 screenWidth: frame.width, multiTouch: multiTouch)
            // The menu bar alone, or the safe area when that is taller: a hidden menu bar reads 0, while a Dynamic Island
            // display's safe area still holds the system island's band.
            let menuBarHeight = max(frame.maxY - screen.visibleFrame.maxY, screen.safeAreaInsets.top)
            var notch: Notch?
            if kind == .notch, let left, let right {
                notch = Notch(width: frame.width - left.width - right.width, height: screen.safeAreaInsets.top)
                measured?(NotchMeasurement(screenWidth: frame.width, left: left, right: right, safeAreaTop: screen.safeAreaInsets.top,
                                           scale: screen.backingScaleFactor))
            }
            let visible = screen.visibleFrame
            let insets = NotchVisibleInsets(left: visible.minX - frame.minX, bottom: visible.minY - frame.minY, right: frame.maxX - visible.maxX)
            return NotchDisplay(id: number?.uint32Value ?? UInt32(index), x: frame.minX, y: mainHeight - frame.maxY,
                                width: frame.width, height: frame.height, notch: notch, isMain: screen == main,
                                isBuiltIn: isBuiltIn, menuBarHeight: menuBarHeight, kind: kind, multiTouch: multiTouch,
                                visibleInsets: insets)
        }
    }
}
