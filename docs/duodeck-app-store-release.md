# DuoDeck App Store release

[App Store Connect](https://appstoreconnect.apple.com/apps/6832548998/distribution)

App ID **6832548998**, bundle **com.agentsai.duodeck**, team **U549N38BV6**, SKU **DUODECK2026IOS001**. The record was created and independently read back on 9 November 2026 under Agents AI Ltd.

## Release status — 10 November 2026 (seated-Duo rebrand)

The new seated-Duo icon and violet accent replaced the paired-D icon on blue in both apps. The iOS build that was waiting for review was withdrawn and replaced with the rebranded build before review began.

| Component | Candidate | Verified state |
| --- | --- | --- |
| iOS | 1.1.0 (2026111001), build ID `4208a23a-193f-4e53-871c-2a405300f4df` | Uploaded through the Q92YCL7C6D API key, processed by Apple and selected on version `13d239d5-2eb9-4767-a9bd-f33780f4db97` |
| Mac companion | DuoDeck Host 1.1.1 (2026111001) | Public [GitHub release](https://github.com/samihalawa/2026-CODEX-DuoDeck/releases/tag/v1.1.1), notarized and stapled. The latest-download DMG SHA-256 `cd8fe33430f5a599fa9adf572fcefb2bc9625a5ec04c555a86e32bd377ab613a` matches the release record |
| Store screenshots | Six captures from build 2026111001 | Replaced in `IPAD_PRO_3GEN_129` and `IPHONE_61`, three each, in the same order |
| Mac App Store | iPad app on Apple-silicon Macs | Pricing and Availability: "Make this app available" on, Automatic (macOS 14.0); compatibility verified on 2026-11-11 after running the 1.1.0 build as Designed for iPad on an M-series Mac. Lists on the Mac App Store once 1.1.0 is approved |
| App Review | `efcd0eb4-1f69-4910-b13b-f09cdf1703fd` | Submitted; App Store Connect shows Waiting for Review on the submission and the version. The earlier submission `7d3098a7-0a91-49c0-afef-d867f8545bbd` (build 2026110904) was cancelled before review |
| Website | [duodeck.megawebs.com](https://duodeck.megawebs.com) | Serves the new mark and violet accent; the Mac download reports available |

## After App Review

App Store Connect is set to release the version automatically after approval. When Apple reports the version available for distribution, verify the public product page and download in the intended storefronts before adding the App Store link to the website. If Apple requests changes, use the existing submission record and address the specific request.

## Implementation evidence and remaining limits

The final source passed 758 focused capture/recovery checks, 29 isolated AppKit lifecycle checks, native phone/Duo recovery flows and a real encoder/transport/decoder smoke using a synthetic pattern. See [the verification checkpoint](releases/1.1.0-verification.md) for evidence and scope.

On 9 November, the Mac03 installation ran as a regular Dock app and reported Screen Recording off. The physical iPhone query failed with CoreDevice error 4016. A real Mac desktop stream to a physical iPhone running build 2026110904 remains unverified.

## Required companion and product scope

The companion is **DuoDeck Host**, distributed through [the downloads page](https://duodeck.megawebs.com/#downloads) and this repository’s releases. [Support](https://github.com/samihalawa/2026-CODEX-DuoDeck/issues) and [privacy](https://duodeck.megawebs.com/privacy) remain the canonical URLs.

The current native app is free and has no account requirement or paid entitlement implementation. Keep purchases disabled. Planned product identifiers and prices in store/product.json are not active offers. Preserve the existing real company and review contact. DuoDeck controls a Mac, not other iPhone apps.

## Canonical material

- [duodeck-app-store.md](duodeck-app-store.md): listing text and exact reviewer setup instructions.
- [release-checklist.md](release-checklist.md): operational release sequence.
- [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md): product direction and execution prompt.
- [releases/1.1.0.md](releases/1.1.0.md): durable public release notes.
- store/screenshots/ios/en-US/README.md: original capture provenance, retained when unchanged images serve a later build.

Read current provider records before updating release status.
