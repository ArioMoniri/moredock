# Release Notes

## Unreleased

- 📄 Adds the Apache License 2.0 (© Ariorad Moniri) plus a NOTICE file.
- 🗺️ Adds an animated Display Layout map in Settings that shows every screen's position and the glowing dock edge for each one.
- 🎛️ Every appearance control is now always editable: changing a locked control detaches it from "Follow native Dock" (globally) or from global placement/appearance (per display) so the change actually applies instead of being greyed out.
- 🖥️ Per-Display Docks now list **every** display (including the main one), not just external ones, each with its own show/hide, location, size, opacity, auto-hide, magnification, and junction settings.
- 🔐 Clicked Display no longer prompts for Accessibility on every click: it asks once (throttled), remembers the pending move, and applies it automatically as soon as access is granted — no second click needed.
- ⚙️ Settings gains a live Accessibility status row with a Grant… button that opens System Settings directly.
- 🖥️ Fixes the duplicate dock that could overlap the real macOS Dock on the main display by flipping Quartz→Cocoa coordinates when locating the native Dock and excluding **all** displays that host it.
- 🧊 Insets extra docks a few points off shared display seams so their glass no longer bleeds onto the neighbouring monitor.
- ✨ Gives the Settings window a richer liquid-glass backdrop.
- 🕵️ Adds a detective (Murdoch-inspired) app-icon vector source, README hero, and an icon-generation script.

## 0.1.9

This release expands the per-display controls and fixes a likely Clicked Display coordinate issue.

- 🖥️ Adds separate external-display controls for location, icon size, opacity, auto-hide, magnification, and junction behavior.
- 🪟 Converts Clicked Display window placement from AppKit coordinates to Accessibility coordinates before moving windows.
- 🧊 Moves Settings to lighter liquid-glass materials.
- 📏 Keeps the vertical Dock fit fix from 0.1.8.

## 0.1.8

This release adds the missing per-display placement controls and fixes more of the Dock behavior issues.

- 🖥️ Adds a Displays section where each screen can be enabled/disabled and assigned a custom MoreDock edge.
- 📏 Fixes vertical Dock fitting by including icon button padding in the fit calculation.
- 🪟 Improves Clicked Display mode with stronger app activation and longer window-move retries.
- 🧭 Keeps per-display junction avoidance configurable for each screen.

## 0.1.7

This release fixes the focus-dependent display behavior.

- 🖱️ Uses `CGMainDisplayID()` instead of `NSScreen.main` for native Dock display fallback.
- 🖥️ Prevents focus changes on another display from causing the wrong MoreDock panel to hide.
- 📌 Raises revealed extra docks above focused app windows with status-bar window level.
- 🎛️ Keeps the native macOS Dock settings controls added in 0.1.6.

## 0.1.6

This release focuses on the unresolved native-Dock matching and settings issues.

- 🎛️ Adds editable macOS Dock settings for location, size, zoom, magnification, and auto-hide.
- 🖥️ Strengthens native Dock display exclusion, especially when the real Dock is auto-hidden.
- 🧭 Adds display-junction avoidance so side docks do not sit on borders shared with another display by default.
- 📁 Re-syncs Dock persistent apps/folders after `com.apple.dock` preference synchronization.
- 🔐 Stops repeated Accessibility prompts during clicked-display moves and adds a Settings permission button.

## 0.1.5

This release restores the previous app icon and moves the detective concept into README/docs only.

- 🎨 Restores the previous MoreDock app icon.
- 🕵️ Adds a detective Rive-ready README element and docs canvas.
- 🧊 Keeps the app branding focused on the Dock itself.

## 0.1.4

This release fixes several Dock behavior issues and cleans up the project presentation.

- 📁 Mirrors persistent Dock apps plus folders/stacks such as Downloads.
- 📏 Dynamically fits all Dock items on each display edge without scrolling.
- ✨ Makes hidden auto-hide panels fully invisible to avoid display-junction bleed.
- 🔐 Reduces repeated Accessibility prompts during clicked-display window movement.
- 🖼️ Simplifies the README around the Settings screenshot only.
- 🕵️ Refreshes the app icon with a simple detective-inspired Dock mark.

## 0.1.3

This release tightens the settings experience and makes updater access visible from the app itself.

- 🧊 Reworks Settings into a compact native macOS glass panel.
- 🎛️ Groups Dock, behavior, appearance, and Liquid Glass controls into clearer sections.
- 🔄 Adds a Settings-window update check backed by Sparkle.
- 🖼️ Refreshes README screenshots from the real app views.

## 0.1.2

This release replaces the app icon with a simpler Dock-focused symbol.

- 🎨 Uses a single minimal Dock pill element.
- 🧊 Removes monitor/display structures from the icon.
- 📦 Keeps the same signed, notarized, Sparkle-enabled release flow.

## 0.1.1

MoreDock now tracks the native Dock more closely and avoids drawing over the display that already owns the macOS Dock.

- 🖥️ Hides MoreDock on the native Dock screen by default.
- 📐 Reads Dock settings with `CFPreferences`, matching `defaults read com.apple.dock`.
- 🧊 Uses a Dock-like pill shape derived from native Dock tile size.
- 🪟 Improves clicked-display window placement with retries, unminimize, center, and raise.
- ✨ Removes panel shadows to avoid bleed at display junctions.
- 🎛️ Adds a clearer setting for hiding where the native Dock lives.
- 🖼️ Replaces README generated catalogue art with real app screenshots.
- 🔄 Keeps Sparkle updater packaging and signed appcast support.

## 0.1.0

Initial public release.

- 🧊 Native macOS menu-bar app with no Dock icon.
- 🖥️ Dock-style launcher panels on multiple displays.
- 🎛️ Settings window for Dock behavior and display activation.
- 🔐 Developer ID signing and notarized release workflow.
- 🔄 Sparkle updater support.
