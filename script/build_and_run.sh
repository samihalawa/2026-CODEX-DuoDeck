#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mode="${1:---verify}"
case "$mode" in run|--verify|verify|--debug|debug|--logs|logs|--telemetry|telemetry|--install|install|--package|package) ;; *) echo "Usage: $0 [--verify|--install|--package|--debug|--logs]" >&2; exit 2 ;; esac
name=DuoDeckHost
app="$PWD/dist/DuoDeck Host.app"
stage="$PWD/dist/.DuoDeck Host.partial.app"
swift build -c release --product DuoDeckMenuBar --arch arm64 --arch x86_64 -j 2
binary="$(swift build -c release --product DuoDeckMenuBar --arch arm64 --arch x86_64 --show-bin-path)/DuoDeckMenuBar"
test -x "$binary"
rm -rf "$stage"
mkdir -p "$stage/Contents/MacOS" "$stage/Contents/Resources"
# SwiftPM may record the deployment target as its SDK. Link metadata must name the
# installed SDK so AppKit and SwiftUI use the current native control appearance.
minos="$(xcrun vtool -show-build "$binary" | awk '$1 == "minos" && !found { print $2; found = 1 }')"
xcrun vtool -set-build-version macos "${minos:?Missing deployment target}" \
  "$(xcrun --sdk macosx --show-sdk-version)" -output "$stage/Contents/MacOS/$name" "$binary"
cp Packaging/Info.plist "$stage/Contents/Info.plist"
# The host is a normal Dock/app-switcher application, not an agent-only bundle.
[ "$(/usr/libexec/PlistBuddy -c 'Print LSUIElement' "$stage/Contents/Info.plist")" = "false" ]
[ -n "$(/usr/libexec/PlistBuddy -c 'Print NSScreenCaptureUsageDescription' "$stage/Contents/Info.plist")" ]
if [ -n "${DUODECK_BUILD_NUMBER:-}" ]; then /usr/libexec/PlistBuddy -c "Set :CFBundleVersion $DUODECK_BUILD_NUMBER" "$stage/Contents/Info.plist"; fi
cp LICENSE NOTICE "$stage/Contents/Resources/"
icon_resources="$(bash script/build_icons.sh)"
cp "$icon_resources/Assets.car" "$icon_resources/AppIcon.icns" "$stage/Contents/Resources/"
# DUODECK_SIGN_KEYCHAIN: sign from that keychain file without adding it to the search list.
sign_keychain="${DUODECK_SIGN_KEYCHAIN:-}"
kc=()
[ -z "$sign_keychain" ] || kc=(--keychain "$sign_keychain")
identities() { security find-identity -v -p codesigning ${sign_keychain:+"$sign_keychain"}; }
identity="${DUODECK_SIGN_ID:-}"
if [ -z "$identity" ]; then
  identity="$(identities | awk '/Developer ID Application: Agents AI Ltd/ && !/REVOKED/ {print $2; exit}')"
fi
if [ -z "$identity" ]; then
  identity="$(identities | awk '/Apple Development:/ && !/REVOKED/ {print $2; exit}')"
fi
test -n "$identity" || { echo "No valid signing identity found." >&2; exit 1; }
# macOS keys Screen Recording and Accessibility to the bundle ID plus the signing certificate.
# A build signed with anything but the Developer ID certificate must never claim the released
# app's identity: launching it once ties those permissions to the wrong certificate, and the
# installed DuoDeck Host then reports them missing while System Settings shows them on.
bundle_id="com.agentsai.duodeck.host"
if identities | grep -F "$identity" | grep -q "Developer ID Application: Agents AI Ltd"; then
  developer_id=1
else
  developer_id=0
  bundle_id="com.agentsai.duodeck.host.dev"
  /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $bundle_id" "$stage/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleName DuoDeck Host Dev" "$stage/Contents/Info.plist"
  /usr/libexec/PlistBuddy -c "Set :CFBundleDisplayName DuoDeck Host Dev" "$stage/Contents/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Add :CFBundleDisplayName string DuoDeck Host Dev" "$stage/Contents/Info.plist"
  echo "Not signed with Developer ID: building DuoDeck Host Dev ($bundle_id), which has its own permissions." >&2
fi
case "$mode" in --package|package|--install|install)
  [ "$developer_id" = 1 ] || { echo "Packaging and installing need the Developer ID Application: Agents AI Ltd certificate." >&2; exit 1; } ;;
esac
# This privileged companion is distributed outside the Mac App Store. It uses
# the login keychain unless it holds its own provisioned access-group entitlement.
# Never reuse upstream's restricted team/keychain entitlements.
codesign --force --options runtime --timestamp ${kc[@]+"${kc[@]}"} --sign "$identity" "$stage"
codesign --verify --strict --verbose=2 "$stage"
[ "$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$stage/Contents/Info.plist")" = "$bundle_id" ]
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
    # One installed copy, where the release DMG puts it. A second copy elsewhere (~/Applications)
    # is a separate app to System Settings and LaunchServices, and its permissions look missing.
    dest="/Applications/DuoDeck Host.app"
    pending="/Applications/.DuoDeck Host.installing.app"
    rm -rf "$pending"
    ditto "$app" "$pending"
    codesign --verify --strict "$pending"
    pkill -x "$name" >/dev/null 2>&1 || true
    rm -rf "$dest"
    mv "$pending" "$dest"
    /usr/bin/open -n "$dest"
    sleep 3
    pgrep -x "$name" >/dev/null
    lsregister=/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister
    "$lsregister" -u "$app" 2>/dev/null || true
    if [ -d "$HOME/Applications/DuoDeck Host.app" ]; then
      echo "warning: an older copy is still at ~/Applications/DuoDeck Host.app; remove it so only $dest remains." >&2
    fi
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
    codesign --force --timestamp ${kc[@]+"${kc[@]}"} --sign "$identity" dist/DuoDeck-Host-macOS.dmg
    echo "DMG=dist/DuoDeck-Host-macOS.dmg"
    ;;
esac
