import AppKit
import SwiftUI

@MainActor
private func render<V: View>(_ view: V, size: CGSize, path: String) throws {
    let hostingView = NSHostingView(rootView: view)
    hostingView.frame = CGRect(origin: .zero, size: size)
    hostingView.layoutSubtreeIfNeeded()

    guard let bitmap = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
        throw CocoaError(.fileWriteUnknown)
    }

    hostingView.cacheDisplay(in: hostingView.bounds, to: bitmap)

    guard let data = bitmap.representation(using: .png, properties: [:]) else {
        throw CocoaError(.fileWriteUnknown)
    }

    try data.write(to: URL(fileURLWithPath: path))
}

@MainActor
private func renderAll() throws {
    let output = CommandLine.arguments.dropFirst().first ?? "docs/images"
    try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

    let defaults = UserDefaults(suiteName: "com.ariomoniri.moredock.docs") ?? .standard
    let settings = SettingsStore(defaults: defaults)
    settings.isEnabled = true
    settings.showOnAllDisplays = true
    settings.followSystemDock = false
    settings.edge = .bottom
    settings.iconSize = 54
    settings.opacity = 0.92
    settings.liquidGlass = true
    settings.magnification = true
    settings.activationDisplayMode = .clickedDisplay

    let settingsBackdrop = ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.15, green: 0.20, blue: 0.23)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        SettingsView(settings: settings, onCheckForUpdates: {})
            .frame(width: 700, height: 500)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.35), radius: 24, y: 14)
    }

    try render(settingsBackdrop, size: CGSize(width: 1200, height: 675), path: "\(output)/moredock-settings.png")
}

@main
struct DocsScreenshotRenderer {
    static func main() async throws {
        try await MainActor.run {
            try renderAll()
        }
    }
}
