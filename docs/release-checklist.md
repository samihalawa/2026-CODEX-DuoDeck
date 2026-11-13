# DuoDeck release checklist

## Canonical targets

- Repository: samihalawa/2026-CODEX-DuoDeck; production branch: main.
- Website: https://duodeck.megawebs.com.
- Coolify project: suyvt8nfhv849irgyww0www2; application: oigyirmzcv60zph5dexh6ehh.
- Mac host: com.agentsai.duodeck.host; Developer ID distribution outside the Mac App Store.
- iOS: com.agentsai.duodeck; Agents AI Ltd. team U549N38BV6.
- App Store Connect app: 6832548998. Record creation is verified; check current build/review state in the provider before any subsequent action.

Publish only to the DuoDeck repository, team and App Store listing.

## Source and verification

1. Review current git state and preserve unrelated work. Reconcile the final source revision.
2. Build both native targets and run the relevant existing checks. Inspect ordinary phone, Duo, iPad and Mac surfaces affected by the change.
3. Run npm run check and inspect the actual website at desktop/mobile sizes, including light/dark, preview controls, dialogs and navigation.
4. Review reader-facing copy against the implemented product. Keep store publication, hosted accounts, paid products and unsupported platforms out of available-feature claims.
5. Commit the reviewed sources, integrate to main without overwriting unrelated work, push and verify the remote SHA.

## Mac distribution

The canonical command is script/release_mac.sh. The compatibility Scripts/release.sh delegates to it.

- script/build_and_run.sh creates a universal arm64/x86_64 app, correct bundle metadata, original icon resources, LICENSE and NOTICE.
- Distribution must use a valid Agents AI Ltd. Developer ID certificate and hardened runtime with a trusted timestamp.
- Supply notarization credentials through DUODECK_NOTARY_KEY, DUODECK_NOTARY_KEY_ID and DUODECK_NOTARY_ISSUER. Never commit them.
- Read Apple's final Accepted result for the actual uploaded artifact. Staple and validate its ticket, verify codesign and Gatekeeper, and generate SHA256SUMS.txt.
- To continue an existing submission, use `--resume-notary` with its ID and `--expected-dmg-sha` with the pristine uploaded checksum. Add `--source-commit` from the original build record when publishing. Resume stages that exact DMG, derives the app from it, waits at most three hours, and verifies Apple's accepted log checksum. The release tag and notes come from the recorded artifact source even if main has advanced.
- The release command freezes the pushed main commit and release notes, retains verified artifacts under `.build/releases/`, and refuses to overwrite an existing release. Inspect native state before handling any ambiguous response.
- Publish the DMG, ZIP and checksums to the intended DuoDeck release only. Confirm the download URL resolves and its bytes match.
- Inspect any existing local installation identity before replacing DuoDeck Host, then launch and confirm its actual process and UI. Do not replace another product.

A notarized privileged Mac host is not a Mac App Store client. A future Mac App Store client must use its own supported sandboxed architecture and exclude private capture/virtual-display host APIs.

## iOS distribution

The canonical Xcode project is apps/ios/DuoDeck.xcodeproj, scheme DuoDeck.

- Build and install a signed development app on the intended paired device. Read its installed bundle/version and launch result.
- Scripts/release-ios.sh validates the own bundle com.agentsai.duodeck, team U549N38BV6 and Packaging/ExportOptions-duodeck.plist.
- Archive/export the final source revision. Inspect the IPA identity, distribution signature, profile, permissions and version/build.
- Inspect App Store Connect app 6832548998 before uploading; do not duplicate a build number.
- Upload once, preserve the provider delivery/build ID, and wait for processing. Upload receipt is not processed-build proof.
- Before review submission, verify the version's selected build, required metadata, privacy and age-rating declarations, actual support/privacy URLs, valid pricing/availability and authentic screenshots.
- Use actual current app screenshots. Debug fixture windows and illustrative website previews are not live-stream screenshots.
- Submit only a complete verified candidate and record the native submission state. Review submission is not approval or public availability.

## Website deployment

The dedicated Coolify application builds this repository's main branch from /Dockerfile. Port 3000 serves /api/health. The production DNS record points to the observed Coolify server.

Use repository-driven deployment. Verify the GitHub webhook, deployed commit, Coolify terminal success, HTTPS routes, health version/commit and actual rendered pages. The current website is static marketing plus a local interactive preview; it does not implement an account database or checkout.

## Remaining platform work

Android, Windows, a sandboxed Mac App Store client, account services, RevenueCat entitlements and web payments were requested in the broader project plan. They do not exist in the current shipping source tree. Track their implementation from source and provider evidence; never promote a planned platform into a submitted or released one.
