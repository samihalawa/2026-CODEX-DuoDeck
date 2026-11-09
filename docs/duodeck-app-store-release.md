# DuoDeck App Store release

App Store Connect: https://appstoreconnect.apple.com/apps/6832548998/distribution

App ID **6832548998**, bundle **com.agentsai.duodeck**, team **U549N38BV6**, SKU **DUODECK2026IOS001**. The record was created and independently read back on 9 November 2026 under Agents AI Ltd.

## Current candidate — 9 November 2026

The simpler second redesign is version **1.1.0**. These states were read from the providers on 9 November 2026; they do not establish public App Store availability.

| Component | Candidate | Verified state |
| --- | --- | --- |
| iOS | 1.1.0 (2026110903) | Archive/export succeeded; uploaded, VALID, APP_STORE_ELIGIBLE and selected on the existing version |
| Mac companion | 1.1.0 (2026110902) | Signed universal package; installed and running; new notarization In Progress |
| App Store listing | docs/duodeck-app-store.md | New listing copy and review instructions saved; independent native readback matches the canonical text |
| Store screenshots | Six genuine build03 captures | Normal Macs, Add Mac and setup scenes captured on both families; provider replacement processing |
| Review draft | 7d3098a7-0a91-49c0-afef-d867f8545bbd | READY_FOR_REVIEW, submittedDate null; no submission attempt |
| Website | duodeck.megawebs.com | Redesigned production source `2aff42d81bfe664d7613c97a338da487734db3b5` confirmed by health and rendered browser checks |

Selected iOS build ID: **baa56e48-04e3-40ce-976a-1a777d39af32**. Version ID: **13d239d5-2eb9-4767-a9bd-f33780f4db97**. Exported IPA SHA-256: `032d9d6cb4b17ec3628c65cbe22d44b894254ce191206941c6e1c92eaa17af42`.

Mac notarization job: **1b80fbe5-f7e9-4907-b3f5-9688ed66a816**, created 15:58:45 UTC. Pristine DMG SHA-256: `b172925c67a448ebc32fd3b85f82b37962679ec71f39cdfeb1b637860ead7af0`. The old build02 iOS candidate and build01 Mac candidate remain historical and are superseded; their earlier checks do not verify this redesign.

The intended physical iPhone was unavailable to CoreDevice at the build03 installation attempt. Build03 was not installed on that phone. The installed Mac opens its native Permissions page and requires local Screen Recording and Accessibility approval. Simulator/UI checks and a running Mac process are not a live-stream verification.

The one-shot release continuation is prepared to resume this exact notarization job and checksum. It publishes the verified Mac artifact after Apple acceptance and then submits the existing iOS review draft only after the selected build and new screenshot set pass native readback. No new draft or recurring agent is needed.

## Required companion and product scope

The companion is **DuoDeck Host**, distributed outside the Mac App Store through https://duodeck.megawebs.com/#downloads and this repository's releases. Verify that the exact signed, notarized artifact is publicly downloadable before sending the iOS review draft. Support: https://github.com/samihalawa/2026-CODEX-DuoDeck/issues. Privacy: https://duodeck.megawebs.com/privacy.

The current native app is free and has no account requirement or paid entitlement implementation. Keep purchases disabled. Planned product identifiers and prices in store/product.json are not active offers. Preserve the existing real company and review contact. DuoDeck controls a Mac, not other iPhone apps.

## Canonical material

- [duodeck-app-store.md](duodeck-app-store.md): listing text and exact reviewer setup instructions.
- [release-checklist.md](release-checklist.md): operational release sequence.
- [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md): product direction and execution prompt.
- [releases/1.1.0.md](releases/1.1.0.md): durable public release notes.
- store/screenshots/ios/en-US/README.md: capture provenance; it must match the selected screenshots and build.

Read current provider records before each final release action. Build, installation, upload, processing, review submission and public availability are distinct states. Do not restart stopped bots or treat prior assistant reports as current provider evidence.
