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
        autoHide = SystemDockPreferences.nativeAutoHide
        showRunningIndicators = SystemDockPreferences.nativeShowRunningIndicators
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
    }
}
