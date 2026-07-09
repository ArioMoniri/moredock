import AppKit
import ApplicationServices

enum ActivationDisplayMode: String, CaseIterable, Identifiable {
    case native
    case clickedDisplay

    var id: String { rawValue }

    var title: String {
        switch self {
        case .native: "macOS"
        case .clickedDisplay: "Clicked Display"
        }
    }
}

enum AccessibilityWindowMover {
    static func isTrusted(prompt: Bool) -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    static func moveWindows(for processIdentifier: pid_t, to visibleFrame: NSRect, prompt: Bool = false) {
        guard isTrusted(prompt: prompt) else { return }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return
        }

        for window in windows.prefix(8) {
            move(window: window, to: visibleFrame)
        }
    }

    private static func move(window: AXUIElement, to visibleFrame: NSRect) {
        var minimizedValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(window, kAXMinimizedAttribute as CFString, &minimizedValue) == .success,
           let isMinimized = minimizedValue as? Bool,
           isMinimized {
            AXUIElementSetAttributeValue(window, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
        }

        var sizeValue: CFTypeRef?
        var currentSize = CGSize(width: min(1100, visibleFrame.width * 0.82), height: min(760, visibleFrame.height * 0.82))

        if AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
           let value = sizeValue,
           CFGetTypeID(value) == AXValueGetTypeID() {
            var size = CGSize.zero
            if AXValueGetValue(value as! AXValue, .cgSize, &size), size.width > 120, size.height > 80 {
                currentSize = size
            }
        }

        let clampedSize = CGSize(
            width: max(220, min(currentSize.width, visibleFrame.width - 32)),
            height: max(160, min(currentSize.height, visibleFrame.height - 32))
        )
        let appKitOrigin = CGPoint(
            x: visibleFrame.midX - clampedSize.width / 2,
            y: visibleFrame.midY - clampedSize.height / 2
        )

        var newSize = clampedSize
        var newPosition = axPosition(fromAppKitOrigin: appKitOrigin, size: clampedSize)
        guard let sizeAX = AXValueCreate(.cgSize, &newSize),
              let positionAX = AXValueCreate(.cgPoint, &newPosition) else {
            return
        }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeAX)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionAX)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }

    private static func axPosition(fromAppKitOrigin origin: CGPoint, size: CGSize) -> CGPoint {
        let displayBounds = NSScreen.screens.map(\.frame)
        guard let union = displayBounds.reduce(nil as NSRect?, { partial, frame in
            partial?.union(frame) ?? frame
        }) else {
            return origin
        }

        return CGPoint(
            x: origin.x,
            y: union.maxY - origin.y - size.height
        )
    }
}
