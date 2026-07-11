#!/usr/bin/env bash
set -euo pipefail

PRODUCT_NAME="MoreDock"
CONFIGURATION="${CONFIGURATION:-release}"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"

APP_PATH="${APP_PATH:-"${REPO_ROOT}/.build/${PRODUCT_NAME}.app"}"
CONTENTS_DIR="${APP_PATH}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
APP_RESOURCES_DIR="${CONTENTS_DIR}/Resources"
FRAMEWORKS_DIR="${CONTENTS_DIR}/Frameworks"
SOURCE_RESOURCES_DIR="${REPO_ROOT}/Resources"
SOURCE_INFO_PLIST="${SOURCE_RESOURCES_DIR}/Info.plist"
SPARKLE_FRAMEWORK="${REPO_ROOT}/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"

if ! command -v swift >/dev/null 2>&1; then
  echo "error: swift is not available on PATH" >&2
  exit 1
fi

if [[ ! -f "${REPO_ROOT}/Package.swift" ]]; then
  echo "error: Package.swift not found at ${REPO_ROOT}" >&2
  exit 1
fi

if [[ ! -f "${SOURCE_INFO_PLIST}" ]]; then
  echo "error: Info.plist not found at ${SOURCE_INFO_PLIST}" >&2
  exit 1
fi

echo "Building ${PRODUCT_NAME} (${CONFIGURATION})..."
swift build \
  --package-path "${REPO_ROOT}" \
  --configuration "${CONFIGURATION}" \
  --product "${PRODUCT_NAME}"

BIN_DIR="$(swift build \
  --package-path "${REPO_ROOT}" \
  --configuration "${CONFIGURATION}" \
  --show-bin-path)"
EXECUTABLE_PATH="${BIN_DIR}/${PRODUCT_NAME}"

if [[ ! -x "${EXECUTABLE_PATH}" ]]; then
  echo "error: executable not found at ${EXECUTABLE_PATH}" >&2
  exit 1
fi

echo "Assembling ${APP_PATH}..."
rm -rf -- "${APP_PATH}"
mkdir -p -- "${MACOS_DIR}" "${APP_RESOURCES_DIR}" "${FRAMEWORKS_DIR}"

cp -- "${SOURCE_INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
cp -- "${EXECUTABLE_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
chmod 755 "${MACOS_DIR}/${PRODUCT_NAME}"

if [[ -d "${SPARKLE_FRAMEWORK}" ]]; then
  cp -R -- "${SPARKLE_FRAMEWORK}" "${FRAMEWORKS_DIR}/Sparkle.framework"
  install_name_tool -add_rpath "@loader_path/../Frameworks" "${MACOS_DIR}/${PRODUCT_NAME}" 2>/dev/null || true
fi

if [[ -d "${SOURCE_RESOURCES_DIR}" ]]; then
  while IFS= read -r -d '' item; do
    rel_path="${item#"${SOURCE_RESOURCES_DIR}/"}"
    if [[ "${rel_path}" == "Info.plist" ]]; then
      continue
    fi

    if [[ -d "${item}" ]]; then
      mkdir -p -- "${APP_RESOURCES_DIR}/${rel_path}"
    else
      mkdir -p -- "$(dirname -- "${APP_RESOURCES_DIR}/${rel_path}")"
      cp -R -- "${item}" "${APP_RESOURCES_DIR}/${rel_path}"
    fi
  done < <(find "${SOURCE_RESOURCES_DIR}" -mindepth 1 -print0)
fi

# Code-sign the assembled bundle. macOS will not retain an Accessibility (TCC)
# grant for an unsigned app, which makes it re-prompt on every launch. Ad-hoc
# signing lets a local build keep the grant for the life of that build.
#
# The release pipeline (package_release.sh) signs the bundle itself, so it sets
# SKIP_BUILD_APP_SIGN to avoid signing twice (a double sign here races the later
# hdiutil DMG step). This block only runs for standalone `build_app.sh` dev builds.
if [[ -z "${SKIP_BUILD_APP_SIGN:-}" ]] && command -v codesign >/dev/null 2>&1; then
  if [[ -n "${CODESIGN_IDENTITY:-}" ]]; then
    codesign --force --deep --options runtime --timestamp --sign "${CODESIGN_IDENTITY}" "${APP_PATH}"
  else
    codesign --force --deep --sign - "${APP_PATH}"
  fi
  xattr -cr "${APP_PATH}" 2>/dev/null || true
fi

echo "Created ${APP_PATH}"
