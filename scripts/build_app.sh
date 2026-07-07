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
SOURCE_RESOURCES_DIR="${REPO_ROOT}/Resources"
SOURCE_INFO_PLIST="${SOURCE_RESOURCES_DIR}/Info.plist"

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
mkdir -p -- "${MACOS_DIR}" "${APP_RESOURCES_DIR}"

cp -- "${SOURCE_INFO_PLIST}" "${CONTENTS_DIR}/Info.plist"
cp -- "${EXECUTABLE_PATH}" "${MACOS_DIR}/${PRODUCT_NAME}"
chmod 755 "${MACOS_DIR}/${PRODUCT_NAME}"

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

echo "Created ${APP_PATH}"
