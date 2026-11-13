# DuoDeck: canonical engineering instructions

Canonical checkout: /Users/samihalawa/git/PROJECTS_ON_PROCESS/2026-CODEX-DuoDeck.
Canonical repository: samihalawa/2026-CODEX-DuoDeck. Keep the LICENSE and NOTICE files unchanged.

Keep the working Swift streaming engine. This is a polyglot monorepo: apps/ios (native SwiftUI), apps/macos (native Mac host and a separate App Store client where needed), apps/android, apps/windows, apps/web (marketing/account), apps/api (account/billing), packages/stream-protocol (the existing Swift wire protocol). Root Sources and iOSClient are compatibility symlinks for the proven engine tests/scripts; do not create duplicate source copies.

Reference conventions, read-only: sibling 2026-CODEX-MagicInterview and 2026-MANUS-oulang, including their native builds, Better Auth, RevenueCat, pay.megawebs.com HMAC checkout and Coolify patterns. Never copy their credentials or application identifiers into DuoDeck sources. Never print secrets, browser cookies, private keys or bearer tokens. Credentials remain outside Git or in ignored local files.

Product domain: https://duodeck.megawebs.com. iOS identifier com.agentsai.duodeck; team U549N38BV6. Premium entitlement DuoDeck Pro; retain a useful local free control mode without login. Native stores use store IAP via RevenueCat; website uses pay.megawebs.com. Do not link native paywalls to external payment without a proven storefront entitlement.

Store and deployment mutations have one coordinator. Worker agents must stay in their assigned paths, never commit/push, publish, change another checkout, or interfere with another worker. Record actual build/test outcomes in .build/orchestration/<worker>-result.md; never mark an operation complete without proof. Do not add TODO placeholders or synthetic successful implementations. No public release claims without actual provider confirmation.

App Store client artifacts must exclude private host APIs and be sandboxed on macOS. Do not disable sandboxing to make a Mac App Store build work. Preserve the separately signed/notarized Mac host for capture and remote input functionality.

Product direction and the current professional execution prompt: docs/PRODUCT_BRIEF.md. Operational release authority: docs/release-checklist.md, script/build_and_run.sh, script/release_mac.sh and Scripts/release-ios.sh. Older engineering notes are context, not current publishing destinations.
