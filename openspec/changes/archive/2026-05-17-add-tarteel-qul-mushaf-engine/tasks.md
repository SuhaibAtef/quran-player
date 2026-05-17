## 1. Spike — verify the rendering assumptions before building

- [x] 1.1 Unzip a few `pN.ttf` from `assets/qul/ttf.zip` and render sample glyph strings from `qpc-v4.db` `words.text` in a throwaway Flutter widget. Confirm: (a) a line's glyph run fills its width at the page's design size, or whether explicit space/kashida distribution is needed; (b) whether QPC V4 tajweed colour is intrinsic to the font glyphs or applied. Record both findings in `design.md` (resolves Open Questions 1 and 2).
- [x] 1.2 Confirm the layout↔word join: a `pages` row's `first_word_id..last_word_id` range against `qpc-v4.db` `words.id` yields the expected words for that line, with surah/ayah coordinates intact. Note the `info` table's actual `number_of_pages` / `lines_per_page` / `font_name` values.

## 2. Scaffold the `tarteel_qul` package

- [x] 2.1 Create `packages/tarteel_qul/` as a Flutter package: `pubspec.yaml` (`name: tarteel_qul`, Dart SDK `^3.11.0`, `resolution: workspace`, `publish_to` NOT set to none, deps on `flutter`, `sqflite_common_ffi`), plus `README.md`, `CHANGELOG.md`, `LICENSE`. (Per design D1 the package is asset-agnostic — `pageFont` returns raw per-page bytes — so it carries no unzip dependency; `archive` lives in the root pubspec for the host `MushafAssetSource`, task 5.3.)
- [x] 2.2 Add `packages/tarteel_qul` to the root `pubspec.yaml` `workspace:` list and as a path dependency.
- [x] 2.3 `flutter pub get`; confirm the workspace resolves cleanly.
- [x] 2.4 Add `test/isolation_test.dart` in the package asserting no file under `packages/tarteel_qul/lib/` imports `package:quran_player/`.

## 3. Engine core — asset source, parsing, coordinate API

- [x] 3.1 Define `MushafAssetSource` (abstract): `layoutDb()`, `wordDb()`, `pageFont(int page)` — all returning `Future<Uint8List>`.
- [x] 3.2 Define typed models: `MushafPage`, `MushafLine` (line type `ayah`/`surahName`/`basmallah`, `isCentered`), `MushafWord` (id, glyph-code text, surah, ayah, word index).
- [x] 3.3 Implement `MushafLayoutRepository`: open the layout + word DBs from the asset source; derive dimensions from the `pages` table (the QPC V4 layout DB has no `info` table — see the task-1 spike); produce `page(page)` lines via the `first_word_id..last_word_id` ↔ `words.id` join.
- [x] 3.4 Implement schema validation on open — expected tables/columns present — surfacing a structured failure (not an exception) on mismatch.
- [x] 3.5 Implement the coordinate API: `pageForAyah`, `firstAyahOnPage`, `ayahsOnPage`, `pageForSurah`; out-of-range input returns a structured failure.
- [x] 3.6 Tests: a fake `MushafAssetSource` over small fixture DBs; assert page→lines, the word join, schema-validation failure, and coordinate round-trips (Spec `mushaf-engine`: parsing, validation, coordinate API).

## 4. Engine rendering — fonts and `MushafView`

- [x] 4.1 Implement `FontCache`: lazily fetch `pageFont(N)` from the asset source, register it once via Flutter's `FontLoader` under a stable family (e.g. `qul_p{N}`), cache process-wide.
- [x] 4.2 Implement line rendering: `ayah` lines as RTL justified glyph runs in the page font; `surah_name` / `basmallah` / centered lines centered.
- [x] 4.3 Implement `MushafView` — renders a page, emits `onWordTap(MushafWord)` and `onAyahTap(AyahKey)`, accepts a `decorations` list (ayah-highlight model). No "mode" concept in its API.
- [x] 4.4 Implement `MushafController` for page navigation (open/next/prev, current page).
- [x] 4.5 Tests: widget tests with a fake asset source — page renders expected line count, word-tap emits the right `MushafWord`, ayah-tap emits the right `AyahKey`, a supplied decoration renders, lazy font load happens once per page (Spec `mushaf-engine`: rendering, `MushafView`).
- [x] 4.6 Add a minimal `packages/tarteel_qul/example/` app driven by a checked-in tiny fake/fixture asset source (`DemoMushafAssetSource`) so the package is runnable without a QUL download (pub.dev hygiene).

