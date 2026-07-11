import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Pin/unpin/add callbacks handed to a panel so the dock can edit its own display's
/// custom app list from a right-click menu or a drag-and-drop.
struct DockActions {
    var supportsPinning: Bool = false
    var isPinned: (DockAppItem) -> Bool = { _ in false }
    var pin: (DockAppItem, _ allDisplays: Bool) -> Void = { _, _ in }
    var unpin: (DockAppItem) -> Void = { _ in }
    var addURL: (URL, _ allDisplays: Bool) -> Void = { _, _ in }
}

/// Asks whether an added app should go on just this dock or all docks.
/// Returns true for all docks, false for this dock, nil if cancelled.
@MainActor
func promptAddScope(appName: String) -> Bool? {
    let alert = NSAlert()
    alert.messageText = "Add \(appName) to Dock"
    alert.informativeText = "Add it to only this display's dock, or to every dock?"
    alert.addButton(withTitle: "This Dock")
    alert.addButton(withTitle: "All Docks")
    alert.addButton(withTitle: "Cancel")
    NSApp.activate(ignoringOtherApps: true)
    switch alert.runModal() {
    case .alertFirstButtonReturn: return false
    case .alertSecondButtonReturn: return true
    default: return nil
    }
}

@MainActor
final class DockPanelController {
    private let panel: NSPanel
    private let hostingView: NSHostingView<DockPanelView>
    private let screenNumber: DisplayID
    private var isRevealed = true
    private var revealRequestedAt: Date?
    private var hasPositioned = false
    private var lastStateSignature = ""

    init(screenNumber: DisplayID) {
        self.screenNumber = screenNumber
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = false

        hostingView = NSHostingView(rootView: DockPanelView(apps: [], settings: SnapshotSettings(), targetVisibleFrame: .zero, actions: DockActions()))
        hostingView.wantsLayer = true
        panel.contentView = hostingView
    }

    func update(screen: NSScreen, apps: [DockAppItem], settings: DockRuntimeSettings, actions: DockActions, now: Date) {
        let snapshot = SnapshotSettings(settings)
        hostingView.rootView = DockPanelView(apps: apps, settings: snapshot, targetVisibleFrame: screen.visibleFrame, actions: actions)

        updateRevealState(screen: screen, settings: snapshot, now: now)

        let targetFrame = frame(for: screen, apps: apps, settings: snapshot, revealed: isRevealed)
        let targetAlpha: CGFloat = isRevealed ? 1.0 : 0.0

        if !hasPositioned {
            // Snap the first appearance into place instead of animating from a
            // zero-size rect at the origin (which reads as "not showing").
            hasPositioned = true
            panel.setFrame(targetFrame, display: true)
            panel.alphaValue = targetAlpha
            panel.orderFrontRegardless()
        } else {
            let animationDuration = settings.autoHide ? settings.autoHideDuration : 0.16
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(targetFrame, display: true)
                panel.animator().alphaValue = targetAlpha
            }
            if !panel.isVisible || isRevealed {
                panel.orderFrontRegardless()
            }
        }

