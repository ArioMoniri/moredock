#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="MoreDock"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
SOURCE_INFO_PLIST="${REPO_ROOT}/Resources/Info.plist"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${SOURCE_INFO_PLIST}")}"
DIST_DIR="${REPO_ROOT}/dist"
APP_PATH="${REPO_ROOT}/.build/${PRODUCT_NAME}.app"
ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.zip"
DMG_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.dmg"
DMG_RW_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS-rw.dmg"
DMG_STAGING_DIR="${DIST_DIR}/dmg-staging"
DMG_BACKGROUND_PATH="${DMG_STAGING_DIR}/.background/dmg-background.png"
CHECKSUM_PATH="${DIST_DIR}/SHA256SUMS.txt"
NOTARY_ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-notary.zip"
APPCAST_PATH="${DIST_DIR}/appcast.xml"
SPARKLE_BIN_DIR="${REPO_ROOT}/.build/artifacts/sparkle/Sparkle/bin"

rm -rf -- "${DIST_DIR}"
mkdir -p -- "${DIST_DIR}"

# This script signs the bundle itself below, so tell build_app.sh not to sign
# too (a double sign races the hdiutil DMG step with "Resource busy").
SKIP_BUILD_APP_SIGN=1 "${SCRIPT_DIR}/build_app.sh"

if command -v codesign >/dev/null 2>&1; then
  SIGN_ARGS=(--force --deep)
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    SIGN_ARGS+=(--options runtime --timestamp --sign "${CODESIGN_IDENTITY}")
  else
    SIGN_ARGS+=(--sign -)
  fi

  codesign "${SIGN_ARGS[@]}" "${APP_PATH}"
fi

xattr -cr "${APP_PATH}" || true

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  if [[ -z "${CODESIGN_IDENTITY:-}" ]]; then
    echo "error: notarization requires CODESIGN_IDENTITY to be set" >&2
    exit 1
  fi

  echo "Submitting app for notarization..."
  COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "${APP_PATH}" "${NOTARY_ZIP_PATH}"
  xcrun notarytool submit "${NOTARY_ZIP_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --wait
  xcrun stapler staple "${APP_PATH}"
  rm -f -- "${NOTARY_ZIP_PATH}"
fi

COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

rm -rf -- "${DMG_STAGING_DIR}"
mkdir -p -- "${DMG_STAGING_DIR}/.background"
cp -R -- "${APP_PATH}" "${DMG_STAGING_DIR}/${PRODUCT_NAME}.app"
ln -s /Applications "${DMG_STAGING_DIR}/Applications"

swift - "${DMG_BACKGROUND_PATH}" <<'SWIFT'
import AppKit

let output = CommandLine.arguments[1]
let size = NSSize(width: 720, height: 460)
let image = NSImage(size: size)

image.lockFocus()

let bounds = NSRect(origin: .zero, size: size)
NSColor(calibratedRed: 0.055, green: 0.070, blue: 0.082, alpha: 1).setFill()
bounds.fill()

let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.21, alpha: 1),
    NSColor(calibratedRed: 0.055, green: 0.070, blue: 0.082, alpha: 1)
])!
gradient.draw(in: bounds, angle: -28)

let glow = NSBezierPath(ovalIn: NSRect(x: 208, y: 108, width: 304, height: 238))
NSColor(calibratedRed: 0.35, green: 0.74, blue: 0.86, alpha: 0.16).setFill()
glow.fill()

let rail = NSBezierPath(roundedRect: NSRect(x: 155, y: 90, width: 410, height: 78), xRadius: 32, yRadius: 32)
NSColor(calibratedWhite: 1, alpha: 0.16).setFill()
rail.fill()
NSColor(calibratedWhite: 1, alpha: 0.20).setStroke()
rail.lineWidth = 1
rail.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

("Drag MoreDock to Applications" as NSString).draw(
    in: NSRect(x: 0, y: 338, width: size.width, height: 34),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 24, weight: .semibold),
        .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.94),
        .paragraphStyle: paragraph
    ]
)

("Keep a Dock-style launcher on every display." as NSString).draw(
    in: NSRect(x: 0, y: 310, width: size.width, height: 24),
    withAttributes: [
        .font: NSFont.systemFont(ofSize: 14, weight: .medium),
        .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.62),
        .paragraphStyle: paragraph
    ]
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 328, y: 132))
arrow.line(to: NSPoint(x: 392, y: 132))
arrow.move(to: NSPoint(x: 374, y: 151))
arrow.line(to: NSPoint(x: 393, y: 132))
arrow.line(to: NSPoint(x: 374, y: 113))
NSColor(calibratedWhite: 1, alpha: 0.78).setStroke()
arrow.lineWidth = 4
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.stroke()

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let data = bitmap.representation(using: .png, properties: [:])
else {
    fatalError("Unable to render DMG background")
}

try data.write(to: URL(fileURLWithPath: output))
SWIFT

