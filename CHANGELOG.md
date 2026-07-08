# Release Notes

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
