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
[ -f Packaging/AppIcon.icns ] && cp Packaging/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns" && \
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "$APP/Contents/Info.plist"
codesign --force --deep --sign - "$APP"
codesign --verify --verbose "$APP"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
cp Packaging/ReadMeFirst.txt "$STAGE/Read Me First.txt"
hdiutil create -volname "Pomodoro City" -srcfolder "$STAGE" -ov -format UDZO "$OUT/PomodoroCity.dmg"
echo "Built $OUT/PomodoroCity.dmg"
