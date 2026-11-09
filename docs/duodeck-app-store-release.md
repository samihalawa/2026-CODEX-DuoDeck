# DuoDeck App Store release

[App Store Connect](https://appstoreconnect.apple.com/apps/6832548998/distribution)

App ID **6832548998**, bundle **com.agentsai.duodeck**, team **U549N38BV6**, SKU **DUODECK2026IOS001**. The record was created and independently read back on 9 November 2026 under Agents AI Ltd.

## Current checkpoint — 9 November 2026

Version **1.1.0** now includes the regular Mac Dock application and capture/first-picture recovery fixes. The states below distinguish local verification, Apple processing and public availability.

| Component | Candidate | Verified state |
| --- | --- | --- |
| iOS | 1.1.0 (2026110904) | Signed archive/export passed; VALID, APP_STORE_ELIGIBLE, unexpired, selected on the existing version and attached to the existing draft |
| Mac companion | 1.1.0 (2026110903) | Signed universal package installed and running as a regular app; notarization In Progress |
| App Store listing | docs/duodeck-app-store.md | Final description and review instructions saved; exact native readback passed at 17:15:56 UTC |
| Store screenshots | Six genuine build03 captures | Macs, Add Mac and setup scenes remain applicable to04; modern placements repaired, ordered and pixel verified |
| Review draft | 7d3098a7-0a91-49c0-afef-d867f8545bbd | READY_FOR_REVIEW, submittedDate null, exactly one intended version item attached; not submitted |
| Website | duodeck.megawebs.com | HTTPS health/homepage HTTP 200 at 17:25:38 UTC, exact deployed source `0bda6694a6ce0ca45f95242b7a5e9c751f9aa6f0` and new Dock copy confirmed; 10 source checks pass |

**iOS04:** exported IPA SHA-256 `30796cb84f1973cc6dbd2443b98f38b69a425fdff1b0ee5cb5485a335564ddb8`. Native build ID `ec90336b-fcd4-44c3-867d-5d10f8a90e11`, checked at `2026-11-09T17:20:28.584816Z`, is VALID, APP_STORE_ELIGIBLE and unexpired. It is selected on version `13d239d5-2eb9-4767-a9bd-f33780f4db97` and attached to the same draft through exact item `N2QzMDk4YTctMGE5MS00OWMwLWFmZWYtZDg2N2Y4NTQ1YmJkfDZ8ODk0ODg1NTU2`. Evidence: `.build/orchestration/asc-build04-current-candidate.json`.

**Mac03:** pristine DMG SHA-256 `7c15aab45ac5ea505c52cb30fc86e5101b86999a8157dcc6bd08fe779b9526cf`. Notarization job `610d133c-b145-4a35-8170-c514d6a3ad0f`, created `2026-11-09T17:13:45.857Z`, is In Progress. iOS03/Mac02 and Mac02 job `1b80fbe5-f7e9-4907-b3f5-9688ed66a816` are superseded, not current release proof.

The six store images remain genuine build03 captures from **15:50 UTC**. Their unchanged setup scenes are appropriate for build 2026110904; they are not recaptured from build 2026110904 or evidence of live streaming. Native placement readback verified three ordered ACTIVE placements in each of `IPAD_13_PROFILE` and `IPHONE_DYNAMIC_ISLAND_MEDIUM_PROFILE`. Apple-hosted full-size image pixels match the source PNGs.

The one-shot continuation is prepared with the exact Mac03 job/hash and iOS04 build/review-item pins above. Native read-only preflight passed at `2026-11-09T17:21:48.046984Z`: `ready_read_only`, draft/version/item READY_FOR_REVIEW, six ACTIVE placements with READY_FOR_REVIEW images, null submitted date, zero submission attempts and no prior attempt ledger. It starts only after current source is clean and pushed and exact preflight still passes. No running continuation is asserted at this checkpoint. After Mac acceptance, staple and validate the exact artifact, verify signatures/Gatekeeper and public download bytes, then perform native iOS readiness checks and submit the existing draft once. Record the submitted date and state. No new draft or recurring agent is needed.

## Implementation evidence and remaining limits

The production Mac download remains disabled with no href while its artifact is not public. The current rendered/geometry check was unavailable after bounded timeouts in the existing CDP tab; the HTTPS and exact-copy results do not establish a passing current layout check. Earlier responsive inspection remains historical. Evidence: `.build/orchestration/capture-dock-production-web-proof.json`.

The final source passed 758 focused capture/recovery checks, 29 isolated AppKit lifecycle checks, native phone/Duo recovery flows and a real encoder/transport/decoder smoke using a synthetic pattern. See [the verification checkpoint](releases/1.1.0-verification.md) for evidence and scope.

The production Mac03 installation is running with regular activation, PID 48608 and native window 7023. Its actual Permissions page still shows Screen Recording and Accessibility warnings/Allow buttons, and the capture log reports Screen Recording Is Off. The final physical-iPhone app query at `2026-11-09T17:23:23.195971Z` still failed with CoreDevice error 4016. No installation was attempted because the app-query service was unavailable; build04 installation is not verified. No physical-iPhone-to-real-Mac desktop stream is claimed. Synthetic video and UI checks do not prove that local macOS permissions are repaired.

## Required companion and product scope

The companion is **DuoDeck Host**, distributed outside the Mac App Store through [the downloads page](https://duodeck.megawebs.com/#downloads) and this repository's releases. Verify that the exact signed, notarized artifact is publicly downloadable before sending the iOS review draft. [Support](https://github.com/samihalawa/2026-CODEX-DuoDeck/issues) and [privacy](https://duodeck.megawebs.com/privacy) remain the canonical URLs.

The current native app is free and has no account requirement or paid entitlement implementation. Keep purchases disabled. Planned product identifiers and prices in store/product.json are not active offers. Preserve the existing real company and review contact. DuoDeck controls a Mac, not other iPhone apps.

## Canonical material

- [duodeck-app-store.md](duodeck-app-store.md): listing text and exact reviewer setup instructions.
- [release-checklist.md](release-checklist.md): operational release sequence.
- [PRODUCT_BRIEF.md](PRODUCT_BRIEF.md): product direction and execution prompt.
- [releases/1.1.0.md](releases/1.1.0.md): durable public release notes.
- store/screenshots/ios/en-US/README.md: original capture provenance, retained when unchanged images serve a later build.

Read current provider records before each final release action. Build, installation, upload, processing, review submission and public availability are distinct states. Do not restart stopped bots or treat prior assistant reports as current provider evidence.
