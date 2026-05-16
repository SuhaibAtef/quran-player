## 1. Spike — verify the rendering assumptions before building

- [ ] 1.1 Unzip a few `pN.ttf` from `assets/qul/ttf.zip` and render sample glyph strings from `qpc-v4.db` `words.text` in a throwaway Flutter widget. Confirm: (a) a line's glyph run fills its width at the page's design size, or whether explicit space/kashida distribution is needed; (b) whether QPC V4 tajweed colour is intrinsic to the font glyphs or applied. Record both findings in `design.md` (resolves Open Questions 1 and 2).
- [ ] 1.2 Confirm the layout↔word join: a `pages` row's `first_word_id..last_word_id` range against `qpc-v4.db` `words.id` yields the expected words for that line, with surah/ayah coordinates intact. Note the `info` table's actual `number_of_pages` / `lines_per_page` / `font_name` values.

## 2. Scaffold the `tarteel_qul` package

- [ ] 2.1 Create `packages/tarteel_qul/` as a Flutter package: `pubspec.yaml` (`name: tarteel_qul`, Dart SDK `^3.11.0`, `resolution: workspace`, `publish_to` NOT set to none, deps on `flutter`, `sqflite_common_ffi`, an unzip lib such as `archive`), plus `README.md`, `CHANGELOG.md`, `LICENSE`.
- [ ] 2.2 Add `packages/tarteel_qul` to the root `pubspec.yaml` `workspace:` list and as a path dependency.
- [ ] 2.3 `flutter pub get`; confirm the workspace resolves cleanly.
- [ ] 2.4 Add `test/isolation_test.dart` in the package asserting no file under `packages/tarteel_qul/lib/` imports `package:quran_player/`.

## 3. Engine core — asset source, parsing, coordinate API

- [ ] 3.1 Define `MushafAssetSource` (abstract): `layoutDb()`, `wordDb()`, `pageFont(int page)` — all returning `Future<Uint8List>`.
- [ ] 3.2 Define typed models: `MushafPage`, `MushafLine` (line type `ayah`/`surahName`/`basmallah`, `isCentered`), `MushafWord` (id, glyph-code text, surah, ayah, word index).
- [ ] 3.3 Implement `MushafLayoutRepository`: open the layout + word DBs from the asset source; read `info`; produce `pageLines(page)` via the `first_word_id..last_word_id` ↔ `words.id` join.
- [ ] 3.4 Implement schema validation on open — expected tables/columns present, `info` populated — surfacing a structured failure (not an exception) on mismatch.
- [ ] 3.5 Implement the coordinate API: `pageForAyah`, `firstAyahOnPage`, `ayahsOnPage`, `pageForSurah`; out-of-range input returns a structured failure.
- [ ] 3.6 Tests: a fake `MushafAssetSource` over small fixture DBs; assert page→lines, the word join, schema-validation failure, and coordinate round-trips (Spec `mushaf-engine`: parsing, validation, coordinate API).

## 4. Engine rendering — fonts and `MushafView`

- [ ] 4.1 Implement `FontCache`: lazily fetch `pageFont(N)` from the asset source, register it once via Flutter's `FontLoader` under a stable family (e.g. `qul_p{N}`), cache process-wide.
- [ ] 4.2 Implement line rendering: `ayah` lines as RTL justified glyph runs in the page font; `surah_name` / `basmallah` / centered lines centered.
- [ ] 4.3 Implement `MushafView` — renders a page, emits `onWordTap(MushafWord)` and `onAyahTap(AyahKey)`, accepts a `decorations` list (ayah-highlight model). No "mode" concept in its API.
- [ ] 4.4 Implement `MushafController` for page navigation (open/next/prev, current page).
- [ ] 4.5 Tests: widget tests with a fake asset source — page renders expected line count, word-tap emits the right `MushafWord`, ayah-tap emits the right `AyahKey`, a supplied decoration renders, lazy font load happens once per page (Spec `mushaf-engine`: rendering, `MushafView`).
- [ ] 4.6 Add a minimal `packages/tarteel_qul/example/` app driven by a checked-in tiny fake/fixture asset source so the package is runnable without a QUL download (pub.dev hygiene).

## 5. App integration — assets and asset source

