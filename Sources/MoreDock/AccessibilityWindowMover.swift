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

    static func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
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

/// Coordinates Clicked-Display window moves so the Accessibility permission is
/// requested at most once per cooldown and a pending move is applied automatically
/// as soon as the user grants access, without requiring a second click.
@MainActor
final class AccessibilityMoveCoordinator {
    static let shared = AccessibilityMoveCoordinator()

    private struct Request {
        let frame: NSRect
        var attemptsLeft: Int
    }

    private var pending: [pid_t: Request] = [:]
    private var pollTimer: Timer?
    private var lastPromptAt: Date?
    private let promptCooldown: TimeInterval = 20
    private let maxPollAttempts = 60

    private init() {}

    /// Move `pid`'s windows onto `frame`. If Accessibility is not yet trusted, the
    /// request is queued, the permission is requested once, and the move fires when
    /// trust becomes available.
    func requestMove(pid: pid_t, to frame: NSRect) {
        guard !frame.isEmpty else { return }

        if AccessibilityWindowMover.isTrusted(prompt: false) {
            performMoves(pid: pid, frame: frame)
            return
        }

        pending[pid] = Request(frame: frame, attemptsLeft: maxPollAttempts)
        promptForAccessibilityIfNeeded()
        startPolling()
    }

    private func performMoves(pid: pid_t, frame: NSRect) {
        for attempt in 1...14 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.16) {
                AccessibilityWindowMover.moveWindows(for: pid, to: frame)
            }
        }
    }

    private func promptForAccessibilityIfNeeded() {
        let now = Date()
        if let last = lastPromptAt, now.timeIntervalSince(last) < promptCooldown {
            return
        }
        lastPromptAt = now
        _ = AccessibilityWindowMover.isTrusted(prompt: true)
    }

    private func startPolling() {
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.4, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.poll()
            }
        }
    }

    private func poll() {
        guard !pending.isEmpty else {
            stopPolling()
            return
        }

        let trusted = AccessibilityWindowMover.isTrusted(prompt: false)
        for (pid, request) in pending {
            guard NSRunningApplication(processIdentifier: pid) != nil else {
                pending[pid] = nil
                continue
            }

            if trusted {
                performMoves(pid: pid, frame: request.frame)
                pending[pid] = nil
                continue
            }

            var next = request
            next.attemptsLeft -= 1
            pending[pid] = next.attemptsLeft <= 0 ? nil : next
        }

        if pending.isEmpty {
            stopPolling()
        }
    }

    private func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
