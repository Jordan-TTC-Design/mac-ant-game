#!/bin/bash
# Build GoblinCamp.app (no Xcode project needed): SwiftPM release build + hand-assembled bundle.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release
BIN="$(swift build -c release --show-bin-path)/GoblinCamp"

APP="GoblinCamp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp "$BIN" "$APP/Contents/MacOS/GoblinCamp"
cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/Characters "$APP/Contents/Resources/Characters"
cp -R Resources/Camps "$APP/Contents/Resources/Camps"
cp -R Resources/Animals "$APP/Contents/Resources/Animals"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
# let macOS know this copy handles goblincamp:// links (Claude Code hooks use them)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true
echo "Built $PWD/$APP"
