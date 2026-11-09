# DuoDeck visual identity

## App icon

The canonical source is **AppIcon.png**, an opaque 1024×1024 PNG with a white paired-D monogram on blue. The former vector icon and website SVG mark are retired. Use this PNG when exporting the native app icons, website icon and other size variants; do not redraw the monogram independently.

The iOS app icon is apps/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png. The website icon is apps/web/public/icon.png. The Mac build uses script/build_icons.sh to compile design/AppIcon.png into Assets.car and AppIcon.icns before signing. Check dimensions, opacity and the rendered result whenever exporting or packaging an icon. Inspect it at small sizes as well as full resolution.

## Website and native apps

The website uses a plain **DuoDeck** text wordmark in Instrument Sans. Follow the current MagicInterview public website reference: white and light grey surfaces, dark text, quiet borders and blue actions (#2f55e4). This is the interface color specification; the generated icon source retains slight texture and is not a pixel-exact solid-color swatch.

Native apps use system typography, standard lists, grouped forms, toolbars and adaptive platform colors. Keep working screens focused on Macs, pairing and controls. Do not add repeated logo or slogan banners. The same identity should be recognizable without replacing familiar platform navigation.

See docs/PRODUCT_BRIEF.md for the product journeys, copy direction and current reference. Website previews must be labeled as previews. App Store images must be genuine captures of the submitted app build.

## Historical material

The older ipad-*.jpg files in screenshots are retained upstream assets. They are not DuoDeck release screenshots or evidence of current live behavior. Current QA captures and renderer fixtures live under ignored .build/orchestration during release validation. Store capture provenance belongs beside the current images in store/screenshots/ios/en-US/README.md.

The website also exports a 32px favicon and a 180px Apple touch icon from the same PNG to avoid fetching the full app artwork for small browser icons.
