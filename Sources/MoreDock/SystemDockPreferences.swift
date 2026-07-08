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

        runtime.edge = edge(from: string("orientation")) ?? runtime.edge
        runtime.iconSize = clamped(double("tilesize"), defaultValue: runtime.iconSize, range: 24...96)
        runtime.magnification = bool("magnification") ?? runtime.magnification
        runtime.magnifiedIconSize = clamped(
            double("largesize"),
            defaultValue: max(runtime.iconSize * 1.25, runtime.iconSize + 10),
            range: runtime.iconSize...128
        )
        runtime.autoHide = bool("autohide") ?? runtime.autoHide
        runtime.autoHideDelay = clamped(
            double("autohide-delay"),
            defaultValue: 0.0,
            range: 0.0...2.0
        )
        runtime.autoHideDuration = clamped(
            double("autohide-time-modifier"),
            defaultValue: 0.20,
            range: 0.0...2.0
        )
        return runtime
    }

    static func nativeDockScreen(for screens: [NSScreen], edge: DockEdge) -> NSScreen? {
        let reservedScreens = screens.filter { screen in
            switch edge {
            case .bottom:
                screen.visibleFrame.minY - screen.frame.minY > 20
            case .left:
                screen.visibleFrame.minX - screen.frame.minX > 20
            case .right:
                screen.frame.maxX - screen.visibleFrame.maxX > 20
            }
        }

        return reservedScreens.first ?? NSScreen.main
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

    private static func value(_ key: String) -> Any? {
        CFPreferencesCopyAppValue(key as CFString, "com.apple.dock" as CFString)
    }

    private static func string(_ key: String) -> String? {
        value(key) as? String
    }

    private static func double(_ key: String) -> Double? {
        switch value(key) {
        case let number as NSNumber:
            number.doubleValue
        case let string as String:
            Double(string)
        default:
            nil
        }
    }

    private static func bool(_ key: String) -> Bool? {
        switch value(key) {
        case let number as NSNumber:
            number.boolValue
        case let string as String:
            (string as NSString).boolValue
        default:
            nil
        }
    }
}
