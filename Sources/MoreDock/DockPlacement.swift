import AppKit

/// Single source of truth for where a display's dock is drawn. Used by both the
/// renderer (`DockController`) and the Settings "Display Layout" preview so the
/// preview always matches reality.
enum DockPlacement {
    /// The base edge before per-display overrides: the native Dock orientation when
    /// following the system Dock, otherwise the user's global edge.
    @MainActor
    static func globalEdge(for settings: SettingsStore) -> DockEdge {
        settings.followSystemDock ? SystemDockPreferences.nativeEdge : settings.edge
    }

    /// The edge a display's dock is actually drawn on, after applying that display's
    /// placement override and junction avoidance.
    static func resolvedEdge(
        globalEdge: DockEdge,
        displaySettings: DisplayDockSettings,
        screen: NSScreen,
        allScreens: [NSScreen]
    ) -> DockEdge {
        var edge = displaySettings.followsGlobalPlacement ? globalEdge : displaySettings.edge

        guard displaySettings.avoidDisplayJunctions else { return edge }
        guard isEdgeShared(edge, of: screen, with: allScreens) else { return edge }

        switch edge {
        case .left:
            edge = isEdgeShared(.right, of: screen, with: allScreens) ? .bottom : .right
        case .right:
            edge = isEdgeShared(.left, of: screen, with: allScreens) ? .bottom : .left
        case .bottom:
            // A shared bottom edge (a display directly below/at the junction) moves
            // to a free side edge so the dock is not stuck on the seam.
            if !isEdgeShared(.left, of: screen, with: allScreens) {
                edge = .left
            } else if !isEdgeShared(.right, of: screen, with: allScreens) {
                edge = .right
            } else {
                edge = .bottom
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
            }
        }
    }
}
