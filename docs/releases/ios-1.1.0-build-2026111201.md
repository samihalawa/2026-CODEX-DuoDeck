# DuoDeck for iPhone and iPad 1.1.0, build 2026111201

Replaces build 2026111001 in the 1.1.0 review. Owner decision, 11 November 2026: 1.1.0 was still waiting for review, so its submission was cancelled and this build sent instead.

## What's New (App Store text)

Your Macs show up the moment you open DuoDeck, and connecting works in more places.

- Your paired Macs appear instantly, then light up as soon as they're found.
- On your iPhone's hotspot or without shared Wi-Fi, DuoDeck now looks for your Mac nearby by itself. Turn on Without Wi-Fi in DuoDeck on your Mac (version 1.2.2 or later), or connect with a USB cable.
- Smoother, livelier Macs list.

## Release steps, once 1.1.0 is approved

1. `Scripts/release-ios.sh --upload --api-key ~/.appstoreconnect/private_keys/AuthKey_Q92YCL7C6D.p8 --api-issuer 3812fee7-31e4-4330-ae7a-ca0a5992f475` (build 2026111201 from main at or after d7add18).
2. In App Store Connect (helm-asc), create iOS version 1.1.1, paste the What's New text above, select build 2026111201, keep the 1.1.0 screenshots, add for review and submit; automatic release after approval.
3. Read back the version state with `helm-asc apps 6832548998 versions --agent`.
