#!/usr/bin/env bash
# Compile the shared DuoDeck icon with the current macOS mask and asset catalog.
set -euo pipefail
cd "$(dirname "$0")/.."
icon="$PWD/design/AppIcon.png"
output="${1:-$PWD/.build/branding/macos-icon}"
document="$output/AppIcon.icon"
compiled="$output/compiled"
test -f "$icon"
mkdir -p "$document/Assets" "$compiled"
cp "$icon" "$document/Assets/DuoDeck.png"
cat > "$document/icon.json" <<'JSON'
{
  "fill": { "solid": "srgb:0.184314,0.333333,0.894118,1.000000" },
  "groups": [{ "layers": [{ "image-name": "DuoDeck.png", "name": "DuoDeck" }] }],
  "supported-platforms": { "squares": ["macOS"] }
}
JSON
xcrun actool --compile "$compiled" --platform macosx --minimum-deployment-target 14.0 \
  --app-icon AppIcon --output-partial-info-plist "$output/partial.plist" "$document" >/dev/null
test -s "$compiled/Assets.car"
test -s "$compiled/AppIcon.icns"
printf '%s\n' "$compiled"
