#!/bin/bash
# Builds the macOS app from source with plain clang/swiftc — no Xcode needed.
#
#   scripts/build_native_app.sh
#
# Produces build/VNCViewerNative.app, which can be launched directly.
# This is the fallback for machines that have the Command Line Tools but no
# full Xcode (xcodebuild unavailable).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/cotvnc/Source"
BUILD="$ROOT/build"
OBJC="$BUILD/objc"
SWIFT="$BUILD/swift"
APP="$BUILD/VNCViewerNative.app"

mkdir -p "$OBJC" "$SWIFT" "$APP/Contents/MacOS" "$APP/Contents/Resources"

# --- 1. Source list, taken from the Xcode project's Sources build phase -----
awk '/PBXSourcesBuildPhase/,/end PBXSourcesBuildPhase/' \
    "$ROOT/cotvnc/ChickenFork.xcodeproj/project.pbxproj" \
  | grep -oE "[A-Za-z0-9_+-]+\.(m|c|swift) in Sources" \
  | sed 's/ in Sources//' | sort -u > "$BUILD/sources.txt"

OBJC_SRCS=()
SWIFT_SRCS=()
while read -r f; do
    case "$f" in
        *.swift) SWIFT_SRCS+=("$SRC/$f") ;;
        *)       OBJC_SRCS+=("$SRC/$f") ;;
    esac
done < "$BUILD/sources.txt"

# --- 2. Swift part ---------------------------------------------------------
echo "--- compiling Swift ---"
swiftc -emit-objc-header -emit-module -emit-library -static \
    -module-name ChickenFork -O \
    "${SWIFT_SRCS[@]}" \
    -o "$SWIFT/libChickenForkSwift.a" \
    -emit-objc-header-path "$SWIFT/ChickenFork-Swift.h"

# --- 3. Objective-C part ---------------------------------------------------
echo "--- compiling Objective-C ---"
cd "$OBJC"
rm -f ./*.o
clang -x objective-c \
    -I "$SRC" -I "$SWIFT" \
    -I "$ROOT/cotvnc/freerdp/include/freerdp3" \
    -I "$ROOT/cotvnc/freerdp/include" \
    -c "${OBJC_SRCS[@]}"

# --- 4. Link ---------------------------------------------------------------
echo "--- linking ---"
clang -o "$APP/Contents/MacOS/VNC Viewer" ./*.o \
    "$SWIFT/libChickenForkSwift.a" \
    "$ROOT/cotvnc/freerdp/lib/libfreerdp3.a" \
    "$ROOT/cotvnc/freerdp/lib/libfreerdp-client3.a" \
    "$ROOT/cotvnc/freerdp/lib/libwinpr3.a" \
    "$ROOT/cotvnc/freerdp/lib/libssl.a" \
    "$ROOT/cotvnc/freerdp/lib/libcrypto.a" \
    "$ROOT/cotvnc/libjpeg-turbo/lib/libturbojpeg.a" \
    -framework Foundation -framework AppKit -framework Security \
    -framework CoreGraphics -framework CoreServices -framework Carbon \
    -framework VideoToolbox -framework AVFoundation -framework CoreMedia \
    -framework IOKit -framework Network -framework AudioToolbox \
    -framework CoreAudio \
    -lz -liconv

# --- 5. Bundle -------------------------------------------------------------
cp "$ROOT/cotvnc/Resources/Info.plist" "$APP/Contents/Info.plist"
plutil -replace CFBundleExecutable -string "VNC Viewer" "$APP/Contents/Info.plist"
plutil -replace CFBundleIdentifier -string "ru.gsky.vncviewer.native" "$APP/Contents/Info.plist"
plutil -replace CFBundleName -string "VNC Viewer Native" "$APP/Contents/Info.plist"
plutil -replace CFBundleDisplayName -string "VNC Viewer Native" "$APP/Contents/Info.plist"

cp -R "$ROOT/cotvnc/Resources/Base.lproj" "$APP/Contents/Resources/"
for f in icon.icns cursors.plist rfbCursor.tiff rfbCursor2.tiff rfbCursor3.tiff ssh-helper.sh; do
    [ -f "$ROOT/cotvnc/Resources/$f" ] && cp "$ROOT/cotvnc/Resources/$f" "$APP/Contents/Resources/"
done

# Compiled nibs: ibtool is not part of the Command Line Tools, so reuse the
# ones from an installed build of the same sources when available.
INSTALLED_NIBS="/Applications/VNC Viewer.app/Contents/Resources/Base.lproj"
if [ -d "$INSTALLED_NIBS" ]; then
    cp "$INSTALLED_NIBS"/*.nib "$APP/Contents/Resources/Base.lproj/" 2>/dev/null || true
fi

codesign -s - --force --deep "$APP"

echo "built: $APP"
