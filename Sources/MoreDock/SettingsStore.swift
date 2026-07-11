import AppKit
import Combine

enum DockEdge: String, CaseIterable, Codable, Identifiable {
    case bottom
    case left
    case right

    var id: String { rawValue }

    var title: String {
        switch self {
        case .bottom: "Bottom"
        case .left: "Left"
        case .right: "Right"
        }
    }
}

struct DisplayDockSettings: Codable, Equatable {
    var isEnabled = true
    var followsGlobalPlacement = true
    var edge: DockEdge = .bottom
    var followsGlobalAppearance = true
    var iconSize = 48.0
    var opacity = 0.82
    var autoHide = false
    var magnification = true
    var showRunningIndicators = true
    var avoidDisplayJunctions = true
}

/// A user-pinned application in a specific dock's custom list.
struct PinnedApp: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var bundleIdentifier: String?
    var path: String?

    /// Builds a pin from a dropped or chosen `.app` bundle URL.
    static func from(url: URL) -> PinnedApp {
        let bundleIdentifier = Bundle(url: url)?.bundleIdentifier
        let displayName = FileManager.default.displayName(atPath: url.path)
        let name = displayName.hasSuffix(".app") ? String(displayName.dropLast(4)) : displayName
        return PinnedApp(
            id: bundleIdentifier ?? url.path,
            name: name.isEmpty ? url.deletingPathExtension().lastPathComponent : name,
            bundleIdentifier: bundleIdentifier,
            path: url.path
        )
    }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published var isEnabled: Bool {
        didSet { save(isEnabled, for: Keys.isEnabled) }
    }

    @Published var showOnAllDisplays: Bool {
        didSet { save(showOnAllDisplays, for: Keys.showOnAllDisplays) }
    }

    @Published var followSystemDock: Bool {
        didSet { save(followSystemDock, for: Keys.followSystemDock) }
    }

    @Published var hideOnNativeDockScreen: Bool {
        didSet { save(hideOnNativeDockScreen, for: Keys.hideOnNativeDockScreen) }
    }

    @Published var activationDisplayMode: ActivationDisplayMode {
        didSet { save(activationDisplayMode.rawValue, for: Keys.activationDisplayMode) }
    }

    @Published var edge: DockEdge {
        didSet { save(edge.rawValue, for: Keys.edge) }
    }

    @Published var iconSize: Double {
        didSet { save(iconSize, for: Keys.iconSize) }
    }

    @Published var magnification: Bool {
        didSet { save(magnification, for: Keys.magnification) }
    }

    @Published var opacity: Double {
        didSet { save(opacity, for: Keys.opacity) }
    }

    @Published var liquidGlass: Bool {
        didSet { save(liquidGlass, for: Keys.liquidGlass) }
    }

    @Published var showRunningIndicators: Bool {
        didSet { save(showRunningIndicators, for: Keys.showRunningIndicators) }
    }

    @Published var autoHide: Bool {
        didSet { save(autoHide, for: Keys.autoHide) }
    }

    @Published var respectMenuBarSafeArea: Bool {
        didSet { save(respectMenuBarSafeArea, for: Keys.respectMenuBarSafeArea) }
    }

    @Published var avoidDisplayJunctions: Bool {
        didSet { save(avoidDisplayJunctions, for: Keys.avoidDisplayJunctions) }
    }

    @Published var displaySettings: [String: DisplayDockSettings] {
        didSet { saveDisplaySettings() }
    }

    /// Per-display custom pinned app lists. A missing entry means that display
    /// mirrors the native Dock's pinned apps; a present entry (even empty) means the
    /// display has its own independent list.
    @Published var customDockApps: [String: [PinnedApp]] {
        didSet { saveCustomDockApps() }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        showOnAllDisplays = defaults.object(forKey: Keys.showOnAllDisplays) as? Bool ?? true
        followSystemDock = defaults.object(forKey: Keys.followSystemDock) as? Bool ?? true
        hideOnNativeDockScreen = defaults.object(forKey: Keys.hideOnNativeDockScreen) as? Bool ?? true
        activationDisplayMode = ActivationDisplayMode(rawValue: defaults.string(forKey: Keys.activationDisplayMode) ?? "") ?? .native
        edge = DockEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .bottom
        iconSize = defaults.object(forKey: Keys.iconSize) as? Double ?? 48
        magnification = defaults.object(forKey: Keys.magnification) as? Bool ?? true
        opacity = defaults.object(forKey: Keys.opacity) as? Double ?? 0.82
        liquidGlass = defaults.object(forKey: Keys.liquidGlass) as? Bool ?? true
        showRunningIndicators = defaults.object(forKey: Keys.showRunningIndicators) as? Bool ?? true
        autoHide = defaults.object(forKey: Keys.autoHide) as? Bool ?? false
        respectMenuBarSafeArea = defaults.object(forKey: Keys.respectMenuBarSafeArea) as? Bool ?? true
        avoidDisplayJunctions = defaults.object(forKey: Keys.avoidDisplayJunctions) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.displaySettings),
           let decoded = try? JSONDecoder().decode([String: DisplayDockSettings].self, from: data) {
            displaySettings = decoded
        } else {
            displaySettings = [:]
        }
        if let data = defaults.data(forKey: Keys.customDockApps),
           let decoded = try? JSONDecoder().decode([String: [PinnedApp]].self, from: data) {
            customDockApps = decoded
        } else {
            customDockApps = [:]
        }
    }

    private let defaults: UserDefaults

    private func save(_ value: Any, for key: String) {
        defaults.set(value, forKey: key)
    }

    /// Copies the current native macOS Dock values into the editable global
    /// settings. Called the moment a mirrored Appearance control is edited so that
    /// turning off "Follow native Dock" does not snap the other controls back to
    /// stale stored defaults.
    func adoptNativeDockValues() {
        edge = SystemDockPreferences.nativeEdge
        iconSize = SystemDockPreferences.nativeIconSize
        magnification = SystemDockPreferences.nativeMagnification
        showRunningIndicators = SystemDockPreferences.nativeShowRunningIndicators
        // Auto-hide is intentionally not adopted from the native Dock — extra docks
        // stay visible by default and auto-hide is controlled explicitly.
    }

    func settingsForDisplay(_ displayID: String) -> DisplayDockSettings {
        displaySettings[displayID] ?? DisplayDockSettings()
    }

    func updateSettingsForDisplay(_ displayID: String, mutate: (inout DisplayDockSettings) -> Void) {
        var next = displaySettings[displayID] ?? DisplayDockSettings()
        mutate(&next)
        var copy = displaySettings
        copy[displayID] = next
        displaySettings = copy
    }

    private func saveDisplaySettings() {
        guard let data = try? JSONEncoder().encode(displaySettings) else { return }
        defaults.set(data, forKey: Keys.displaySettings)
    }

    // MARK: - Per-dock pinned apps

    /// The custom list for a display, or nil when it mirrors the native Dock.
    func customPins(for displayID: String) -> [PinnedApp]? {
        customDockApps[displayID]
    }

    func hasCustomPins(_ displayID: String) -> Bool {
        customDockApps[displayID] != nil
    }

    /// Adds `app` to each display in `displayIDs`. A display with no custom list yet
    /// is seeded from `nativePins` first so its existing native apps are kept.
    func pin(_ app: PinnedApp, toDisplays displayIDs: [String], seededWith nativePins: [PinnedApp]) {
        var copy = customDockApps
        for target in displayIDs {
            var list = copy[target] ?? nativePins
            if !list.contains(where: { $0.id == app.id }) {
                list.append(app)
            }
            copy[target] = list
        }
        customDockApps = copy
    }

    func unpin(_ id: String, from displayID: String, seededWith nativePins: [PinnedApp]) {
        var copy = customDockApps
        var list = copy[displayID] ?? nativePins
        list.removeAll { $0.id == id }
        copy[displayID] = list
        customDockApps = copy
    }

    /// Drops a display's custom list so it mirrors the native Dock again.
    func resetPins(for displayID: String) {
        guard customDockApps[displayID] != nil else { return }
        var copy = customDockApps
        copy[displayID] = nil
        customDockApps = copy
    }

    private func saveCustomDockApps() {
        guard let data = try? JSONEncoder().encode(customDockApps) else { return }
        defaults.set(data, forKey: Keys.customDockApps)
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let showOnAllDisplays = "showOnAllDisplays"
        static let followSystemDock = "followSystemDock"
        static let hideOnNativeDockScreen = "hideOnNativeDockScreen"
        static let activationDisplayMode = "activationDisplayMode"
        static let edge = "edge"
        static let iconSize = "iconSize"
        static let magnification = "magnification"
        static let opacity = "opacity"
        static let liquidGlass = "liquidGlass"
        static let showRunningIndicators = "showRunningIndicators"
        static let autoHide = "autoHide"
        static let respectMenuBarSafeArea = "respectMenuBarSafeArea"
        static let avoidDisplayJunctions = "avoidDisplayJunctions"
        static let displaySettings = "displaySettings"
        static let customDockApps = "customDockApps"
    }
}
