# MoreDock

MoreDock is a native macOS menu-bar app that shows a lightweight glass dock on every connected display. It runs as an accessory app, so its icon is not shown in the macOS Dock while it is working.

## Layout

Expected project layout:

```text
Package.swift
Sources/MoreDock/
Resources/Info.plist
Resources/MoreDock.icns
Resources/
scripts/build_app.sh
scripts/package_release.sh
```

The executable product should be named `MoreDock`.

## Features

- Shows dock panels on all connected screens.
- Tracks running regular macOS apps and lets you activate them from any display.
- Native settings window with liquid-glass visual material.
- Menu-bar controls for settings, refresh, enable/disable, and quit.
- `LSUIElement` app metadata keeps MoreDock out of the Dock and app switcher.

## Build The App

Run:

```sh
./scripts/build_app.sh
```

By default the script builds the Swift package in release mode and writes:

```text
.build/MoreDock.app
```

You can override the build configuration or output path:

```sh
CONFIGURATION=debug ./scripts/build_app.sh
APP_PATH=/tmp/MoreDock.app ./scripts/build_app.sh
```

## Package A Release

Run:

```sh
./scripts/package_release.sh
```

This writes:

```text
dist/MoreDock-0.1.0-macOS.zip
dist/MoreDock-0.1.0-macOS.dmg
dist/SHA256SUMS.txt
```

The local package is ad-hoc signed when no Developer ID certificate is configured. For public distribution without Gatekeeper warnings, build with a Developer ID certificate via `CODESIGN_IDENTITY` and notarize the resulting artifacts with Apple.

## Packaging Notes

The build helper:

- runs `swift build --product MoreDock`
- creates `MoreDock.app/Contents/MacOS`
- copies `Resources/Info.plist` to `MoreDock.app/Contents/Info.plist`
- copies the built `MoreDock` executable into the app bundle
- copies resource files from `Resources/` into `Contents/Resources`, excluding `Info.plist`

The release helper also ad-hoc signs the app locally when no `CODESIGN_IDENTITY` is provided, then creates zip and dmg artifacts. Set `CODESIGN_IDENTITY` to use a Developer ID certificate.
