# DuoDeck

**Control your Mac from your iPhone or iPad.**

<img width="2853" height="2007" alt="image" src="https://github.com/user-attachments/assets/0e206c54-42df-4452-9e10-4a7f57fdaf4b" />

<img width="1398" height="2034" alt="image" src="https://github.com/user-attachments/assets/f7a1180f-3b1f-48ca-9d66-2a8e6299a6fd" />





DuoDeck shows a Mac window or desktop on your phone or tablet. Point and click with a resizable trackpad, type with the keyboard, and use familiar Mac shortcuts. DuoDeck Host is a native Mac app with a full Dock icon and a resizable window. It handles pairing, screen capture and input, with quick controls also available from the menu bar.

[Website and downloads](https://duodeck.megawebs.com/#downloads) · [Mac releases](https://github.com/samihalawa/2026-CODEX-DuoDeck/releases) · [Support](https://github.com/samihalawa/2026-CODEX-DuoDeck/issues) · [Privacy](https://duodeck.megawebs.com/privacy)

## Get connected

1. Open DuoDeck Host on your Mac and finish Screen Recording and Accessibility setup.
2. Choose **Pair iPhone or iPad…** from its menu bar menu. On your phone or tablet, open DuoDeck and choose **Macs › Add Mac**. Scan the Mac's code, or choose **Enter code**, enter its address and 12-digit code, then tap **Pair Mac**.
3. Choose your paired Mac and open a window or the desktop. Use the trackpad to point and click, **Keyboard** to type, and **Shortcuts** for common actions.

Start with both devices on the same network. A discovered Mac can also be selected directly to begin pairing. Your Mac must remain awake with DuoDeck Host running.

## Make the controls comfortable

- Choose **Small**, **Medium** or **Full** in **Settings › Trackpad** for the upright layout. Pointer speed and saved preferences keep the controls consistent between sessions.
- Open **Shortcuts** for Editing, Browsing, Windows or Code actions. An optional shortcut row keeps the selected group beside the trackpad.
- Use **Trackpad › More controls** when you need window thumbnails, text size, Mac menus or extra modifier keys on the main surface.
- Find display and audio, connection details and advanced options in separate settings pages.
- On Mac, use **General**, **Devices**, **Streaming** and **Advanced**. General covers setup and pairing; Advanced holds permissions, remote access, virtual display and diagnostics.

Both native apps follow the system appearance. Smooth, Balanced and Crisp streaming profiles, optional audio and clipboard sharing remain available in settings. The current native product is free and requires no DuoDeck account or subscription.

DuoDeck controls a Mac. It does not provide a system-wide pointer for other iPhone apps.

## Requirements and distribution

The Mac host requires macOS 14 or later and supports Intel and Apple silicon. The iOS client requires iOS 17 or later; fold-aware iPhone Duo layouts require iOS 27.1 or later. Building the iOS app requires Xcode 27.1 or later.

See the [website's download section](https://duodeck.megawebs.com/#downloads) for current availability and the [App Store release record](docs/duodeck-app-store-release.md) for release preparation. Signed Mac downloads are published to this repository after Apple notarization. An App Store Connect record or uploaded build alone does not establish a public iOS release.

The current source contains the iOS client, Mac host and website. Android, Windows, a Mac App Store client, account services and paid entitlements remain planned work. Planned commerce identifiers in store/product.json are inactive.

## Repository

| Path | Purpose |
| --- | --- |
| apps/ios | Native SwiftUI client |
| apps/macos | Native Mac app with Dock, window and menu bar controls |
| apps/web | Product site and interactive browser preview |
| packages/stream-protocol | Shared Swift streaming protocol |
| script | Canonical DuoDeck build and release entry points |
| design/AppIcon.png | Shared opaque 1024×1024 app icon source |
| Tests | Engine and UI-policy checks |
| docs/PRODUCT_BRIEF.md | Product direction and execution prompt |

Sources and iOSClient are compatibility symlinks. Internal Sill symbols and the wire service name remain where compatibility requires them; there is one implementation per platform.

## Run the website

```sh
npm run dev:web
npm run check
```

The site listens on port 3000 by default. Its interactive preview demonstrates the trackpad and settings in the browser; it does not connect to a Mac. The production Dockerfile serves the same assets and exposes /api/health with product, version and commit metadata.

## Build the Mac companion

```sh
./script/build_and_run.sh --verify
./script/build_and_run.sh --install
./script/build_and_run.sh --package
```

The script builds the universal app bundle, compiles the shared PNG into Mac icon resources, selects an available signing identity, verifies the signature and packages the host. Distribution uses an Agents AI Ltd. Developer ID certificate and Apple notarization. Upstream restricted entitlements are not reused.

```sh
./script/release_mac.sh
# Add --publish when the committed release is ready for GitHub.
```

Provide DUODECK_NOTARY_KEY, DUODECK_NOTARY_KEY_ID and DUODECK_NOTARY_ISSUER through your local environment. Credentials and generated binaries stay out of source control. See [the release checklist](docs/release-checklist.md).

## Build the iOS client

Open apps/ios/Sill.xcodeproj, select the Sill scheme and the DuoDeck signing team, then build. The internal scheme and product name preserve the upstream project wiring; the installed app is DuoDeck, bundle com.agentsai.duodeck.

```sh
npm run build:ios
Scripts/release-ios.sh --print-version
```

The release script validates DuoDeck's own bundle and team. Archive, export, upload, processing and App Review are separate steps. The active listing and reviewer setup instructions are in [duodeck-app-store.md](docs/duodeck-app-store.md).

## Verification

```sh
npm run check
Tests/checks/run-all.sh
```

The native checks cover protocol, pairing, gestures, input, layout, settings and streaming policies. Debug layout fixtures support visual QA; genuine connected-device behavior needs its own verification.

## License and attribution

DuoDeck is an independent project derived from the Apache 2.0 licensed [Sill](https://github.com/Saffsanity/sill) engine. See [LICENSE](LICENSE) and [NOTICE](NOTICE). Original Sill software copyright 2026 Noah Saffer. DuoDeck changes copyright 2026 Agents AI Ltd. Neither the Sill authors nor Apple endorse DuoDeck.

Historical upstream design notes remain under docs for engineering context. Current operational directions are this README, AGENTS.md, docs/PRODUCT_BRIEF.md and the DuoDeck release checklist.
