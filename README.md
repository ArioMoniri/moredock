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

## GitHub Release Signing

Tagged releases are signed and notarized in GitHub Actions when these repository secrets are configured:

- `MACOS_DEVELOPER_ID_CERTIFICATE_BASE64`: base64-encoded `.p12` export of the Developer ID Application certificate and private key.
- `MACOS_DEVELOPER_ID_CERTIFICATE_PASSWORD`: password used when exporting the `.p12`.
- `MACOS_KEYCHAIN_PASSWORD`: temporary CI keychain password.
- `MACOS_CODESIGN_IDENTITY`: exact Developer ID Application identity, for example `Developer ID Application: Your Name (TEAMID)`.
- `APPLE_ID`: Apple ID email used for Developer ID notarization.
- `APPLE_TEAM_ID`: Apple Developer Team ID.
- `APPLE_APP_SPECIFIC_PASSWORD`: app-specific password for `notarytool`.

Create a release by pushing a version tag:

```sh
git tag v0.1.0
git push origin v0.1.0
```

## Packaging Notes

The build helper:

- runs `swift build --product MoreDock`
- creates `MoreDock.app/Contents/MacOS`
- copies `Resources/Info.plist` to `MoreDock.app/Contents/Info.plist`
- copies the built `MoreDock` executable into the app bundle
- copies resource files from `Resources/` into `Contents/Resources`, excluding `Info.plist`

The release helper also ad-hoc signs the app locally when no `CODESIGN_IDENTITY` is provided, then creates zip and dmg artifacts. Set `CODESIGN_IDENTITY` to use a Developer ID certificate.
