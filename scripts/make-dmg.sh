#!/usr/bin/env bash
# Builds the player installer: build/dist/NOVEXA-Generals-Mac-<version>.dmg
# (drag-to-Applications window with Novexa background + bilingual install guide).
set -eo pipefail
source "$(dirname "$0")/env.sh"
APP="$NOVEXA_ROOT/build/NOVEXA Generals Mac.app"
[[ -d "$APP" ]] || "$NOVEXA_ROOT/scripts/bundle-app.sh"
VER=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$APP/Contents/Info.plist")
NAME="NOVEXA Generals Mac"; DIST="$NOVEXA_ROOT/build/dist"; OUT="$DIST/NOVEXA-Generals-Mac-$VER.dmg"
WORK=$(mktemp -d); STAGE="$WORK/stage"; mkdir -p "$STAGE/.background" "$DIST"
ditto "$APP" "$STAGE/$NAME.app"
ln -s /Applications "$STAGE/Applications"
swift "$NOVEXA_ROOT/scripts/tools/make-dmg-background.swift" "$STAGE/.background/bg.png"
cp "$NOVEXA_ROOT/legal/INSTALL.txt" "$STAGE/Install guide - دليل التثبيت.txt"
hdiutil create -quiet -volname "$NAME" -srcfolder "$STAGE" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
MNT=$(hdiutil attach -readwrite -noverify -noautoopen "$WORK/rw.dmg" | awk -F'\t' '/\/Volumes\//{print $NF}')
# Window layout via Finder (best effort; the DMG still works if Automation access is denied).
osascript <<OSA || echo "note: Finder layout skipped"
tell application "Finder"
  tell disk "$NAME"
    open
    set current view of container window to icon view
    set toolbar visible of container window to false
    set statusbar visible of container window to false
    set the bounds of container window to {200, 120, 840, 520}
    set opts to the icon view options of container window
    set arrangement of opts to not arranged
    set icon size of opts to 112
    set background picture of opts to file ".background:bg.png"
    set position of item "$NAME.app" of container window to {170, 200}
    set position of item "Applications" of container window to {470, 200}
    set position of item "Install guide - دليل التثبيت.txt" of container window to {320, 330}
    close
  end tell
end tell
OSA
sync; hdiutil detach -quiet "$MNT"
rm -f "$OUT"; hdiutil convert -quiet "$WORK/rw.dmg" -format UDZO -imagekey zlib-level=9 -o "$OUT"
codesign --force --sign - "$OUT" 2>/dev/null || true
rm -rf "$WORK"
shasum -a 256 "$OUT" | tee "$OUT.sha256"
ls -lh "$OUT"
