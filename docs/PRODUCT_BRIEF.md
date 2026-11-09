# DuoDeck product and engineering brief

## Goal

Make controlling a Mac from an iPhone or iPad clear and comfortable. Preserve the working streaming, pairing, gesture and keyboard engine. Give the screen and trackpad most of the space, keep the next action obvious, and make the Mac companion feel at home on macOS.

## Source of direction

The owner's shared conversation, “Enable iPhone Trackpad”, and the 9 November 2026 corrections establish the intent: a distinct product, native platform behavior, advanced settings in submenus, consistent Mac branding and verified deployment. The later correction rejects the decorative website and illustrated icon and selects the current MagicInterview website and native apps as the design reference. Current code and native provider records determine what exists. Earlier build or submission claims require their own evidence.

## Core journeys

- On iPhone and iPad, start at **Macs**. **Add Mac** opens a native sheet with **Scan code** and **Enter code**. The manual path uses the Mac address and 12-digit pairing code, then **Pair Mac**. A discovered Mac can also open its pairing sheet directly.
- Once connected, keep the picture, trackpad, Keyboard and Shortcuts easy to reach. Put trackpad size and pointer speed in **Settings › Trackpad**. Small, Medium and Full sizes apply to the upright layout; pointer speed applies across the on-screen trackpads.
- Keep the shortcut row optional. Editing, Browsing, Windows and Code groups remain available through Shortcuts. Put extra window, menu and modifier controls under **Trackpad › More controls**.
- On Mac, use four settings tabs: **General**, **Devices**, **Streaming** and **Advanced**. General explains readiness and offers setup or pairing. Devices manages connections. Streaming holds quality and audio. Advanced contains network options, Remote Access, Virtual Display, Permissions and diagnostics. DuoDeck Host is a regular Mac app with its full icon in the Dock and app switcher, a resizable main window, standard minimize/zoom/full-screen controls and Dock reopening. Closing its window keeps an active connection running; Quit stops the host.
- Treat connection and video readiness as separate states. An app catalog can work before screen capture starts. Show an actionable picture-unavailable state for denied capture, missing display, capture-start failure or a missing first frame, and provide a bounded retry. Never present a silent black panel as a successful stream. Preserve old-client wire compatibility.
- Preserve saved preferences, pairing and meaningful error states. Support ordinary iPhone, iPad and Duo layouts, keyboard visibility, larger text and accessible controls.
- Keep the current local-control product free and usable without an account. Planned accounts, subscriptions and entitlements must not appear as working features.

## Design language

Use the simple paired-D app icon from **design/AppIcon.png**, an opaque 1024×1024 PNG. Native app icons and web icon derivatives share that source. The website header uses a plain **DuoDeck** text wordmark.

The web reference is MagicInterview's current public stylesheet: Instrument Sans, white and light grey surfaces, dark readable text, restrained borders and one blue action color, #2f55e4. Its older typography specimen page is not the current reference. Explain the product with “Control your Mac from your iPhone or iPad.” Follow that with specific actions and clear setup steps.

Native apps use system typography, standard lists, forms, toolbars and semantic light/dark surfaces. Use blue as an accent, not as a large decorative surface. Live video keeps its appropriate dark canvas. Working screens lead with the task and the Mac's name; they do not repeat logo or slogan banners.

Use short, literal labels. A shortcut that cycles windows says Next Window. Place advanced controls behind named settings rather than showing every option at once. Avoid oversized marketing headings inside apps, glowing gradients, decorative metrics and invented device scenes presented as product evidence. Clearly identify the website's interactive preview; release screenshots must come from the actual app.

## Engineering boundaries

Canonical repository: samihalawa/2026-CODEX-DuoDeck.
Canonical checkout: /Users/samihalawa/git/PROJECTS_ON_PROCESS/2026-CODEX-DuoDeck.

Preserve unrelated working changes. Keep one canonical source per platform; root Sources and iOSClient symlinks are compatibility paths. Maintain Apache 2.0 attribution and upstream copyright notices. Internal protocol and engine names may remain where compatibility requires them.

The current implementation comprises apps/ios, apps/macos and apps/web, plus packages/stream-protocol. Android, Windows, a sandboxed Mac App Store client, account services and paid entitlements remain planned work. The privileged Mac host is distributed separately from any future Mac App Store client. Source presence does not establish public availability.

## Professional execution prompt

Inspect the canonical repository, relevant original conversation and current provider state before changing DuoDeck. Preserve working behavior and user changes. Follow the native journeys and the current MagicInterview design reference above. Simplify the actual controls, pairing and settings before adding decoration. Apply one identity across app icons, website, help and release metadata. Verify affected layouts, action behavior and real builds; resolve concrete defects; then commit and publish through DuoDeck's own release paths. Report build, install, upload, processing, submission and public availability as separate outcomes supported by direct evidence.

## Completion evidence

A release needs successful builds, relevant behavioral checks, rendered UI review, correct signed identities and native deployment readback. Website health must identify the version and source commit. Screenshots must match the selected build. A Mac download requires the exact artifact's notarization and public-byte verification. Store preparation and upload do not establish review approval or public availability. Record current release state in docs/duodeck-app-store-release.md and the release verification record; keep public release notes focused on durable changes.
