# MoreDock 🧊

MoreDock is a native macOS menu-bar app that puts a Dock-style launcher on every display.

It follows your real Dock settings by default: location, icon size, magnification, auto-hide, reveal delay, and reveal animation timing. It also runs as an accessory app, so MoreDock itself does not show up as an extra icon in the macOS Dock.

![MoreDock dock preview](docs/images/moredock-dock.png)

![MoreDock settings](docs/images/moredock-settings.png)

## What It Does ✨

- Shows a lightweight Dock panel on every connected screen.
- Mirrors the native Dock settings from `com.apple.dock`.
- Updates while running when the native Dock location, size, or auto-hide settings change.
- Tracks running regular macOS apps and activates them from any display.
- Can either use normal macOS app activation or move windows to the display whose MoreDock panel was clicked.
- Uses a native SwiftUI/AppKit settings window with glassy macOS materials.
- Includes Sparkle updates with a **Check for Updates...** menu item.
- Runs with `LSUIElement`, so there is no extra Dock icon.

## Native Dock Sync 🖥️

When **Follow native Dock** is on, MoreDock reads:

- `orientation`
- `tilesize`
- `largesize`
- `magnification`
- `autohide`
- `autohide-delay`
- `autohide-time-modifier`

That keeps MoreDock aligned with the Dock you already configured in macOS.

## Opening Apps On Displays 🪟

The **Open apps on** setting has two modes:

- **macOS**: let the system decide, exactly like a normal Dock click.
- **Clicked Display**: activate the app, then move its windows to the display where you clicked the MoreDock icon.

Clicked Display uses the macOS Accessibility API. macOS may ask for Accessibility permission the first time this mode moves a window.

## Build 🛠️

```sh
./scripts/build_app.sh
```

The app bundle is written to:

```text
.build/MoreDock.app
```

## Package 📦

```sh
./scripts/package_release.sh
```

This creates:

```text
dist/MoreDock-0.1.0-macOS.zip
dist/MoreDock-0.1.0-macOS.dmg
dist/SHA256SUMS.txt
```

If `SPARKLE_PRIVATE_KEY` is set, packaging also creates:

```text
dist/appcast.xml
```

Local builds are ad-hoc signed unless `CODESIGN_IDENTITY` is set.

## GitHub Release Signing 🔐

Tagged releases are signed, notarized, and published from GitHub Actions with these secrets:

- `APPLE_CERTIFICATE`: base64 `.p12` export of the Developer ID Application certificate and private key.
- `APPLE_CERTIFICATE_PASSWORD`: password for the `.p12`.
- `APPLE_SIGNING_IDENTITY`: exact identity, for example `Developer ID Application: Your Name (TEAMID)`.
- `APPLE_ID`: Apple ID email for notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_PASSWORD`: app-specific password for `notarytool`.
- `SPARKLE_PRIVATE_KEY`: Sparkle EdDSA private key used to sign `appcast.xml`.

`TAURI_SIGNING_PRIVATE_KEY` is not used here; MoreDock is Swift/AppKit, not Tauri.

Publish a release:

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Screenshots 🖼️

The README screenshots are rendered from the real SwiftUI/AppKit views:

```sh
xcrun swiftc -parse-as-library \
  Sources/MoreDock/AccessibilityWindowMover.swift \
  Sources/MoreDock/SettingsStore.swift \
  Sources/MoreDock/SystemDockPreferences.swift \
  Sources/MoreDock/DockController.swift \
  Sources/MoreDock/DockPanelController.swift \
  Sources/MoreDock/SettingsWindowController.swift \
  scripts/render_docs_screenshots.swift \
  -o .build/render_docs_screenshots

.build/render_docs_screenshots docs/images
```
