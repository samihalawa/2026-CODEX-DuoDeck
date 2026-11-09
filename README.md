# DuoDeck

**Your Mac. In your hands.**

DuoDeck brings Mac windows to an iPhone or iPad, with an adjustable trackpad and useful keyboard shortcuts. Its native Mac companion handles pairing, capture and input. DuoDeck is an independent project derived from the Apache 2.0 licensed [Sill](https://github.com/Saffsanity/sill) engine.

[Website](https://duodeck.megawebs.com) · [Mac releases](https://github.com/samihalawa/2026-CODEX-DuoDeck/releases) · [Support](https://github.com/samihalawa/2026-CODEX-DuoDeck/issues) · [Privacy](https://duodeck.megawebs.com/privacy)

## The experience

- Small, Medium and Full trackpad layouts with saved preferences and pointer speed.
- Editing, Browsing, Windows and Code shortcut sets.
- Native Controls and Settings sheets; advanced options stay out of the everyday interface.
- A native menu bar Mac host with clear readiness, pairing and permissions.
- Matching Smooth, Balanced and Crisp streaming profiles.
- Direct encrypted streaming of a Mac window or desktop, with optional audio and clipboard sharing.
- Adaptive light/dark appearance and a coherent DuoDeck identity.

DuoDeck controls a Mac. It is not a system-wide pointer for other iPhone apps. A compatible Mac must be awake with DuoDeck Host running.

## Requirements and distribution

The Mac host requires macOS 14 or later. The iOS client requires iOS 17 or later; fold-aware iPhone Duo layouts require iOS 27.1 or later. Building the iOS app requires Xcode 27.1 or later.

Signed Mac downloads appear in this repository's releases after Apple notarization. The website checks actual download availability. The iOS source is available here; an App Store Connect record exists, and public App Store availability must be checked in the store itself. No Android, Windows, Mac App Store client, account backend or paid entitlement implementation is included in the current source tree.

## Repository

| Path | Purpose |
| --- | --- |
| apps/ios | Native SwiftUI client |
| apps/macos | Native Mac host and menu bar application |
| apps/web | Product site and interactive layout preview |
| packages/stream-protocol | Shared Swift streaming protocol |
| script | Canonical DuoDeck build/release entry points |
| Tests | Existing engine and UI-policy checks |
| docs/PRODUCT_BRIEF.md | Product direction and professional execution prompt |

Sources and iOSClient are compatibility symlinks. Internal Sill symbols and the wire service name remain where compatibility requires them. They are not another copy of the product.

## Run the website

```sh
npm run dev:web
npm run check
```

The site listens on port 3000 by default. Its preview is interactive and clearly labeled; it does not connect to a Mac. The production Dockerfile serves the same assets and exposes /api/health with product, version and commit metadata.

## Build the Mac companion

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --install
./script/build_and_run.sh --package
```

The script builds the real app bundle, generates its icon resources, selects an available signing identity, verifies the signature, and packages the host. It never signs with upstream's restricted entitlements. Distribution uses an Agents AI Ltd. Developer ID certificate and Apple notarization.

```sh
./script/release_mac.sh
# Add --publish only when the committed release is ready for GitHub.
```

Provide DUODECK_NOTARY_KEY, DUODECK_NOTARY_KEY_ID and DUODECK_NOTARY_ISSUER through your local environment. Credentials and generated binaries stay out of source control. See [the release checklist](docs/release-checklist.md).

## Build the iOS client

Open apps/ios/Sill.xcodeproj, select the Sill scheme and the DuoDeck signing team, then build. The internal scheme/product name preserves the upstream project wiring; the installed app is DuoDeck, bundle com.agentsai.duodeck.

```sh
npm run build:ios
Scripts/release-ios.sh --print-version
```

The iOS release script now validates DuoDeck's own bundle and team. Export and upload are distinct steps; an upload requires the real DuoDeck App Store Connect record.

## Verification

```sh
npm run check
Tests/checks/run-all.sh
```

The native checks cover protocol, pairing, gestures, input, layout, settings and streaming policies. Debug layout fixtures are useful for visual QA but are not evidence of live device control.

## License and attribution

See [LICENSE](LICENSE) and [NOTICE](NOTICE). Original Sill software copyright 2026 Noah Saffer. DuoDeck changes copyright 2026 Agents AI Ltd. Neither the Sill authors nor Apple endorse DuoDeck. Historical upstream design notes remain under docs for engineering context; the current operational directions are this README, AGENTS.md and the DuoDeck release checklist.
