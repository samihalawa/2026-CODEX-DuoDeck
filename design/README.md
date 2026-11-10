# DuoDeck visual identity

## App icon

The mark is the seated iPhone Duo: a violet-to-pink upright half (#6D28D9 to #EC4899) over an orange-to-amber flared deck (#FF5A3C to #FFB020) on white. Where the two overlap, a darker band (#4C1D95 at 55%) forms the fold, and one soft key bar sits on the deck. The canonical vector source is **AppIcon.svg**; **AppIcon.png** is its opaque 1024×1024 export and **DuoDeckMark.svg** is the same mark on a transparent ground. Export every size variant from these; do not redraw the mark independently. To re-export the PNG: `qlmanage -t -s 1024 -o . design/AppIcon.svg`, then flatten onto white without alpha.

The iOS app icon is apps/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png. The website icon is apps/web/public/icon.png. The website header mark is apps/web/public/mark.svg (a copy of DuoDeckMark.svg). The Mac build uses script/build_icons.sh to compile design/AppIcon.png into Assets.car and AppIcon.icns before signing. Check dimensions, opacity and the rendered result whenever exporting or packaging an icon. Inspect it at small sizes as well as full resolution.

## Website and native apps

The website header pairs the mark with a **DuoDeck** text wordmark in Instrument Sans. Follow the current MagicInterview public website reference: white and light grey surfaces, dark text, quiet borders and violet actions (#6d28d9 on light, #c4b5fd on dark), taken from the mark's upper colour. The Mac menu bar glyph (StatusGlyph.swift) is the same mark as a one-colour template.

Native apps use system typography, standard lists, grouped forms, toolbars and adaptive platform colors. Keep working screens focused on Macs, pairing and controls. Do not add repeated logo or slogan banners. The same identity should be recognizable without replacing familiar platform navigation.

See docs/PRODUCT_BRIEF.md for the product journeys, copy direction and current reference. Website previews must be labeled as previews. App Store images must be genuine captures of the submitted app build.

## Historical material

The older ipad-*.jpg files in screenshots are retained upstream assets. They are not DuoDeck release screenshots or evidence of current live behavior. Current QA captures and renderer fixtures live under ignored .build/orchestration during release validation. Store capture provenance belongs beside the current images in store/screenshots/ios/en-US/README.md.

The website also exports a 32px favicon and a 180px Apple touch icon from the same PNG to avoid fetching the full app artwork for small browser icons.
