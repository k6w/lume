#!/usr/bin/env bash
# Rasterize assets/app-icon.svg into AppIcon.appiconset PNGs at every
# size macOS expects. Tries `rsvg-convert` first (sharper anti-alias),
# falls back to `qlmanage` + `sips` which ship with macOS by default.
#
# Usage: ./scripts/generate-icons.sh
set -euo pipefail
cd "$(dirname "$0")/.."

SRC="assets/app-icon.svg"
DST="Lume/Lume/Resources/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "error: source $SRC missing" >&2
  exit 1
fi

mkdir -p "$DST"

# size:filename pairs (px : output)
SIZES=(
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

render() {
  local px="$1" out="$2"
  if command -v rsvg-convert >/dev/null 2>&1; then
    rsvg-convert -w "$px" -h "$px" "$SRC" -o "$DST/$out"
  else
    # Fallback: render large via qlmanage, then sips-resize.
    local tmp
    tmp="$(mktemp -d)"
    qlmanage -t -s 2048 -o "$tmp" "$SRC" >/dev/null 2>&1 || true
    local big
    big=$(ls "$tmp"/*.png 2>/dev/null | head -1 || true)
    if [[ -z "$big" ]]; then
      echo "error: cannot rasterize without rsvg-convert (install: brew install librsvg)" >&2
      rm -rf "$tmp"
      exit 1
    fi
    sips -z "$px" "$px" "$big" --out "$DST/$out" >/dev/null
    rm -rf "$tmp"
  fi
}

for entry in "${SIZES[@]}"; do
  px="${entry%%:*}"
  out="${entry##*:}"
  render "$px" "$out"
  echo "wrote $DST/$out (${px}x${px})"
done
