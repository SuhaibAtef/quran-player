## Context

The app is English-only and LTR-only. `lib/app/app.dart` builds a `MaterialApp.router` wired with `FLocalizations` delegates *only* — there is no `flutter_localizations`, `intl`, or `generate: true`, and every UI-chrome string is a hardcoded literal. Preferences (theme mode, reader mode, mushaf colour scheme) follow a settled pattern: a Riverpod provider backed by `shared_preferences`, e.g. `lib/app/state/theme_mode_provider.dart`.

Two facts constrain the design:

- **ForUI is already RTL- and Arabic-capable.** It ships `FLocalizations` (including `ar`) and direction-aware widgets. This change *composes with* ForUI's delegates, never replaces them.
- **Quran content is already RTL.** The mushaf engine and the text reader render Arabic Quran/tafsir content with their own pinned direction. This change is about **UI chrome** — navigation, buttons, labels, menus, settings — not Quran content.

## Goals / Non-Goals

**Goals:**

- An ARB-based localization pipeline producing a typed `AppLocalizations` accessor, covering English and Arabic.
- A persisted locale preference (English / Arabic / System) consistent with the existing theme-mode pattern.
- Correct right-to-left layout for all UI chrome when an RTL locale is active.
- Conventions documented in `AGENTS.md` so every later V1 feature stays locale- and RTL-aware by default.

**Non-Goals:**

- Translating Quran or tafsir *content* (Quran text stays exactly as sourced).
- The V1 design rework — this change makes the *current* chrome localizable, not prettier.
- Languages beyond `en` / `ar` — the pipeline is extensible (drop in another ARB), but no third language ships here.
- Changes to the mushaf rendering engine or the always-RTL reader content.

## Decisions

### 1. Flutter's built-in `gen-l10n`, not a third-party l10n package

Use `generate: true` + an `l10n.yaml` + ARB files, generating `AppLocalizations` via Flutter's official tooling. Rationale: zero added runtime dependency, integrates natively with `flutter_localizations`/`MaterialApp`, the same delegate model ForUI already uses, and it is what the `flutter-setup-localization` skill targets. Alternatives — `slang` (compile-time, nicer API) and `easy_localization` (runtime JSON, no codegen type-safety) — were rejected: for a small string catalogue the extra dependency and divergent idiom are not justified ("simplicity first").

### 2. ARB layout

`lib/l10n/app_en.arb` is the template; `lib/l10n/app_ar.arb` is the Arabic catalogue. `l10n.yaml` sets `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-class: AppLocalizations`, `nullable-getter: false`, and `synthetic-package: false` so the generated Dart lands in the source tree as a real, importable file. The generated `app_localizations*.dart` is **gitignored and regenerated** by `flutter pub get` / `flutter gen-l10n` — it is build output, treated like other generated code.

### 3. Locale preference mirrors `theme_mode_provider`

A new `lib/app/state/locale_provider.dart` holds the choice as `English | Arabic | System`, persists a string key (`en` / `ar` / `system`) in `shared_preferences`, and exposes a resolved `Locale?` (null = follow the platform). `app.dart` passes that to `MaterialApp.router`'s `locale:`. Rationale: an exact parallel to the existing theme-mode provider keeps the codebase consistent and the change low-risk.

### 4. Compose delegates; don't replace ForUI's

`MaterialApp.router` gets `AppLocalizations.localizationsDelegates` **merged with** `FLocalizations.localizationsDelegates`, and `supportedLocales` becomes `AppLocalizations.supportedLocales` (`en`, `ar`). ForUI's delegates stay so ForUI widget strings localize too; the app's narrower supported set drives platform locale resolution.

### 5. RTL via the framework's `Directionality`, not manual wrapping

An Arabic locale makes Flutter set `TextDirection.rtl` for the whole subtree automatically. The work is **auditing chrome for hardcoded LTR assumptions** and converting them to direction-aware primitives: `EdgeInsetsDirectional`, `AlignmentDirectional`, `PositionedDirectional`, directional `BorderRadius`, and `start`/`end` over `left`/`right`. Direction-encoding icons (back chevrons, page-turn affordances) flip with direction. The shell's `FSidebar` moves to the trailing edge and `FBottomNavigationBar` order reverses under RTL — verified against ForUI behaviour during the audit. Per-screen manual `Directionality` overrides were rejected: they fight the framework and scatter direction logic.

### 6. Quran content keeps its own pinned direction

Reader/mushaf content is always RTL Arabic regardless of the UI locale. Those widgets keep an explicit `TextDirection.rtl` so an English UI still renders Quran content correctly. UI chrome follows the locale; Quran content does not.

### 7. Localized numerals for display only

UI-chrome numbers (surah numbers in lists, result counts, ayah references shown in chrome) format through `intl` so an Arabic locale renders Eastern Arabic digits. **Identifiers never localize** — `AyahKey`s, route params (`/reader/ayah/2/255`), DB keys, and MCP arguments stay ASCII. Only human-facing display text is converted. The mushaf's font-baked ayah-end glyphs are untouched.

### 8. What is not a "UI string"

Extract user-visible chrome text only. Do **not** route through ARB: `appLogger` messages, error codes/identifiers, route paths and names, MCP tool names, asset paths, or DB column names. Parameterized and pluralized strings use ARB placeholders and `plural`.

## Risks / Trade-offs

- **Generated `AppLocalizations` absent on a fresh clone** → `generate: true` makes `flutter pub get` produce it; a missing file fails the build loudly. Documented in `AGENTS.md`/README, same accepted posture as the gitignored QUL assets.
- **Large mechanical diff across many features** → extraction is low-risk and mechanical; split into reviewable commits per feature area (aligns with the incoming commit-hygiene rule). `just check` and widget tests guard regressions.
- **Missed RTL bugs — a hardcoded `left`/`right` survives the audit** → the analyzer cannot catch every case. Mitigation: manual audit, exercising the running app under `ar`, and an RTL widget test on the shell. Residual risk accepted; fix as found.
- **Arabic translation quality** → `app_ar.arb` values are reviewed by an Arabic speaker (the maintainer); any provisional string is marked.
- **Quran content direction leaking into chrome (or vice versa)** → Decision 6 pins reader content to RTL explicitly; a test asserts an English UI still renders Arabic Quran content correctly.

## Migration Plan

Not a data migration — no schema or storage change. Staged rollout, each stage independently buildable:

1. Dependencies + `l10n.yaml` + ARB scaffolding with English strings only — a behavioural no-op (app still renders exactly as today).
2. String extraction per feature area, replacing literals with `AppLocalizations` lookups.
3. `app_ar.arb` Arabic catalogue, the locale selector in Settings, and the RTL chrome audit.

No rollback concern: the locale preference defaults to System and, with English strings, behaviour is unchanged.

## Open Questions

- Confirm the repo's stance on generated code — gitignore `app_localizations*.dart` (assumed) versus committing it.
- The exact surfaces that should show localized numerals — settled during extraction rather than enumerated up front.
- Whether ForUI 0.21.3's `FSidebar` / `FBottomNavigationBar` fully honour RTL or need manual tweaks — resolved by a short spike inside the RTL audit task.
