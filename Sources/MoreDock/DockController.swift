import AppKit
import Combine
import SwiftUI
import UniformTypeIdentifiers

typealias DisplayID = NSNumber

struct DockAppItem: Identifiable, Equatable {
    enum Kind: Equatable {
        case application
        case folder
        case file
        case trash
        case separator
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
        lhs.id == rhs.id && lhs.isRunning == rhs.isRunning
    }

    /// A thin divider tile that mirrors the native Dock separator between apps
    /// and the folders/Trash section.
    static func separator(id: String) -> DockAppItem {
        DockAppItem(
            id: id,
            name: "",
            bundleIdentifier: nil,
            url: nil,
            icon: NSImage(),
            processIdentifier: nil,
            kind: .separator,
            isRunning: false
        )
    }
}

@MainActor
final class DockController {
    private let settings: SettingsStore
    private var panels: [DisplayID: DockPanelController] = [:]
    // Building blocks for each display's dock. Pinned apps are chosen per display
    // (custom list or native), so items are assembled per display, not shared.
    private var nativePinnedApps: [DockAppItem] = []
    private var pinnedOthers: [DockAppItem] = []
    private var runningApps: [DockAppItem] = []
    private var lastItemsSignature = ""
    private var cancellables = Set<AnyCancellable>()
    private var refreshTimer: Timer?
    private var appRefreshCounter = 0
    private var lastPanelSignature = ""

    // Cached results of the expensive native-Dock reads (CGWindowList + CFPreferences).
    // Recomputed ~1x/second or when settings/screens change, so the 0.12s tick that
    // drives auto-hide reveal stays cheap and responsive.
    private var cachedRuntimeSettings: DockRuntimeSettings?
    private var cachedNativeDockScreens: Set<NSNumber> = []
    private var cachedGlobalEdge: DockEdge = .bottom
    private var heavyRecomputeCounter = 0

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

