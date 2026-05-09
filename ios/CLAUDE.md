# ios/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds iOS-specific notes.

## Identity

- `PRODUCT_BUNDLE_IDENTIFIER` lives in [Runner.xcodeproj/project.pbxproj](Runner.xcodeproj/project.pbxproj). Default is `com.example.quranPlayer` (set by `flutter create`) — change before shipping to the App Store.
- `CFBundleDisplayName` is **"Quran Player"** and `CFBundleName` is `quran_player` ([Runner/Info.plist:7-16](Runner/Info.plist#L7-L16)). Update `CFBundleDisplayName` if the user-visible app name changes.
- Version (`CFBundleShortVersionString`) and build number (`CFBundleVersion`) are driven by `version:` in [pubspec.yaml](../pubspec.yaml) — do not hardcode.

## Signing & capabilities

- Signing config is set in Xcode (Runner target → Signing & Capabilities). Keep development team out of `project.pbxproj` if multiple devs share the repo; configure via `--export-options-plist` for CI builds.
- When adding capabilities (background audio for playback, push, etc.), update both Xcode entitlements and [Runner/Info.plist](Runner/Info.plist) keys — Flutter does not generate these for you.

## Notes

- Quran playback will likely need `UIBackgroundModes` → `audio` in Info.plist. Add it when audio playback lands.
