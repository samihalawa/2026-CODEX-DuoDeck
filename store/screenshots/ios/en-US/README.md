# Authentic iOS store screenshots — en-US

Captured on Mac4 on 2026-11-10 at about 11:20 UTC from DuoDeck 1.1.0 (2026111001), the build with the seated-Duo icon and violet accent, bundle `com.agentsai.duodeck`. The UTC time is derived from the Unix timestamps in `capture-provenance.json`. These replace the blue-accent build 2026110903 captures.

## Images

| File | Native dimensions | Scene |
| --- | --- | --- |
| iphone-6_3-connect.png | 1206 × 2622 | Macs list with real Bonjour discovery and Add Mac |
| iphone-6_3-add-mac.png | 1206 × 2622 | Native Add Mac sheet, empty manual pairing fields |
| iphone-6_3-setup.png | 1206 × 2622 | Set up your Mac help, reached through normal navigation |
| ipad-13-connect.png | 2064 × 2752 | Macs list at readable iPad width |
| ipad-13-add-mac.png | 2064 × 2752 | Native Add Mac form sheet, empty manual pairing fields |
| ipad-13-setup.png | 2064 × 2752 | Set up your Mac help at readable iPad width |

All six canonical PNGs were individually inspected after capture. They show the final system typography, semantic surfaces and violet accent, with clear Add Mac text and no repeated promotional mark or slogan.

## Capture provenance

The two dedicated store simulators were reused:

- DuoDeck Store iPhone 6.3: iPhone 17 Pro, iOS 27.0; F7317CDD-90DC-4B9A-AAD4-057E6D1F0A6F.
- DuoDeck Store iPad 13: iPad Pro 13-inch (M5), iOS 27.0; C0033497-0517-44CE-98DF-0393C03859E4.

The compiled app at `.build/ios-native-ui/Build/Products/Debug-iphonesimulator/DuoDeck.app` was installed on each. Its Info.plist was checked as version 1.1.0, build 2026111001 (compiled at `.build/ios-icon-check/Build/Products/Debug-iphonesimulator/DuoDeck.app` for this capture). The simulator build succeeded; evidence is in `.build/orchestration/ios-native-v2-final-build.log`.

Both used a normal `XCUIApplication(bundleIdentifier: "com.agentsai.duodeck")` launch with no app arguments. XCTest navigated the actual app through Macs → Add Mac → Cancel → Set up your Mac. Images were captured as native XCTest screenshots and copied byte-for-byte from the result attachments. The isolated test runner lives only under the ignored `.build/orchestration/ios-native-v2-ui` directory; the shipped Xcode project has no added UI-test target.

Both simulators used light appearance and the standard Large content-size category. No layout harness, mock catalog, mock pairing, saved fake Mac, fake video frame, debug UI launch argument, or status bar override was used. The PNGs have not been resized, cropped, retouched, composited or generated.

The Macs list shows the genuinely discovered “Mac3” as Not paired. No connection to, pairing with, or operation of this Mac was performed. The simulator has no camera, so Add Mac legitimately shows the manual address/code path rather than the camera scanner.

The normal-flow tests also checked 12-digit code formatting after the blank-field screenshot, then cancelled without pressing Pair Mac. Those test values were never sent to a host and are not in any store screenshot.

## Integrity and test evidence

`capture-provenance.json` records each file's native dimensions, byte count, SHA-256, source attachment, timestamp, build and empty launch-argument array.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| iphone-6_3-connect.png | 127644 | e06b8ea76f49b6939c8abcb235b28495cdbcdf5296f6a1214447ef546a93004c |
| iphone-6_3-add-mac.png | 147957 | fe5776c8c3ebaf25e23fd78c04bc6ba8e17018d285b57aa8e20612a64a209757 |
| iphone-6_3-setup.png | 221671 | ecd9a67df00d1b9c040807b9942bc3023cc20f33c4f86797c64207cd18cfa595 |
| ipad-13-connect.png | 144486 | 3c46fe038f4172b63ed41dd992fe09ca3cf70fff6d323ecade91ad86f7de6340 |
| ipad-13-add-mac.png | 257145 | 4174e510c055d9c22a06db6ab9d279607e008b70487f16fcb19a1fd4702b5464 |
| ipad-13-setup.png | 207285 | 29ddee91104f9139313b59683f2017c5c208abbee71d055938b3ac1837c6c9f3 |

Normal-flow result bundles:

- `.build/orchestration/ios-native-v2-ui/phone-violet.xcresult` — 1 test, 0 failures.
- `.build/orchestration/ios-native-v2-ui/ipad-violet.xcresult` — 1 test, 0 failures.

The final app icon and shared mark were supplied by the release coordinator. Their PNG SHA-256 is `3094208e3f10985d52495bb08b8a786af2db59fb73faa5798c70f8f103188904`. Working screens intentionally use native controls and text without repeated product marks.

## Scope and limitations

These are authentic discovery, pairing-entry and setup screens. They do not demonstrate a connected streaming session. Separate connected-layout QA images use the repository's existing DEBUG fixture and remain under `.build`; none are store assets.

These images were captured from build 2026111001 itself, the build they accompany.

The release coordinator corrected the camera permission purpose string after these captures. No screenshot contains a camera prompt; that string-only correction does not change the depicted screens. The final archive is rebuilt separately by the release coordinator.

No upload, App Store submission, credential entry or security-permission change was performed by the screenshot worker. Other simulators and agent sessions were preserved.
