#!/bin/bash
# Build a signed Tinycast.app and pack it into build/Tinycast-<version>.dmg. Usage: ./build-dmg.sh [version]
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"; cd "$ROOT"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
IDENTITY="Tinycast Self-Signed"
DERIVED="build/DerivedData"

if ! security find-identity -p codesigning | grep -q "$IDENTITY"; then
    echo "✗ '$IDENTITY' code-signing identity not found — create it once (docs/signing.md)." >&2
    exit 1
fi

echo "▸ Building signed Tinycast.app (Release, arm64 + x86_64)…"
xcodebuild -project Tinycast.xcodeproj -scheme Tinycast -configuration Release \
    -derivedDataPath "$DERIVED" \
    ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY="$IDENTITY" OTHER_CODE_SIGN_FLAGS="--timestamp=none" \
    ${1:+MARKETING_VERSION="$1"} \
    build

APP="$DERIVED/Build/Products/Release/Tinycast.app"
BIN="$APP/Contents/MacOS/Tinycast"
ARCHS_BUILT="$(lipo -archs "$BIN")"
for WANT in arm64 x86_64; do
    case " $ARCHS_BUILT " in
        *" $WANT "*) ;;
        *) echo "✗ Missing $WANT slice; built: $ARCHS_BUILT" >&2; exit 1 ;;
    esac
done
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="build/Tinycast-${VERSION}.dmg"

echo "▸ Packaging ${DMG}"
STAGE="$(mktemp -d)"
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
diskutil image create from "$STAGE" --format UDZO --volumeName "Tinycast" "$DMG" >/dev/null
rm -rf "$STAGE"

echo "✓ $DMG"
