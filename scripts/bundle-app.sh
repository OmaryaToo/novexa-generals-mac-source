#!/usr/bin/env bash
# Builds the SwiftUI launcher (release, arm64) and assembles "NOVEXA Generals Mac.app",
# embedding any staged engines from build/runtime.noindex/.
set -eo pipefail
source "$(dirname "$0")/env.sh"
cd "$NOVEXA_ROOT/app"
swift build -c release --arch arm64
APP="$NOVEXA_ROOT/build/app.noindex/NOVEXA Generals Mac.app"
rm -rf "$APP"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"   # build/app.noindex: dev copy hidden from Spotlight
cp .build/arm64-apple-macosx/release/NovexaLauncher "$APP/Contents/MacOS/NOVEXA Generals Mac"
cp "$NOVEXA_ROOT/assets/branding/Info.plist" "$APP/Contents/Info.plist"
[[ -f "$NOVEXA_ROOT/assets/icons/AppIcon.icns" ]] && cp "$NOVEXA_ROOT/assets/icons/AppIcon.icns" "$APP/Contents/Resources/"
"$NOVEXA_ROOT/scripts/collect-licenses.sh"
cp -R "$NOVEXA_ROOT/build/legal" "$APP/Contents/Resources/Legal"
mkdir -p "$APP/Contents/Resources/Fonts"
cp "$NOVEXA_ROOT"/app/Sources/NovexaLauncher/Resources/Fonts/* "$APP/Contents/Resources/Fonts/"
for g in zeroHour generals; do
  if [[ -d "$NOVEXA_ROOT/build/runtime.noindex/$g" ]]; then
    mkdir -p "$APP/Contents/Resources/Engine"; cp -R "$NOVEXA_ROOT/build/runtime.noindex/$g" "$APP/Contents/Resources/Engine/"
  fi
done
codesign --force --deep --sign - "$APP" >/dev/null
echo "Built $APP"
