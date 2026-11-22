#!/usr/bin/env bash
# Build the GeneralsX engine (Zero Hour by default; pass "generals" for base game).
set -eo pipefail
source "$(dirname "$0")/env.sh"
TARGET="${1:-zh}"
"$NOVEXA_ROOT/scripts/apply-engine-patches.sh"
cd "$ENGINE_SRC"
mkdir -p "$NOVEXA_ROOT/build/logs"
if [[ ! -f build/macos-vulkan/build.ninja ]]; then
  # vcpkg's ffmpeg port rejects paths containing spaces, so vcpkg build trees,
  # packages and installed tree live in a space-free per-user cache directory.
  cmake --preset macos-vulkan \
    "-DVCPKG_INSTALL_OPTIONS=--x-buildtrees-root=$NOVEXA_CACHE/buildtrees;--x-packages-root=$NOVEXA_CACHE/packages" \
    "-DVCPKG_INSTALLED_DIR=$NOVEXA_CACHE/installed" 2>&1 | tee "$NOVEXA_ROOT/build/logs/configure.log"
fi
case "$TARGET" in
  zh) T=z_generals ;;
  generals) T=g_generals ;;
  *) T="$TARGET" ;;
esac
cmake --build build/macos-vulkan --target "$T" 2>&1 | tee "$NOVEXA_ROOT/build/logs/build_$T.log"
