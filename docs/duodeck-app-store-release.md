# DuoDeck 1.0 — App Store release handoff

**Last verified:** 6 November 2026. **Product:** DuoDeck — Mac Trackpad. **Repository:** https://github.com/samihalawa/2026-CODEX-DuoDeck, standalone main branch; prior Sill PR #1 is historical. **Upstream:** Saffsanity/sill, Apache 2.0; retain its license and copyright notices.

## Verified, do not repeat as an assumption

- Source commit `255f86aeec412df9d3b37646e58d5d22a24bb53c` introduced a fold-aware lower-half trackpad with persistent Small / Medium / Full sizing, Editing / Browsing / Windows / Code shortcut presets, and DuoDeck name/icon.
- Xcode 27.1 iOS simulator build succeeded; physical iOS 27.2 build succeeded, and the development-signed DuoDeck app installed on the connected iPhone. Original Sill is not overwritten.
- Full upstream `Tests/checks/run-all.sh` suite ended **All passed**.
- Xcode 27.1 Release archive succeeded. IPA export with App Store Connect API signing succeeded, with Apple Distribution certificate, Team `U549N38BV6`, store provisioning, `get-task-allow=false`.
- Product version 1.0.0, build 1; bundle ID `com.agentsai.duodeck` (registered Apple Developer bundle identifier ID `P29T6YA779`).
- On **mac4.local**, working tree is at `/Users/samihalawa/Projects/DuoDeck`; archive `.build/DuoDeck.xcarchive`; signed IPA `.build/DuoDeckExport/Sill.ipa` (the physical IPA filename remains Sill.ipa because the Xcode scheme retains upstream's name; embedded display name and bundle ID are DuoDeck). The IPA is not in GitHub. No IPA was uploaded.
- The Apple account's existing API keys successfully read app records and provisioned the bundle ID, but the App Store Connect **Apps API does not support creation** of new apps. Apple requires app-record creation using its web UI. On the last checked session, no record existed for this bundle identifier. A Fastlane Apple ID session was expired.

## Authorized orchestration task

The owner explicitly ordered the Grokbot controller to finish DuoDeck's App Store Connect setup and submit to the App Store. Operate through the existing **Grokbot CLI** and its own Chrome/1Password browser for the Apple Account passkey. Never paste secrets into bot prompts, logs, chat, or GitHub. Use one existing bot controller; if locked out of 1Password or Apple verification, surface only the specific interaction needed.

**First recheck live state** before each side effect: the App Store Connect app list, any new DuoDeck app record, uploaded builds, TestFlight processing, all required metadata, and submission status. Avoid duplicate records, uploads, and review submissions.

## Web UI app record

Official instructions: https://developer.apple.com/help/app-store-connect/create-an-app-record/add-a-new-app

1. In the **Agents AI Ltd.** team open https://appstoreconnect.apple.com/apps. Use the existing Apple Account through Chrome/1Password/passkey. Complete any Apple agreements only if already authorized and no new legal/financial commitments are required.
2. **Apps → + → New App**. Platform **iOS**, name **DuoDeck — Mac Trackpad** (if unavailable, use **DuoDeck: Mac Control**), primary locale **English (U.S.)**, existing bundle `com.agentsai.duodeck`, SKU `DUODECK2026IOS001`, full access for account users. Record Apple's resulting numeric app ID.
3. Inspect current app/build state. If no build exists, upload the existing signed IPA using Transporter on mac4 or its local Xcode tooling. Before uploading, confirm bundle ID, version and build string from the actual IPA. Verify Apple has processed build 1, not merely accepted the upload.
4. Complete product page, permissions, age rating, pricing/availability, export compliance, privacy questionnaire, screenshots and App Review notes with truthful data. For App Review, explain the required **free Sill for Mac companion** and user-visible Mac Screen Recording/Accessibility prompts. Do not claim the app remotely controls iOS itself; it controls a connected Mac.
5. Submit **once** to App Review; verify the actual App Store Connect submission status and provide its page URL and timestamp. If an App Review hold/owner interaction occurs, leave a precise status and required action.

## Suggested App Store metadata (verify length and uniqueness in UI)

**App name**: DuoDeck — Mac Trackpad
**Subtitle**: Foldable Mac control surface
**Primary category**: Productivity
**Secondary category**: Utilities
**Version**: 1.0.0
**Copyright**: © 2026 Agents AI Ltd.
**Support URL**: https://github.com/samihalawa/2026-CODEX-DuoDeck/issues
**Privacy URL**: https://github.com/samihalawa/2026-CODEX-DuoDeck/blob/main/PRIVACY.md (prefer /blob/main/PRIVACY.md after PR is merged)
**Mac companion**: https://getsill.app/download

**Promotional text**:

Turn your iPhone Duo into a pocket-sized Mac control desk. Choose a smaller trackpad and keep useful shortcuts close at hand.

**Description**:

Turn the iPhone Duo into a compact control surface for your Mac.

DuoDeck displays your Mac's windows on your iPhone or iPad. On the iPhone Duo, fold into laptop posture to keep the Mac picture above the hinge while the lower half becomes a responsive trackpad and command deck.

MADE FOR THE FOLD
- Choose Small, Medium or Full trackpad size, and keep your preferred layout between sessions.
- Make room for functional shortcut buttons next to the trackpad.
- Select Editing, Browsing, Windows or Code shortcut presets.

MAC CONTROL
- View a Mac window or the entire desktop on your iPhone or iPad.
- Use cursor movement, click, scroll, typing and common keyboard controls.
- Connect securely to the free Sill for Mac companion on your network or via its supported remote connection options.

DuoDeck requires a compatible Mac running Sill for Mac. It does not provide a system-wide cursor to control other apps on the iPhone.

Based on the Apache 2.0 licensed Sill open-source project.

**Keywords**: iphone duo,trackpad,mac remote,foldable,mouse,shortcuts,desktop,productivity
**What's new**: Introducing DuoDeck: flexible trackpad sizing and four shortcut palettes for iPhone Duo laptop posture.

**App Review notes**:

DuoDeck is an iOS client of the Sill Mac streaming engine. To test it, download and run Sill for Mac from https://getsill.app/download on a Mac. Grant macOS Screen Recording and Accessibility permissions to the Mac companion. Launch DuoDeck on the iPhone/iPad connected to the same local network, select the Mac, and complete the visible pairing process. Fold an iPhone Duo into laptop posture to access the flexible trackpad and command presets in the lower half. The app does not collect account credentials or require a DuoDeck login. The original open-source source and license are linked from the support and privacy pages.

## Commercial/default-release decision

No StoreKit paywall, entitlement check, subscription or purchase is implemented. **Do not advertise premium-only features or submit an in-app purchase that is not in the binary.** A free first listing is functionally accurate; monetization can be added in a subsequent version after the product has passed App Review. App Store pricing is an account-level commercial decision; verify selection before final review submission.

## Remaining product QA

- On an actual half-folded iPhone Duo paired to a Mac, verify all three pad modes and Editing / Browsing / Windows / Code shortcut outputs. The previous simulator screen rendering and a device install do not prove end-to-end mouse control.
- Verify layout when moving from folded to flat, disconnect/reconnect, keyboard visible, VoiceOver and varying text sizes.
- Generate authentic Duo App Store screenshots from the built app at Apple's required sizes; the existing test harness mock screenshot must not be misrepresented as a real Mac session.
- The fork's `main` was upstream-identical before PR #1. Merge only when feature validation is complete; leave unrelated upstream work intact.

## Verified finish line

App record created + build processed + truthful metadata and screenshots accepted + review submission confirmed in **App Store Connect itself**, not inferred from a Grokbot message, a local build, or an IPA upload.
