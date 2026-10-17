#!/bin/bash
# Builds "Pomodoro City.app" from the SwiftPM release binary and wraps it in a DMG.
set -euo pipefail
VERSION="${VERSION:-0.0.0}"; BUILD="${BUILD:-0}"
OUT=build; APP="$OUT/Pomodoro City.app"; STAGE="$OUT/dmg"
rm -rf "$OUT"; mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGE"
swift build -c release
BIN="$(swift build -c release --show-bin-path)/PomodoroCity"
cp "$BIN" "$APP/Contents/MacOS/PomodoroCity"
sed -e "s/__VERSION__/$VERSION/" -e "s/__BUILD__/$BUILD/" Packaging/Info.plist > "$APP/Contents/Info.plist"
if [ -f Packaging/AppIcon.png ]; then
  ICONSET="$OUT/AppIcon.iconset"; mkdir -p "$ICONSET"
  for s in 16 32 128 256 512; do
    sips -z $s $s Packaging/AppIcon.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
    sips -z $((s*2)) $((s*2)) Packaging/AppIcon.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
  done
  iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/AppIcon.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
fi
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Packaging/ReadMeFirst.txt "$STAGE/Read Me First.txt"
hdiutil create -volname "Pomodoro City" -srcfolder "$STAGE" -ov -format UDZO "$OUT/PomodoroCity.dmg"
echo "Built $OUT/PomodoroCity.dmg"
