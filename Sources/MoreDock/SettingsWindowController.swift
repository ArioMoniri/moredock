import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: SettingsStore, onCheckForUpdates: (() -> Void)? = nil) {
        let content = SettingsView(settings: settings, onCheckForUpdates: onCheckForUpdates)
        let hosting = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 880, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MoreDock Settings"
        window.titlebarAppearsTransparent = true
        // The content scrolls under the transparent title bar; hiding the title text
        // stops "MoreDock Settings" from overlapping the top of the content.
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 800, height: 600)
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore
    var onCheckForUpdates: (() -> Void)?

    /// Snapshots the live native Dock values into the editable settings and turns
    /// off "Follow native Dock", so editing one control does not snap the others
    /// back to stale stored defaults.
    private func detachFromNative() {
        guard settings.followSystemDock else { return }
        settings.adoptNativeDockValues()
        settings.followSystemDock = false
    }

    /// While following the native Dock, the getter reflects the real native value so
    /// the control matches reality; editing snapshots native and detaches.
    private func mirrored<Value>(
        _ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>,
        native: @autoclosure @escaping () -> Value
    ) -> Binding<Value> {
        Binding {
            settings.followSystemDock ? native() : settings[keyPath: keyPath]
        } set: { newValue in
            detachFromNative()
            settings[keyPath: keyPath] = newValue
        }
    }

    /// A binding that applies a value and detaches from "Follow native Dock" so the
    /// edit takes effect (used for controls with no native equivalent).
    private func detach<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding {
            settings[keyPath: keyPath]
        } set: { newValue in
            detachFromNative()
            settings[keyPath: keyPath] = newValue
        }
    }

    var body: some View {
        ZStack {
            SettingsVisualEffect()
                .ignoresSafeArea()

            LiquidGlassBackdrop()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    HStack(alignment: .top, spacing: 14) {
                        VStack(spacing: 14) {
                            SettingsSection("General") {
                                VStack(spacing: 11) {
                                    SettingsToggleRow("Enable MoreDock", isOn: $settings.isEnabled)
                                    SettingsToggleRow("Show on all displays", isOn: $settings.showOnAllDisplays)
                                    SettingsToggleRow("Follow native Dock", isOn: $settings.followSystemDock)
                                    SettingsToggleRow("Hide on Dock display", isOn: $settings.hideOnNativeDockScreen)
                                    SettingsToggleRow("Respect menu bar", isOn: $settings.respectMenuBarSafeArea)
                                    SettingsToggleRow("Avoid display junctions", isOn: $settings.avoidDisplayJunctions)
                                    SettingsPickerRow("Open apps on") {
                                        Picker("Open apps on", selection: $settings.activationDisplayMode) {
                                            ForEach(ActivationDisplayMode.allCases) { mode in
                                                Text(mode.title).tag(mode)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 190)
                                    }
                                }
                            }

                            DisplayArrangementSection(settings: settings)

                            DisplaySettingsSection(settings: settings)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        VStack(spacing: 14) {
                            SettingsSection("Appearance") {
                                VStack(alignment: .leading, spacing: 11) {
                                    Text("The defaults for every dock. A display set to \u{201C}Customize\u{201D} in Per-Display Docks uses its own values instead of these.")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if settings.followSystemDock {
                                        Text("Showing your macOS Dock values. Editing anything here switches to your own settings for every MoreDock.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }

                                    SettingsPickerRow("Edge") {
                                        Picker("Edge", selection: mirrored(\.edge, native: SystemDockPreferences.nativeEdge)) {
                                            ForEach(DockEdge.allCases) { edge in
                                                Text(edge.title).tag(edge)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 190)
                                    }

                                    SettingsSliderRow(title: "Icon size", value: mirrored(\.iconSize, native: SystemDockPreferences.nativeIconSize), range: 32...72, step: 2, suffix: "")
                                    SettingsSliderRow(title: "Opacity", value: $settings.opacity, range: 0.45...1.0, step: 0.01, suffix: "%")
                                    SettingsToggleRow("Magnification", isOn: mirrored(\.magnification, native: SystemDockPreferences.nativeMagnification))
                                    SettingsToggleRow("Auto-hide", isOn: $settings.autoHide)
                                    if settings.autoHide {
                                        SettingsSliderRow(title: "Reveal delay", value: $settings.autoHideDelay, range: 0.0...1.0, step: 0.05, suffix: "s")
                                    }
                                    SettingsToggleRow("Running indicators", isOn: mirrored(\.showRunningIndicators, native: SystemDockPreferences.nativeShowRunningIndicators))
                                    SettingsToggleRow("Glass material", isOn: $settings.liquidGlass)
                                }
                            }

                            NativeDockSettingsSection()

                            SettingsSection("Diagnostics") {
                                VStack(spacing: 11) {
                                    SettingsUpdateRow(onCheckForUpdates: onCheckForUpdates)
                                    SettingsAccessibilityRow()
                                    SettingsLogsRow()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .top)
                    }

                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 18)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
    }

    private var header: some View {
        HStack(spacing: 13) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 26, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text("MoreDock")
                    .font(.title.weight(.semibold))
                Text("A lightweight Dock for every display.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("Settings")
                .font(.callout.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

private struct DisplayArrangementSection: View {
    @ObservedObject var settings: SettingsStore
    @State private var animate = false

    var body: some View {
        SettingsSection("Display Layout") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Live map of every display. The glowing edge shows where each MoreDock sits \u{2014} change a display\u{2019}s Location below to move it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GeometryReader { geo in
                    arrangement(in: geo.size)
                }
                .frame(height: 150)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }

    private func arrangement(in size: CGSize) -> some View {
        let screens = NSScreen.screens
        let frames = screens.map(\.frame)
        let union = frames.dropFirst().reduce(frames.first ?? .zero) { $0.union($1) }
        let inset: CGFloat = 12
        let availableWidth = max(size.width - inset * 2, 1)
        let availableHeight = max(size.height - inset * 2, 1)
        let scale = min(availableWidth / max(union.width, 1), availableHeight / max(union.height, 1))
        let offsetX = inset + (availableWidth - union.width * scale) / 2
        let offsetY = inset + (availableHeight - union.height * scale) / 2
        let primaryID = CGMainDisplayID()
        let globalEdge = DockPlacement.globalEdge(for: settings)

        // Number externals the same way the Per-Display list does.
        var externalIndex = 0
        let rows: [ArrangementRow] = screens.compactMap { screen in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let isPrimary = number.uint32Value == primaryID
            let label: String
            if isPrimary {
                label = "Main"
            } else {
                externalIndex += 1
                label = "Ext \(externalIndex)"
            }
            let displaySettings = settings.settingsForDisplay(number.stringValue)
            let edge = DockPlacement.resolvedEdge(
                globalEdge: globalEdge,
                globalAvoidJunctions: settings.avoidDisplayJunctions,
                displaySettings: displaySettings,
                screen: screen,
                allScreens: screens
            )
            return ArrangementRow(
                id: number.stringValue,
                frame: screen.frame,
                label: label,
                edge: edge,
                enabled: displaySettings.isEnabled
            )
        }

        return ZStack(alignment: .topLeading) {
            ForEach(rows) { row in
                DisplayTile(
                    width: max(row.frame.width * scale, 10),
                    height: max(row.frame.height * scale, 10),
                    label: row.label,
                    edge: row.edge,
                    enabled: row.enabled,
                    animate: animate
                )
                .offset(
                    x: offsetX + (row.frame.minX - union.minX) * scale,
                    y: offsetY + (union.maxY - row.frame.maxY) * scale
                )
            }
        }
    }

    private struct ArrangementRow: Identifiable {
        let id: String
        let frame: NSRect
        let label: String
        let edge: DockEdge
        let enabled: Bool
    }
}

private struct DisplayTile: View {
    let width: CGFloat
    let height: CGFloat
    let label: String
    let edge: DockEdge
    let enabled: Bool
    let animate: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(.white.opacity(enabled ? 0.32 : 0.14), lineWidth: 1)

            if enabled {
                dockBar
            }

            Text(label)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .padding(2)
        }
        .frame(width: width, height: height)
        .opacity(enabled ? 1 : 0.55)
    }

    private var dockBar: some View {
        let thickness = max(3, min(width, height) * 0.16)
        let barLength = (edge == .bottom ? width : height) * 0.66
        return RoundedRectangle(cornerRadius: thickness / 2, style: .continuous)
            .fill(Color.accentColor.opacity(animate ? 0.95 : 0.5))
            .frame(
                width: edge == .bottom ? barLength : thickness,
                height: edge == .bottom ? thickness : barLength
            )
            .frame(width: width, height: height, alignment: alignment)
    }

    private var alignment: Alignment {
        switch edge {
        case .bottom: .bottom
        case .left: .leading
        case .right: .trailing
        }
    }
}

private struct DisplaySettingsSection: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        SettingsSection("Per-Display Docks") {
            VStack(spacing: 12) {
                let rows = displayRows
                if rows.isEmpty {
                    Text("No displays detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Turn on \u{201C}Customize\u{201D} to give a display its own location, size, and opacity. Otherwise it follows the global Appearance settings.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(rows) { display in
                    displayRow(display)

                    if display.id != rows.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func displayRow(_ display: DisplayRow) -> some View {
        let displaySettings = settings.settingsForDisplay(display.id)
        let customizing = !(displaySettings.followsGlobalPlacement && displaySettings.followsGlobalAppearance)

        VStack(spacing: 9) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(display.name)
                        .font(.callout.weight(.medium))
                    Text(display.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !display.isNativeDockScreen {
                    Toggle("Show", isOn: binding(display.id, \.isEnabled))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                }
            }

            if display.isNativeDockScreen {
                Text("Shows the macOS Dock, so MoreDock stays hidden here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                SettingsToggleRow("Customize", isOn: customizeBinding(display))

                if customizing {
                    SettingsPickerRow("Location") {
                        Picker("Location", selection: binding(display.id, \.edge)) {
                            ForEach(display.usableEdges) { edge in
                                Text(edge.title).tag(edge)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(width: 190)
                    }

                    SettingsSliderRow(title: "Icon size", value: binding(display.id, \.iconSize), range: 18...96, step: 1, suffix: "")
                    SettingsSliderRow(title: "Opacity", value: binding(display.id, \.opacity), range: 0.45...1.0, step: 0.01, suffix: "%")
                    SettingsToggleRow("Auto-hide", isOn: binding(display.id, \.autoHide))
                    if displaySettings.autoHide {
                        SettingsSliderRow(title: "Reveal delay", value: binding(display.id, \.autoHideDelay), range: 0.0...1.0, step: 0.05, suffix: "s")
                    }
                    SettingsToggleRow("Magnification", isOn: binding(display.id, \.magnification))
                    SettingsToggleRow("Running indicators", isOn: binding(display.id, \.showRunningIndicators))
                    SettingsToggleRow("Avoid junctions", isOn: binding(display.id, \.avoidDisplayJunctions))
                } else {
                    Text("Following global settings \u{2022} Location: \(display.effectiveEdge.title)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                appsRow(display)
            }
        }
    }

    @ViewBuilder
    private func appsRow(_ display: DisplayRow) -> some View {
        let hasCustom = settings.hasCustomPins(display.id)
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 8) {
                Text("Apps")
                    .font(.callout.weight(.medium))
                Text(hasCustom ? "Custom list" : "Mirrors macOS Dock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if hasCustom {
                    Button("Reset") { settings.resetPins(for: display.id) }
                        .controlSize(.small)
                }
                Button("Add App\u{2026}") { addApp(to: display.id) }
                    .controlSize(.small)
            }
            .frame(minHeight: 30)

            Text("Drag an app onto this dock, or right-click a dock icon, to pin or remove it.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func addApp(to displayID: String) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let url = panel.url else { return }
        let name = url.deletingPathExtension().lastPathComponent
        guard let allDocks = promptAddScope(appName: name) else { return }
        let targets: [String]
        if allDocks {
            let all = NSScreen.screens.compactMap { ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.stringValue }
            targets = all.isEmpty ? [displayID] : all
        } else {
            targets = [displayID]
        }
        settings.pin(PinnedApp.from(url: url), toDisplays: targets, seededWith: nativePins())
    }

    private func nativePins() -> [PinnedApp] {
        SystemDockPreferences.persistentApps()
            .filter { $0.bundleIdentifier != "com.apple.finder" }
            .map { PinnedApp(id: $0.id, name: $0.name, bundleIdentifier: $0.bundleIdentifier, path: $0.url?.path) }
    }

    private var displayRows: [DisplayRow] {
        let primaryID = CGMainDisplayID()
        let allScreens = NSScreen.screens
        let globalEdge = DockPlacement.globalEdge(for: settings)
        let nativeDockScreens: Set<NSNumber> = settings.hideOnNativeDockScreen
            ? SystemDockPreferences.nativeDockScreenNumbers(for: allScreens, edge: SystemDockPreferences.nativeEdge)
            : []
        var externalIndex = 0
        return allScreens.compactMap { screen -> DisplayRow? in
            guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
                return nil
            }
            let isPrimary = number.uint32Value == primaryID
            let name: String
            if isPrimary {
                name = "Main Display"
            } else {
                externalIndex += 1
                name = "External Display \(externalIndex)"
            }

            let scale = screen.backingScaleFactor
            let pixels = "\(Int(screen.frame.width * scale))\u{00D7}\(Int(screen.frame.height * scale))"
            let localizedName = screen.localizedName
            let detail = localizedName.isEmpty ? "\(pixels) \u{2022} ID \(number.stringValue)" : "\(localizedName) \u{2022} \(pixels)"
            let displaySettings = settings.settingsForDisplay(number.stringValue)
            let effectiveEdge = DockPlacement.resolvedEdge(
                globalEdge: globalEdge,
                globalAvoidJunctions: settings.avoidDisplayJunctions,
                displaySettings: displaySettings,
                screen: screen,
                allScreens: allScreens
            )
            // Only offer edges the dock will actually stay on. With junction
            // avoidance on, a shared edge gets moved, so hide it as a choice. A
            // customized display uses its own toggle; a follower uses the global one.
            let avoidJunctions = displaySettings.followsGlobalPlacement
                ? settings.avoidDisplayJunctions
                : displaySettings.avoidDisplayJunctions
            let usable = DockEdge.allCases.filter { edge in
                !(avoidJunctions && DockPlacement.isEdgeShared(edge, of: screen, with: allScreens))
            }
            return DisplayRow(
                id: number.stringValue,
                name: name,
                detail: detail,
                effectiveEdge: effectiveEdge,
                usableEdges: usable.isEmpty ? DockEdge.allCases : usable,
                isNativeDockScreen: nativeDockScreens.contains(number)
            )
        }
    }

    private func binding<Value>(_ displayID: String, _ keyPath: WritableKeyPath<DisplayDockSettings, Value>) -> Binding<Value> {
        Binding {
            settings.settingsForDisplay(displayID)[keyPath: keyPath]
        } set: { value in
            settings.updateSettingsForDisplay(displayID) { displaySettings in
                displaySettings[keyPath: keyPath] = value
            }
        }
    }

    /// One toggle detaches a display from every global setting (placement +
    /// appearance) and seeds its location from where the dock currently is, so the
    /// controls start matching reality instead of a stale default.
    private func customizeBinding(_ display: DisplayRow) -> Binding<Bool> {
        Binding {
            let displaySettings = settings.settingsForDisplay(display.id)
            return !(displaySettings.followsGlobalPlacement && displaySettings.followsGlobalAppearance)
        } set: { customizing in
            settings.updateSettingsForDisplay(display.id) { displaySettings in
                if customizing {
                    displaySettings.followsGlobalPlacement = false
                    displaySettings.followsGlobalAppearance = false
                    displaySettings.edge = display.effectiveEdge
                } else {
                    displaySettings.followsGlobalPlacement = true
                    displaySettings.followsGlobalAppearance = true
                }
            }
        }
    }

    private struct DisplayRow: Identifiable {
        let id: String
        let name: String
        let detail: String
        let effectiveEdge: DockEdge
        let usableEdges: [DockEdge]
        let isNativeDockScreen: Bool
    }
}

private struct NativeDockSettingsSection: View {
    @State private var edge = SystemDockPreferences.nativeEdge
    @State private var iconSize = SystemDockPreferences.nativeIconSize
    @State private var magnifiedIconSize = SystemDockPreferences.nativeMagnifiedIconSize
    @State private var magnification = SystemDockPreferences.nativeMagnification
    @State private var autoHide = SystemDockPreferences.nativeAutoHide
    @State private var expanded = false

    var body: some View {
        SettingsSection("macOS Dock") {
            DisclosureGroup(isExpanded: $expanded) {
                content
                    .padding(.top, 6)
            } label: {
                Text("Edit the real macOS Dock\u{2026}")
                    .font(.callout.weight(.medium))
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("Changes the real macOS Dock in System Settings (restarts the Dock). This is not MoreDock\u{2019}s own appearance.")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            SettingsPickerRow("Location") {
                    Picker("Location", selection: $edge) {
                        ForEach(DockEdge.allCases) { edge in
                            Text(edge.title).tag(edge)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                    .frame(width: 190)
                }

                SettingsSliderRow(title: "Size", value: $iconSize, range: 24...96, step: 1, suffix: "")
                SettingsSliderRow(title: "Zoom", value: $magnifiedIconSize, range: iconSize...128, step: 1, suffix: "")
                SettingsToggleRow("Magnification", isOn: $magnification)
                SettingsToggleRow("Automatically hide", isOn: $autoHide)

                HStack {
                    Button("Refresh") {
                        refresh()
                    }
                    .controlSize(.small)

                    Spacer()

                    Button("Apply to macOS Dock") {
                        SystemDockPreferences.applyNativeDockSettings(
                            edge: edge,
                            iconSize: iconSize,
                            magnifiedIconSize: magnifiedIconSize,
                            magnification: magnification,
                            autoHide: autoHide
                        )
                    }
                    .controlSize(.small)
                    .buttonStyle(.borderedProminent)
                }
            }
        }

    private func refresh() {
        edge = SystemDockPreferences.nativeEdge
        iconSize = SystemDockPreferences.nativeIconSize
        magnifiedIconSize = SystemDockPreferences.nativeMagnifiedIconSize
        magnification = SystemDockPreferences.nativeMagnification
        autoHide = SystemDockPreferences.nativeAutoHide
    }
}

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.leading, 2)

            content
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                }
        }
    }
}

private struct SettingsToggleRow: View {
    let title: String
    @Binding var isOn: Bool

    init(_ title: String, isOn: Binding<Bool>) {
        self.title = title
        _isOn = isOn
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }
        .frame(minHeight: 30)
    }
}

private struct SettingsPickerRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            content
                .controlSize(.small)
        }
        .frame(minHeight: 30)
    }
}

private struct SettingsSliderRow: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let suffix: String

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.callout.weight(.medium))
                .frame(width: 72, alignment: .leading)
            Spacer()
            Slider(value: $value, in: range, step: step)
                .frame(width: 150)
                .controlSize(.small)
            Text(label)
                .font(.callout.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 42, alignment: .trailing)
        }
        .frame(minHeight: 30)
    }

    private var label: String {
        switch suffix {
        case "%":
            return "\(Int(value * 100))%"
        case "s":
            return value == 0 ? "0s" : String(format: "%.2fs", value)
        default:
            return "\(Int(value))"
        }
    }
}

private struct SettingsUpdateRow: View {
    var onCheckForUpdates: (() -> Void)?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Updates")
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button("Check Now") {
                onCheckForUpdates?()
            }
            .controlSize(.small)
            .disabled(onCheckForUpdates == nil)
        }
        .frame(minHeight: 30)
    }
}

private struct SettingsAccessibilityRow: View {
    @State private var isTrusted = AccessibilityWindowMover.isTrusted(prompt: false)
    private let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Accessibility")
                    .font(.callout.weight(.medium))
                    .lineLimit(1)
                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(isTrusted ? Color.green : (Diagnostics.isTranslocated ? Color.orange : Color.secondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            if isTrusted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                HStack(spacing: 6) {
                    Button("Grant\u{2026}") {
                        if !AccessibilityWindowMover.isTrusted(prompt: true) {
                            AccessibilityWindowMover.openAccessibilitySettings()
                        }
                    }
                    .controlSize(.small)
                    Button("Reset") {
                        Diagnostics.resetAccessibilityPermission()
                        AccessibilityWindowMover.openAccessibilitySettings()
                    }
                    .controlSize(.small)
                    .help("Clears a stale Accessibility entry for MoreDock, then reopens Settings so you can grant it fresh. Use this if granting never sticks.")
                    Button("Relaunch") {
                        Diagnostics.relaunch()
                    }
                    .controlSize(.small)
                    .help("Quit and reopen MoreDock so it picks up a grant you just enabled.")
                }
            }
        }
        .frame(minHeight: 30)
        .onReceive(pollTimer) { _ in
            isTrusted = AccessibilityWindowMover.isTrusted(prompt: false)
        }
    }

    private var statusText: String {
        if isTrusted {
            return "Granted \u{2014} Clicked Display is ready."
        }
        if Diagnostics.isTranslocated {
            return "MoreDock is running from a temporary copy, so permission will not stick. Move it to /Applications, then grant access."
        }
        if Diagnostics.isDevBuild {
            return "This is a local dev build. After granting, quit and reopen MoreDock. Each rebuild changes the signature and needs a re-grant \u{2014} the signed release keeps it permanently."
        }
        return "Needed for Clicked Display. Enable MoreDock in the list, then click Relaunch \u{2014} macOS only applies the grant to a freshly started copy. If it never turns on no matter how often you grant it, click Reset to clear a stale entry, then grant and Relaunch."
    }
}

private struct SettingsLogsRow: View {
    @State private var controller: LogWindowController?

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Logs")
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button("Open") {
                if controller == nil {
                    controller = LogWindowController()
                }
                NSApp.activate(ignoringOtherApps: true)
                controller?.showWindow(nil)
            }
            .controlSize(.small)
        }
        .frame(minHeight: 30)
    }
}

private struct SettingsVisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .underWindowBackground
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// A soft, translucent colour wash layered over the window's vibrancy material to
/// give the Settings window a liquid-glass depth in both light and dark modes.
private struct LiquidGlassBackdrop: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.white.opacity(0.10),
                    Color.clear,
                    Color.accentColor.opacity(0.07)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Color.white.opacity(0.16), Color.clear],
                center: .topTrailing,
                startRadius: 0,
                endRadius: 460
            )

            RadialGradient(
                colors: [Color.accentColor.opacity(0.12), Color.clear],
                center: .bottomLeading,
                startRadius: 0,
                endRadius: 520
            )
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
    }
}
