import AppKit
import UniformTypeIdentifiers

struct DockRuntimeSettings: Equatable {
    var edge: DockEdge
    var iconSize: Double
    var magnifiedIconSize: Double
    var magnification: Bool
    var opacity: Double
    var liquidGlass: Bool
    var showRunningIndicators: Bool
    var autoHide: Bool
    var autoHideDelay: Double
    var autoHideDuration: Double
    var respectMenuBarSafeArea: Bool
    var avoidDisplayJunctions: Bool
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
        showRunningIndicators = settings.showRunningIndicators
        autoHide = settings.autoHide
        autoHideDelay = settings.autoHideDelay
        autoHideDuration = 0.20
        respectMenuBarSafeArea = settings.respectMenuBarSafeArea
        avoidDisplayJunctions = settings.avoidDisplayJunctions
        followsSystemDock = settings.followSystemDock
        activationDisplayMode = settings.activationDisplayMode
    }
}

enum SystemDockPreferences {
    static func synchronize() {
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
    }

    @MainActor
    static func runtimeSettings(fallback settings: SettingsStore) -> DockRuntimeSettings {
        var runtime = DockRuntimeSettings(settings: settings)
        guard settings.followSystemDock else { return runtime }

        synchronize()
        runtime.edge = edge(from: string("orientation")) ?? runtime.edge
        runtime.iconSize = clamped(double("tilesize"), defaultValue: runtime.iconSize, range: 24...96)
        runtime.magnification = bool("magnification") ?? runtime.magnification
        runtime.showRunningIndicators = bool("show-process-indicators") ?? runtime.showRunningIndicators
        runtime.magnifiedIconSize = clamped(
            double("largesize"),
            defaultValue: max(runtime.iconSize * 1.25, runtime.iconSize + 10),
            range: runtime.iconSize...128
        )
        // Do NOT mirror the native Dock's auto-hide onto the extra docks. The extra
        // docks are the whole point of MoreDock, so they stay visible by default;
        // auto-hide is an explicit MoreDock setting, and its reveal delay is the
        // user's own "Reveal delay" control (already carried on `runtime`). Only the
        // slide-in animation length is borrowed so it feels like macOS.
        runtime.autoHideDuration = clamped(
            double("autohide-time-modifier"),
            defaultValue: 0.20,
            range: 0.0...2.0
        )
        return runtime
    }

    static func nativeDockScreen(for screens: [NSScreen], edge: DockEdge) -> NSScreen? {
        if let dockWindowScreen = dockWindowScreens(for: screens).first {
            return dockWindowScreen
        }

        let reservedScreens = screens.filter { hasReservedDockArea($0, edge: edge) }
        return reservedScreens.first ?? primaryDisplayScreen(from: screens) ?? screens.first
    }

    /// Returns the screen numbers of every display that currently appears to host the
    /// native macOS Dock. Combining the on-screen Dock window location with the
    /// reserved-area heuristic (and a primary-display fallback) makes sure MoreDock
    /// never draws a duplicate dock on top of the real one.
    static func nativeDockScreenNumbers(for screens: [NSScreen], edge: DockEdge) -> Set<NSNumber> {
        var numbers = Set<NSNumber>()

        for screen in dockWindowScreens(for: screens) {
            if let number = screenNumber(of: screen) {
                numbers.insert(number)
            }
        }

        for screen in screens where hasReservedDockArea(screen, edge: edge) {
            if let number = screenNumber(of: screen) {
                numbers.insert(number)
            }
        }

        if numbers.isEmpty, let number = primaryDisplayScreen(from: screens).flatMap(screenNumber(of:)) {
            numbers.insert(number)
        }

        return numbers
    }

