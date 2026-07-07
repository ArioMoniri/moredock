import AppKit
import SwiftUI

@MainActor
final class DockPanelController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<DockPanelView>
    private let screenNumber: DisplayID

    init(screenNumber: DisplayID) {
        self.screenNumber = screenNumber
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = false

        hostingView = NSHostingView(rootView: DockPanelView(apps: [], settings: SnapshotSettings()))
        hostingView.wantsLayer = true
        panel.contentView = hostingView
    }

    func update(screen: NSScreen, apps: [DockAppItem], settings: SettingsStore) {
        let snapshot = SnapshotSettings(settings)
        hostingView.rootView = DockPanelView(apps: apps, settings: snapshot)
        panel.alphaValue = settings.autoHide ? 0.72 : 1.0
        panel.setFrame(frame(for: screen, apps: apps, settings: snapshot), display: true)

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func close() {
        panel.orderOut(nil)
    }

    private func frame(for screen: NSScreen, apps: [DockAppItem], settings: SnapshotSettings) -> NSRect {
        let visible = settings.respectMenuBarSafeArea ? screen.visibleFrame : screen.frame
        let itemCount = max(apps.count, 1)
        let gap: CGFloat = 8
        let padding: CGFloat = 12
        let icon = CGFloat(settings.iconSize)
        let thickness = icon + padding * 2
        let length = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.width - 48))
        let inset: CGFloat = 10

        switch settings.edge {
        case .bottom:
            return NSRect(
                x: visible.midX - length / 2,
                y: visible.minY + inset,
                width: length,
                height: thickness
            )
        case .left:
            let height = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.height - 48))
            return NSRect(
                x: visible.minX + inset,
                y: visible.midY - height / 2,
                width: thickness,
                height: height
            )
        case .right:
            let height = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.height - 48))
            return NSRect(
                x: visible.maxX - thickness - inset,
                y: visible.midY - height / 2,
                width: thickness,
                height: height
            )
        }
    }
}

struct SnapshotSettings: Equatable {
    var edge: DockEdge = .bottom
    var iconSize: Double = 48
    var magnification = true
    var opacity = 0.82
    var liquidGlass = true
    var autoHide = false
    var respectMenuBarSafeArea = true

    init() {}

    @MainActor
    init(_ settings: SettingsStore) {
        edge = settings.edge
        iconSize = settings.iconSize
        magnification = settings.magnification
        opacity = settings.opacity
        liquidGlass = settings.liquidGlass
        autoHide = settings.autoHide
        respectMenuBarSafeArea = settings.respectMenuBarSafeArea
    }
}

struct DockPanelView: View {
    let apps: [DockAppItem]
    let settings: SnapshotSettings

    var body: some View {
        DockVisualEffect(liquidGlass: settings.liquidGlass)
            .overlay {
                ScrollView(settings.edge == .bottom ? .horizontal : .vertical, showsIndicators: false) {
                    stack {
                        ForEach(apps) { item in
                            DockIconButton(item: item, settings: settings)
                        }
                    }
                    .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(.white.opacity(settings.liquidGlass ? 0.28 : 0.14), lineWidth: 1)
            }
            .opacity(settings.opacity)
    }

    @ViewBuilder
    private func stack<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        if settings.edge == .bottom {
            HStack(spacing: 8, content: content)
        } else {
            VStack(spacing: 8, content: content)
        }
    }
}

private struct DockIconButton: View {
    let item: DockAppItem
    let settings: SnapshotSettings
    @State private var isHovering = false

    var body: some View {
        Button {
            activate()
        } label: {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .padding(2)
                .scaleEffect(isHovering && settings.magnification ? 1.18 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovering)
        }
        .buttonStyle(.plain)
        .help(item.name)
        .onHover { isHovering = $0 }
        .accessibilityLabel(item.name)
    }

    private var iconSize: CGFloat {
        CGFloat(settings.iconSize)
    }

    private func activate() {
        if let app = NSRunningApplication(processIdentifier: item.processIdentifier) {
            app.activate(options: [.activateIgnoringOtherApps])
        }
    }
}

private struct DockVisualEffect: NSViewRepresentable {
    let liquidGlass: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = liquidGlass ? .hudWindow : .underWindowBackground
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = liquidGlass ? .hudWindow : .underWindowBackground
    }
}
