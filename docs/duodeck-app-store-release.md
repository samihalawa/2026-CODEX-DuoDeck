# DuoDeck App Store release

[App Store Connect](https://appstoreconnect.apple.com/apps/6832548998/distribution)

App ID **6832548998**, bundle **com.agentsai.duodeck**, team **U549N38BV6**, SKU **DUODECK2026IOS001**. The record was created and independently read back on 9 November 2026 under Agents AI Ltd.

## Release status — 10 November 2026

Version **1.1.0** now includes the regular Mac Dock application and capture/first-picture recovery fixes. The states below distinguish local verification, Apple processing and public availability.

| Component | Candidate | Verified state |
| --- | --- | --- |
| iOS | 1.1.0 (2026110904) | Signed archive and export passed. The valid build is selected on the submitted version |
| Mac companion | 1.1.0 (2026110903) | Public [GitHub release](https://github.com/samihalawa/2026-CODEX-DuoDeck/releases/tag/v1.1.0) with notarized universal DMG, ZIP and checksums |
| App Store listing | [Listing material](duodeck-app-store.md) | App Store Connect matched the description and review instructions on 9 November |
| Store screenshots | Six captures from build 2026110903 | Ordered and verified Macs, Add Mac and setup scenes also used for build 2026110904 |
| App Review | 7d3098a7-0a91-49c0-afef-d867f8545bbd | Submitted at `2026-11-10T08:20:37.384Z`. App Store Connect shows Waiting for Review on the submission and the version |
| Website | [Downloads](https://duodeck.megawebs.com/#downloads) | The Mac button is enabled. The public DMG returned HTTP 200 and matched the published checksum |

The selected iOS build ID is `ec90336b-fcd4-44c3-867d-5d10f8a90e11` on version `13d239d5-2eb9-4767-a9bd-f33780f4db97`. The exported IPA SHA-256 is `30796cb84f1973cc6dbd2443b98f38b69a425fdff1b0ee5cb5485a335564ddb8`.

Apple accepted Mac notarization job `610d133c-b145-4a35-8170-c514d6a3ad0f`. The release tag `v1.1.0` points to the recorded installer source `d82aaf695232d536d13e34253cde2976646664a1`. The published stapled DMG SHA-256 is `a9e42fcc454efddccdbaaa5f1918458e2832cc3efefa3731581c7a4d0e839e57`.

The six store images remain genuine build03 captures from **15:50 UTC**. Their unchanged setup scenes are appropriate for build 2026110904; they are not recaptured from build 2026110904 or evidence of live streaming. Native placement readback verified three ordered ACTIVE placements in each of `IPAD_13_PROFILE` and `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`. Apple-hosted full-size image pixels match the source PNGs.

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
