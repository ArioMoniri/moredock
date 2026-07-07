import AppKit
import Combine

enum DockEdge: String, CaseIterable, Identifiable {
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

    @Published var autoHide: Bool {
        didSet { save(autoHide, for: Keys.autoHide) }
    }

    @Published var respectMenuBarSafeArea: Bool {
        didSet { save(respectMenuBarSafeArea, for: Keys.respectMenuBarSafeArea) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        isEnabled = defaults.object(forKey: Keys.isEnabled) as? Bool ?? true
        showOnAllDisplays = defaults.object(forKey: Keys.showOnAllDisplays) as? Bool ?? true
        followSystemDock = defaults.object(forKey: Keys.followSystemDock) as? Bool ?? true
        activationDisplayMode = ActivationDisplayMode(rawValue: defaults.string(forKey: Keys.activationDisplayMode) ?? "") ?? .native
        edge = DockEdge(rawValue: defaults.string(forKey: Keys.edge) ?? "") ?? .bottom
        iconSize = defaults.object(forKey: Keys.iconSize) as? Double ?? 48
        magnification = defaults.object(forKey: Keys.magnification) as? Bool ?? true
        opacity = defaults.object(forKey: Keys.opacity) as? Double ?? 0.82
        liquidGlass = defaults.object(forKey: Keys.liquidGlass) as? Bool ?? true
        autoHide = defaults.object(forKey: Keys.autoHide) as? Bool ?? false
        respectMenuBarSafeArea = defaults.object(forKey: Keys.respectMenuBarSafeArea) as? Bool ?? true
    }

    private let defaults: UserDefaults

    private func save(_ value: Any, for key: String) {
        defaults.set(value, forKey: key)
    }

    private enum Keys {
        static let isEnabled = "isEnabled"
        static let showOnAllDisplays = "showOnAllDisplays"
        static let followSystemDock = "followSystemDock"
        static let activationDisplayMode = "activationDisplayMode"
        static let edge = "edge"
        static let iconSize = "iconSize"
        static let magnification = "magnification"
        static let opacity = "opacity"
        static let liquidGlass = "liquidGlass"
        static let autoHide = "autoHide"
        static let respectMenuBarSafeArea = "respectMenuBarSafeArea"
    }
}