- [ ] 5.1 Add `assets/qul/` to `.gitignore`. Confirm the downloaded QUL files (`qpc-v4-tajweed-15-lines.db`, `qpc-v4.db`, `ttf.zip`) are present locally and ignored by git.
- [ ] 5.2 Declare the QUL files as Flutter assets in the root `pubspec.yaml`.
- [ ] 5.3 Implement a host `MushafAssetSource` in `lib/data/quran/` reading the bundled assets: the layout + word DBs directly, page fonts unzipped on demand from `ttf.zip`.
- [ ] 5.4 Add a light structural validation + "mushaf assets available?" check the reader can branch on (fail-soft to text mode — Spec `mushaf-reader`: graceful degrade).

## 6. App integration — re-back the seam and rebuild page mode

- [ ] 6.1 Implement `QulMushafLocator` (in `lib/data/quran/`) satisfying the existing `MushafLocator` contract, backed by the engine's coordinate API. Keep `kMushafPageCount = 604`.
- [ ] 6.2 Update `lib/data/quran/mushaf_locator_provider.dart` to provide `QulMushafLocator`; delete `mushaf_locator_qcf.dart`.
- [ ] 6.3 Rebuild `lib/features/reader/widgets/page_mushaf_view.dart` on `tarteel_qul`'s `MushafView`: preserve mouse-drag paging, keyboard arrow navigation, prev/next buttons, RTL paging, and active-ayah playback highlighting (passed as a decoration).
- [ ] 6.4 Wire the degrade path: missing/invalid QUL assets or a font-load failure → session fallback to text mode + non-fatal banner; persisted preference unchanged; never the data-integrity fatal screen.
- [ ] 6.5 Update reader-locator and reader-widget tests for `QulMushafLocator` / `MushafView`; replace the qcf import-boundary test with one asserting `package:tarteel_qul/` is imported only by the locator adapter and the page widget.

## 7. Remove qcf_quran_plus

- [ ] 7.1 Remove `qcf_quran_plus` from the root `pubspec.yaml`; `flutter pub get`.
- [ ] 7.2 Delete any remaining qcf imports / references; confirm `flutter analyze` is clean.
- [ ] 7.3 Swap the Settings attribution row from `qcf_quran_plus` to the QUL mushaf layout / word-script / KFGQPC fonts.
- [ ] 7.4 Update `THIRD_PARTY_NOTICES.md`: remove the `qcf_quran_plus` entry; add QUL layout / word-script / KFGQPC font entries, noting the app binary redistributes the fonts and confirming the redistribution terms.

## 8. Docs and tooling

- [ ] 8.1 `README.md`: add a required contributor setup step — download the QUL resources (QPC V4 layout, QPC V4 word script, V4 fonts) from qul.tarteel.ai into `assets/qul/`; note a fresh clone cannot `flutter build` until this is done.
- [ ] 8.2 `packages/tarteel_qul/README.md`: document the package, the `MushafAssetSource` contract, and which QUL resources a consumer must supply.
- [ ] 8.3 `AGENTS.md`: update *Project state* (mushaf reader now on `tarteel_qul` / QUL), *Lib layout* (add `packages/tarteel_qul/`, drop the qcf note), and *Notes for future work* (remove the deferred-rendering note; record the QUL asset model).
- [ ] 8.4 Extend the pre-commit hook and `just test` to also run `flutter test packages/tarteel_qul/test/`.

## 9. Verification

- [ ] 9.1 `just check` clean — format, analyze, host + `quran_mcp_server` + `tarteel_qul` test suites pass.
- [ ] 9.2 `openspec validate add-tarteel-qul-mushaf-engine` clean.
- [ ] 9.3 Manual: launch the app on Windows, open the reader in page mode — confirm a QUL V4 page renders, paging (swipe / keys / buttons) works, and tapping a verse emits the ayah event.
- [ ] 9.4 Manual: confirm audio-follow still highlights the active ayah on the page, and the reader deep-link routes (`/reader/page`, `/reader/surah`, `/reader/ayah`) still work.
- [ ] 9.5 Manual degrade test: temporarily rename `assets/qul/` contents, launch — confirm the reader falls back to text mode with the non-fatal banner and no fatal screen.
