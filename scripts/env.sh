#!/usr/bin/env bash
# Shared build environment for NOVEXA Generals Mac. Source this file.
# Must be sourced from bash (scripts use #!/usr/bin/env bash).
if [[ -z "${BASH_SOURCE[0]:-}" ]]; then echo "env.sh: source from bash" >&2; return 1; fi
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -d "$ROOT/engine/upstream/GeneralsX" ]] || { echo "env.sh: bad project root $ROOT" >&2; return 1; }
export NOVEXA_ROOT="$ROOT"
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
ln -sfn "$ROOT/engine/deps" "$HOME/Library/Caches/com.novexa.generalsmac/deps"
export VCPKG_ROOT="$HOME/Library/Caches/com.novexa.generalsmac/deps/vcpkg"
export VCPKG_DISABLE_METRICS=1
export VULKAN_SDK="$HOME/Library/Caches/com.novexa.generalsmac/deps/vulkan-sdk/macOS"
export VK_ICD_FILENAMES="$VULKAN_SDK/share/vulkan/icd.d/MoltenVK_icd.json"
# Many third-party build scripts (FFmpeg, SDL3_image, Meson) break on paths containing
# spaces. The engine is therefore always built through a space-free symlink.
export NOVEXA_CACHE_ROOT="$HOME/Library/Caches/com.novexa.generalsmac"
mkdir -p "$NOVEXA_CACHE_ROOT"
ln -sfn "$ROOT/engine/upstream/GeneralsX" "$NOVEXA_CACHE_ROOT/GeneralsX"
export ENGINE_SRC="$NOVEXA_CACHE_ROOT/GeneralsX"
export NOVEXA_CACHE="$HOME/Library/Caches/com.novexa.generalsmac/vcpkg"
mkdir -p "$NOVEXA_CACHE"
