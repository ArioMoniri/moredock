#!/usr/bin/env bash
set -euo pipefail

# Regenerates Resources/MoreDock.icns and Resources/AppIcon.png from the vector
# source Resources/AppIcon.svg. Run this on macOS after editing AppIcon.svg.
#
# Requires one SVG rasteriser on PATH:
#   - rsvg-convert   (brew install librsvg)      -- preferred, crispest output
#   - inkscape       (brew install inkscape)
# Falls back to qlmanage (built in) if neither is installed.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/.." && pwd)"
RES_DIR="${REPO_ROOT}/Resources"
SVG="${RES_DIR}/AppIcon.svg"
MASTER_PNG="${RES_DIR}/AppIcon.png"

if [[ ! -f "${SVG}" ]]; then
  echo "error: ${SVG} not found" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
trap 'rm -rf -- "${WORK_DIR}"' EXIT

render() { # render <size> <output>
  local size="$1" out="$2"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "${size}" -h "${size}" "${SVG}" -o "${out}"
  elif command -v inkscape >/dev/null 2>&1; then
    inkscape "${SVG}" --export-type=png --export-filename="${out}" \
      --export-width="${size}" --export-height="${size}" >/dev/null 2>&1
  else
    echo "warning: no rsvg-convert/inkscape found, using qlmanage (lower quality)" >&2
    qlmanage -t -s "${size}" -o "${WORK_DIR}" "${SVG}" >/dev/null 2>&1
    mv -- "${WORK_DIR}/$(basename -- "${SVG}").png" "${out}"
  fi
}

echo "Rendering master 1024x1024 icon..."
render 1024 "${MASTER_PNG}"

ICONSET="${WORK_DIR}/MoreDock.iconset"
mkdir -p -- "${ICONSET}"

echo "Building iconset..."
render 16   "${ICONSET}/icon_16x16.png"
render 32   "${ICONSET}/icon_16x16@2x.png"
render 32   "${ICONSET}/icon_32x32.png"
render 64   "${ICONSET}/icon_32x32@2x.png"
render 128  "${ICONSET}/icon_128x128.png"
render 256  "${ICONSET}/icon_128x128@2x.png"
render 256  "${ICONSET}/icon_256x256.png"
render 512  "${ICONSET}/icon_256x256@2x.png"
render 512  "${ICONSET}/icon_512x512.png"
render 1024 "${ICONSET}/icon_512x512@2x.png"

echo "Packing MoreDock.icns..."
iconutil -c icns "${ICONSET}" -o "${RES_DIR}/MoreDock.icns"

echo "Done:"
echo "  ${MASTER_PNG}"
echo "  ${RES_DIR}/MoreDock.icns"
