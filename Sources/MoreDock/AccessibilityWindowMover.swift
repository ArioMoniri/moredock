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

    @discardableResult
    static func moveWindows(for processIdentifier: pid_t, to visibleFrame: NSRect, prompt: Bool = false) -> Int {
        guard isTrusted(prompt: prompt) else { return 0 }

        let appElement = AXUIElementCreateApplication(processIdentifier)
        var windowsValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &windowsValue) == .success,
              let windows = windowsValue as? [AXUIElement] else {
            return 0
        }

        var moved = 0
        for window in windows.prefix(8) {
            move(window: window, to: visibleFrame)
            moved += 1
        }
        return moved
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
        // Accessibility/Quartz global coordinates put (0,0) at the TOP-LEFT of the
        // PRIMARY display with y increasing downward, while AppKit uses bottom-left
        // with y increasing upward. The reference is the primary display's top —
        // NOT the union of all displays. Using the union offsets the window by the
        // height of any display sitting above the primary, which dropped clicked
        // windows onto the wrong screen / a display junction.
        let primaryTop = NSScreen.screens.first { $0.frame.origin == .zero }?.frame.maxY
            ?? NSScreen.screens.map(\.frame.maxY).max()
            ?? (origin.y + size.height)

        return CGPoint(
            x: origin.x,
            y: primaryTop - origin.y - size.height
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
            mdLog("Clicked Display: moving windows of pid \(pid) onto the clicked screen.")
            performMoves(pid: pid, frame: frame)
            return
        }

        mdLog("Clicked Display: Accessibility not granted yet — queuing move for pid \(pid).", level: .warn)
        if Diagnostics.isTranslocated {
            mdLog("Accessibility will not persist while MoreDock runs from a translocated copy. Move it to /Applications, then remove and re-add it in Privacy & Security ▸ Accessibility.", level: .error)
        }
        pending[pid] = Request(frame: frame, attemptsLeft: maxPollAttempts)
        promptForAccessibilityIfNeeded()
        startPolling()
    }

    private func performMoves(pid: pid_t, frame: NSRect) {
        for attempt in 1...14 {
            let isLastAttempt = attempt == 14
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.16) {
                let moved = AccessibilityWindowMover.moveWindows(for: pid, to: frame)
                guard isLastAttempt else { return }
                Task { @MainActor in
                    if moved > 0 {
                        mdLog("Clicked Display: moved \(moved) window(s) of pid \(pid) to the clicked screen.")
                    } else {
                        mdLog("Clicked Display: no movable windows found for pid \(pid). The app may block Accessibility window moves, or it has no standard windows.", level: .warn)
                    }
                }
            }
        }
    }

    private func promptForAccessibilityIfNeeded() {
        let now = Date()
        if let last = lastPromptAt, now.timeIntervalSince(last) < promptCooldown {
            return
        }
        lastPromptAt = now
        mdLog("Requesting Accessibility permission (system prompt).")
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
        if trusted {
            mdLog("Accessibility granted — applying \(pending.count) queued Clicked Display move(s).")
        }
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
            if next.attemptsLeft <= 0 {
                pending[pid] = nil
                mdLog("Gave up moving pid \(pid): Accessibility still not granted. See the Accessibility note in Settings.", level: .warn)
            } else {
                pending[pid] = next
            }
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
