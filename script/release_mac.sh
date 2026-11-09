#!/usr/bin/env bash
# DuoDeck distribution: one canonical build, notarization and publication path.
set -euo pipefail
cd "$(dirname "$0")/.."
publish=0
for arg in "$@"; do
  case "$arg" in
    --publish) publish=1 ;;
    --help|-h) echo "Usage: $0 [--publish]"; echo "Requires DUODECK_NOTARY_KEY, DUODECK_NOTARY_KEY_ID and DUODECK_NOTARY_ISSUER."; exit 0 ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done
: "${DUODECK_NOTARY_KEY:?Path to your App Store Connect notarization key}"
: "${DUODECK_NOTARY_KEY_ID:?Notarization key ID}"
: "${DUODECK_NOTARY_ISSUER:?Notarization issuer ID}"
if [ "$publish" = 1 ] && [ -n "$(git status --porcelain)" ]; then echo "Commit the verified release sources before publishing." >&2; exit 1; fi
./script/build_and_run.sh --package
app="$PWD/dist/DuoDeck Host.app"
dmg="$PWD/dist/DuoDeck-Host-macOS.dmg"
xcrun notarytool submit "$dmg" --key "$DUODECK_NOTARY_KEY" --key-id "$DUODECK_NOTARY_KEY_ID" --issuer "$DUODECK_NOTARY_ISSUER" --no-s3-acceleration --wait --output-format json > .build/branding/notary-release.json
python3 -c 'import json; r=json.load(open(".build/branding/notary-release.json")); assert r["status"]=="Accepted", r; print("Notarization accepted:",r["id"])'
xcrun stapler staple "$dmg"
xcrun stapler staple "$app"
xcrun stapler validate "$dmg"
spctl --assess --type execute --verbose=2 "$app"
ditto -c -k --keepParent "$app" dist/DuoDeck-Host-macOS.zip
(cd dist && shasum -a 256 DuoDeck-Host-macOS.dmg DuoDeck-Host-macOS.zip > SHA256SUMS.txt)
version="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$app/Contents/Info.plist")"
if [ "$publish" = 1 ]; then
  notes="docs/releases/$version.md"
  test -s "$notes"
  gh release create "v$version" dist/DuoDeck-Host-macOS.dmg dist/DuoDeck-Host-macOS.zip dist/SHA256SUMS.txt --repo samihalawa/2026-CODEX-DuoDeck --target "$(git rev-parse HEAD)" --title "DuoDeck $version" --notes-file "$notes"
fi
echo "VERIFIED_RELEASE=dist"