        logStateIfChanged(targetFrame: targetFrame, apps: apps.count, autoHide: settings.autoHide)
    }

    private func logStateIfChanged(targetFrame: NSRect, apps: Int, autoHide: Bool) {
        let frameText = "[\(Int(targetFrame.minX)),\(Int(targetFrame.minY)),\(Int(targetFrame.width))x\(Int(targetFrame.height))]"
        let signature = "\(isRevealed)|\(autoHide)|\(apps)|\(frameText)|\(panel.isVisible)"
        guard signature != lastStateSignature else { return }
        lastStateSignature = signature
        mdLog("Panel #\(screenNumber): revealed=\(isRevealed) autohide=\(autoHide) apps=\(apps) frame=\(frameText) onScreen=\(panel.isVisible) alpha=\(String(format: "%.2f", panel.alphaValue)).")
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
        let metrics = DockPanelMetrics(settings: settings, itemCount: apps.count, visibleFrame: visible)
        let thickness = metrics.thickness
        let length = metrics.length
        // Keep a small gap from the physical screen edge even when following the
        // native Dock so the glass panel does not bleed across a shared display seam
        // onto the neighbouring monitor.
        let inset: CGFloat = 6

        switch settings.edge {
        case .bottom:
            var frame = NSRect(
                x: visible.midX - length / 2,
                y: visible.minY + inset,
                width: length,
                height: thickness
            )
            if !revealed {
                frame.origin.y = screen.frame.minY - frame.height - 2
            }
            return frame
        case .left:
            var frame = NSRect(
                x: visible.minX + inset,
                y: visible.midY - length / 2,
                width: thickness,
                height: length
            )
            if !revealed {
                frame.origin.x = screen.frame.minX - frame.width - 2
            }
            return frame
        case .right:
            var frame = NSRect(
                x: visible.maxX - thickness - inset,
                y: visible.midY - length / 2,
                width: thickness,
                height: length
            )
            if !revealed {
                frame.origin.x = screen.frame.maxX + 2
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
    var showRunningIndicators = true
    var autoHide = false
    var autoHideDelay = 0.05
    var autoHideDuration = 0.20
    var respectMenuBarSafeArea = true
    var avoidDisplayJunctions = true
    var followsSystemDock = true
    var activationDisplayMode: ActivationDisplayMode = .native
    var cornerRadius: Double {
        let thickness = iconSize + max(9, iconSize * 0.24) * 2
        // Cap the radius so a long dock reads as a rounded rectangle like the
        // native Dock instead of a full stadium/pill.
        return min(thickness / 2, 26)
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
        showRunningIndicators = settings.showRunningIndicators
        autoHide = settings.autoHide
        autoHideDelay = settings.autoHideDelay
        autoHideDuration = settings.autoHideDuration
        respectMenuBarSafeArea = settings.respectMenuBarSafeArea
        avoidDisplayJunctions = settings.avoidDisplayJunctions
        followsSystemDock = settings.followsSystemDock
        activationDisplayMode = settings.activationDisplayMode
    }
}

struct DockPanelMetrics {
    let iconSize: CGFloat
    let gap: CGFloat
    let padding: CGFloat
    let thickness: CGFloat
    let length: CGFloat

    init(settings: SnapshotSettings, itemCount: Int, visibleFrame: NSRect) {
        let count = max(itemCount, 1)
        let baseIcon = CGFloat(settings.iconSize)
        let availableLength = max(180, settings.edge == .bottom ? visibleFrame.width - 48 : visibleFrame.height - 48)
        let baseGap = max(6, baseIcon * 0.13)
        let basePadding = max(8, baseIcon * 0.22)
        let buttonExtra: CGFloat = 4
        let fittedIcon = floor((availableLength - basePadding * 2 + baseGap) / CGFloat(count) - baseGap - buttonExtra)
        iconSize = min(baseIcon, max(12, fittedIcon))
        gap = max(4, min(baseGap, iconSize * 0.18))
        padding = max(7, min(basePadding, iconSize * 0.30))
        let buttonExtent = iconSize + buttonExtra
        thickness = buttonExtent + padding * 2
        length = min(
            CGFloat(count) * (buttonExtent + gap) - gap + padding * 2,
            availableLength
        )
    }
}

struct DockPanelView: View {
    let apps: [DockAppItem]
    let settings: SnapshotSettings
    let targetVisibleFrame: NSRect
    var actions = DockActions()

    var body: some View {
        let metrics = DockPanelMetrics(settings: settings, itemCount: apps.count, visibleFrame: targetVisibleFrame)

        DockVisualEffect(liquidGlass: settings.liquidGlass)
            .overlay {
                stack(spacing: metrics.gap) {
                    ForEach(apps) { item in
                        DockIconButton(item: item, settings: settings, targetVisibleFrame: targetVisibleFrame, baseIconSize: metrics.iconSize, actions: actions)
                    }
                }
                .padding(metrics.padding)
            }
            .clipShape(RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: settings.cornerRadius, style: .continuous)
                    .strokeBorder(.white.opacity(settings.liquidGlass ? 0.34 : 0.16), lineWidth: 1)
            }
            .opacity(settings.opacity)
            .onDrop(of: [UTType.fileURL], isTargeted: nil) { providers in
                handleDrop(providers)
            }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard actions.supportsPinning else { return false }
        var handled = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            handled = true
            provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                guard let data, let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                Task { @MainActor in
                    guard url.pathExtension.lowercased() == "app" else { return }
                    let name = url.deletingPathExtension().lastPathComponent
                    if let allDocks = promptAddScope(appName: name) {
                        actions.addURL(url, allDocks)
                    }
                }
            }
        }
        return handled
    }

    @ViewBuilder
    private func stack<Content: View>(spacing: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        if settings.edge == .bottom {
            HStack(spacing: spacing, content: content)
        } else {
            VStack(spacing: spacing, content: content)
        }
    }
}

