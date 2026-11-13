# DuoDeck App Store release

[App Store Connect](https://appstoreconnect.apple.com/apps/6832548998/distribution)

App ID **6832548998**, bundle **com.agentsai.duodeck**, team **U549N38BV6**, SKU **DUODECK2026IOS001**. The record was created and independently read back on 9 November 2026 under Agents AI Ltd.

## Current release status — 13 November 2026

**DuoDeck 1.1.0 (2026111301) was submitted at 11:20:20.509 UTC, 12:20:20.509 Madrid time, on 13 November 2026.** A fresh App Store Connect API read at 11:21:23 UTC confirmed `WAITING_FOR_REVIEW` on both the version and submission, with the new build selected.

| Component | Candidate | Verified state |
| --- | --- | --- |
| iOS source | `b4abce0147d86d0f7f1ac1ed8f1cb59c920db90b` | Committed and pushed source for 1.1.0 (2026111301), including personal control decks, presentation shortcuts and in-app open-source attribution |
| Selected build | `15b528a0-1e12-45d7-8341-83913b796607` | Build 2026111301, uploaded at 11:13:26 UTC on 13 November, processed `VALID` and `APP_STORE_ELIGIBLE`, encryption declaration false |
| App version | `13d239d5-2eb9-4767-a9bd-f33780f4db97` | Version 1.1.0, `WAITING_FOR_REVIEW`, selected build 2026111301, release after approval |
| App Review | `76426df0-5d78-409a-93ed-58b77a72d4e7` | Existing submission resubmitted with the replacement build at 11:20:20.509 UTC, `WAITING_FOR_REVIEW` |
| Reviewer information | Nine answers and updated setup notes | The full responses to guidelines 4.3 and 4.2.6 were saved in two Resolution Center messages at 12:18 and 12:19 Madrid time. Listing metadata and 2,779-character setup notes were saved and read back |
| Store screenshots | Six genuine captures from build 2026111001 | Existing three phone and three iPad captures retained, with their original provenance. Fresh iPhone Duo and personal-control-deck captures remain to be supplied from the actual app |

The signed exported IPA is `.build/ios/export/DuoDeck.ipa`, SHA-256 `fb141fc9c6e14b699b0374aa94a65c28bcd7b3d30bf493f513dba9fb47caaa1a`. Archive and IPA checks confirmed version 1.1.0, build 2026111301, bundle com.agentsai.duodeck, team U549N38BV6, and the iOS 27.1 SDK. The export is signed by Apple Distribution for Agents AI Ltd.

## Rejection addressed in this submission

On 12 November 2026 Apple rejected build 2026111201 under guidelines 4.3 and 4.2.6, requesting details about originality, audience, testing, related apps, shared code and ownership. The replacement adds persistent named control decks with editable and reorderable key commands, an adaptive large-button grid, saved deck selection, and a Presenting shortcut group. The reviewer response identifies the substantial DuoDeck-derived engine and its Apache 2.0 attribution, describes the original additions, explains the product's independent Mac-control purpose, and gives the testing evidence with its actual limits. The complete nine-question response and current listing blocks are in [the store copy](duodeck-app-store.md).

Generic iOS Release compilation, archive, export and upload succeeded for this revision. The owner requested code-only work, so this revision received no device or simulator execution. Existing historical test results do not establish runtime validation of the new control decks. Fresh screenshots and any physical-device demonstration require genuine captures of the submitted build. App Review acceptance remains pending.

## Release history

### 9–11 November 2026

The seated-Duo icon and violet accent replaced the paired-D icon on blue in both apps. Submission `7d3098a7-0a91-49c0-afef-d867f8545bbd`, containing build 2026110904, was cancelled before review. Submission `efcd0eb4-1f69-4910-b13b-f09cdf1703fd`, containing build 2026111001, was also cancelled while waiting. On 11 November build 2026111201, ID `8714f227-f7d1-4029-b4ca-6e76aed69ec6`, replaced it in submission `76426df0-5d78-409a-93ed-58b77a72d4e7`. That submission entered review and received the 12 November rejection described above.

The 10 November release record verified DuoDeck Host 1.1.1 (2026111001) as a public, notarized and stapled [GitHub release](https://github.com/samihalawa/2026-CODEX-DuoDeck/releases/tag/v1.1.1), with DMG SHA-256 `cd8fe33430f5a599fa9adf572fcefb2bc9625a5ec04c555a86e32bd377ab613a`. This is historical release evidence. The current companion is obtained through the [downloads page](https://duodeck.megawebs.com/#downloads).

Six genuine screenshots from build 2026111001 were placed in `IPAD_PRO_3GEN_129` and `IPHONE_61`, three each. The original files and capture provenance remain under store/screenshots/ios/en-US.

On 11 November, Pricing and Availability had availability for Apple-silicon Macs enabled, with Automatic compatibility at macOS 14.0. The 1.1.0 build was run as Designed for iPad on an M-series Mac in that historical check. This setting does not establish public Mac App Store availability while iOS review is pending.

The earlier [verification checkpoint](releases/1.1.0-verification.md) records 758 focused capture/recovery checks, 29 isolated AppKit lifecycle checks, native phone/Duo recovery flows and an encoder/transport/decoder smoke using a synthetic pattern. On 9 November the Mac03 installation ran as a regular Dock app and reported Screen Recording off. The physical iPhone query failed with CoreDevice error 4016, leaving a real Mac desktop stream to a physical iPhone running build 2026110904 unverified in that record.

## After App Review

App Store Connect is set to release the version automatically after approval. When Apple reports the version available for distribution, verify the public product page and download in the intended storefronts before adding the App Store link to the website. Address any further reviewer request through the existing submission record.

## Required companion and product scope

The companion is **DuoDeck Host**, distributed through [the downloads page](https://duodeck.megawebs.com/#downloads) and this repository’s releases. [Support](https://github.com/samihalawa/2026-CODEX-DuoDeck/issues) and [privacy](https://duodeck.megawebs.com/privacy) remain the canonical URLs. All three public URLs returned HTTP 200 during preparation of this submission.

The current native app is free and has no account requirement or paid entitlement implementation. Purchases remain disabled. Planned product identifiers and prices in store/product.json are not active offers. The saved App Review contact remains the existing Agents AI Ltd contact. DuoDeck controls a Mac.

## Canonical material

- [duodeck-app-store.md](duodeck-app-store.md) contains listing text, reviewer setup instructions and the nine-question response.
- [release-checklist.md](release-checklist.md) contains the operational release sequence.
- [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md) contains the product direction and execution prompt.
- [releases/1.1.0.md](releases/1.1.0.md) contains durable public release notes.
- store/screenshots/ios/en-US/README.md records the original capture provenance.

Read current provider records before updating release status.
