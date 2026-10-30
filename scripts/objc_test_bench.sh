#!/bin/bash
# Local Objective-C test bench.
#
# The macOS app cannot be compiled on this Linux host, but the portable parts
# (connection-file parsing, address book, profile model) can: GNUstep provides
# Foundation, and zig's clang cross-compiler builds Objective-C.
#
# The runtime is expected to be unpacked under ./.objcbench/root (see
# scripts/objc_test_bench_setup.sh). This script only compiles and runs.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BENCH="$ROOT/.objcbench"
PREFIX="$BENCH/root"
ZIG="/opt/data/.venv-search/bin/python -m ziglang cc"

INC="$PREFIX/usr/include/x86_64-linux-gnu/GNUstep"
OBJCINC="$PREFIX/usr/lib/gcc/x86_64-linux-gnu/14/include"
LIB="$PREFIX/usr/lib/x86_64-linux-gnu"

if [ ! -d "$INC" ]; then
  echo "GNUstep runtime missing under $PREFIX - run scripts/objc_test_bench_setup.sh" >&2
  exit 1
fi

export LD_LIBRARY_PATH="$LIB:${LD_LIBRARY_PATH:-}"

build_and_run() {
  local name="$1"; shift
  local out="$BENCH/$name"
  $ZIG -x objective-c -fobjc-runtime=gcc -fconstant-string-class=NSConstantString \
    -I "$INC" -I "$INC/Foundation" -I "$OBJCINC" \
    -I "$ROOT/cotvnc/Source" \
    "$@" -o "$out" \
    -L "$LIB" -Wl,-rpath,"$LIB" -lgnustep-base -lobjc
  echo "--- running $name ---"
  "$out"
}

case "${1:-}" in
  --profile-tests)
    shift
    build_and_run vnc_profile_tests \
      "$ROOT/tests/test_vnc_connection_profile.m" \
      "$ROOT/cotvnc/Source/VNCConnectionProfile.m"
    ;;
  --build-only)
    shift
    build_and_run "$@"
    ;;
  *)
    build_and_run vnc_profile_tests \
      "$ROOT/tests/test_vnc_connection_profile.m" \
      "$ROOT/cotvnc/Source/VNCConnectionProfile.m"
    ;;
esac