    /// Confident detection only — a visible Dock window or a reserved Dock area.
    /// Returns an empty set when the Dock cannot be located (e.g. it is auto-hidden),
    /// so callers can hold on to a last-known value instead of flickering to a
    /// fallback and hiding/showing panels.
    static func detectedNativeDockScreenNumbers(for screens: [NSScreen], edge: DockEdge) -> Set<NSNumber> {
        var numbers = Set<NSNumber>()
        for screen in dockWindowScreens(for: screens) {
            if let number = screenNumber(of: screen) {
                numbers.insert(number)
            }
        }
        for screen in screens where hasReservedDockArea(screen, edge: edge) {
            if let number = screenNumber(of: screen) {
                numbers.insert(number)
            }
        }
        return numbers
    }

    private static func hasReservedDockArea(_ screen: NSScreen, edge: DockEdge) -> Bool {
        switch edge {
        case .bottom:
            return screen.visibleFrame.minY - screen.frame.minY > 20
        case .left:
            return screen.visibleFrame.minX - screen.frame.minX > 20
        case .right:
            return screen.frame.maxX - screen.visibleFrame.maxX > 20
        }
    }

    private static func screenNumber(of screen: NSScreen) -> NSNumber? {
        screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    static func primaryDisplayScreen(from screens: [NSScreen] = NSScreen.screens) -> NSScreen? {
        let primaryDisplayID = NSNumber(value: CGMainDisplayID())
        return screens.first { screen in
            screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber == primaryDisplayID
        } ?? screens.first { screen in
            screen.frame.origin == .zero
        } ?? screens.first
    }

    static func persistentApps() -> [DockAppItem] {
        synchronize()
        return persistentItems(for: "persistent-apps")
    }

    static func persistentOthers() -> [DockAppItem] {
        synchronize()
        return persistentItems(for: "persistent-others")
    }

    /// The Finder tile, which the native Dock always shows first.
    static func finderItem() -> DockAppItem {
        let url = URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app")
        let pid = NSRunningApplication
            .runningApplications(withBundleIdentifier: "com.apple.finder")
            .first?
            .processIdentifier
        return DockAppItem(
            id: "com.apple.finder",
            name: "Finder",
            bundleIdentifier: "com.apple.finder",
            url: url,
            icon: NSWorkspace.shared.icon(forFile: url.path),
            processIdentifier: pid,
            kind: .application,
            isRunning: pid != nil
        )
    }

    /// The Trash tile, which the native Dock always shows last.
    static func trashItem() -> DockAppItem {
        let trashURL = (try? FileManager.default.url(for: .trashDirectory, in: .userDomainMask, appropriateFor: nil, create: false))
            ?? URL(fileURLWithPath: NSString(string: "~/.Trash").expandingTildeInPath)
        return DockAppItem(
            id: "moredock.trash",
            name: "Trash",
            bundleIdentifier: nil,
            url: trashURL,
            icon: NSWorkspace.shared.icon(forFile: trashURL.path),
            processIdentifier: nil,
            kind: .trash,
            isRunning: false
        )
    }

    static var nativeEdge: DockEdge {
        synchronize()
        return edge(from: string("orientation")) ?? .bottom
    }

    static var nativeIconSize: Double {
        synchronize()
        return clamped(double("tilesize"), defaultValue: 48, range: 24...96)
    }

    static var nativeMagnifiedIconSize: Double {
        synchronize()
        let iconSize = nativeIconSize
        return clamped(double("largesize"), defaultValue: max(iconSize + 12, iconSize * 1.25), range: iconSize...128)
    }

    static var nativeMagnification: Bool {
        synchronize()
        return bool("magnification") ?? true
    }

    static var nativeShowRunningIndicators: Bool {
        synchronize()
        return bool("show-process-indicators") ?? true
    }

    static var nativeAutoHide: Bool {
        synchronize()
        return bool("autohide") ?? false
    }

    static func applyNativeDockSettings(edge: DockEdge, iconSize: Double, magnifiedIconSize: Double, magnification: Bool, autoHide: Bool) {
        set(edge.rawValue as NSString, for: "orientation")
        set(NSNumber(value: iconSize), for: "tilesize")
        set(NSNumber(value: max(iconSize, magnifiedIconSize)), for: "largesize")
        set(NSNumber(value: magnification), for: "magnification")
        set(NSNumber(value: autoHide), for: "autohide")
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        relaunchDock()
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

    private static func set(_ value: Any, for key: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFPropertyList, "com.apple.dock" as CFString)
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

    private static func persistentItems(for key: String) -> [DockAppItem] {
        guard let items = value(key) as? [[String: Any]] else { return [] }
        return items.compactMap { item in
            guard let tileData = item["tile-data"] as? [String: Any] else { return nil }
            let label = tileData["file-label"] as? String
            let bundleIdentifier = tileData["bundle-identifier"] as? String
            let fileData = tileData["file-data"] as? [String: Any]
            let urlString = fileData?["_CFURLString"] as? String
            let url = urlString.flatMap(URL.init(string:))
            let name = label ?? bundleIdentifier ?? url?.deletingPathExtension().lastPathComponent ?? "Dock Item"
            let tileType = item["tile-type"] as? String
            let kind: DockAppItem.Kind = tileType == "directory-tile" ? .folder : .application
            let id = bundleIdentifier ?? url?.absoluteString ?? name
            let icon: NSImage

            if let url, url.isFileURL {
                icon = NSWorkspace.shared.icon(forFile: url.path)
            } else {
                icon = NSWorkspace.shared.icon(for: kind == .folder ? .folder : .item)
            }

            return DockAppItem(
                id: id,
                name: name,
                bundleIdentifier: bundleIdentifier,
                url: url,
                icon: icon,
                processIdentifier: runningProcessIdentifier(for: bundleIdentifier),
                kind: kind,
                isRunning: runningProcessIdentifier(for: bundleIdentifier) != nil
            )
        }
    }

    private static func runningProcessIdentifier(for bundleIdentifier: String?) -> pid_t? {
        guard let bundleIdentifier else { return nil }
        return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier
    }

    /// Screens that currently show a real Dock window, most-covered first.
    ///
    /// `CGWindowListCopyWindowInfo` reports bounds in Quartz global coordinates
    /// (origin at the top-left of the primary display, y increasing downward), while
    /// `NSScreen.frame` uses Cocoa coordinates (origin bottom-left, y increasing
    /// upward). The bounds must be flipped before intersecting them with screen
    /// frames, otherwise the Dock can be attributed to the wrong display on
    /// multi-monitor setups and MoreDock draws a duplicate dock over the real one.
    private static func dockWindowScreens(for screens: [NSScreen]) -> [NSScreen] {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        let primaryHeight = screens.first { $0.frame.origin == .zero }?.frame.height
            ?? screens.map(\.frame.maxY).max()
            ?? 0

        let dockWindows = windows.filter { window in
            (window[kCGWindowOwnerName as String] as? String) == "Dock"
        }

        var matches: [(screen: NSScreen, area: CGFloat)] = []
        for window in dockWindows {
            guard let boundsDictionary = window[kCGWindowBounds as String] as? [String: Any],
                  let x = boundsDictionary["X"] as? CGFloat,
                  let y = boundsDictionary["Y"] as? CGFloat,
                  let width = boundsDictionary["Width"] as? CGFloat,
                  let height = boundsDictionary["Height"] as? CGFloat,
                  width > 40,
                  height > 40 else {
                continue
            }

            let bounds = NSRect(x: x, y: primaryHeight - y - height, width: width, height: height)
            if let screen = screens.max(by: { $0.frame.intersection(bounds).area < $1.frame.intersection(bounds).area }),
               screen.frame.intersects(bounds) {
                matches.append((screen, screen.frame.intersection(bounds).area))
            }
        }

        return matches
            .sorted { $0.area > $1.area }
            .map(\.screen)
    }

    private static func relaunchDock() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        task.arguments = ["Dock"]
        try? task.run()
    }
}

private extension NSRect {
    var area: CGFloat {
        guard !isNull, !isEmpty else { return 0 }
        return width * height
    }
}
