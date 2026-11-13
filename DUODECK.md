# DuoDeck for iPhone Duo

DuoDeck turns the lower half of a half-folded iPhone Duo into an adjustable Mac trackpad and control surface, while keeping the Mac video above the fold.

## DuoDeck additions
- Compact, balanced and full trackpad footprints selected in the lower half; saved between launches.
- Compact and balanced layouts put Mac shortcut presets beside the trackpad.
- Built-in Editing, Browsing, Windows and Code shortcut palettes. Each shortcut sends proper HID key down and up events, with Mac modifier flags.
- Works with the free DuoDeck Host companion for Mac.

## Requirements
An iPhone Duo with iOS 27.1 or later for fold-aware laptop layout, plus a Mac running DuoDeck Host. On ordinary iPhones and iPads, the standard layouts remain available.

## Build
On a Mac with Xcode 27.1 or newer, run xcodebuild with project apps/ios/DuoDeck.xcodeproj, scheme DuoDeck, configuration Debug and destination generic/platform=iOS Simulator, with CODE_SIGNING_ALLOWED=NO.

For code signing, use your own Apple Developer account and unique bundle identifier. The current DuoDeck bundle identifier is com.agentsai.duodeck (Agents AI Ltd.).

The open-source license is Apache 2.0; please retain the LICENSE and NOTICE files when redistributing.
