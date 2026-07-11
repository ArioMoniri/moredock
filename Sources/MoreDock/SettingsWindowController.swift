import AppKit
import SwiftUI

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

    /// A binding that applies a value immediately and detaches from "Follow native
    /// Dock" so the edit actually takes effect instead of being overridden by the
    /// system Dock. Keeps every appearance control live and editable.
    private func detach<Value>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, Value>) -> Binding<Value> {
        Binding {
            settings[keyPath: keyPath]
        } set: { newValue in
            if settings.followSystemDock {
                settings.followSystemDock = false
            }
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
                            SettingsSection("Dock") {
                                VStack(spacing: 11) {
                                    SettingsToggleRow("Enable MoreDock", isOn: $settings.isEnabled)
                                    SettingsToggleRow("Show on all displays", isOn: $settings.showOnAllDisplays)
                                    SettingsToggleRow("Follow native Dock", isOn: $settings.followSystemDock)
                                    SettingsToggleRow("Hide on Dock display", isOn: $settings.hideOnNativeDockScreen)
                                        .disabled(!settings.followSystemDock)
                                    SettingsToggleRow("Respect menu bar", isOn: $settings.respectMenuBarSafeArea)
                                    SettingsToggleRow("Avoid display junctions", isOn: $settings.avoidDisplayJunctions)
                                }
                            }

                            SettingsSection("Behavior") {
                                VStack(spacing: 11) {
                                    SettingsPickerRow("Open on") {
                                        Picker("Open apps on", selection: $settings.activationDisplayMode) {
                                            ForEach(ActivationDisplayMode.allCases) { mode in
                                                Text(mode.title).tag(mode)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 190)
                                    }

                                    SettingsUpdateRow(onCheckForUpdates: onCheckForUpdates)
                                    SettingsAccessibilityRow()
                                }
                            }

                            DisplayArrangementSection(settings: settings)

                            DisplaySettingsSection(settings: settings)
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        VStack(spacing: 14) {
                            SettingsSection("Appearance") {
                                VStack(alignment: .leading, spacing: 11) {
                                    SettingsPickerRow("Edge") {
                                        Picker("Edge", selection: detach(\.edge)) {
                                            ForEach(DockEdge.allCases) { edge in
                                                Text(edge.title).tag(edge)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 190)
                                    }

                                    SettingsSliderRow(title: "Icon size", value: detach(\.iconSize), range: 32...72, step: 2, suffix: "")

                                    SettingsSliderRow(title: "Opacity", value: $settings.opacity, range: 0.45...1.0, step: 0.01, suffix: "%")

                                    if settings.followSystemDock {
                                        Text("Editing any control below turns off \u{201C}Follow native Dock\u{201D} so your change sticks.")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }

                            NativeDockSettingsSection()

                            SettingsSection("Liquid Glass") {
                                VStack(spacing: 11) {
                                    SettingsToggleRow("Glass material", isOn: $settings.liquidGlass)
                                    SettingsToggleRow("Magnification", isOn: detach(\.magnification))
                                    SettingsToggleRow("Auto-hide", isOn: detach(\.autoHide))
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

        return ZStack(alignment: .topLeading) {
            ForEach(Array(screens.enumerated()), id: \.offset) { index, screen in
                let frame = screen.frame
                let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
                let displayID = number?.stringValue ?? "\(index)"
                let displaySettings = settings.settingsForDisplay(displayID)
                let isPrimary = number?.uint32Value == primaryID
                let edge = displaySettings.followsGlobalPlacement ? settings.edge : displaySettings.edge
                let tileWidth = max(frame.width * scale, 10)
                let tileHeight = max(frame.height * scale, 10)

                DisplayTile(
                    width: tileWidth,
                    height: tileHeight,
                    label: isPrimary ? "Main" : "Ext \(index)",
                    edge: edge,
                    enabled: displaySettings.isEnabled,
                    animate: animate
                )
                .offset(
                    x: offsetX + (frame.minX - union.minX) * scale,
                    y: offsetY + (union.maxY - frame.maxY) * scale
                )
            }
        }
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
                if displayRows.isEmpty {
                    Text("No displays detected.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text("Each connected display has its own dock settings below. Turn off \u{201C}Use global placement\u{201D} or \u{201C}Use global appearance\u{201D} to give a display its own location, size, and opacity.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ForEach(displayRows) { display in
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
                            Toggle("Show", isOn: binding(display.id, \.isEnabled))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
                        }

                        SettingsToggleRow("Use global placement", isOn: binding(display.id, \.followsGlobalPlacement))

                        SettingsPickerRow("Location") {
                            Picker("Edge", selection: placementBinding(display.id, \.edge)) {
                                ForEach(DockEdge.allCases) { edge in
                                    Text(edge.title).tag(edge)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.segmented)
                            .frame(width: 190)
                        }

                        SettingsToggleRow("Use global appearance", isOn: binding(display.id, \.followsGlobalAppearance))

                        SettingsSliderRow(title: "Icon size", value: appearanceBinding(display.id, \.iconSize), range: 18...96, step: 1, suffix: "")

                        SettingsSliderRow(title: "Opacity", value: appearanceBinding(display.id, \.opacity), range: 0.45...1.0, step: 0.01, suffix: "%")

                        SettingsToggleRow("Auto-hide", isOn: appearanceBinding(display.id, \.autoHide))

                        SettingsToggleRow("Magnification", isOn: appearanceBinding(display.id, \.magnification))

                        SettingsToggleRow("Avoid junctions", isOn: binding(display.id, \.avoidDisplayJunctions))
                    }

                    if display.id != displayRows.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private var displayRows: [DisplayRow] {
        let primaryID = CGMainDisplayID()
        var externalIndex = 0
        return NSScreen.screens.compactMap { screen -> DisplayRow? in
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
            return DisplayRow(
                id: number.stringValue,
                name: name,
                detail: detail
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

    /// Editing a per-display placement control detaches that display from global
    /// placement so the change is applied to just that screen.
    private func placementBinding<Value>(_ displayID: String, _ keyPath: WritableKeyPath<DisplayDockSettings, Value>) -> Binding<Value> {
        Binding {
            settings.settingsForDisplay(displayID)[keyPath: keyPath]
        } set: { value in
            settings.updateSettingsForDisplay(displayID) { displaySettings in
                displaySettings.followsGlobalPlacement = false
                displaySettings[keyPath: keyPath] = value
            }
        }
    }

    /// Editing a per-display appearance control detaches that display from global
    /// appearance so the change is applied to just that screen.
    private func appearanceBinding<Value>(_ displayID: String, _ keyPath: WritableKeyPath<DisplayDockSettings, Value>) -> Binding<Value> {
        Binding {
            settings.settingsForDisplay(displayID)[keyPath: keyPath]
        } set: { value in
            settings.updateSettingsForDisplay(displayID) { displaySettings in
                displaySettings.followsGlobalAppearance = false
                displaySettings[keyPath: keyPath] = value
            }
        }
    }

    private struct DisplayRow: Identifiable {
        let id: String
        let name: String
        let detail: String
    }
}

private struct NativeDockSettingsSection: View {
    @State private var edge = SystemDockPreferences.nativeEdge
    @State private var iconSize = SystemDockPreferences.nativeIconSize
    @State private var magnifiedIconSize = SystemDockPreferences.nativeMagnifiedIconSize
    @State private var magnification = SystemDockPreferences.nativeMagnification
    @State private var autoHide = SystemDockPreferences.nativeAutoHide

    var body: some View {
        SettingsSection("macOS Dock") {
            VStack(alignment: .leading, spacing: 11) {
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
        if suffix == "%" {
            "\(Int(value * 100))%"
        } else {
            "\(Int(value))"
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
                Text(isTrusted ? "Granted \u{2014} Clicked Display is ready." : "Needed for Clicked Display.")
                    .font(.caption)
                    .foregroundStyle(isTrusted ? Color.green : Color.secondary)
            }
            Spacer()
            if isTrusted {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Grant\u{2026}") {
                    if !AccessibilityWindowMover.isTrusted(prompt: true) {
                        AccessibilityWindowMover.openAccessibilitySettings()
                    }
                }
                .controlSize(.small)
            }
        }
        .frame(minHeight: 30)
        .onReceive(pollTimer) { _ in
            isTrusted = AccessibilityWindowMover.isTrusted(prompt: false)
        }
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
