import AppKit
import Combine
import SwiftUI

typealias DisplayID = NSNumber

struct DockAppItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case application
        case folder
        case file
    }

    let id: String
    let name: String
    let bundleIdentifier: String?
    let url: URL?
    let icon: NSImage
    let processIdentifier: pid_t?
    let kind: Kind
    let isRunning: Bool

    static func == (lhs: DockAppItem, rhs: DockAppItem) -> Bool {
        lhs.id == rhs.id
    }
}

@MainActor
final class DockController {
    private let settings: SettingsStore
    private var panels: [DisplayID: DockPanelController] = [:]
    private var dockItems: [DockAppItem] = []
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
        refreshItems()
        syncPanels()
    }

    private func tick() {
        appRefreshCounter += 1
        if appRefreshCounter >= 10 {
            appRefreshCounter = 0
            refreshItems()
        }
        syncPanels()
    }

    private func refreshItems() {
        let workspace = NSWorkspace.shared
        let running = workspace.runningApplications
            .filter { app in
                app.activationPolicy == .regular && !app.isTerminated
            }
            .sorted { lhs, rhs in
                (lhs.localizedName ?? "") < (rhs.localizedName ?? "")
            }

        let runningItems = running.map { app in
            let identifier = app.bundleIdentifier ?? "pid-\(app.processIdentifier)"
            let name = app.localizedName ?? identifier
            let icon = app.icon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name) ?? NSImage()
            return DockAppItem(
                id: identifier,
                name: name,
                bundleIdentifier: app.bundleIdentifier,
                url: app.bundleURL,
                icon: icon,
                processIdentifier: app.processIdentifier,
                kind: .application,
                isRunning: true
            )
        }

        var seen = Set<String>()
        var items: [DockAppItem] = []
        for item in SystemDockPreferences.persistentDockItems() + runningItems {
            guard !seen.contains(item.id) else { continue }
            seen.insert(item.id)
            items.append(item)
        }
        dockItems = items
    }

    private func syncPanels() {
        guard settings.isEnabled else {
            panels.values.forEach { $0.close() }
            panels.removeAll()
            return
        }

        let runtimeSettings = SystemDockPreferences.runtimeSettings(fallback: settings)
        var targetScreens = settings.showOnAllDisplays ? NSScreen.screens : [SystemDockPreferences.primaryDisplayScreen()].compactMap { $0 }
        if settings.followSystemDock, settings.hideOnNativeDockScreen,
           let nativeDockScreenNumber = SystemDockPreferences
            .nativeDockScreen(for: NSScreen.screens, edge: runtimeSettings.edge)?
            .screenNumber {
            targetScreens.removeAll { $0.screenNumber == nativeDockScreenNumber }
        }
        targetScreens = targetScreens.filter { screen in
            guard let displayID = screen.screenNumber?.stringValue else { return false }
            return settings.settingsForDisplay(displayID).isEnabled
        }

        let targetNumbers = Set(targetScreens.compactMap(\.screenNumber))

        for (number, panel) in panels where !targetNumbers.contains(number) {
            panel.close()
        }
        panels = panels.filter { targetNumbers.contains($0.key) }

        for screen in targetScreens {
            guard let number = screen.screenNumber else { continue }
            let panel = panels[number] ?? DockPanelController(screenNumber: number)
            panels[number] = panel
            let panelSettings = effectiveSettings(runtimeSettings, for: screen, allScreens: NSScreen.screens, displayID: number.stringValue)
            panel.update(
                screen: screen,
                apps: dockItems,
                settings: panelSettings,
                now: Date()
            )
        }
    }

    private func effectiveSettings(_ settings: DockRuntimeSettings, for screen: NSScreen, allScreens: [NSScreen], displayID: String) -> DockRuntimeSettings {
        let displaySettings = self.settings.settingsForDisplay(displayID)
        var adjusted = settings

        if !displaySettings.followsGlobalPlacement {
            adjusted.edge = displaySettings.edge
        }

        adjusted.avoidDisplayJunctions = displaySettings.avoidDisplayJunctions

        guard adjusted.avoidDisplayJunctions else { return adjusted }
        guard isEdgeShared(adjusted.edge, of: screen, with: allScreens) else { return adjusted }

        switch adjusted.edge {
        case .left:
            adjusted.edge = isEdgeShared(.right, of: screen, with: allScreens) ? .bottom : .right
        case .right:
            adjusted.edge = isEdgeShared(.left, of: screen, with: allScreens) ? .bottom : .left
        case .bottom:
            adjusted.edge = .bottom
        }
        return adjusted
    }

    private func isEdgeShared(_ edge: DockEdge, of screen: NSScreen, with screens: [NSScreen]) -> Bool {
        let tolerance: CGFloat = 2
        let frame = screen.frame
        return screens.contains { other in
            guard other != screen else { return false }
            let otherFrame = other.frame
            let verticalOverlap = frame.minY < otherFrame.maxY - tolerance && frame.maxY > otherFrame.minY + tolerance
            let horizontalOverlap = frame.minX < otherFrame.maxX - tolerance && frame.maxX > otherFrame.minX + tolerance

            switch edge {
            case .left:
                return verticalOverlap && abs(frame.minX - otherFrame.maxX) <= tolerance
            case .right:
                return verticalOverlap && abs(frame.maxX - otherFrame.minX) <= tolerance
            case .bottom:
                return horizontalOverlap && abs(frame.minY - otherFrame.maxY) <= tolerance
            }
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
