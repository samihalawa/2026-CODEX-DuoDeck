# DuoDeck visual identity

The canonical vector mark is AppIcon.svg. Its checked-in opaque 1024×1024 PNG derivatives are apps/ios/Assets.xcassets/AppIcon.appiconset/AppIcon.png and apps/web/public/icon.png. The website uses apps/web/public/mark.svg. The Mac packaging script produces all ICNS sizes from the iOS asset, so both native apps use the same source identity.

Use a standards-compliant SVG renderer when regenerating raster assets; inspect the pixels and verify the 1024×1024 opaque result before packaging. Quick Look can produce a blank thumbnail and is not a valid substitute for that check.

DuoDeck uses native system type, adaptive platform surfaces, restrained teal and short functional labels. See docs/PRODUCT_BRIEF.md for design decisions.

The older ipad-*.jpg screenshots in screenshots are retained upstream historical assets; they are not DuoDeck release screenshots or evidence of current live behavior. Current QA images and renderer fixtures live under ignored .build/orchestration during release validation.
