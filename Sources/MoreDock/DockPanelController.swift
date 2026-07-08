import AppKit
import SwiftUI

@MainActor
final class DockPanelController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<DockPanelView>
    private let screenNumber: DisplayID
    private var isRevealed = true
    private var revealRequestedAt: Date?

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
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        hostingView = NSHostingView(rootView: DockPanelView(apps: [], settings: SnapshotSettings(), targetVisibleFrame: .zero))
        hostingView.wantsLayer = true
        panel.contentView = hostingView
    }

    func update(screen: NSScreen, apps: [DockAppItem], settings: DockRuntimeSettings, now: Date) {
        let snapshot = SnapshotSettings(settings)
        hostingView.rootView = DockPanelView(apps: apps, settings: snapshot, targetVisibleFrame: screen.visibleFrame)

        updateRevealState(screen: screen, settings: snapshot, now: now)

        let targetFrame = frame(for: screen, apps: apps, settings: snapshot, revealed: isRevealed)
        let animationDuration = settings.autoHide ? settings.autoHideDuration : 0.16
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(targetFrame, display: true)
            panel.animator().alphaValue = isRevealed ? 1.0 : 0.08
        }

        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    func close() {
        panel.orderOut(nil)
    }

    private func frame(
        for screen: NSScreen,
        apps: [DockAppItem],
        settings: SnapshotSettings,
        revealed: Bool
    ) -> NSRect {
        let visible = settings.respectMenuBarSafeArea && !settings.followsSystemDock ? screen.visibleFrame : screen.frame
        let itemCount = max(apps.count, 1)
        let gap: CGFloat = max(7, CGFloat(settings.iconSize) * 0.14)
        let padding: CGFloat = max(9, CGFloat(settings.iconSize) * 0.24)
        let icon = CGFloat(settings.iconSize)
        let thickness = icon + padding * 2
        let length = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.width - 48))
        let inset: CGFloat = settings.autoHide || settings.followsSystemDock ? 0 : 8

        switch settings.edge {
        case .bottom:
            var frame = NSRect(
                x: visible.midX - length / 2,
                y: visible.minY + inset,
                width: length,
                height: thickness
            )
            if !revealed {
                frame.origin.y = screen.frame.minY - frame.height + 3
            }
            return frame
        case .left:
            let height = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.height - 48))
            var frame = NSRect(
                x: visible.minX + inset,
                y: visible.midY - height / 2,
                width: thickness,
                height: height
            )
            if !revealed {
                frame.origin.x = screen.frame.minX - frame.width + 3
            }
            return frame
        case .right:
            let height = min(CGFloat(itemCount) * (icon + gap) - gap + padding * 2, max(240, visible.height - 48))
            var frame = NSRect(
                x: visible.maxX - thickness - inset,
                y: visible.midY - height / 2,
                width: thickness,
                height: height
            )
            if !revealed {
                frame.origin.x = screen.frame.maxX - 3
            }
            return frame
        }
    }

    private func updateRevealState(screen: NSScreen, settings: SnapshotSettings, now: Date) {
        guard settings.autoHide else {
            isRevealed = true
            revealRequestedAt = nil
            return
        }

        let mouse = NSEvent.mouseLocation
        let wantsReveal = screen.frame.contains(mouse) && isMouseNearDockEdge(mouse, screen: screen, settings: settings)
        if wantsReveal || panel.frame.insetBy(dx: -8, dy: -8).contains(mouse) {
            if revealRequestedAt == nil {
                revealRequestedAt = now
            }
            if now.timeIntervalSince(revealRequestedAt ?? now) >= settings.autoHideDelay {
                isRevealed = true
            }
        } else {
            revealRequestedAt = nil
            isRevealed = false
        }
    }

    private func isMouseNearDockEdge(_ point: NSPoint, screen: NSScreen, settings: SnapshotSettings) -> Bool {
        let revealBand = max(4, CGFloat(settings.iconSize) * 0.20)
        switch settings.edge {
        case .bottom:
            return point.y <= screen.frame.minY + revealBand
        case .left:
            return point.x <= screen.frame.minX + revealBand
        case .right:
            return point.x >= screen.frame.maxX - revealBand
        }
    }
}

struct SnapshotSettings: Equatable {
    var edge: DockEdge = .bottom
    var iconSize: Double = 48
    var magnifiedIconSize: Double = 60
    var magnification = true
    var opacity = 0.82
    var liquidGlass = true
    var autoHide = false
    var autoHideDelay = 0.05
    var autoHideDuration = 0.20
    var respectMenuBarSafeArea = true
    var followsSystemDock = true
    var activationDisplayMode: ActivationDisplayMode = .native
    var cornerRadius: Double {
        let thickness = iconSize + max(9, iconSize * 0.24) * 2
        return thickness / 2
    }

    init() {}

    @MainActor
    init(_ settings: SettingsStore) {
        self.init(DockRuntimeSettings(settings: settings))
    }

    init(_ settings: DockRuntimeSettings) {
        edge = settings.edge
        iconSize = settings.iconSize
        magnifiedIconSize = settings.magnifiedIconSize
        magnification = settings.magnification
        opacity = settings.opacity
        liquidGlass = settings.liquidGlass
        autoHide = settings.autoHide
        autoHideDelay = settings.autoHideDelay
        autoHideDuration = settings.autoHideDuration
        respectMenuBarSafeArea = settings.respectMenuBarSafeArea
        followsSystemDock = settings.followsSystemDock
        activationDisplayMode = settings.activationDisplayMode
    }
}

struct DockPanelView: View {
    let apps: [DockAppItem]
    let settings: SnapshotSettings
    let targetVisibleFrame: NSRect

    var body: some View {
        DockVisualEffect(liquidGlass: settings.liquidGlass)
            .overlay {
                ScrollView(settings.edge == .bottom ? .horizontal : .vertical, showsIndicators: false) {
                    stack {
                        ForEach(apps) { item in
                            DockIconButton(item: item, settings: settings, targetVisibleFrame: targetVisibleFrame)
                        }
                    }
                    .padding(12)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(settings.liquidGlass ? 0.34 : 0.16), lineWidth: 1)
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
    let targetVisibleFrame: NSRect
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
        if isHovering && settings.magnification {
            return CGFloat(settings.magnifiedIconSize)
        }
        return CGFloat(settings.iconSize)
    }

    private func activate() {
        if let app = NSRunningApplication(processIdentifier: item.processIdentifier) {
            if #available(macOS 14.0, *) {
                app.activate()
            } else {
                app.activate(options: [.activateIgnoringOtherApps])
            }

            if settings.activationDisplayMode == .clickedDisplay, !targetVisibleFrame.isEmpty {
                for attempt in 1...6 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.18) {
                        AccessibilityWindowMover.moveWindows(for: item.processIdentifier, to: targetVisibleFrame)
                    }
                }
            }
        }
    }
}

private struct DockVisualEffect: NSViewRepresentable {
    let liquidGlass: Bool

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = liquidGlass ? .popover : .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = liquidGlass ? .popover : .hudWindow
    }
}
