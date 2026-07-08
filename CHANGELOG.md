# Release Notes

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
