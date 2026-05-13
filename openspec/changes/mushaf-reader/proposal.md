## Why

With foundation and the verified Quran data layer shipped, the app still has no way to *read* the Quran — the Surahs list is a dead end. IDEA.md MVP calls out "Ayah display" and "Arabic Quran text" as the next user-visible step, and CLAUDE.md already names [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) as the planned visual mushaf renderer. Wiring the reader now unblocks every downstream MVP slice: audio (anchors highlighting), search (jump-to-ayah target), bookmarks (anchor a saved position), and MCP (`get_ayah` / `get_surah` need a UI to open a reference into).

## What Changes

- Add a **mushaf reader** feature that renders Quran text and supports prev/next navigation, with two render modes:
  - **Page mode (primary, default):** glyph-perfect printed mushaf via `qcf_quran_plus`, page-by-page navigation with the package's bundled QCF fonts and page metadata.
  - **Text mode (fallback):** continuous vertical scroll of ayahs from `QuranRepository`, surah-at-a-time, no extra fonts.
- Add a **render-mode setting** (page vs. text) in the Settings page; persists in `SharedPreferences`. Default = page mode.
- Add **reader routes** under the existing `go_router` shell:
  - `/reader/page/{pageNumber}` — page mode canonical.
  - `/reader/surah/{surahNumber}` — text mode canonical, also acts as a redirect entry from any caller that only knows a surah.
  - `/reader/ayah/{surah}/{ayah}` — addressable redirect to whichever mode is active, opening at that ayah.
- Wire the **Surahs list → reader** navigation: tapping a surah opens the reader at the first ayah of that surah, in the user's selected mode.
- Add a **`MushafLocator`** value type (`AyahKey ↔ pageNumber`) and a thin `MushafLocatorService` that resolves between them using `qcf_quran_plus`'s page-metadata. This is the seam future audio/search/bookmark changes use to jump the reader to a position without depending on the rendering package directly.
- Add a **graceful degrade** rule: if `qcf_quran_plus` fails to load fonts/metadata at runtime, the reader auto-switches to text mode for that session and surfaces a non-fatal banner. The integrity guarantees of the data layer are unaffected — text mode still uses the verified Tanzil text.
- Tests: widget tests for both modes (open at a position, navigate prev/next, ayah-key → page locator round-trip), integration test for the Surahs-list → reader handoff, and a regression test that the unknown-route redirect still works for the new route patterns.

Not in scope: tap-to-bookmark, audio playback or audio-anchored highlighting, in-reader search, range repeat, translation rendering. Each lands in its own follow-up change against this reader.

## Capabilities

### New Capabilities

- `mushaf-reader`: A reader surface that renders the Quran in either a page-based mushaf view (via `qcf_quran_plus`) or a continuous text view (via `QuranRepository`). Covers route shape, mode selection and persistence, navigation between adjacent pages/surahs, addressable jump-to-ayah, and the graceful-degrade contract. Defines the `MushafLocator` seam that future audio/search/bookmark changes plug into.

### Modified Capabilities

<!-- None. The reader is a new feature surface; existing `quran-data` and `app-shell` capabilities are consumed unchanged. -->

## Impact

- **New dependencies (runtime):** [`qcf_quran_plus`](https://pub.dev/packages/qcf_quran_plus) — bundles QCF glyph fonts and printed-mushaf page metadata. Apply-time measurement showed ~70 MB of package font assets in the Windows release bundle. Maintainer decision for MVP: ship as-is now, then revisit package choice, pruning/vendoring, or a different Quran rendering method when the project defines its long-term rendering approach. License compatibility is recorded in `THIRD_PARTY_NOTICES.md` alongside Tanzil.
- **No new dev/tooling deps.**
- **Repo additions:**
  - `lib/features/reader/` — pages, widgets, providers, route wiring.
  - `lib/domain/quran/mushaf_locator.dart` — value type for `(AyahKey, pageNumber)` mapping.
  - `lib/data/quran/mushaf_locator_qcf.dart` — `qcf_quran_plus`-backed locator implementation.
  - `lib/app/state/reader_mode_provider.dart` — Riverpod `StateNotifier` over `SharedPreferences` for the page/text toggle.
  - `THIRD_PARTY_NOTICES.md` entry for `qcf_quran_plus` and the QCF font license.
- **Repo modifications:**
  - [lib/features/surahs/](../../../lib/features/surahs/) — surah-tile tap navigates to the reader (today it's inert).
  - [lib/app/router/](../../../lib/app/router/) — three new routes, three new `RouteNames`/`RoutePaths` entries, unknown-route redirect still applies.
  - [lib/features/settings/](../../../lib/features/settings/) — render-mode toggle row above the existing source-attribution section.
  - [pubspec.yaml](../../../pubspec.yaml) — register `qcf_quran_plus` and any extra font assets it requires (per its docs).
- **Tests:** widget tests for both render modes (open / navigate prev-next / locator round-trip), Surahs-tap-to-reader integration, settings-toggle persistence, unknown-route still redirects, and a fallback test that simulates a `qcf_quran_plus` load failure and asserts the auto-switch + banner.
- **Platforms affected:** Windows, macOS, Linux. `qcf_quran_plus` is Flutter-pure (font assets) so no native build deps; verify font loading on each platform during the change.
- **Risk hot-spots:** licensing trail for QCF fonts (must be recorded), reader-mode persistence across upgrades (default = page; existing user preference must survive), router redirect ordering (the new ayah-redirect must not shadow the unknown-route catchall), and divergence between `qcf_quran_plus`'s page metadata and our DB's `(surah, ayah)` keys (validated by the locator round-trip test).