rm -f -- "${DMG_PATH}" "${DMG_RW_PATH}"
COPYFILE_DISABLE=1 hdiutil create \
  -volname "${PRODUCT_NAME}" \
  -srcfolder "${DMG_STAGING_DIR}" \
  -ov \
  -format UDRW \
  -fs HFS+ \
  "${DMG_RW_PATH}" >/dev/null

DMG_MOUNT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/moredock-dmg.XXXXXX")"
cleanup_dmg_mount() {
  hdiutil detach "${DMG_MOUNT_DIR}" -quiet 2>/dev/null || hdiutil detach "${DMG_MOUNT_DIR}" -force -quiet 2>/dev/null || true
  rmdir "${DMG_MOUNT_DIR}" 2>/dev/null || true
}
trap cleanup_dmg_mount EXIT

hdiutil attach "${DMG_RW_PATH}" -mountpoint "${DMG_MOUNT_DIR}" -nobrowse -quiet

osascript <<APPLESCRIPT || true
set dmgFolder to POSIX file "${DMG_MOUNT_DIR}" as alias
set backgroundPicture to POSIX file "${DMG_MOUNT_DIR}/.background/dmg-background.png" as alias

tell application "Finder"
  open dmgFolder
  delay 1
  set dmgWindow to container window of dmgFolder
  set current view of dmgWindow to icon view
  set toolbar visible of dmgWindow to false
  set statusbar visible of dmgWindow to false
  set the bounds of dmgWindow to {180, 110, 900, 570}
  set viewOptions to the icon view options of dmgWindow
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 96
  set background picture of viewOptions to backgroundPicture
  set position of item "MoreDock.app" of dmgFolder to {238, 250}
  set position of item "Applications" of dmgFolder to {482, 250}
  update dmgFolder without registering applications
  delay 1
  close dmgWindow
end tell
APPLESCRIPT

sync
cleanup_dmg_mount
trap - EXIT

hdiutil convert "${DMG_RW_PATH}" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "${DMG_PATH}" >/dev/null
rm -f -- "${DMG_RW_PATH}"
rm -rf -- "${DMG_STAGING_DIR}"

if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "${CODESIGN_IDENTITY}" "${DMG_PATH}"
fi

if [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_SPECIFIC_PASSWORD:-}" ]]; then
  echo "Submitting dmg for notarization..."
  xcrun notarytool submit "${DMG_PATH}" \
    --apple-id "${APPLE_ID}" \
    --team-id "${APPLE_TEAM_ID}" \
    --password "${APPLE_APP_SPECIFIC_PASSWORD}" \
    --wait
  xcrun stapler staple "${DMG_PATH}"
fi

if [[ -n "${SPARKLE_PRIVATE_KEY:-}" ]]; then
  if [[ ! -x "${SPARKLE_BIN_DIR}/generate_appcast" ]]; then
    echo "error: Sparkle generate_appcast tool was not found" >&2
    exit 1
  fi

  UPDATES_DIR="${REPO_ROOT}/.build/sparkle-updates"
  DOWNLOAD_PREFIX="${SPARKLE_DOWNLOAD_URL_PREFIX:-https://github.com/ArioMoniri/moredock/releases/download/v${VERSION}/}"
  RELEASE_NOTES_PATH="${UPDATES_DIR}/$(basename "${DMG_PATH}" .dmg).md"

  rm -rf -- "${UPDATES_DIR}"
  mkdir -p -- "${UPDATES_DIR}"
  cp -- "${DMG_PATH}" "${UPDATES_DIR}/"
  cat > "${RELEASE_NOTES_PATH}" <<NOTES
# MoreDock ${VERSION}

- Native multi-display dock panels.
- Adds per-external-display size, opacity, auto-hide, magnification, location, and junction controls.
- Converts clicked-display Accessibility movement to AX coordinates.
- Makes Settings use lighter liquid-glass materials.
- Sparkle-powered app updates.
NOTES

  echo "${SPARKLE_PRIVATE_KEY}" | "${SPARKLE_BIN_DIR}/generate_appcast" \
    --ed-key-file - \
    --download-url-prefix "${DOWNLOAD_PREFIX}" \
    --embed-release-notes \
    -o "${APPCAST_PATH}" \
    "${UPDATES_DIR}"
fi

(
  cd "${DIST_DIR}"
  shasum -a 256 "$(basename "${ZIP_PATH}")" "$(basename "${DMG_PATH}")" > "${CHECKSUM_PATH}"
  if [[ -f "$(basename "${APPCAST_PATH}")" ]]; then
    shasum -a 256 "$(basename "${APPCAST_PATH}")" >> "${CHECKSUM_PATH}"
  fi
)

echo "Packaged:"
echo "  ${ZIP_PATH}"
echo "  ${DMG_PATH}"
if [[ -f "${APPCAST_PATH}" ]]; then
  echo "  ${APPCAST_PATH}"
fi
echo "  ${CHECKSUM_PATH}"
