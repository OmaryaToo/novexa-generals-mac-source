#!/usr/bin/env bash
# Packages a built GeneralsX engine as a small macOS app bundle so the Dock shows a proper
# name and icon while the game runs:
#   build/runtime/<game>/<Name>.app/Contents/{MacOS: engine + dylibs, Resources: configs + icon}
# No game data is copied: the launcher passes the user's folder via -assetPath.
set -eo pipefail
source "$(dirname "$0")/env.sh"
GAME="${1:-zeroHour}"
B="$ENGINE_SRC/build/macos-vulkan"
case "$GAME" in
  zeroHour) BIN="$B/GeneralsMD/GeneralsXZH"; NAME="NOVEXA ZH"; BID=zerohour ;;
  generals) BIN="$B/Generals/GeneralsX"; NAME="NOVEXA Classic"; BID=generals ;;
  *) echo "usage: $0 zeroHour|generals"; exit 2 ;;
esac
ROOTOUT="$NOVEXA_ROOT/build/runtime/$GAME"
APPB="$ROOTOUT/$NAME.app"
OUT="$APPB/Contents/MacOS"
RES="$APPB/Contents/Resources"
[[ -s "$BIN" ]] || { echo "Engine binary not built: $BIN"; exit 1; }
rm -rf "$ROOTOUT"; mkdir -p "$OUT" "$RES"
cp "$BIN" "$OUT/"
cp "$B"/_deps/sdl3-build/libSDL3.0.dylib "$OUT/"
cp "$B"/_deps/sdl3_image-build/libSDL3_image*.dylib "$OUT/" 2>/dev/null || true
cp "$B"/libgamespy.dylib "$OUT/" 2>/dev/null || true
cp "$B"/bin/libGameNetworkingSockets.dylib "$OUT/" 2>/dev/null || true
cp "$B"/libdxvk_d3d8.0.dylib "$B"/libdxvk_d3d9.0.dylib "$OUT/"
cp -L "$VULKAN_SDK/lib/libvulkan.1.dylib" "$OUT/"
cp -L "$VULKAN_SDK/lib/libMoltenVK.dylib" "$OUT/"
( cd "$OUT"; ln -sf libSDL3.0.dylib libSDL3.dylib; ln -sf libdxvk_d3d8.0.dylib libdxvk_d3d8.dylib
  ln -sf libdxvk_d3d9.0.dylib libdxvk_d3d9.dylib; ln -sf libvulkan.1.dylib libvulkan.dylib
  for f in libSDL3_image.*.*.*.dylib; do [[ -e "$f" ]] && ln -sf "$f" libSDL3_image.0.dylib; done; true )
# library_path is relative to this JSON file (Contents/Resources → Contents/MacOS)
cat > "$RES/MoltenVK_icd.json" <<'J'
{ "file_format_version": "1.0.0",
  "ICD": { "library_path": "../MacOS/libMoltenVK.dylib", "api_version": "1.4.0", "is_portability_driver": true } }
J
[[ -f "$ENGINE_SRC/resources/dxvk/dxvk.conf" ]] && cp "$ENGINE_SRC/resources/dxvk/dxvk.conf" "$RES/" || true
FC="$NOVEXA_CACHE/installed/arm64-osx/etc/fonts"
if [[ -d "$FC" ]]; then
  mkdir -p "$RES/fontconfig"; cp -R "$FC"/. "$RES/fontconfig/"
  # Never cache inside the (signed, possibly read-only) bundle: drop relative cachedirs and keep
  # only the XDG one; the launcher points XDG_CACHE_HOME at Application Support/.../Cache.
  sed -i '' -E '/<cachedir>\.\/|<cachedir>~\/\.fontconfig/d' "$RES/fontconfig/fonts.conf"
