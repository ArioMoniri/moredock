import AppKit
import Combine
import SwiftUI

typealias DisplayID = NSNumber

struct DockAppItem: Identifiable, Equatable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let icon: NSImage
    let processIdentifier: pid_t

    static func == (lhs: DockAppItem, rhs: DockAppItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class DockController {
    private let settings: SettingsStore
    private var panels: [DisplayID: DockPanelController] = [:]
    private var appItems: [DockAppItem] = []
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var appRefreshCounter = 0

    init(settings: SettingsStore) {
        self.settings = settings
    }

    func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )

        settings.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.refreshAll()
                }
            }
            .store(in: &cancellables)

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.12, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.tick()
            }
        }

        refreshAll()
    }

    func refreshAll() {
        refreshApps()
        syncPanels()
    }

    private func tick() {
        appRefreshCounter += 1
        if appRefreshCounter >= 10 {
            appRefreshCounter = 0
            refreshApps()
        }
        syncPanels()
    }

    private func refreshApps() {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications
            .filter { app in
                app.activationPolicy == .regular && !app.isTerminated
            }
            .sorted { lhs, rhs in
                (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
            }

        appItems = running.map { app in
            let identifier = app.bundleIdentifier ?? "pid-\(app.processIdentifier)"
            let name = app.localizedName ?? identifier
            let icon = app.icon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name) ?? NSImage()
            return DockAppItem(
                id: identifier,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                icon: icon,
                processIdentifier: app.processIdentifier
            )
        }
    }

    private func syncPanels() {
        guard settings.isEnabled else {
            panels.values.forEach { $0.close() }
            panels.removeAll()
            return
        }

        let targetScreens = settings.showOnAllDisplays ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        let targetNumbers = Set(targetScreens.compactMap(\.screenNumber))

        for (number, panel) in panels where !targetNumbers.contains(number) {
            panel.close()
        }
        panels = panels.filter { targetNumbers.contains($0.key) }

        for screen in targetScreens {
            guard let number = screen.screenNumber else { continue }
            let panel = panels[number] ?? DockPanelController(screenNumber: number)
            panels[number] = panel
            panel.update(
                screen: screen,
                apps: appItems,
                settings: SystemDockPreferences.runtimeSettings(fallback: settings),
                now: Date()
            )
        }
    }

    @objc private func screenParametersChanged() {
        refreshAll()
    }
}

private extension NSScreen {
    var screenNumber: DisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? DisplayID
    }
}
