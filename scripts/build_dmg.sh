#!/bin/bash
#
# Build the VNC viewer app and package it as a .dmg on macOS.
#
# Usage:
#   ./scripts/build_dmg.sh              # build and package
#   ./scripts/build_dmg.sh --no-dmg     # build the .app only
#
# Requirements: Xcode command line tools (xcode-select --install) on macOS.
#
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

PROJECT="cotvnc/ChickenFork.xcodeproj"
SCHEME="VNC Viewer"
CONFIG="Deployment"
DERIVED="$ROOT/DerivedData"
DIST="$ROOT/dist"

MAKE_DMG=1
[ "${1:-}" = "--no-dmg" ] && MAKE_DMG=0

if [ "$(uname)" != "Darwin" ]; then
  echo "This script has to run on macOS (xcodebuild is not available on $(uname))." >&2
  echo "On Linux, use the GitHub Actions workflow instead: .github/workflows/build.yml" >&2
  exit 1
fi

echo "=== Toolchain ==="
xcodebuild -version
echo

echo "=== Build (universal: x86_64 + arm64) ==="
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -derivedDataPath "$DERIVED" \
  ONLY_ACTIVE_ARCH=NO \
  ARCHS="x86_64 arm64" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  clean build

APP_PATH="$(find "$DERIVED" -name "$SCHEME.app" -type d | head -n 1)"
if [ -z "$APP_PATH" ]; then
  echo "ERROR: $SCHEME.app was not produced by the build." >&2
  exit 1
fi
echo
echo "Built: $APP_PATH"
file "$APP_PATH/Contents/MacOS/"* 2>/dev/null | head -3
echo

if [ "$MAKE_DMG" = "0" ]; then
  echo "Skipping the DMG (--no-dmg)."
  exit 0
fi

echo "=== Ad-hoc signature ==="
codesign --force --deep --options runtime -s - \
  --entitlements cotvnc/Resources/ChickenFork.entitlements "$APP_PATH"
codesign --verify --deep --strict "$APP_PATH"
echo

echo "=== Package the DMG ==="
mkdir -p "$DIST"
VERSION="$(defaults read "$APP_PATH/Contents/Info.plist" CFBundleShortVersionString 2>/dev/null || echo "1.0")"
DMG="$DIST/VNC-Viewer-${VERSION}.dmg"
STAGING="$ROOT/dmg_staging"

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

rm -f "$DMG"
hdiutil create \
  -volname "VNC Viewer" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$DMG"

codesign --force -s - "$DMG" 2>/dev/null || true
rm -rf "$STAGING"

echo
echo "=== Verify the image mounts ==="
MOUNT_DIR="$(mktemp -d)"
hdiutil attach "$DMG" -mountpoint "$MOUNT_DIR" -nobrowse -readonly
ls -la "$MOUNT_DIR"
hdiutil detach "$MOUNT_DIR"
rmdir "$MOUNT_DIR"

echo
echo "=== Result ==="
ls -lh "$DMG"
shasum -a 256 "$DMG"
echo
echo "Done: $DMG"
echo "To install: open the DMG and drag the app into Applications."
echo "The app is not notarised, so macOS will ask you to confirm it the first"
echo "time: right-click the app -> Open -> Open."
