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

    /// True for a local `swift build` / Xcode build. These are ad-hoc signed and
    /// their signature changes on every rebuild, so an Accessibility grant has to be
    /// re-done after each build. Only the signed release keeps the grant permanently.
    static var isDevBuild: Bool {
        bundlePath.contains("/.build/") || bundlePath.contains("/DerivedData/")
    }

    static func summaryLine() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let trusted = AccessibilityWindowMover.isTrusted(prompt: false)
        return "v\(version) (\(build)) · accessibility=\(trusted ? "granted" : "not granted") · translocated=\(isTranslocated) · devBuild=\(isDevBuild) · path=\(bundlePath)"
    }

    @MainActor
    static func logStartup() {
        mdLog("MoreDock started · \(summaryLine())")
        mdLog(codeSignatureSummary())
        if isTranslocated {
            mdLog("Running from a translocated/temporary path. Move MoreDock into /Applications so Accessibility permission persists.", level: .warn)
        } else if isDevBuild {
            mdLog("Running a local dev build from .build. After granting Accessibility, quit and reopen MoreDock. Each rebuild changes the signature and needs a re-grant — the signed release keeps it permanently.", level: .warn)
        }
    }

    /// Reads this bundle's code signature so the logs reveal whether it is a proper
    /// Developer ID signature (grant persists) or ad-hoc (grant will not persist).
    static func codeSignatureSummary() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["-dvv", Bundle.main.bundlePath]
        let errorPipe = Pipe()
        process.standardError = errorPipe
        process.standardOutput = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "Signature: could not run codesign (\(error.localizedDescription))."
        }

        let data = errorPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let isAdhoc = output.contains("Signature=adhoc")
        var authority = "none"
        for line in output.split(separator: "\n") where line.hasPrefix("Authority=") {
            authority = String(line.dropFirst("Authority=".count))
            break
        }

        if isAdhoc || authority == "none" {
            return "Signature: ad-hoc/unsigned — macOS will NOT keep an Accessibility grant across relaunches. Install the Developer ID signed release."
        }
        return "Signature: \(authority) — grant should persist after you relaunch once."
    }

    static var bundleIdentifier: String {
        Bundle.main.bundleIdentifier ?? "com.ariomoniri.moredock"
    }

    /// Clears MoreDock's Accessibility TCC entry via `tccutil reset`. A stale or
    /// mismatched entry (left by an earlier build/copy with the same bundle id) can
    /// silently block the grant so it never turns on no matter how many times it is
    /// enabled. Resetting removes every entry for this bundle id so the next grant
    /// starts clean. Returns true if `tccutil` exited successfully.
    @MainActor
    @discardableResult
    static func resetAccessibilityPermission() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleIdentifier]
        process.standardOutput = Pipe()
        process.standardError = Pipe()
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            mdLog("Reset Accessibility failed to run tccutil: \(error.localizedDescription)", level: .error)
            return false
        }
        let ok = process.terminationStatus == 0
        mdLog(ok
            ? "Reset Accessibility: cleared the TCC entry for \(bundleIdentifier). Grant access again, then Relaunch."
            : "Reset Accessibility: tccutil exited with status \(process.terminationStatus).",
            level: ok ? .info : .warn)
        return ok
    }

    /// Relaunches MoreDock. macOS evaluates Accessibility trust when a process
    /// starts, so a fresh instance is the reliable way to pick up a grant that was
    /// enabled while the app was already running.
    @MainActor
    static func relaunch() {
        mdLog("Relaunching MoreDock to pick up the Accessibility grant.")
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Bundle.main.bundleURL, configuration: configuration) { _, _ in
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
