# Authentic iOS store screenshots — en-US

Captured on Mac4 on 2026-11-09 from DuoDeck 1.1.0 (2026110902), bundle com.agentsai.duodeck.

## Images

| File | Native dimensions | Simulator | Scene |
| --- | --- | --- | --- |
| iphone-6_3-connect.png | 1206 × 2622 | iPhone 17 Pro, iOS 27.0 | Actual connection screen |
| ipad-13-connect.png | 2064 × 2752 | iPad Pro 13-inch (M5), iOS 27.0 | Actual connection screen |

Both images were directly inspected after capture. They show the DuoDeck identity, Connect to a Mac, the genuinely discovered Mac3 marked Not paired, Pair a Mac, and the host/support/privacy links. Discovery was real Bonjour browsing on Mac4's network. No connection to, pairing with, or operation of Mac3 was performed.

## Capture provenance

Two dedicated new simulators were created for this task:

- iPhone: F7317CDD-90DC-4B9A-AAD4-057E6D1F0A6F
- iPad: C0033497-0517-44CE-98DF-0393C03859E4

The final compiled app at .build/ios-native-ui/Build/Products/Debug-iphonesimulator/Sill.app was installed on each. Its Info.plist was checked for the bundle, display name, version and build number. The installed app is DuoDeck, minimum iOS 17.0.

Both simulators used a clean, normal launch with no app arguments:

    xcrun simctl launch --terminate-running-process SIMULATOR_ID com.agentsai.duodeck

Light appearance was selected using the simulator's standard UI appearance command. Screenshots were captured with the standard simctl io screenshot command.

No layout harness, mock catalog, mock pairing, saved fake Mac, fake video frame, debug UI launch flag, or status bar override was used. The images are original native simulator PNGs, without resizing, cropping, retouching or generated content. Native PNG encoding is 8-bit RGBA.

## File integrity

- iphone-6_3-connect.png — 161462 bytes
  SHA-256: de1acb94164150887ffa4df525f0fcf289f59eacf7b1069a064e10a8e9809505
- ipad-13-connect.png — 185270 bytes
  SHA-256: b45f42a8be158ae3722b21429c1a78468267ad5b8998ef22496ca569974d3ef9

## Scope and limitations

These are authentic initial connection-screen captures, one per device family. They do not demonstrate a connected streaming or trackpad session. No actual paired Mac4 session was available at capture time, so no connected controls/settings or streaming screen was presented as real.

Capture used the final branded source without debug substitutions. Other simulators and agent sessions were not modified. The two dedicated store simulators remain available for later genuine captures.

No upload or App Store submission was performed by the screenshot worker.

## Canonical branding refresh

These files replace the earlier build 2026110901 captures. They were recaptured after the shared native DuoDeckMark was changed to an original-color imageset copied byte-for-byte from the final AppIcon.png, and the header tagline was aligned to “Your Mac. In your hands.” The same native mark component is used in Connect and the compact connected deck.

Both replacement images were directly inspected: porcelain panels, teal pointer, three lines, and the canonical tagline are visible. The compiled app version/build was asserted to be 1.1.0/2026110902 before capture.

Canonical mark PNG SHA-256: f31f5592cb97c0fa621c05cd9916d3b5c116b0eedb625d9d025c346e8e83295e.

Simulator build evidence: .build/orchestration/ios-brand-final-build.log, BUILD SUCCEEDED.