private struct DockIconButton: View {
    let item: DockAppItem
    let settings: SnapshotSettings
    let targetVisibleFrame: NSRect
    let baseIconSize: CGFloat
    var actions = DockActions()
    @State private var isHovering = false

    private var canPin: Bool {
        actions.supportsPinning && item.kind == .application && item.bundleIdentifier != "com.apple.finder"
    }

    var body: some View {
        if item.kind == .separator {
            separator
        } else {
            iconButton
        }
    }

    private var iconButton: some View {
        Button {
            activate()
        } label: {
            Image(nsImage: item.icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .padding(2)
                .overlay(alignment: dotAlignment) { runningDot }
                .scaleEffect(isHovering && settings.magnification ? 1.18 : 1.0)
                .animation(.spring(response: 0.22, dampingFraction: 0.72), value: isHovering)
        }
        .buttonStyle(.plain)
        .help(item.name)
        .onHover { isHovering = $0 }
        .accessibilityLabel(item.name)
        .contextMenu {
            if canPin {
                if actions.isPinned(item) {
                    Button("Remove from This Dock") { actions.unpin(item) }
                } else {
                    Button("Keep in This Dock") { actions.pin(item, false) }
                    Button("Keep in All Docks") { actions.pin(item, true) }
                }
            }
        }
    }

    @ViewBuilder
    private var runningDot: some View {
        if settings.showRunningIndicators && item.isRunning && item.kind == .application && item.bundleIdentifier != "com.apple.finder" {
            Circle()
                .fill(.white.opacity(0.85))
                .frame(width: max(3, iconSize * 0.1), height: max(3, iconSize * 0.1))
        }
    }

    private var dotAlignment: Alignment {
        switch settings.edge {
        case .bottom: .bottom
        case .left: .trailing
        case .right: .leading
        }
    }

    private var separator: some View {
        let isBottom = settings.edge == .bottom
        let lineThickness: CGFloat = 1
        let lineLength = baseIconSize * 0.6
        return RoundedRectangle(cornerRadius: lineThickness / 2, style: .continuous)
            .fill(.white.opacity(0.28))
            .frame(
                width: isBottom ? lineThickness : lineLength,
                height: isBottom ? lineLength : lineThickness
            )
            .frame(
                width: isBottom ? baseIconSize * 0.5 : baseIconSize,
                height: isBottom ? baseIconSize : baseIconSize * 0.5
            )
    }

    private var iconSize: CGFloat {
        if isHovering && settings.magnification {
            return min(CGFloat(settings.magnifiedIconSize), baseIconSize * 1.22)
        }
        return baseIconSize
    }

    private func activate() {
        let shouldMoveToClickedDisplay = settings.activationDisplayMode == .clickedDisplay && !targetVisibleFrame.isEmpty
        let clickedDisplayFrame = targetVisibleFrame
        let moveAfterActivation: @Sendable (pid_t) -> Void = { processIdentifier in
            guard shouldMoveToClickedDisplay else { return }
            Task { @MainActor in
                AccessibilityMoveCoordinator.shared.requestMove(pid: processIdentifier, to: clickedDisplayFrame)
            }
        }

        if let processIdentifier = item.processIdentifier,
           let app = NSRunningApplication(processIdentifier: processIdentifier) {
            app.activate(options: [.activateAllWindows])
            moveAfterActivation(processIdentifier)
            return
        }

        if let bundleIdentifier = item.bundleIdentifier,
           let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) ?? item.url {
            let configuration = NSWorkspace.OpenConfiguration()
            configuration.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: configuration) { app, _ in
                if let processIdentifier = app?.processIdentifier {
                    moveAfterActivation(processIdentifier)
                } else {
                    for attempt in 1...14 {
                        DispatchQueue.main.asyncAfter(deadline: .now() + Double(attempt) * 0.20) {
                            if let processIdentifier = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.processIdentifier {
                                moveAfterActivation(processIdentifier)
                            }
                        }
                    }
                }
            }
            return
        }

        if let url = item.url {
            NSWorkspace.shared.open(url)
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
