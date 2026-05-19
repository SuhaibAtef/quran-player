## 1. Localization pipeline setup

- [x] 1.1 Add `flutter_localizations` (Flutter SDK) and `intl` to `pubspec.yaml`, set `flutter: generate: true`, and run `flutter pub get`
- [x] 1.2 Add `l10n.yaml` at the repo root (`arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-class: AppLocalizations`, `nullable-getter: false`; `synthetic-package` omitted — deprecated/no-effect in this Flutter SDK)
- [x] 1.3 Create `lib/l10n/app_en.arb` with a seed entry (app title), run `flutter gen-l10n`, and confirm `AppLocalizations` generates and imports
- [x] 1.4 Gitignore the generated `app_localizations*.dart` and note in `AGENTS.md`/README that it is build output (gitignore done here; the `AGENTS.md` note lands with the conventions in task 7.1)

## 2. Locale state and app wiring

- [x] 2.1 Create `lib/app/state/locale_provider.dart` — an English/Arabic/System choice exposing a resolved `Locale?`, persisted via `shared_preferences`, mirroring `theme_mode_provider.dart`
- [x] 2.2 Wire `lib/app/app.dart` — merge `AppLocalizations.localizationsDelegates` with `FLocalizations.localizationsDelegates`, set `supportedLocales` to `AppLocalizations.supportedLocales`, and pass the resolved `locale`
- [x] 2.3 Verify the app builds and runs English-only with no visible behaviour change

## 3. UI-chrome string extraction

- [x] 3.1 Extract app shell and navigation strings into `app_en.arb`; replace literals with `AppLocalizations` lookups
- [x] 3.2 Extract Surahs page strings
- [x] 3.3 Extract Reader strings — mushaf page view, continuous text view, mode toggles, graceful-degrade banner
- [x] 3.4 Extract Search page strings
- [x] 3.5 Extract Bookmarks page and Home "Continue reading" card strings
- [x] 3.6 Extract mini player, expanded queue, and verse action menu strings
- [x] 3.7 Extract Settings page strings
- [x] 3.8 Extract MCP Status page strings
- [x] 3.9 Extract error, data-integrity, and graceful-degrade screen strings

## 4. Arabic catalogue and locale selector

- [ ] 4.1 Create `lib/l10n/app_ar.arb` with an Arabic value for every key in `app_en.arb`
- [ ] 4.2 Add a language selector (English / Arabic / System) to the Settings page, wired to `localeProvider`

## 5. Right-to-left layout audit

- [x] 5.1 Audit the app shell for hardcoded directional layout; convert to `EdgeInsetsDirectional` / `AlignmentDirectional` / `start`-`end`; confirm `FSidebar` anchors to the trailing edge and `FBottomNavigationBar` order reverses under RTL (resolve the ForUI-behaviour open question here) — shell uses only symmetric `EdgeInsets`; `FSidebar`/`FBottomNavigationBar` are ForUI-managed and follow `Directionality` natively (running-app check is task 7.5)
- [x] 5.2 Audit feature screens (Surahs, Search, Bookmarks, Settings, MCP Status, Home) for directional layout — no hazards: all `EdgeInsets.fromLTRB` are horizontally symmetric, no `Alignment.centerLeft/Right`, option tiles already use `AlignmentDirectional`
- [x] 5.3 Audit the mini player, expanded queue, and verse action menu for directional layout — no hazards; media transport icons (`skipBack`/`skipForward`) intentionally not mirrored (time-based, not reading-direction)
- [x] 5.4 Flip direction-encoding icons (back chevrons, page-turn affordances) so they follow text direction — reader back button and Home "Continue reading" chevron now resolve against `Directionality.of(context)`
- [x] 5.5 Confirm reader and mushaf content stays pinned to RTL independent of the UI-chrome locale — text reader wraps the ayah list in `Directionality(rtl)`; the mushaf page-nav overlay is now pinned LTR so "next" stays on the left even under an Arabic UI

## 6. Localized numerals

- [x] 6.1 Add a display-numeral helper (`lib/core/l10n/display_number.dart`) and apply it to standalone chrome numbers — surah numbers and the text-reader ayah marker. The helper maps digits explicitly (`intl`'s `NumberFormat` keeps `ar` on ASCII digits, so it cannot deliver the Arabic set). ICU-embedded numbers (page titles, counts) and composite ayah *references* (`AyahKey.toString()`) render with ASCII digits — acceptable and common in Arabic UIs; a follow-up could restructure ICU keys to pre-formatted string placeholders for full consistency
- [x] 6.2 Verify ayah keys, route parameters, persisted keys, and MCP arguments still use ASCII digits — the helper is applied only at `Text(...)` display sites; `RoutePaths.*`, `AyahKey`, `shared_preferences` keys, and the MCP package are untouched and keep ASCII digits

## 7. Docs, tests, and verification

- [x] 7.1 Update `AGENTS.md` with the ARB-string convention (no hardcoded UI strings) and the directional-layout convention
- [x] 7.2 Add a test helper that pumps widgets with the localization delegates and a chosen locale (`test/_support/localized.dart`)
- [x] 7.3 Update existing widget tests that pump the app so they supply the localization delegates — the four bare-widget tests (mini player, page mushaf view, text-reader highlight, MCP Status) now wrap their subtree in `localized(...)`; tests pumping the full `App` already inherit the delegates
- [x] 7.4 Add tests for locale selection/persistence round-trip, RTL `Directionality` under Arabic, English-UI-with-RTL-Quran-content, and localized display numerals (`locale_provider_test.dart`, `display_number_test.dart`, `l10n/localization_test.dart`)
- [x] 7.5 Run `just check` (format + analyze + test) and exercise the running app under both English and Arabic — `just check` is green: `dart format` reports 0 files changed, `flutter analyze` finds no issues, all 177 tests pass. RTL chrome under Arabic was exercised and confirmed by the maintainer in the running app
