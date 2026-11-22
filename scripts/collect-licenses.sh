#!/usr/bin/env bash
# Gathers every license that must ship with the app into build/legal/ (copied into the app bundle
# and each engine bundle by bundle-app.sh / stage-engine.sh). Fails if a required license is missing.
set -eo pipefail
source "$(dirname "$0")/env.sh"
OUT="$NOVEXA_ROOT/build/legal"; rm -rf "$OUT"; mkdir -p "$OUT/third-party"
B="$ENGINE_SRC/build/macos-vulkan/_deps"
V="$NOVEXA_CACHE/installed/arm64-osx/share"
F="$NOVEXA_ROOT/app/Sources/NovexaLauncher/Resources/Fonts"
missing=0
add() { # name, license-id, source file
  local name="$1" id="$2" src="$3"
  if [[ -f "$src" ]]; then cp "$src" "$OUT/third-party/$name.txt"; echo "| $name | $id | third-party/$name.txt |" >> "$OUT/.index"
  else echo "MISSING license for $name: $src" >&2; missing=1; fi
}
: > "$OUT/.index"
# Engine (GPL-3.0 + EA additional terms) — the main license of the game executables.
cp "$NOVEXA_ROOT/LICENSE" "$OUT/LICENSE-GeneralsX-GPL-3.0-with-EA-terms.txt"
# Bundled shared libraries
add "SDL3" "Zlib" "$B/sdl3-src/LICENSE.txt"
add "SDL3_image" "Zlib" "$B/sdl3_image-src/LICENSE.txt"
add "DXVK" "Zlib" "$B/dxvk-src-generalsx/LICENSE"
add "MoltenVK" "Apache-2.0" "$(brew --prefix molten-vk)/LICENSE"
add "Vulkan-Loader" "Apache-2.0" "$(brew --prefix vulkan-loader)/LICENSE.txt"
add "libpng" "libpng-2.0" "$(brew --prefix libpng)/LICENSE"
add "protobuf" "BSD-3-Clause" "$(brew --prefix protobuf)/LICENSE"
add "abseil-cpp" "Apache-2.0" "$(brew --prefix abseil)/LICENSE"
add "OpenSSL" "Apache-2.0" "$(brew --prefix openssl@3)/LICENSE.txt"
add "GameNetworkingSockets" "BSD-3-Clause" "$B/gamenetworkingsockets-src/LICENSE"
add "GameSpy-SDK" "BSD-3-Clause" "$B/gamespy-src/LICENSE"
# Statically linked into the engine
add "FFmpeg" "LGPL-2.1-or-later" "$V/ffmpeg/copyright"
add "curl" "curl" "$V/curl/copyright"
add "zlib" "Zlib" "$V/zlib/copyright"
add "freetype" "FTL" "$V/freetype/copyright"
add "fontconfig" "MIT-style" "$V/fontconfig/copyright"
add "expat" "MIT" "$V/expat/copyright"
add "brotli" "MIT" "$V/brotli/copyright"
add "bzip2" "bzip2-1.0.6" "$V/bzip2/copyright"
# libiconv: macOS system library (/usr/lib), not bundled. gettext: build tools only, not linked.
add "glm" "MIT" "$V/glm/copyright"
add "gli" "MIT" "$V/gli/copyright"
add "stb" "MIT or Public Domain" "$V/stb/copyright"
add "nlohmann-json" "MIT" "$B/json-src/LICENSE.MIT"
add "miniaudio" "MIT-0 or Public Domain" "$B/miniaudio-src/LICENSE"
add "GameMath" "see file" "$B/gamemath-src/LICENSE.md"
# LZH-Light keeps its permissive license in the header comment.
sed -n '1,40p' "$(ls "$B"/lzhl-src/CompLibHeader/*.h | head -1)" > "$OUT/third-party/LZH-Light.txt"; echo "| LZH-Light | permissive (header) | third-party/LZH-Light.txt |" >> "$OUT/.index"
# Launcher fonts
add "Font-Alexandria" "OFL-1.1" "$F/OFL-Alexandria.txt"
add "Font-InstrumentSans" "OFL-1.1" "$F/OFL-InstrumentSans.txt"
add "Font-IBMPlexMono" "OFL-1.1" "$F/OFL-IBMPlexMono.txt"
cp "$NOVEXA_ROOT/legal/NOTICE.md" "$OUT/NOTICE.md"
{ echo "# Third-party notices"; echo; echo "| Component | License | File |"; echo "|---|---|---|"; cat "$OUT/.index"; } > "$OUT/THIRD_PARTY_NOTICES.md"
rm "$OUT/.index"
[[ $missing == 0 ]] || { echo "ERROR: missing licenses (see above)"; exit 1; }
echo "Legal bundle: $OUT ($(ls "$OUT/third-party" | wc -l | tr -d ' ') third-party licenses)"
