#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="MoreDock"
VERSION="${VERSION:-0.1.8}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
APP_PATH="${REPO_ROOT}/.build/${PRODUCT_NAME}.app"
ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.zip"
DMG_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.dmg"
CHECKSUM_PATH="${DIST_DIR}/SHA256SUMS.txt"
NOTARY_ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-notary.zip"
APPCAST_PATH="${DIST_DIR}/appcast.xml"
SPARKLE_BIN_DIR="${REPO_ROOT}/.build/artifacts/sparkle/Sparkle/bin"

rm -rf -- "${DIST_DIR}"
mkdir -p -- "${DIST_DIR}"

"${SCRIPT_DIR}/build_app.sh"

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

rm -f -- "${DMG_PATH}"
COPYFILE_DISABLE=1 hdiutil create \
  -volname "${PRODUCT_NAME}" \
  -srcfolder "${APP_PATH}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

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
- Adds per-display MoreDock placement controls.
- Fixes vertical fitting so icon button padding is included.
- Improves clicked-display app activation and window movement retries.
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
