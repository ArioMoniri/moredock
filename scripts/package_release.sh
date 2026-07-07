#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="MoreDock"
VERSION="${VERSION:-0.1.0}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist"
APP_PATH="${REPO_ROOT}/.build/${PRODUCT_NAME}.app"
ZIP_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.zip"
DMG_PATH="${DIST_DIR}/${PRODUCT_NAME}-${VERSION}-macOS.dmg"
CHECKSUM_PATH="${DIST_DIR}/SHA256SUMS.txt"

rm -rf -- "${DIST_DIR}"
mkdir -p -- "${DIST_DIR}"

"${SCRIPT_DIR}/build_app.sh"

if command -v codesign >/dev/null 2>&1; then
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --sign "${CODESIGN_IDENTITY}" "${APP_PATH}"
  else
    codesign --force --deep --sign - "${APP_PATH}"
  fi
fi

xattr -cr "${APP_PATH}" || true

COPYFILE_DISABLE=1 ditto -c -k --norsrc --keepParent "${APP_PATH}" "${ZIP_PATH}"

rm -f -- "${DMG_PATH}"
COPYFILE_DISABLE=1 hdiutil create \
  -volname "${PRODUCT_NAME}" \
  -srcfolder "${APP_PATH}" \
  -ov \
  -format UDZO \
  "${DMG_PATH}" >/dev/null

(
  cd "${DIST_DIR}"
  shasum -a 256 "$(basename "${ZIP_PATH}")" "$(basename "${DMG_PATH}")" > "${CHECKSUM_PATH}"
)

echo "Packaged:"
echo "  ${ZIP_PATH}"
echo "  ${DMG_PATH}"
echo "  ${CHECKSUM_PATH}"