fi
( cd "$ENGINE_SRC"; echo "GeneralsX $(git rev-parse --short HEAD) ($(git log -1 --format=%cs))" ) > "$RES/ENGINE_VERSION"
cp "$NOVEXA_ROOT/assets/icons/Engine-$GAME.icns" "$RES/AppIcon.icns"
"$NOVEXA_ROOT/scripts/collect-licenses.sh" >/dev/null
cp -R "$NOVEXA_ROOT/build/legal" "$RES/Legal"
cat > "$APPB/Contents/Info.plist" <<P
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>com.novexa.generalsmac.$BID</string>
  <key>CFBundleName</key><string>$NAME</string>
  <key>CFBundleDisplayName</key><string>$NAME</string>
  <key>CFBundleExecutable</key><string>$(basename "$BIN")</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>0.1.0</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.strategy-games</string>
  <key>NSHighResolutionCapable</key><true/>
</dict></plist>
P

# ── Portability: make the runtime self-contained (no /opt/homebrew or build-dir paths) ──
cp -L /opt/homebrew/opt/libpng/lib/libpng16.16.dylib "$OUT/"
EXE="$OUT/$(basename "$BIN")"
# Recursively bundle every Homebrew dependency (protobuf/abseil for GameNetworkingSockets, etc.).
while :; do
  added=0
  for f in "$EXE" "$OUT"/*.dylib; do
    [[ -L "$f" ]] && continue
    while read -r dep; do
      [[ -z "$dep" ]] && continue
      name=$(basename "$dep")
      if [[ ! -e "$OUT/$name" ]]; then cp -L "$dep" "$OUT/$name"; chmod u+w "$OUT/$name"; added=1; fi
    done < <(otool -L "$f" | tail -n +2 | awk '{print $1}' | { grep -E '^(/opt/homebrew|/usr/local)/' || true; })
    # @rpath deps that only resolve through a Homebrew rpath
    while read -r dep; do
      [[ -z "$dep" ]] && continue
      name=${dep#@rpath/}
      if [[ ! -e "$OUT/$name" ]]; then
        for d in /opt/homebrew/lib /opt/homebrew/opt/*/lib; do
          if [[ -e "$d/$name" ]]; then cp -L "$d/$name" "$OUT/$name"; chmod u+w "$OUT/$name"; added=1; break; fi
        done
      fi
    done < <(otool -L "$f" | tail -n +2 | awk '{print $1}' | { grep -E '^@rpath/' || true; })
  done
  [[ $added == 0 ]] && break
done
chmod u+w "$OUT"/*.dylib
for f in "$OUT"/*.dylib; do [[ -L "$f" ]] || install_name_tool -id "@rpath/$(basename "$f")" "$f" 2>/dev/null; done
install_name_tool -id @rpath/libpng16.16.dylib "$OUT/libpng16.16.dylib"
install_name_tool -id @rpath/libvulkan.1.dylib "$OUT/libvulkan.1.dylib"
install_name_tool -id @rpath/libMoltenVK.dylib "$OUT/libMoltenVK.dylib"
for f in "$EXE" "$OUT"/*.dylib; do
  [[ -L "$f" ]] && continue
  otool -L "$f" | tail -n +2 | awk '{print $1}' | { grep -E '^(/opt/homebrew|/usr/local)/' || true; } | while read -r dep; do
    install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$f" 2>/dev/null
  done
  otool -l "$f" | awk '/LC_RPATH/{getline;getline;print $2}' | { grep -vE '^@' || true; } | while read -r rp; do
    install_name_tool -delete_rpath "$rp" "$f" 2>/dev/null
  done
done
for f in "$OUT"/*.dylib; do [[ -L "$f" ]] || { otool -l "$f" | grep -q "@loader_path$" || install_name_tool -add_rpath @loader_path "$f" 2>/dev/null || true; }; done
otool -l "$EXE" | grep -q "@executable_path" || install_name_tool -add_rpath @executable_path "$EXE"
for f in "$OUT"/*.dylib; do [[ -L "$f" ]] || codesign --force --sign - "$f" 2>/dev/null; done
codesign --force --sign - "$APPB"
if otool -L "$EXE" "$OUT"/*.dylib | grep -E '/opt/homebrew|/usr/local|com.novexa.generalsmac'; then
  echo "ERROR: runtime still references build-machine paths"; exit 1
fi
echo "Staged $GAME engine to $APPB"; file "$EXE"; codesign -v "$APPB" && echo "signature ok"
