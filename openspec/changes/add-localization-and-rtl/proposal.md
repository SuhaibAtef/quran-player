## Why

Quran Companion is English-only and left-to-right only — every UI-chrome string is hardcoded, and the shell assumes LTR layout. Its primary users are Arabic-speaking Muslims and students of Quran, for whom an Arabic interface is a baseline expectation, not a nicety.

This must land before the rest of V1. The design rework, the custom title bar + mode system, and Teacher mode all reshape the UI shell, and right-to-left is a layout fact — building that chrome LTR-only guarantees a rebuild. Localizing first means every subsequent V1 surface is built locale- and RTL-aware from the start.

## What Changes

- Add the `flutter_localizations` + `intl` dependencies, enable `generate: true`, and add an `l10n.yaml` configuration.
- Introduce an ARB-based string catalog: `app_en.arb` (the English template) and `app_ar.arb` (Arabic), generating a typed `AppLocalizations` accessor.
- Extract every current hardcoded UI-chrome string into the catalog and replace usages with `AppLocalizations` lookups — across the app shell, Surahs, Search, Bookmarks, Settings, MCP Status, the reader, the mini player, the verse action menu, and the error/degrade screens.
- Wire `AppLocalizations.delegate` into `MaterialApp.router` alongside ForUI's existing `FLocalizations`.
- Add a persisted locale preference — English / Arabic / System — as a Riverpod provider mirroring `themeModeProvider`, surfaced as a language selector in Settings.
- Full right-to-left support: the active locale drives `Directionality`; audit the chrome for hardcoded directional layout (sidebar side, paddings, alignments, directional icons) and move it to direction-aware primitives.
- Locale-aware formatting of UI-chrome numerals (Eastern Arabic digits under Arabic).
- Update `AGENTS.md` so new UI strings go through the ARB catalog rather than being hardcoded, and chrome uses directional layout primitives.

Out of scope: translating Quran or tafsir *content* (UI chrome only — Quran text stays exactly as sourced and already renders RTL); the design rework itself; the mushaf rendering engine (it already renders RTL Arabic content).

No breaking changes for end users; no database, schema, or API changes.

## Capabilities

### New Capabilities

- `localization`: app locale selection and persistence, the ARB-based string catalog and generated accessor, right-to-left / text-direction behavior, and locale-aware formatting of UI-chrome values.

### Modified Capabilities

<!-- None. Existing feature specs do not change their requirements; their UI
     strings being externalized to the catalog traces to the new `localization`
     capability rather than altering any existing spec's behavior. -->

## Impact

- **Dependencies / config**: `pubspec.yaml` (`flutter_localizations`, `intl`, `generate: true`); new `l10n.yaml`; new `lib/l10n/app_en.arb` + `lib/l10n/app_ar.arb`; generated `AppLocalizations`.
- **App composition**: `lib/app/app.dart` gains the localization delegate, supported locales, and the active `locale`; new `lib/app/state/locale_provider.dart` (persisted via `shared_preferences`, like `theme_mode_provider.dart`).
- **Feature code**: every widget with hardcoded UI strings is touched to read from `AppLocalizations`; chrome widgets are audited for directional layout.
- **ForUI**: `FLocalizations` already supports Arabic — the app composes its own delegate alongside it.
- **Docs**: `AGENTS.md` updated with the ARB-string and directional-layout conventions.
- **Tests**: widget tests that pump the app must supply the localization delegates; new tests cover locale selection/persistence and RTL layout direction.
