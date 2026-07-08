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
    static func moveWindows(for processIdentifier: pid_t, to visibleFrame: NSRect) {
        guard ensureTrusted() else { return }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return
        }

        for window in windows.prefix(6) {
            move(window: window, to: visibleFrame)
        }
    }

    private static func ensureTrusted() -> Bool {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
            width: min(currentSize.width, visibleFrame.width - 32),
            height: min(currentSize.height, visibleFrame.height - 32)
        )
        let origin = CGPoint(
            x: visibleFrame.midX - clampedSize.width / 2,
            y: visibleFrame.midY - clampedSize.height / 2
        )

        var newSize = clampedSize
        var newPosition = origin
        guard let sizeAX = AXValueCreate(.cgSize, &newSize),
              let positionAX = AXValueCreate(.cgPoint, &newPosition) else {
            return
        }

        AXUIElementSetAttributeValue(window, kAXSizeAttribute as CFString, sizeAX)
        AXUIElementSetAttributeValue(window, kAXPositionAttribute as CFString, positionAX)
        AXUIElementPerformAction(window, kAXRaiseAction as CFString)
    }
}
