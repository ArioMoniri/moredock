import AppKit
import Foundation
import os

/// In-memory, user-visible diagnostics log. Entries are also forwarded to the
/// unified system log (`os.Logger`) so they show up in Console.app, and can be
/// viewed/copied from inside the app via the Logs window.
@MainActor
final class LogStore: ObservableObject {
    static let shared = LogStore()

    enum Level: String, CaseIterable {
        case info
        case warn
        case error

        var label: String {
            switch self {
            case .info: "INFO"
            case .warn: "WARN"
            case .error: "ERROR"
            }
        }
    }

    struct Entry: Identifiable {
        let id = UUID()
        let date: Date
        let level: Level
        let message: String
    }

    @Published private(set) var entries: [Entry] = []

    private let logger = Logger(subsystem: "com.ariomoniri.moredock", category: "diagnostics")
    private let maxEntries = 1000

    private init() {}

    func log(_ message: String, level: Level = .info) {
        let entry = Entry(date: Date(), level: level, message: message)
        entries.append(entry)
        if entries.count > maxEntries {
            entries.removeFirst(entries.count - maxEntries)
        }

        switch level {
        case .info:
            logger.info("\(message, privacy: .public)")
        case .warn:
            logger.warning("\(message, privacy: .public)")
        case .error:
            logger.error("\(message, privacy: .public)")
        }
    }

    func clear() {
        entries.removeAll()
    }

    func exportText() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        let header = "MoreDock diagnostics — \(Diagnostics.summaryLine())\n"
        let body = entries
            .map { "[\(formatter.string(from: $0.date))] \($0.level.label) \($0.message)" }
            .joined(separator: "\n")
        return header + body
    }
}

/// Logs from the main actor. Use `Diagnostics.log` from other contexts.
@MainActor
func mdLog(_ message: String, level: LogStore.Level = .info) {
    LogStore.shared.log(message, level: level)
}

enum Diagnostics {
    /// True when the app is running from a Gatekeeper "App Translocation" copy or a
    /// randomized temporary path. In that state macOS keys Accessibility permission
    /// against a path that changes on every launch, so a previously granted
    /// permission never "sticks" and the prompt keeps reappearing.
    static var isTranslocated: Bool {
        let path = Bundle.main.bundlePath
        return path.contains("/AppTranslocation/")
            || path.contains("/private/var/folders/")
            || path.hasPrefix("/private/var/folders/")
    }

    static var bundlePath: String {
        Bundle.main.bundlePath
    }

    static func summaryLine() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let trusted = AccessibilityWindowMover.isTrusted(prompt: false)
        return "v\(version) (\(build)) · accessibility=\(trusted ? "granted" : "not granted") · translocated=\(isTranslocated) · path=\(bundlePath)"
    }

    @MainActor
    static func logStartup() {
        mdLog("MoreDock started · \(summaryLine())")
        if isTranslocated {
            mdLog("Running from a translocated/temporary path. Move MoreDock into /Applications so Accessibility permission persists.", level: .warn)
        }
    }
}
