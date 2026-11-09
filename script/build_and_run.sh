#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:---verify}"
case "$mode" in run|--verify|verify|--debug|debug|--logs|logs|--telemetry|telemetry|--install|install|--package|package) ;; *) echo "Usage: $0 [--verify|--install|--package|--debug|--logs]" >&2; exit 2 ;; esac
name=DuoDeckHost
app="$PWD/dist/DuoDeck Host.app"
stage="$PWD/dist/.DuoDeck Host.partial.app"
swift build -c release --product SillMenuBar --arch arm64 --arch x86_64 -j 2
binary="$(swift build -c release --product SillMenuBar --arch arm64 --arch x86_64 --show-bin-path)/SillMenuBar"
test -x "$binary"
rm -rf "$stage"
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources"
# SwiftPM may record the deployment target as its SDK. Link metadata must name the
# installed SDK so AppKit and SwiftUI use the current native control appearance.
minos="$(xcrun vtool -show-build "$binary" | awk '$1 == "minos" && !found { print $2; found = 1 }')"
xcrun vtool -set-build-version macos "${minos:?Missing deployment target}" \
  "$(xcrun --sdk macosx --show-sdk-version)" -output "$stage/Contents/MacOS/$name" "$binary"
cp Packaging/Info.plist "$stage/Contents/Info.plist"
if [ -n "${DUODECK_BUILD_NUMBER:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $DUODECK_BUILD_NUMBER" "$stage/Contents/Info.plist"; fi
cp LICENSE NOTICE "$stage/Contents/Resources/"
icon_resources="$(bash script/build_icons.sh)"
cp "$icon_resources/Assets.car" "$icon_resources/AppIcon.icns" "$stage/Contents/Resources/"
identity="${DUODECK_SIGN_ID:-}"
if [ -z "$identity" ]; then
  identity="$(security find-identity -v -p codesigning | awk '/Developer ID Application: Agents AI Ltd/ && !/REVOKED/ {print $2; exit}')"
fi
if [ -z "$identity" ]; then
  identity="$(security find-identity -v -p codesigning | awk '/Apple Development:/ && !/REVOKED/ {print $2; exit}')"
fi
test -n "$identity" || { echo "No valid signing identity found." >&2; exit 1; }
# This privileged companion is distributed outside the Mac App Store. It uses
# the login keychain unless it holds its own provisioned access-group entitlement.
# Never reuse upstream's restricted team/keychain entitlements.
codesign --force --options runtime --timestamp --sign "$identity" "$stage"
codesign --verify --strict --verbose=2 "$stage"
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$stage/Contents/Info.plist")" = "com.agentsai.duodeck.host" ]
rm -rf "$app"
mv "$stage" "$app"
echo "VERIFIED_APP=$app"
launch_app() {
  pkill -x "$name" >/dev/null 2>&1 || true
  /usr/bin/open -n "$1"
}
case "$mode" in
  run) launch_app "$app" ;;
  --verify|verify)
    launch_app "$app"
    sleep 3
    pgrep -x "$name" >/dev/null
    echo "RUNNING=yes"
    ;;
  --debug|debug) lldb -- "$app/Contents/MacOS/$name" ;;
  --logs|logs|--telemetry|telemetry)
    launch_app "$app"
    /usr/bin/log stream --info --style compact --predicate 'process == "DuoDeckHost"'
    ;;
  --install|install)
    dest="$HOME/Applications/DuoDeck Host.app"
    pending="$HOME/Applications/.DuoDeck Host.installing.app"
    mkdir -p "$HOME/Applications"
    rm -rf "$pending"
    ditto "$app" "$pending"
    codesign --verify --strict "$pending"
    pkill -x "$name" >/dev/null 2>&1 || true
    rm -rf "$dest"
    mv "$pending" "$dest"
    /usr/bin/open -n "$dest"
    sleep 3
    pgrep -x "$name" >/dev/null
    echo "INSTALLED=$dest"
    ;;
  --package|package)
    dmgroot="$PWD/.build/branding/dmg"
    rm -rf "$dmgroot"
    mkdir -p "$dmgroot"
    ditto "$app" "$dmgroot/DuoDeck Host.app"
    ln -s /Applications "$dmgroot/Applications"
    cp LICENSE NOTICE "$dmgroot/"
    hdiutil create -volname "DuoDeck Host" -srcfolder "$dmgroot" -ov -format UDZO "dist/DuoDeck-Host-macOS.dmg" >/dev/null
    codesign --force --timestamp --sign "$identity" dist/DuoDeck-Host-macOS.dmg
    echo "DMG=dist/DuoDeck-Host-macOS.dmg"
    ;;
esac
