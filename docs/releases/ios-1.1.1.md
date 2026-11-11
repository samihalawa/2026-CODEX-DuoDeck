# DuoDeck for iPhone and iPad 1.1.1 (2026111201)

Held until Apple approves 1.1.0 (version 13d239d5-2eb9-4767-a9bd-f33780f4db97, submission efcd0eb4-1f69-4910-b13b-f09cdf1703fd). Owner decision, 11 November 2026: ship after approval, do not replace 1.1.0 in review.

## What's New (App Store text)

Your Macs show up the moment you open DuoDeck, and connecting works in more places.

- Your paired Macs appear instantly, then light up as soon as they're found.
- On your iPhone's hotspot or without shared Wi-Fi, DuoDeck now looks for your Mac nearby by itself. Turn on Without Wi-Fi in DuoDeck on your Mac (version 1.2.2 or later), or connect with a USB cable.
- Smoother, livelier Macs list.

## Release steps, once 1.1.0 is approved

1. `Scripts/release-ios.sh --upload --api-key ~/.appstoreconnect/private_keys/AuthKey_Q92YCL7C6D.p8 --api-issuer 3812fee7-31e4-4330-ae7a-ca0a5992f475` (build 2026111201 from main at or after d7add18).
2. In App Store Connect (helm-asc), create iOS version 1.1.1, paste the What's New text above, select build 2026111201, keep the 1.1.0 screenshots, add for review and submit; automatic release after approval.
3. Read back the version state with `helm-asc apps 6832548998 versions --agent`.
