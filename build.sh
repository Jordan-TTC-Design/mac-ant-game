#!/bin/bash
# Build GoblinCamp.app (no Xcode project needed): SwiftPM release build + hand-assembled bundle.
#   ./build.sh                    quick build for this Mac
#   ./build.sh --release          universal build (Apple Silicon + Intel), dist/GoblinCamp-<version>.zip and dist/version.json
#   ./build.sh --release "說明"    same, with the release notes the in-app updater shows
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
cp -R Resources/Scenery "$APP/Contents/Resources/Scenery"
cp -R Resources/Terrain "$APP/Contents/Resources/Terrain"
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

    # The feed the in-app updater reads: a plain file uploaded next to the zip, so there is no server to run.
    REPO="Jordan-TTC-Design/mac-ant-game"
    TAG="v$VERSION"
    NOTES="${2:-$(git log -1 --pretty=%s 2>/dev/null || echo "")}"
    SHA="$(shasum -a 256 "$ZIP" | cut -d' ' -f1)"
    MIN="$(/usr/libexec/PlistBuddy -c 'Print LSMinimumSystemVersion' Resources/Info.plist)"
    VERSION="$VERSION" URL="https://github.com/$REPO/releases/download/$TAG/GoblinCamp-$VERSION.zip" \
        NOTES="$NOTES" SHA="$SHA" MIN="$MIN" /usr/bin/python3 -c '
import json, os
keys = ["version", "url", "notes", "sha256", "minimumSystemVersion"]
env = ["VERSION", "URL", "NOTES", "SHA", "MIN"]
print(json.dumps(dict(zip(keys, (os.environ[e] for e in env))), ensure_ascii=False, indent=2))
' > dist/version.json
    echo "Wrote $PWD/dist/version.json (sha256 ${SHA:0:12}...)"
    echo
    echo "Publish it so everyone's app finds it:"
    if command -v gh >/dev/null 2>&1; then
        echo "  gh release create $TAG \"$ZIP\" dist/version.json --title \"$TAG\" --notes \"$NOTES\""
    else
        echo "  1. git tag $TAG && git push origin $TAG"
        echo "  2. open https://github.com/$REPO/releases/new?tag=$TAG"
        echo "  3. attach BOTH $ZIP and dist/version.json, then publish"
        echo "  (or install the GitHub CLI once: brew install gh)"
    fi
fi
