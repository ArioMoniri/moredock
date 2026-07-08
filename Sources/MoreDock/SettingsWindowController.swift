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

    var body: some View {
        ZStack {
            SettingsVisualEffect()
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
                        }
                        .frame(maxWidth: .infinity, alignment: .top)

                        VStack(spacing: 14) {
                            SettingsSection("Appearance") {
                                VStack(alignment: .leading, spacing: 11) {
                                    SettingsPickerRow("Edge") {
                                        Picker("Edge", selection: $settings.edge) {
                                            ForEach(DockEdge.allCases) { edge in
                                                Text(edge.title).tag(edge)
                                            }
                                        }
                                        .labelsHidden()
                                        .pickerStyle(.segmented)
                                        .frame(width: 190)
                                    }
                                    .disabled(settings.followSystemDock)

                                    SettingsSliderRow(title: "Icon size", value: $settings.iconSize, range: 32...72, step: 2, suffix: "")
                                        .disabled(settings.followSystemDock)

                                    SettingsSliderRow(title: "Opacity", value: $settings.opacity, range: 0.45...1.0, step: 0.01, suffix: "%")
                                }
                            }

                            NativeDockSettingsSection()

                            SettingsSection("Liquid Glass") {
                                VStack(spacing: 11) {
                                    SettingsToggleRow("Glass material", isOn: $settings.liquidGlass)
                                    SettingsToggleRow("Magnification", isOn: $settings.magnification)
                                        .disabled(settings.followSystemDock)
                                    SettingsToggleRow("Auto-hide", isOn: $settings.autoHide)
                                        .disabled(settings.followSystemDock)
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .strokeBorder(.white.opacity(0.20), lineWidth: 1)
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
    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text("Accessibility")
                .font(.callout.weight(.medium))
                .lineLimit(1)
            Spacer()
            Button("Grant") {
                _ = AccessibilityWindowMover.isTrusted(prompt: true)
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
        view.material = .hudWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