## 5. App integration — assets and asset source

- [x] 5.1 Add `assets/qul/` to `.gitignore`. Confirm the downloaded QUL files (`qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, `ttf.zip`) are present locally and ignored by git.
- [x] 5.2 Declare the QUL files as Flutter assets in the root `pubspec.yaml`.
- [x] 5.3 Implement a host `MushafAssetSource` (`BundledMushafAssetSource` in [lib/data/quran/mushaf_engine.dart](../../../lib/data/quran/mushaf_engine.dart)) reading the bundled assets: the layout + word DBs directly, page fonts unzipped on demand from `ttf.zip`.
- [x] 5.4 Add a light structural validation + "mushaf assets available?" check the reader can branch on — `openMushafEngine` validates 604 pages + a smoke test and yields `MushafEngine.usingFallback` on any failure (fail-soft to text mode — Spec `mushaf-reader`: graceful degrade).

## 6. App integration — re-back the seam and rebuild page mode

- [x] 6.1 Implement `QulMushafLocator` (in [lib/data/quran/mushaf_engine.dart](../../../lib/data/quran/mushaf_engine.dart)) satisfying the existing `MushafLocator` contract, backed by the engine's coordinate API. Keep `kMushafPageCount = 604`.
- [x] 6.2 Update `lib/data/quran/mushaf_locator_provider.dart` to provide the QUL engine (`mushafEngineProvider` — async, lazy); delete `mushaf_locator_qcf.dart`. (`QulMushafLocator` lives in the consolidated adapter `mushaf_engine.dart` so `package:tarteel_qul/` stays confined to two host files.)
- [x] 6.3 Rebuild `lib/features/reader/widgets/page_mushaf_view.dart` on `tarteel_qul`'s `MushafView`: preserve mouse-drag paging (in `MushafView`), keyboard arrow navigation, prev/next buttons, RTL paging, and active-ayah playback highlighting (passed as a decoration).
- [x] 6.4 Wire the degrade path: missing/invalid QUL assets or a font-load failure → session fallback to text mode + non-fatal banner; persisted preference unchanged; never the data-integrity fatal screen.
- [x] 6.5 Update reader-locator and reader-widget tests for `QulMushafLocator` / `MushafView`; replace the qcf import-boundary test with one asserting `package:tarteel_qul/` is imported only by the engine adapter and the page widget.

## 7. Remove qcf_quran_plus

- [x] 7.1 Remove `qcf_quran_plus` from the root `pubspec.yaml`; `flutter pub get`.
- [x] 7.2 Delete any remaining qcf imports / references; confirm `flutter analyze` is clean.
- [x] 7.3 Swap the Settings attribution row from `qcf_quran_plus` to the QUL mushaf layout / word-script / KFGQPC fonts.
- [x] 7.4 Update `THIRD_PARTY_NOTICES.md`: remove the `qcf_quran_plus` entry; add QUL layout / word-script / KFGQPC font entries, noting the app binary redistributes the fonts and confirming the redistribution terms.

## 8. Docs and tooling

- [x] 8.1 `README.md`: add a required contributor setup step — download the QUL resources (QPC V4 layout, QPC V4 word script, V4 fonts) from qul.tarteel.ai into `assets/qul/`; note a fresh clone cannot `flutter build` until this is done.
- [x] 8.2 `packages/tarteel_qul/README.md`: document the package, the `MushafAssetSource` contract, and which QUL resources a consumer must supply.
- [x] 8.3 `AGENTS.md`: update *Project state* (mushaf reader now on `tarteel_qul` / QUL), *Lib layout* (add `packages/tarteel_qul/`, drop the qcf note), and *Notes for future work* (remove the deferred-rendering note; record the QUL asset model).
- [x] 8.4 Extend the pre-commit hook and `just test` to also run `flutter test packages/tarteel_qul/test/`.

## 9. Verification

- [x] 9.1 `just check` clean — format, analyze, host (142) + `quran_mcp_server` (32) + `tarteel_qul` (18) test suites pass. `flutter build windows` also succeeds (compile + QUL asset bundling validated).
- [x] 9.2 `openspec validate add-tarteel-qul-mushaf-engine` clean.
- [x] 9.3 Manual: launch the app on Windows, open the reader in page mode — confirm a QUL V4 page renders, paging works, and tapping a verse emits the ayah event. *(Confirmed by the user on-device, including the apply-phase fixes: RTL paging, ornamental headers, colour styles.)*
- [x] 9.4 Manual: confirm audio-follow highlights the active ayah on the page and the reader deep-link routes still work. *(Confirmed by the user on-device.)*
- [x] 9.5 Manual degrade test: the reader falls back to text mode with the non-fatal banner and no fatal screen when QUL assets are unavailable. *(Degrade logic is automated-covered by `reader_routes_test.dart`'s graceful-degrade tests; on-device behaviour confirmed by the user.)*

## 10. Folded-in scope: colour schemes, header fonts, Surahs list

Added during apply-phase verification (design D9/D10). The QUL "surah name" SVG font (resource 455) was evaluated and rejected — Flutter cannot render OpenType-`SVG ` colour and it ships no usable glyph map.

- [x] 10.1 Bundle the QUL header fonts: unzip `QCF_SurahHeader_COLOR-Regular.ttf` + `quran-common.ttf`; declare them as Flutter assets in `pubspec.yaml`. Document the download in `README.md`. (The surah-header `ligatures.json` map is embedded in `mushaf_fonts.dart` rather than bundled as an asset.)
- [x] 10.2 Engine: `MushafView` gains a `palette` selector; `FontCache` selects a `CPAL` palette by rewriting the font's `colorRecordIndices` (swap index 0 ↔ N) before registering, keyed by `(page, palette)`. Default behaviour (palette 0) unchanged.
- [x] 10.3 Engine tests: `selectCpalPalette` byte-swap (`cpal_test.dart`); palette selection registers the variant font (`mushaf_view_test.dart`).
- [x] 10.4 Host: a `MushafColorScheme` model — all six QPC V4 palettes exposed as selectable styles (`tajweed`/`tajweedDark`/`tajweedWarm`/`plain`/`plainDark`/`plainSoft`, each a palette index + `darkPage` flag) + a persisted `mushafColorSchemeProvider`. Removed the dead `tajweedEnabledProvider` it supersedes.
- [x] 10.5 Host: the reader renders the selected style's palette + page colour (dark sheet for the dark styles, light parchment otherwise) — an explicit choice, independent of the app theme.
- [x] 10.6 Host: `mushaf_fonts.dart` registers the `QCF_SurahHeader_COLOR` (light + `CPAL` dark variant) + `quran-common` fonts; the reader's `headerBuilder` renders the ornamental surah header (sized large) and the bismillah glyph.
- [x] 10.7 Home Surahs list keeps the plain Arabic surah name. (The QUL "surah name" SVG font is unusable in Flutter; the ornamental surah-header font is a reader-page element, not a list element — product decision.)
- [x] 10.8 Settings: a "Mushaf colours" section with a live real-verse preview (`MushafStylePreview` — page 1 / al-Fātiḥah through the real engine) and all six colour-style options; removed the old tajweed toggle row.
- [x] 10.9 `THIRD_PARTY_NOTICES.md` + `README.md`: add the QUL surah-header and `quran-common` fonts; note the `QCF_FullSurah` SVG font was evaluated and not used.
- [x] 10.10 Tests: colour-scheme provider + persistence (`mushaf_color_scheme_test.dart`), the Settings appearance section (`settings_page_test.dart`), the reader palette wiring (`page_mushaf_view_test.dart`).
- [x] 10.11 `AGENTS.md`: record the colour-scheme + header-font model.
- [x] 10.12 Re-verify: `just check` clean (host 143 + `quran_mcp_server` 32 + `tarteel_qul` 24, analyze clean), `openspec validate` clean, `flutter build windows` succeeds. Manual — dark styles legible, style switch + real-verse preview, ornamental headers, bismillah — confirmed by the user on-device.
