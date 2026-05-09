# quran_player

Flutter app (Android, iOS, web, Windows, macOS, Linux) intended to become a
Quran audio player. **Current state: fresh `flutter create` scaffold** —
`lib/main.dart` is still the default counter demo, `test/widget_test.dart`
tests it, no domain code exists yet. No HTTP, no auth, no storage, no
platform channels in the repo today. Most patterns below describe what the
codebase *will* do as features land; revise this file when real code arrives.

UI library: [forui](https://forui.dev/) (planned, not yet a dependency).
Project mgmt in Linear, hosted on GitHub. Dart SDK `^3.10.4`. Common
workflows are wrapped in the root `Justfile`.

## Auth shape

There is **no authentication code in the repo today** and the app is
expected to remain client-only in early scope (recitations are public
content). If/when auth lands, the convention will be a single
`AuthSession` exposed via the chosen state-mgmt layer with a
`requireAuth()` guard. Until that exists, treat any HTTP client
construction, token persistence, or `Authorization` header as a finding
worth flagging — none of that should be present yet.

## Threat model

A Quran player is content-delivery software; recitation audio is
religiously sensitive and tampering is the highest-impact bug class.

1. **Audio source integrity** — recitations will stream/download from
   third-party mirrors. Any `http://` URL, disabled cert validation, or
   user-controlled stream URL flowing into `just_audio` / `audioplayers`
   is critical: a swapped audio file is the worst-case outcome.
2. **On-device cache of downloads** — once offline mode ships, cached
   audio/mushaf files must live in per-app sandbox paths. Legacy Android
   external storage, iOS shared containers, or world-readable Linux
   paths leak reading history.
3. **WebView / deeplink abuse** — if `webview_flutter` or `url_launcher`
   shows tafsir/translation pages, unfiltered URLs become open-redirect
   or arbitrary-page-load vectors.
4. **Platform native surface** — Android currently signs release builds
   with the **debug keystore** (scaffold default); Linux `APPLICATION_ID`
   and Android `applicationId` are still `com.example.quran_player`
   placeholders.

## Project-specific patterns to flag

- **Hardcoded `http://` literals** anywhere under `lib/` — audio,
  mushaf images, translation JSON must all be HTTPS.
- **`MethodChannel` calls passing user-derived strings** (file paths,
  surah ids) without validation on the native side — path traversal in
  Kotlin/Swift/C++ runners is a real risk once playback ships.
- **`material` / `cupertino` widgets used where a ForUI equivalent
  exists** — consistency gate per the root `CLAUDE.md`, not a security
  finding, but worth surfacing.
- **Background-audio / foreground-service entitlements added outside a
  playback PR** — `UIBackgroundModes: audio` (iOS) or
  `FOREGROUND_SERVICE_MEDIA_PLAYBACK` (Android) showing up in an
  unrelated change is suspicious.
- **Any `Authorization` header, token storage, or `flutter_secure_storage`
  use** — premature given there's no backend; flag for review.

## Known false-positives

- `lib/main.dart`, `test/widget_test.dart` — scaffold counter demo,
  scheduled for deletion when real features land.
- `com.example.quran_player` package id in `android/app/build.gradle.kts`
  and `APPLICATION_ID` in `linux/CMakeLists.txt` — placeholders, not
  vulnerabilities; already documented in the platform `CLAUDE.md` files.
- Debug-key release signing in `android/app/build.gradle.kts` — known
  pre-release scaffold hack, will be replaced before any public APK.
- Per-platform `CMakeLists.txt` `-Wall -Werror` / `/W4 /WX` flags are
  intentional; warnings-as-errors is project policy.
