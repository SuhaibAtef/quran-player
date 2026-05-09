# macos/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds macOS-specific notes.

## Identity

- `PRODUCT_BUNDLE_IDENTIFIER` is the placeholder `com.example.quranPlayer` and `PRODUCT_NAME` is `quran_player` ([Runner/Configs/AppInfo.xcconfig](Runner/Configs/AppInfo.xcconfig)). Change the bundle id before signing for distribution.
- App-display copyright also lives in [AppInfo.xcconfig](Runner/Configs/AppInfo.xcconfig) — currently the scaffold default.
- Version (`MARKETING_VERSION`) and build number (`CURRENT_PROJECT_VERSION`) are driven by `version:` in [pubspec.yaml](../pubspec.yaml) — do not hardcode.

## Sandbox & entitlements

macOS apps run sandboxed by default. The two entitlement files diverge:

- [Runner/DebugProfile.entitlements](Runner/DebugProfile.entitlements) — sandbox + JIT (`com.apple.security.cs.allow-jit`) + `com.apple.security.network.server` (so `flutter run` and DevTools can attach over the loopback).
- [Runner/Release.entitlements](Runner/Release.entitlements) — sandbox only. **No `com.apple.security.network.client`**, so the release build cannot make outbound HTTP requests as-is. Add `com.apple.security.network.client` before any recitation-streaming feature ships, otherwise audio fetch will fail silently in Release.

Add narrow entitlements only as features need them: `com.apple.security.files.user-selected.read-only` for letting the user pick local audio, etc. Keep the sandbox on.

## Signing

- Signing is configured in Xcode (Runner target → Signing & Capabilities). Keep `DEVELOPMENT_TEAM` out of `project.pbxproj` if multiple devs share the repo; configure via CI secrets for release builds.
- Notarization is required for distribution outside the Mac App Store — wire that into the release pipeline when one exists.

## Build

- `flutter build macos` produces `build/macos/Build/Products/Release/quran_player.app`. Ship the `.app` bundle inside a notarized DMG or `.pkg`, not the bare bundle.
