#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:---verify}"
case "$mode" in run|--verify|verify|--debug|debug|--logs|logs|--telemetry|telemetry|--install|install|--package|package) ;; *) echo "Usage: $0 [--verify|--install|--package|--debug|--logs]" >&2; exit 2 ;; esac
name=DuoDeckHost
app="$PWD/dist/DuoDeck Host.app"
stage="$PWD/dist/.DuoDeck Host.partial.app"
icon="$PWD/apps/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png"
swift build -c release --product SillMenuBar --arch arm64 --arch x86_64 -j 2
binary="$(swift build -c release --product SillMenuBar --arch arm64 --arch x86_64 --show-bin-path)/SillMenuBar"
test -x "$binary"
rm -rf "$stage"
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources" .build/branding/icons.iconset
cp "$binary" "$stage/Contents/MacOS/$name"
cp Packaging/Info.plist "$stage/Contents/Info.plist"
if [ -n "${DUODECK_BUILD_NUMBER:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $DUODECK_BUILD_NUMBER" "$stage/Contents/Info.plist"; fi
cp LICENSE NOTICE "$stage/Contents/Resources/"
for points in 16 32 128 256 512; do
  twice=$((points*2))
  sips -s format png -z "$points" "$points" "$icon" --out ".build/branding/icons.iconset/icon_${points}x${points}.png" >/dev/null
  sips -s format png -z "$twice" "$twice" "$icon" --out ".build/branding/icons.iconset/icon_${points}x${points}@2x.png" >/dev/null
done
iconutil -c icns .build/branding/icons.iconset -o "$stage/Contents/Resources/AppIcon.icns"
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
