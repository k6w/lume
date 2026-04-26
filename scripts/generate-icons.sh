#!/usr/bin/env bash
# Rasterize assets/logo-mark.svg into AppIcon.appiconset PNGs at every
# size macOS expects. Requires `rsvg-convert` (brew install librsvg).
#
# Usage: ./scripts/generate-icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="assets/logo-mark.svg"
DST="Lume/Lume/Resources/Assets.xcassets/AppIcon.appiconset"

if ! command -v rsvg-convert >/dev/null 2>&1; then
  echo "error: rsvg-convert not found. Install with: brew install librsvg" >&2
  exit 1
fi

declare -a SIZES=(
  "16:icon_16x16.png"
  "32:icon_16x16@2x.png"
  "32:icon_32x32.png"
  "64:icon_32x32@2x.png"
  "128:icon_128x128.png"
  "256:icon_128x128@2x.png"
  "256:icon_256x256.png"
  "512:icon_256x256@2x.png"
  "512:icon_512x512.png"
  "1024:icon_512x512@2x.png"
)

for entry in "${SIZES[@]}"; do
  px="${entry%%:*}"
  out="${entry##*:}"
  rsvg-convert -w "$px" -h "$px" "$SRC" -o "$DST/$out"
  echo "wrote $DST/$out (${px}x${px})"
done
