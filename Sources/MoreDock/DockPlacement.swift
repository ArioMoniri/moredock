import AppKit

/// Single source of truth for where a display's dock is drawn. Used by both the
/// renderer (`DockController`) and the Settings "Display Layout" preview so the
/// preview always matches reality.
enum DockPlacement {
    /// The base edge before per-display overrides. Non-customized docks mirror the
    /// macOS Dock, so the base edge is always the native Dock's orientation.
    @MainActor
    static func globalEdge(for settings: SettingsStore) -> DockEdge {
        SystemDockPreferences.nativeEdge
    }

    /// The edge a display's dock is actually drawn on, after applying that display's
    /// placement override and junction avoidance.
    static func resolvedEdge(
        globalEdge: DockEdge,
        globalAvoidJunctions: Bool,
        displaySettings: DisplayDockSettings,
        screen: NSScreen,
        allScreens: [NSScreen]
    ) -> DockEdge {
        var edge = displaySettings.followsGlobalPlacement ? globalEdge : displaySettings.edge

        // A display that follows global placement uses the global junction-avoidance
        // toggle; a customized display uses its own. Otherwise the global toggle would
        // silently do nothing for every non-customized dock.
        let avoidJunctions = displaySettings.followsGlobalPlacement
            ? globalAvoidJunctions
            : displaySettings.avoidDisplayJunctions
        guard avoidJunctions else { return edge }
        guard isEdgeShared(edge, of: screen, with: allScreens) else { return edge }

        switch edge {
        case .left:
            edge = isEdgeShared(.right, of: screen, with: allScreens) ? .bottom : .right
        case .right:
            edge = isEdgeShared(.left, of: screen, with: allScreens) ? .bottom : .left
        case .bottom, .top:
            // A shared top/bottom edge (a display directly above/below at the junction)
            // moves to a free side edge so the dock is not stuck on the seam.
            if !isEdgeShared(.left, of: screen, with: allScreens) {
                edge = .left
            } else if !isEdgeShared(.right, of: screen, with: allScreens) {
                edge = .right
            } else if edge == .top, !isEdgeShared(.bottom, of: screen, with: allScreens) {
                edge = .bottom
            } else if edge == .bottom, !isEdgeShared(.top, of: screen, with: allScreens) {
                edge = .top
            }
        }
        return edge
    }

    static func isEdgeShared(_ edge: DockEdge, of screen: NSScreen, with screens: [NSScreen]) -> Bool {
        let tolerance: CGFloat = 2
        let frame = screen.frame
        return screens.contains { other in
            guard other != screen else { return false }
            let otherFrame = other.frame
            let verticalOverlap = frame.minY < otherFrame.maxY - tolerance && frame.maxY > otherFrame.minY + tolerance
            let horizontalOverlap = frame.minX < otherFrame.maxX - tolerance && frame.maxX > otherFrame.minX + tolerance

            switch edge {
            case .left:
                return verticalOverlap && abs(frame.minX - otherFrame.maxX) <= tolerance
            case .right:
                return verticalOverlap && abs(frame.maxX - otherFrame.minX) <= tolerance
            case .bottom:
                return horizontalOverlap && abs(frame.minY - otherFrame.maxY) <= tolerance
            case .top:
                return horizontalOverlap && abs(frame.maxY - otherFrame.minY) <= tolerance
            }
        }
    }
}
