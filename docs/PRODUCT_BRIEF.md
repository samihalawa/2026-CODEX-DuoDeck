# DuoDeck product and engineering brief

## Goal

Make DuoDeck a distinctive, native Mac control experience for iPhone and iPad, with a coherent Mac companion. Preserve the working streaming, pairing, gesture and keyboard engine. Reclaim trackpad space for useful actions and make everyday use simple.

## Source of direction

The owner's shared conversation, “Enable iPhone Trackpad”, and the 9 November 2026 correction establish the product intent: significant differentiation from Sill, native platform behavior, advanced settings in submenus, matching macOS branding, and verified deployment. Current code and native provider records determine what exists. Prior build or submission claims are leads until verified.

## Product priorities

- Make choosing and connecting to a Mac obvious.
- Keep the live picture, trackpad, keyboard and app switching central.
- Preserve Small, Medium and Full trackpad sizes, pointer speed, saved preferences and useful shortcut sets.
- Put advanced streaming, connection, diagnostics and gesture options behind clearly named settings.
- Actions must perform what their labels promise. A shortcut that cycles windows must say Next Window, not Terminal.
- Support ordinary iPhone, iPad and Duo layouts, keyboard visibility, larger text and accessible controls.
- Basic local control remains usable without an account.
- Use actual native APIs and functional state. Demonstration and fixture content must be visibly identified.

## Design language

DuoDeck is the product name. Use the dual-panel pointer icon in design/AppIcon.svg and the checked-in raster derivatives. Use the system typeface, native controls and materials, a restrained teal accent, and adaptive light/dark appearance. Live video keeps its appropriate dark canvas. Keep labels short, readable and specific.

Avoid repeated promotional banners, glowing gradients, oversized dashboard cards, decorative metrics and settings on the main control surface. Standard platform conventions should make the product easier to learn. Branding does not require renaming internal protocol or compatibility identifiers.

## Engineering boundaries

Canonical repository: samihalawa/2026-CODEX-DuoDeck.
Canonical checkout: /Users/samihalawa/git/PROJECTS_ON_PROCESS/2026-CODEX-DuoDeck.

Preserve unrelated working changes. Keep one canonical source per platform; root Sources and iOSClient symlinks are compatibility paths. Maintain Apache 2.0 attribution and upstream copyright notices.

The current shipping code comprises apps/ios, apps/macos and apps/web, plus packages/stream-protocol. Android, Windows, a sandboxed Mac App Store client, account services and paid entitlements are remaining project work; their presence or release must never be inferred from plans or empty directory names. The privileged Mac host is distributed separately from any future Mac App Store client.

## Professional execution prompt

Inspect the canonical repository, current provider state and relevant original conversation before changing DuoDeck. Preserve working behavior and user changes. Improve the actual user journey with coherent native design, useful controls and progressive settings. Apply the identity across app surfaces, icons, help, website and release metadata. Verify every affected layout and actual build, resolve concrete defects, commit the reviewed change, and publish through the project's own release paths. Report build, install, upload, processing, submission and availability as separate outcomes supported by direct evidence.

## Completion evidence

A source diff is not a release. A release needs successful builds, relevant behavioral checks, rendered UI review, a correct signed identity, and native deployment/readback. Website health must identify the version and source commit. Store preparation and upload do not establish review approval or public availability.