        logScreens()
        refreshAll()
    }

    func refreshAll() {
        // Force the cached native-Dock reads to refresh on the next sync.
        cachedRuntimeSettings = nil
        refreshItems()
        syncPanels()
    }

    private func logScreens() {
        let primary = CGMainDisplayID()
        let description = NSScreen.screens.map { screen -> String in
            let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
            let isMain = number?.uint32Value == primary
            let frame = screen.frame
            return "\(isMain ? "Main" : "Ext")#\(number?.stringValue ?? "?")[x\(Int(frame.minX)),y\(Int(frame.minY)),\(Int(frame.width))x\(Int(frame.height))]"
        }
        .joined(separator: " ")
        mdLog("Screens: \(description)")
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
        nativePinnedApps = SystemDockPreferences.persistentApps()
        pinnedOthers = SystemDockPreferences.persistentOthers()
        runningApps = NSWorkspace.shared.runningApplications
            .filter { app in
                app.activationPolicy == .regular && !app.isTerminated && app.bundleIdentifier != "com.apple.finder"
            }
            .compactMap { app -> DockAppItem? in
                let bundleID = app.bundleIdentifier
                let identifier = bundleID ?? "pid-\(app.processIdentifier)"
                let name = app.localizedName ?? identifier
                let icon = app.icon ?? NSImage(systemSymbolName: "app.dashed", accessibilityDescription: name) ?? NSImage()
                return DockAppItem(
                    id: identifier,
                    name: name,
                    bundleIdentifier: bundleID,
                    url: app.bundleURL,
                    icon: icon,
                    processIdentifier: app.processIdentifier,
                    kind: .application,
                    isRunning: true
                )
            }

        let signature = "\(nativePinnedApps.count)|\(pinnedOthers.count)|\(runningApps.map(\.id).joined(separator: ","))"
        if signature != lastItemsSignature {
            lastItemsSignature = signature
            mdLog("Dock items refreshed: \(nativePinnedApps.count) native pinned apps, \(runningApps.count) running, \(pinnedOthers.count) folders/stacks.")
        }
    }

    /// The ordered tiles for one display: Finder, that display's pinned apps
    /// (custom list or native), running (unpinned) apps, separator, folders/stacks,
    /// and Trash.
    private func dockItems(for displayID: String) -> [DockAppItem] {
        let pinned: [DockAppItem]
        if let custom = settings.customPins(for: displayID) {
            pinned = custom.compactMap(resolvePinned)
        } else {
            pinned = nativePinnedApps.filter { $0.bundleIdentifier != "com.apple.finder" }
        }
        let pinnedIDs = Set(pinned.map(\.id))
        let running = runningApps.filter { !pinnedIDs.contains($0.id) }

        var items: [DockAppItem] = []
        items.append(SystemDockPreferences.finderItem())
        items.append(contentsOf: pinned.filter { $0.bundleIdentifier != "com.apple.finder" })
        items.append(contentsOf: running)
        items.append(.separator(id: "moredock.separator.apps"))
        items.append(contentsOf: pinnedOthers)
        items.append(SystemDockPreferences.trashItem())

        var seen = Set<String>()
        return items.filter { seen.insert($0.id).inserted }
    }

    private func resolvePinned(_ pin: PinnedApp) -> DockAppItem? {
        var url: URL?
        if let bundleID = pin.bundleIdentifier {
            url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
        }
        if url == nil, let path = pin.path {
            url = URL(fileURLWithPath: path)
        }

        let icon: NSImage
        if let url, FileManager.default.fileExists(atPath: url.path) {
            icon = NSWorkspace.shared.icon(forFile: url.path)
        } else {
            icon = NSWorkspace.shared.icon(for: .applicationBundle)
        }
        let pid = pin.bundleIdentifier.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first?.processIdentifier
        }
        return DockAppItem(
            id: pin.id,
            name: pin.name,
            bundleIdentifier: pin.bundleIdentifier,
            url: url,
            icon: icon,
            processIdentifier: pid,
            kind: .application,
            isRunning: pid != nil
        )
    }

    private func nativePins() -> [PinnedApp] {
        nativePinnedApps
            .filter { $0.bundleIdentifier != "com.apple.finder" }
            .map { PinnedApp(id: $0.id, name: $0.name, bundleIdentifier: $0.bundleIdentifier, path: $0.url?.path) }
    }

    // MARK: - Pin actions (wired into each panel)

    private func isPinned(_ item: DockAppItem, on displayID: String) -> Bool {
        if let custom = settings.customPins(for: displayID) {
            return custom.contains { $0.id == item.id }
        }
        return nativePinnedApps.contains { $0.id == item.id }
    }

    private func targetDisplayIDs(_ displayID: String, allDisplays: Bool) -> [String] {
        guard allDisplays else { return [displayID] }
        let all = NSScreen.screens.compactMap { $0.screenNumber?.stringValue }
        return all.isEmpty ? [displayID] : all
    }

    private func pin(_ item: DockAppItem, on displayID: String, allDisplays: Bool) {
        let app = PinnedApp(id: item.id, name: item.name, bundleIdentifier: item.bundleIdentifier, path: item.url?.path)
        settings.pin(app, toDisplays: targetDisplayIDs(displayID, allDisplays: allDisplays), seededWith: nativePins())
    }

    private func unpin(_ item: DockAppItem, on displayID: String) {
        settings.unpin(item.id, from: displayID, seededWith: nativePins())
    }

    private func addPinnedURL(_ url: URL, on displayID: String, allDisplays: Bool) {
        settings.pin(PinnedApp.from(url: url), toDisplays: targetDisplayIDs(displayID, allDisplays: allDisplays), seededWith: nativePins())
    }

    private func actions(for displayID: String) -> DockActions {
        DockActions(
            supportsPinning: true,
            isPinned: { [weak self] item in self?.isPinned(item, on: displayID) ?? false },
            pin: { [weak self] item, all in self?.pin(item, on: displayID, allDisplays: all) },
            unpin: { [weak self] item in self?.unpin(item, on: displayID) },
            addURL: { [weak self] url, all in self?.addPinnedURL(url, on: displayID, allDisplays: all) }
        )
    }

    private func syncPanels() {
        guard settings.isEnabled else {
            panels.values.forEach { $0.close() }
            panels.removeAll()
            return
        }

        heavyRecomputeCounter += 1
        if cachedRuntimeSettings == nil || heavyRecomputeCounter >= 8 {
            heavyRecomputeCounter = 0
            let runtime = SystemDockPreferences.runtimeSettings(fallback: settings)
            cachedRuntimeSettings = runtime
            cachedGlobalEdge = DockPlacement.globalEdge(for: settings)
            // The macOS Dock lives on some display regardless of whether MoreDock is
            // "following" it, so hiding on that display must not depend on
            // followSystemDock — otherwise editing an appearance control (which turns
            // followSystemDock off) makes MoreDock draw a duplicate dock on the main
            // display. Detect using the real Dock orientation.
            cachedNativeDockScreens = settings.hideOnNativeDockScreen
                ? SystemDockPreferences.nativeDockScreenNumbers(for: NSScreen.screens, edge: SystemDockPreferences.nativeEdge)
                : []
        }
        let runtimeSettings = cachedRuntimeSettings ?? SystemDockPreferences.runtimeSettings(fallback: settings)
        let nativeDockScreenNumbers = cachedNativeDockScreens

        var targetScreens = settings.showOnAllDisplays ? NSScreen.screens : [SystemDockPreferences.primaryDisplayScreen()].compactMap { $0 }
        if !nativeDockScreenNumbers.isEmpty {
            targetScreens.removeAll { screen in
                guard let number = screen.screenNumber else { return false }
                return nativeDockScreenNumbers.contains(number)
            }
        }
        targetScreens = targetScreens.filter { screen in
            guard let displayID = screen.screenNumber?.stringValue else { return false }
            return settings.settingsForDisplay(displayID).isEnabled
        }

        let targetNumbers = Set(targetScreens.compactMap(\.screenNumber))

        let globalEdge = cachedGlobalEdge
        let placements = targetScreens.compactMap { screen -> String? in
            guard let displayID = screen.screenNumber?.stringValue else { return nil }
            let edge = DockPlacement.resolvedEdge(
                globalEdge: globalEdge,
                displaySettings: settings.settingsForDisplay(displayID),
                screen: screen,
                allScreens: NSScreen.screens
            )
            return "\(displayID)=\(edge.rawValue)"
        }
        .sorted()
        let hiddenList = nativeDockScreenNumbers.map(\.stringValue).sorted().joined(separator: ",")
        let signature = placements.joined(separator: ",") + "|hidden:" + hiddenList
        if signature != lastPanelSignature {
            lastPanelSignature = signature
            let hiddenNote = hiddenList.isEmpty ? "" : " (macOS Dock display hidden: \(hiddenList))"
            mdLog("Dock panels on \(targetNumbers.count) display(s): \(placements.isEmpty ? "none" : placements.joined(separator: ", "))\(hiddenNote).")
        }

        for (number, panel) in panels where !targetNumbers.contains(number) {
            panel.close()
        }
        panels = panels.filter { targetNumbers.contains($0.key) }

        for screen in targetScreens {
            guard let number = screen.screenNumber else { continue }
            let displayID = number.stringValue
            let panel = panels[number] ?? DockPanelController(screenNumber: number)
            panels[number] = panel
            let panelSettings = effectiveSettings(runtimeSettings, for: screen, allScreens: NSScreen.screens, displayID: displayID)
            panel.update(
                screen: screen,
                apps: dockItems(for: displayID),
                settings: panelSettings,
                actions: actions(for: displayID),
                now: Date()
            )
        }
    }

    private func effectiveSettings(_ settings: DockRuntimeSettings, for screen: NSScreen, allScreens: [NSScreen], displayID: String) -> DockRuntimeSettings {
        let displaySettings = self.settings.settingsForDisplay(displayID)
        var adjusted = settings

        if !displaySettings.followsGlobalAppearance {
            adjusted.iconSize = displaySettings.iconSize
            adjusted.opacity = displaySettings.opacity
            adjusted.autoHide = displaySettings.autoHide
            adjusted.magnification = displaySettings.magnification
            adjusted.showRunningIndicators = displaySettings.showRunningIndicators
            adjusted.magnifiedIconSize = max(displaySettings.iconSize * 1.22, adjusted.magnifiedIconSize)
        }

        adjusted.avoidDisplayJunctions = displaySettings.avoidDisplayJunctions
        adjusted.edge = DockPlacement.resolvedEdge(
            globalEdge: settings.edge,
            displaySettings: displaySettings,
            screen: screen,
            allScreens: allScreens
        )
        return adjusted
    }

    @objc private func screenParametersChanged() {
        logScreens()
        refreshAll()
    }
}

private extension NSScreen {
    var screenNumber: DisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? DisplayID
    }
}
