import AppKit

struct DockRuntimeSettings: Equatable {
    var edge: DockEdge
    var iconSize: Double
    var magnifiedIconSize: Double
    var magnification: Bool
    var opacity: Double
    var liquidGlass: Bool
    var autoHide: Bool
    var autoHideDelay: Double
    var autoHideDuration: Double
    var respectMenuBarSafeArea: Bool
    var followsSystemDock: Bool
    var activationDisplayMode: ActivationDisplayMode

    @MainActor
    init(settings: SettingsStore) {
        edge = settings.edge
        iconSize = settings.iconSize
        magnifiedIconSize = settings.iconSize * 1.22
        magnification = settings.magnification
        opacity = settings.opacity
        liquidGlass = settings.liquidGlass
        autoHide = settings.autoHide
        autoHideDelay = 0.05
        autoHideDuration = 0.20
        respectMenuBarSafeArea = settings.respectMenuBarSafeArea
        followsSystemDock = settings.followSystemDock
        activationDisplayMode = settings.activationDisplayMode
    }
}

enum SystemDockPreferences {
    @MainActor
    static func runtimeSettings(fallback settings: SettingsStore) -> DockRuntimeSettings {
        var runtime = DockRuntimeSettings(settings: settings)
        guard settings.followSystemDock else { return runtime }

        let defaults = UserDefaults(suiteName: "com.apple.dock")
        defaults?.synchronize()

        runtime.edge = edge(from: defaults?.string(forKey: "orientation")) ?? runtime.edge
        runtime.iconSize = clamped(defaults?.double(forKey: "tilesize"), defaultValue: runtime.iconSize, range: 24...96)
        runtime.magnification = defaults?.bool(forKey: "magnification") ?? runtime.magnification
        runtime.magnifiedIconSize = clamped(
            defaults?.double(forKey: "largesize"),
            defaultValue: max(runtime.iconSize * 1.25, runtime.iconSize + 10),
            range: runtime.iconSize...128
        )
        runtime.autoHide = defaults?.bool(forKey: "autohide") ?? runtime.autoHide
        runtime.autoHideDelay = clamped(
            defaults?.double(forKey: "autohide-delay"),
            defaultValue: 0.0,
            range: 0.0...2.0
        )
        runtime.autoHideDuration = clamped(
            defaults?.double(forKey: "autohide-time-modifier"),
            defaultValue: 0.20,
            range: 0.0...2.0
        )
        return runtime
    }

    private static func edge(from orientation: String?) -> DockEdge? {
        switch orientation {
        case "left": .left
        case "right": .right
        case "bottom": .bottom
        default: nil
        }
    }

    private static func clamped(_ value: Double?, defaultValue: Double, range: ClosedRange<Double>) -> Double {
        guard let value, value > 0 || range.lowerBound == 0 else { return defaultValue }
        return min(max(value, range.lowerBound), range.upperBound)
    }
}
