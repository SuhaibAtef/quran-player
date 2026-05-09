# android/CLAUDE.md

Read alongside the [root CLAUDE.md](../CLAUDE.md). This file holds Android-specific notes.

## Identity

- `applicationId` and `namespace` are both placeholder `com.example.quran_player` in [app/build.gradle.kts:9](app/build.gradle.kts#L9) and [app/build.gradle.kts:24](app/build.gradle.kts#L24). Change before any release.
- Renaming the package id requires updating: the Kotlin source path under [app/src/main/kotlin/](app/src/main/kotlin/), `applicationId`, `namespace`, and the `package=` in any `AndroidManifest.xml` overrides if added later.

## Build config

- Java/Kotlin target: **17** ([app/build.gradle.kts:14](app/build.gradle.kts#L14)).
- `compileSdk`, `minSdk`, `targetSdk`, `versionCode`, `versionName` are inherited from the Flutter Gradle plugin — bump them by editing [pubspec.yaml](../pubspec.yaml) (`version:`) and the Flutter SDK rather than hardcoding here.

## Signing

- Release builds currently sign with the **debug key** ([app/build.gradle.kts:37](app/build.gradle.kts#L37)) so `flutter run --release` works out of the box. **Replace with a real `signingConfig` before shipping** — never publish an APK/AAB signed with the debug key.
- Keep the keystore out of the repo; reference it via a gitignored `key.properties` file.
