import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSWindowController {
    init(settings: SettingsStore) {
        let content = SettingsView(settings: settings)
        let hosting = NSHostingView(rootView: content)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.center()
        window.title = "MoreDock Settings"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        nil
    }
}

struct SettingsView: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ZStack {
            SettingsVisualEffect()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                header

                GroupBox {
                    VStack(spacing: 14) {
                        Toggle("Enable MoreDock", isOn: $settings.isEnabled)
                        Toggle("Show on all screens", isOn: $settings.showOnAllDisplays)
                        Toggle("Auto-dim when idle", isOn: $settings.autoHide)
                        Toggle("Respect menu bar safe area", isOn: $settings.respectMenuBarSafeArea)
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("Edge", selection: $settings.edge) {
                            ForEach(DockEdge.allCases) { edge in
                                Text(edge.title).tag(edge)
                            }
                        }
                        .pickerStyle(.segmented)

                        LabeledContent("Icon size") {
                            HStack {
                                Slider(value: $settings.iconSize, in: 32...72, step: 2)
                                Text("\(Int(settings.iconSize))")
                                    .monospacedDigit()
                                    .frame(width: 34, alignment: .trailing)
                            }
                        }

                        LabeledContent("Opacity") {
                            HStack {
                                Slider(value: $settings.opacity, in: 0.45...1.0, step: 0.01)
                                Text("\(Int(settings.opacity * 100))%")
                                    .monospacedDigit()
                                    .frame(width: 44, alignment: .trailing)
                            }
                        }
                    }
                }

                GroupBox {
                    VStack(spacing: 14) {
                        Toggle("Liquid glass material", isOn: $settings.liquidGlass)
                        Toggle("Icon magnification", isOn: $settings.magnification)
                    }
                    .toggleStyle(.switch)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer()
            }
            .padding(28)
        }
        .frame(minWidth: 500, minHeight: 500)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "dock.rectangle")
                .font(.system(size: 34, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 3) {
                Text("MoreDock")
                    .font(.largeTitle.weight(.semibold))
                Text("A lightweight dock for every display.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct SettingsVisualEffect: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.material = .sidebar
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
