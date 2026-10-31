#!/bin/bash
# Builds and runs the native macOS integration test for the RealVNC
# import/export bridge.
#
#   scripts/build_integration_test.sh
#
# The test links the app's own server model (ServerDataManager,
# ServerFromPrefs, Profile, …) against the import/export bridge, so it
# exercises the real code paths, not a re-implementation.
#
# Requires only the Command Line Tools (clang + Foundation + AppKit).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT/cotvnc/Source"
BUILD="$ROOT/build"
OBJC="$BUILD/objc"
SWIFT="$BUILD/swift"

if [ ! -d "$OBJC" ] || [ ! -d "$SWIFT" ]; then
    echo "run scripts/build_native_app.sh first" >&2
    exit 1
fi

OBJ_FILES=()
for f in "$OBJC"/*.o; do
    case "$(basename "$f")" in
        VNCViewer_main.o) continue ;;
        # Replaced by the in-memory stub, so that the test never triggers a
        # SecurityAgent prompt for the user's login keychain.
        KeyChain.o) continue ;;
    esac
    OBJ_FILES+=("$f")
done

LIBS=(
    "$SWIFT/libChickenForkSwift.a"
    "$ROOT/cotvnc/freerdp/lib/libfreerdp3.a"
    "$ROOT/cotvnc/freerdp/lib/libfreerdp-client3.a"
    "$ROOT/cotvnc/freerdp/lib/libwinpr3.a"
    "$ROOT/cotvnc/freerdp/lib/libssl.a"
    "$ROOT/cotvnc/freerdp/lib/libcrypto.a"
    "$ROOT/cotvnc/libjpeg-turbo/lib/libturbojpeg.a"
)

FRAMEWORKS=(
    -framework Foundation -framework AppKit -framework Security
    -framework CoreGraphics -framework CoreServices -framework Carbon
    -framework VideoToolbox -framework AVFoundation -framework CoreMedia
    -framework IOKit -framework Network -framework AudioToolbox
    -framework CoreAudio
)

clang -x objective-c \
    -I "$SRC" -I "$SWIFT" \
    -c "$ROOT/tests/test_vnc_integration.m" \
    -o "$BUILD/test_vnc_integration.o"

clang -x objective-c \
    -I "$SRC" -I "$SWIFT" \
    -c "$ROOT/tests/KeyChainStub.m" \
    -o "$BUILD/KeyChainStub.o"

clang -o "$BUILD/integration_tests" \
    "$BUILD/test_vnc_integration.o" \
    "$BUILD/KeyChainStub.o" \
    "${OBJ_FILES[@]}" \
    "${LIBS[@]}" \
    "${FRAMEWORKS[@]}" \
    -lz -liconv

echo "--- running integration tests ---"
"$BUILD/integration_tests"
