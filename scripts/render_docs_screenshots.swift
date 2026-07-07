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
private func sampleApps() -> [DockAppItem] {
    let assetIcon = NSImage(contentsOfFile: "Resources/AppIcon.png")
    let symbols = [
        "display.2": "MoreDock",
        "safari": "Safari",
        "terminal": "Terminal",
        "swift": "Xcode",
        "music.note": "Music",
        "message": "Messages",
        "folder": "Finder"
    ]

    return symbols.enumerated().map { index, item in
        let image: NSImage
        if index == 0, let assetIcon {
            image = assetIcon
        } else {
            image = NSImage(systemSymbolName: item.key, accessibilityDescription: item.value) ?? NSImage()
            image.isTemplate = false
        }
        return DockAppItem(
            id: item.value.lowercased(),
            name: item.value,
            bundleIdentifier: nil,
            icon: image,
            processIdentifier: pid_t(index + 100)
        )
    }
}

@MainActor
private func renderAll() throws {
    let output = CommandLine.arguments.dropFirst().first ?? "docs/images"
    try FileManager.default.createDirectory(atPath: output, withIntermediateDirectories: true)

    let defaults = UserDefaults(suiteName: "com.ariomoniri.moredock.docs") ?? .standard
    let settings = SettingsStore(defaults: defaults)
    settings.isEnabled = true
    settings.showOnAllDisplays = true
    settings.edge = .bottom
    settings.iconSize = 54
    settings.opacity = 0.92
    settings.liquidGlass = true
    settings.magnification = true
    settings.activationDisplayMode = .clickedDisplay

    let snapshot = SnapshotSettings(settings)
    let dockBackdrop = ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.06, green: 0.07, blue: 0.08),
                Color(red: 0.10, green: 0.15, blue: 0.18),
                Color(red: 0.03, green: 0.04, blue: 0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        VStack {
            Spacer()
            DockPanelView(
                apps: sampleApps(),
                settings: snapshot,
                targetVisibleFrame: NSRect(x: 0, y: 0, width: 1200, height: 675)
            )
                .frame(width: 560, height: 90)
                .padding(.bottom, 34)
        }
    }

    try render(dockBackdrop, size: CGSize(width: 1200, height: 675), path: "\(output)/moredock-dock.png")

    let settingsBackdrop = ZStack {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.09, blue: 0.10),
                Color(red: 0.15, green: 0.20, blue: 0.23)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        SettingsView(settings: settings)
            .frame(width: 540, height: 620)
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
