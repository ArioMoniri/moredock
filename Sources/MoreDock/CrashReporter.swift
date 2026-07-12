import AppKit
import Foundation

/// Persistent crash collection so a crash can be inspected by simply reopening
/// MoreDock — no need to dig through Console.app.
///
/// Two sources are combined, covering every crash kind:
/// 1. Uncaught Objective-C/AppKit exceptions, written to our own append-only file
///    from `NSSetUncaughtExceptionHandler` right before the process dies.
/// 2. The system's `.ips` crash reports in `~/Library/Logs/DiagnosticReports`,
///    which also capture Swift traps (force-unwrap, bad cast, precondition) that
///    the exception handler never sees.
///
/// On launch, `surfacePreviousCrashes()` loads the most recent of each into the
/// in-app Logs window, and `latestReportText()` returns the full text for the
/// "Copy Crash Report" button.
enum CrashReporter {
    // MARK: - Paths

    private static func supportDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let dir = base.appendingPathComponent("MoreDock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    /// Append-only log of Objective-C exceptions caught in-process.
    static var exceptionLogURL: URL {
        supportDirectory().appendingPathComponent("crash-exceptions.log")
    }

    private static var diagnosticReportsDirectory: URL {
        URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Logs/DiagnosticReports", isDirectory: true)
    }

    // MARK: - Recording (called from the uncaught-exception handler)

    /// Writes an uncaught exception to the persistent file. Runs inside the crash
    /// handler, so it must not depend on app state — only Foundation file I/O.
    static func recordException(_ exception: NSException, version: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        let stack = exception.callStackSymbols.joined(separator: "\n")
        let record = """

        ===== MoreDock crash \(timestamp) — v\(version) =====
        exception: \(exception.name.rawValue)
        reason: \(exception.reason ?? "<no reason>")
        stack:
        \(stack)
        =====================================================

        """
        append(record, to: exceptionLogURL)
    }

    private static func append(_ text: String, to url: URL) {
        let data = Data(text.utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
        // Keep the file from growing without bound: trim to the last ~40 KB.
        if let attributes = try? FileManager.default.attributesOfItem(atPath: url.path),
           let size = attributes[.size] as? Int, size > 60_000,
           let full = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = String(full.suffix(40_000))
            try? trimmed.data(using: .utf8)?.write(to: url, options: .atomic)
        }
    }

    // MARK: - Surfacing on next launch

    /// Loads the most recent crash from each source into the Logs window, so the
    /// user can copy it after reopening MoreDock.
    @MainActor
    static func surfacePreviousCrashes() {
        var found = false

        if let exceptionText = try? String(contentsOf: exceptionLogURL, encoding: .utf8),
           let latest = latestExceptionBlock(exceptionText) {
            found = true
            mdLog("\u{26A0}\u{FE0F} A previous MoreDock crash was recorded (Obj-C exception). Copy it with \u{201C}Copy Crash Report\u{201D} in Settings \u{25B8} Diagnostics, or from here:", level: .error)
            for line in latest.split(separator: "\n", omittingEmptySubsequences: false) {
                mdLog(String(line), level: .error)
            }
        }

        if let (name, summary) = latestDiagnosticReportSummary() {
            found = true
            mdLog("\u{1F4C4} System crash report found: \(name)", level: .error)
            for line in summary { mdLog(line, level: .error) }
            mdLog("Use \u{201C}Copy Crash Report\u{201D} in Settings \u{25B8} Diagnostics to copy the full report.", level: .error)
        }

        if !found {
            mdLog("No previous crash reports found.")
        }
    }

    /// Number of crash artifacts available (own exceptions + system reports).
    static var reportCount: Int {
        var count = 0
        if let text = try? String(contentsOf: exceptionLogURL, encoding: .utf8), !text.isEmpty {
            count += text.components(separatedBy: "===== MoreDock crash").count - 1
        }
        count += diagnosticReportURLs().count
        return count
    }

    /// The full text to place on the clipboard for the "Copy Crash Report" button:
    /// the newest system `.ips` report if present, otherwise our recorded exception.
    static func latestReportText() -> String? {
        if let url = diagnosticReportURLs().first,
           let text = try? String(contentsOf: url, encoding: .utf8) {
            var header = "MoreDock crash report — \(url.lastPathComponent)\n\n"
            if let exceptionText = try? String(contentsOf: exceptionLogURL, encoding: .utf8),
               let latest = latestExceptionBlock(exceptionText) {
                header += "In-app exception record:\n\(latest)\n\n----- system report below -----\n\n"
            }
            return header + text
        }
        if let exceptionText = try? String(contentsOf: exceptionLogURL, encoding: .utf8),
           let latest = latestExceptionBlock(exceptionText) {
            return latest
        }
        return nil
    }

    /// Deletes all collected crash artifacts we own (the system `.ips` files are left
    /// alone — they belong to macOS).
    static func clear() {
        try? FileManager.default.removeItem(at: exceptionLogURL)
    }

    /// Reveals the newest system crash report (or the Application Support folder) in
    /// Finder.
    @MainActor
    static func revealInFinder() {
        if let url = diagnosticReportURLs().first {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        } else {
            NSWorkspace.shared.activateFileViewerSelecting([exceptionLogURL])
        }
    }

    // MARK: - Helpers

    private static func latestExceptionBlock(_ text: String) -> String? {
        let marker = "===== MoreDock crash"
        guard let range = text.range(of: marker, options: .backwards) else { return nil }
        return String(text[range.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// MoreDock `.ips`/`.crash` reports, newest first.
    private static func diagnosticReportURLs() -> [URL] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: diagnosticReportsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        return files
            .filter { $0.lastPathComponent.hasPrefix("MoreDock") && ["ips", "crash"].contains($0.pathExtension.lowercased()) }
            .sorted { modificationDate($0) > modificationDate($1) }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    /// A concise, human-readable summary of the newest system crash report. `.ips`
    /// files are two JSON documents (a header line, then the payload); this pulls the
    /// exception/termination fields, any Swift error message, and the top frames of
    /// the faulting thread. Falls back to the raw first lines if parsing fails.
    private static func latestDiagnosticReportSummary() -> (name: String, lines: [String])? {
        guard let url = diagnosticReportURLs().first,
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        var lines: [String] = []
        let parts = raw.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        if parts.count == 2,
           let payloadData = String(parts[1]).data(using: .utf8),
           let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any] {

            if let version = payload["version"] as? Int { lines.append("report version: \(version)") }
            if let osVersion = (payload["osVersion"] as? [String: Any])?["train"] as? String {
                lines.append("os: \(osVersion)")
            }
            if let exception = payload["exception"] as? [String: Any] {
                let type = exception["type"] as? String ?? "?"
                let signal = exception["signal"] as? String ?? ""
                lines.append("exception: \(type) \(signal)".trimmingCharacters(in: .whitespaces))
            }
            if let termination = payload["termination"] as? [String: Any] {
                let reason = termination["reason"] as? String ?? ""
                if !reason.isEmpty { lines.append("termination: \(reason)") }
            }
            // Swift fatalError / precondition messages usually land in `asi` or `asiBacktraces`.
            if let asi = payload["asi"] as? [String: [String]] {
                for (_, messages) in asi {
                    for message in messages where !message.isEmpty {
                        lines.append("info: \(message)")
                    }
                }
            }
            lines.append(contentsOf: faultingThreadFrames(payload))
        }

        if lines.isEmpty {
            // Parsing failed — show the first lines raw so something useful surfaces.
            lines = raw.split(separator: "\n").prefix(24).map(String.init)
        }
        return (url.lastPathComponent, lines)
    }

    private static func faultingThreadFrames(_ payload: [String: Any]) -> [String] {
        guard let threads = payload["threads"] as? [[String: Any]] else { return [] }
        let images = payload["usedImages"] as? [[String: Any]] ?? []
        guard let triggered = threads.first(where: { ($0["triggered"] as? Bool) == true }) ?? threads.first,
              let frames = triggered["frames"] as? [[String: Any]] else {
            return []
        }

        var result = ["faulting thread top frames:"]
        for frame in frames.prefix(16) {
            if let symbol = frame["symbol"] as? String {
                let offset = frame["symbolLocation"] as? Int ?? 0
                result.append("  \(symbol) + \(offset)")
            } else if let imageIndex = frame["imageIndex"] as? Int,
                      imageIndex < images.count,
                      let name = images[imageIndex]["name"] as? String {
                let offset = frame["imageOffset"] as? Int ?? 0
                result.append("  \(name) + \(offset)")
            } else {
                let offset = frame["imageOffset"] as? Int ?? 0
                result.append("  <unknown> + \(offset)")
            }
        }
        return result
    }
}
