# Authentic iOS store screenshots — en-US

Captured on Mac4 on 2026-11-09 at approximately 16:50 UTC from DuoDeck 1.1.0 (2026110903), bundle `com.agentsai.duodeck`. These replace the earlier teal build 2026110902 captures.

## Images

| File | Native dimensions | Scene |
| --- | --- | --- |
| iphone-6_3-connect.png | 1206 × 2622 | Macs list with real Bonjour discovery and Add Mac |
| iphone-6_3-add-mac.png | 1206 × 2622 | Native Add Mac sheet, empty manual pairing fields |
| iphone-6_3-setup.png | 1206 × 2622 | Set up your Mac help, reached through normal navigation |
| ipad-13-connect.png | 2064 × 2752 | Macs list at readable iPad width |
| ipad-13-add-mac.png | 2064 × 2752 | Native Add Mac form sheet, empty manual pairing fields |
| ipad-13-setup.png | 2064 × 2752 | Set up your Mac help at readable iPad width |

All six canonical PNGs were individually inspected after capture. They show the final system typography, semantic surfaces and blue accent, with clear Add Mac text and no repeated promotional mark or slogan.

## Capture provenance

The two dedicated store simulators were reused:

- DuoDeck Store iPhone 6.3: iPhone 17 Pro, iOS 27.0; F7317CDD-90DC-4B9A-AAD4-057E6D1F0A6F.
- DuoDeck Store iPad 13: iPad Pro 13-inch (M5), iOS 27.0; C0033497-0517-44CE-98DF-0393C03859E4.

The compiled app at `.build/ios-native-ui/Build/Products/Debug-iphonesimulator/Sill.app` was installed on each. Its Info.plist was checked as version 1.1.0, build 2026110903. The simulator build succeeded; evidence is in `.build/orchestration/ios-native-v2-final-build.log`.

Both used a normal `XCUIApplication(bundleIdentifier: "com.agentsai.duodeck")` launch with no app arguments. XCTest navigated the actual app through Macs → Add Mac → Cancel → Set up your Mac. Images were captured as native XCTest screenshots and copied byte-for-byte from the result attachments. The isolated test runner lives only under the ignored `.build/orchestration/ios-native-v2-ui` directory; the shipped Xcode project has no added UI-test target.

Both simulators used light appearance and the standard Large content-size category. No layout harness, mock catalog, mock pairing, saved fake Mac, fake video frame, debug UI launch argument, or status bar override was used. The PNGs have not been resized, cropped, retouched, composited or generated.

The Macs list shows the genuinely discovered “MacBook Pro de Sami (2)” as Not paired. No connection to, pairing with, or operation of this Mac was performed. The simulator has no camera, so Add Mac legitimately shows the manual address/code path rather than the camera scanner.

The normal-flow tests also checked 12-digit code formatting after the blank-field screenshot, then cancelled without pressing Pair Mac. Those test values were never sent to a host and are not in any store screenshot.

## Integrity and test evidence

`capture-provenance.json` records each file's native dimensions, byte count, SHA-256, source attachment, timestamp, build and empty launch-argument array.

| File | Bytes | SHA-256 |
| --- | ---: | --- |
| iphone-6_3-connect.png | 133711 | 67feaf1de0940950f68752df2cdd101b67c263d807c9ec46c8e907f2026479f3 |
| iphone-6_3-add-mac.png | 148596 | 41d893771902a56d88302d278164b83352f392e53c6e1b2af4ab1ce303712a13 |
| iphone-6_3-setup.png | 221941 | 999b81bb05af0b571dd6303be666426e8bcb6c0aea90cfd787fc85496b82b57a |
| ipad-13-connect.png | 149672 | d073a0a880ab16ffaac6583023468295ce92d1293a4a42a2f89c70c63698a436 |
| ipad-13-add-mac.png | 261914 | 5b92b45944a77c6d5143e0da027a55b42015808cf16318fb91141479f7561fcc |
| ipad-13-setup.png | 207519 | dbb9901c901a019f16935748dbcf3505222677a12f9ee8fe32d6826e332560d6 |

Normal-flow result bundles:

- `.build/orchestration/ios-native-v2-ui/phone-store-final.xcresult` — 1 test, 0 failures.
- `.build/orchestration/ios-native-v2-ui/ipad-store-final.xcresult` — 1 test, 0 failures.

The final app icon and shared mark were supplied by the release coordinator. Their PNG SHA-256 is `a02b8296df9e04c246a4282f398b30175a7b70e940269e1de8bb8a3a0d4a706b`. Working screens intentionally use native controls and text without repeated product marks.

## Scope and limitations

These are authentic discovery, pairing-entry and setup screens. They do not demonstrate a connected streaming session. Separate connected-layout QA images use the repository's existing DEBUG fixture and remain under `.build`; none are store assets.

The release coordinator corrected the camera permission purpose string after these captures. No screenshot contains a camera prompt; that string-only correction does not change the depicted screens. The final archive is rebuilt separately by the release coordinator.

No upload, App Store submission, credential entry or security-permission change was performed by the screenshot worker. Other simulators and agent sessions were preserved.
