import AppKit
import SwiftUI

@MainActor
final class LogWindowController: NSWindowController {
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MoreDock Logs"
        window.center()
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: LogView())
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct LogView: View {
    @ObservedObject private var store = LogStore.shared

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            Text(Diagnostics.summaryLine())
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
            Divider()
            logList
        }
        .frame(minWidth: 520, minHeight: 360)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Text("Diagnostics")
                .font(.headline)
            Spacer()
            Button("Copy All") { copyAll() }
                .controlSize(.small)
            Button("Clear") { store.clear() }
                .controlSize(.small)
        }
        .padding(12)
    }

    private var logList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 3) {
                    ForEach(store.entries) { entry in
                        HStack(alignment: .top, spacing: 8) {
                            Text(timeString(entry.date))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Text(entry.level.label)
                                .font(.system(.caption2, design: .monospaced).weight(.semibold))
                                .foregroundStyle(color(for: entry.level))
                                .frame(width: 44, alignment: .leading)
                            Text(entry.message)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .id(entry.id)
                    }
                }
                .padding(12)
            }
            .onChange(of: store.entries.count) { _ in
                if let last = store.entries.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func color(for level: LogStore.Level) -> Color {
        switch level {
        case .info: .secondary
        case .warn: .orange
        case .error: .red
        }
    }

    private func timeString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSS"
        return formatter.string(from: date)
    }

    private func copyAll() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(store.exportText(), forType: .string)
    }
}
