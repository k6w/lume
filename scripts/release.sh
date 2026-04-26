#!/usr/bin/env bash
# Build a release artifact for GitHub Releases. Unsigned. Not notarized.
# Users bypass Gatekeeper via `xattr -dr com.apple.quarantine`.
#
# Usage: ./scripts/release.sh 0.1.0
set -euo pipefail
cd "$(dirname "$0")/.."

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "usage: $0 <version>  (e.g. 0.1.0)" >&2
  exit 1
fi

PROJECT="Lume/Lume.xcodeproj"
SCHEME="Lume"
BUILD_DIR="build/release"
DIST_DIR="dist"
APP_NAME="Lume.app"

if [[ ! -d "$PROJECT" ]]; then
  echo "Generating Xcode project with XcodeGen…"
  command -v xcodegen >/dev/null 2>&1 || { echo "install xcodegen: brew install xcodegen" >&2; exit 1; }
  xcodegen generate -s Lume/project.yml
fi

rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$BUILD_DIR" "$DIST_DIR"

xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$BUILD_DIR" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$VERSION" \
  build

APP_PATH="$BUILD_DIR/Build/Products/Release/$APP_NAME"
if [[ ! -d "$APP_PATH" ]]; then
  echo "build did not produce $APP_PATH" >&2
  exit 1
fi

# Re-sign ad-hoc (so the binary launches without "damaged" warnings even
# without a Developer ID; the user still has to bypass Gatekeeper once).
codesign --force --deep --sign - "$APP_PATH"

ZIP="$DIST_DIR/Lume-$VERSION.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP"

# Cheap DMG via hdiutil; a fancy create-dmg layout can come later.
DMG="$DIST_DIR/Lume-$VERSION.dmg"
STAGE="$DIST_DIR/dmg-stage"
mkdir -p "$STAGE"
cp -R "$APP_PATH" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
hdiutil create -volname "Lume $VERSION" -srcfolder "$STAGE" -ov -format UDZO "$DMG"
rm -rf "$STAGE"

(cd "$DIST_DIR" && shasum -a 256 "Lume-$VERSION.zip" "Lume-$VERSION.dmg") > "$DIST_DIR/SHA256SUMS"

echo
echo "Release artifacts:"
echo "  $ZIP"
echo "  $DMG"
echo "  $DIST_DIR/SHA256SUMS"
