#!/bin/bash
# Build GoblinCamp.app (no Xcode project needed): SwiftPM release build + hand-assembled bundle.
#   ./build.sh            quick build for this Mac
#   ./build.sh --release  universal build (Apple Silicon + Intel) and dist/GoblinCamp-<version>.zip to hand to others
set -euo pipefail
cd "$(dirname "$0")"

APP="GoblinCamp.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

if [ "${1:-}" = "--release" ]; then
    swift build -c release --arch arm64
    swift build -c release --arch x86_64
    lipo -create -output "$APP/Contents/MacOS/GoblinCamp" \
        "$(swift build -c release --arch arm64 --show-bin-path)/GoblinCamp" \
        "$(swift build -c release --arch x86_64 --show-bin-path)/GoblinCamp"
else
    swift build -c release
    cp "$(swift build -c release --show-bin-path)/GoblinCamp" "$APP/Contents/MacOS/GoblinCamp"
fi

cp Resources/Info.plist "$APP/Contents/Info.plist"
mkdir -p "$APP/Contents/Resources"
cp -R Resources/Characters "$APP/Contents/Resources/Characters"
cp -R Resources/Camps "$APP/Contents/Resources/Camps"
cp -R Resources/Animals "$APP/Contents/Resources/Animals"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - "$APP"
# let macOS know this copy handles goblincamp:// links (Claude Code hooks use them)
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP" >/dev/null 2>&1 || true
echo "Built $PWD/$APP ($(lipo -archs "$APP/Contents/MacOS/GoblinCamp"))"

if [ "${1:-}" = "--release" ]; then
    VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' Resources/Info.plist)"
    mkdir -p dist
    ZIP="dist/GoblinCamp-$VERSION.zip"
    rm -f "$ZIP"
    ditto -c -k --norsrc --noextattr --keepParent "$APP" "$ZIP"   # ditto keeps the app's permissions and signature intact (plain zip can break them)
    echo "Ready to share: $PWD/$ZIP ($(du -h "$ZIP" | cut -f1))"
fi
