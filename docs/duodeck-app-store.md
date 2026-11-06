# DuoDeck — App Store Connect release materials

Release: 1.0.0 (1). Platform: iOS (iPhone and iPad; iPhone Duo optimized). Bundle ID: `com.agentsai.duodeck`. Developer team: Agents AI Ltd. (`U549N38BV6`).

## Identity

App name: **DuoDeck — Mac Trackpad**
Subtitle: **Foldable Mac control surface**
Primary category: **Productivity**
Secondary category: **Utilities**
Primary locale: **English (U.S.)**
Copyright: **2026 Agents AI Ltd.**
License attribution: This client is based on the Apache 2.0 licensed Sill project by Saffsanity; retain the NOTICE and LICENSE in distribution materials.

## Promotional text (editable without a new build)

Turn your iPhone Duo into a pocket-sized Mac control desk. Choose a smaller trackpad and keep your favorite shortcuts within reach.

## Description

**Fold your iPhone into a Mac control surface.**

DuoDeck brings your Mac windows to your iPhone or iPad and makes the most of the iPhone Duo’s foldable display. Set the phone in laptop posture and use the upper half to see your Mac while the lower half becomes a trackpad and shortcut deck.

**Make the lower half yours**
- Pick a Small, Medium or Full trackpad. Your selection is saved.
- Use the space beside the trackpad for useful Mac keyboard shortcuts.
- Switch between Editing, Browsing, Windows and Code command sets.
- Tap to click, move the cursor, scroll and use keyboard controls.

**Work across devices**
- Connect to your Mac on your local network or through compatible Sill remote-access options.
- See individual Mac app windows or the desktop.
- Use the free Sill for Mac companion, compatible with DuoDeck.

DuoDeck works as a Mac remote controller, not as a system-wide pointer controller for other apps on your iPhone. A Mac is required to use its remote-control features. Available capabilities depend on your device, the connected Mac and its permissions. The fold-optimized laptop layout requires iPhone Duo and iOS 27.1 or later.

The companion is free at https://getsill.app/download. DuoDeck is based on the open-source Sill engine, distributed under the Apache 2.0 license.

## Keywords

mac,trackpad,remote,mouse,iphone duo,foldable,shortcuts,productivity,keyboard,desktop

## URLs

Support: https://github.com/samihalawa/2026-CODEX-DuoDeck/issues

Privacy policy: https://github.com/samihalawa/2026-CODEX-DuoDeck/blob/main/PRIVACY.md

Developer / source: https://github.com/samihalawa/2026-CODEX-DuoDeck

Mac companion: https://getsill.app/download

## Review notes

The iPhone app is named DuoDeck; the optional macOS companion is the independently available Sill for Mac application, which communicates via Sill's existing protocol. To test on a Mac running Sill, authorize Screen Recording and Accessibility in macOS Settings and pair the iPhone/iPad. For Duo laptop posture: open the iPhone Duo halfway, choose Small or Medium trackpad at the bottom, and use the action preset selector.

On ordinary iPhones or iPads the inherited layouts are shown. The app requests Local Network access to discover Macs, and Camera access only to scan a pairing code. No account is required. The client has no analytics or ads.

## Screenshots to produce before App Store review

- A genuine running Mac window above the fold and DuoDeck Small trackpad plus shortcut deck below the fold; image must be captured from a real connection (no mocked content presented as live).
- The Medium and Full presets in laptop posture.
- Editing and Browsing action profiles with the actual Mac companion.
- Closed device and fully open Duo compatibility views.

Prepare product page graphics using Apple's current screenshot sizes for iPhone Duo / iPhone, and verify legibility across orientations. Only submit the screenshots of features demonstrated in the uploaded binary.

## Release instructions

1. Merge validated feature branch; public privacy policy must resolve at the URL above.
2. In App Store Connect, create the DuoDeck iOS app record (name, SKU `DUODECK2026IOS001`, `com.agentsai.duodeck`) under Agents AI Ltd.
3. Set pricing and app information, age rating, privacy answers, support links and screenshots.
4. Upload the archived signed IPA generated with `Packaging/ExportOptions-duodeck.plist`.
5. Wait until Apple processes the build; attach build 1.0.0 (1) to the version, fill review metadata, and submit for review. Confirm the submission state in App Store Connect. Do not claim publication from an upload or a submitted review alone.

The signing key and any App Store Connect secrets remain outside this repository.
