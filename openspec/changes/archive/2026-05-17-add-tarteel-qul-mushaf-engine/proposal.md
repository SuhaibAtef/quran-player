## Why

The reader's page mode renders the printed mushaf through `qcf_quran_plus` — a `v0.0.8` third-party package: a sealed black box, one fixed layout, ~70 MB of fonts hidden inside the package, and no real control over theming. AGENTS.md explicitly deferred replacing it until "the project defines the long-term 'perfect rendering' approach." This change is that decision.

Tarteel's QUL (Quran Universal Library) publishes printed-mushaf rendering data — page-by-page layout, word-by-word glyph scripts, and per-page fonts — as open SQLite + font files. Rendering from QUL data ourselves gives full control (theming, exact layout, per-word tap events) and escapes the `0.0.x` dependency. It is also "piece 1" of a larger multi-mode app (Reader / Tasmi' / …): the rendering surface must become a controlled, event-emitting component the future modes can wire behaviour onto.

## What Changes

- **New `packages/tarteel_qul/`** — a standalone, **pub.dev-publishable** Flutter package: a QUL mushaf-layout rendering engine. It bundles **zero QUL assets** — it is asset-agnostic, rendering from whatever a consumer supplies through a `MushafAssetSource` abstraction. Public surface: `MushafAssetSource`, `MushafLayoutRepository`, `MushafController`, a coordinate (page↔ayah) API, and a `MushafView` widget.
- `MushafView` is **mode-agnostic and mode-ready**: it renders a page, emits semantic events (`onWordTap`, `onAyahTap`), and accepts decorations (ayah highlights now; arbitrary marks later). It never knows what a "mode" is — this is the seam future modes wire onto. **BREAKING** for the reader's internal rendering path; not user-facing.
- **Rebuild the reader's page mode** on `tarteel_qul`. The framework-free `MushafLocator` seam is re-backed by a new `QulMushafLocator` replacing `QcfMushafLocator`; the 604-page coordinate system, reader routes, deep links, and audio-follow are unchanged.
- **Remove `qcf_quran_plus`** from `pubspec.yaml` and the codebase once `tarteel_qul` is wired.
- **App asset model:** a contributor downloads the QUL files (documented in the README) into a **gitignored** `assets/qul/` directory; `pubspec.yaml` declares them as Flutter assets so they ship inside the built binary. **End users download nothing.** The QUL files are never committed to the repo.
- **Progressive enhancement:** text mode remains the always-available floor (Tanzil is bundled, tiny). If the QUL assets are absent or fail to load, page mode degrades to a non-fatal "mushaf data unavailable" state and the reader stays in text mode — reusing the existing degrade path. Never the data-integrity fatal screen.
- Settings attribution and `THIRD_PARTY_NOTICES.md` move from `qcf_quran_plus` to the QUL V4 layout / script / fonts.
- **Mushaf colour styles.** The QPC V4 per-page fonts carry six `CPAL` colour palettes. The engine renders any of them by rewriting the font's `CPAL` so the chosen palette sits at index 0 (Flutter only renders palette 0). All six are exposed as selectable user-facing **colour styles** — tajweed / plain, each in light, dark, and a variant. A new Settings section lets the user pick a style with a **live preview that renders a real verse** (page 1, Sūrat al-Fātiḥah); the choice is persisted, independent of the app theme. This supersedes the dead `qcf`-era tajweed toggle, which is removed.
- **True dark mushaf.** The dark colour styles render page mode on a dark sheet with the white-text palette — a genuinely dark mushaf, not a light card on dark chrome.
- **Ornamental surah headers + basmala.** The reader's `surah_name` lines render the QUL **surah-header** colour font (`QCF_SurahHeader_COLOR`, addressed via its `ligatures.json`); `basmallah` lines render the bismillah glyph from the QUL **`quran-common`** font. (The QUL "surah name" SVG font is not used — Flutter cannot render OpenType-SVG colour and the font ships no usable glyph map; the Home Surahs list keeps the plain Arabic surah name.)

## Capabilities

### New Capabilities

- `mushaf-engine`: the `tarteel_qul` package contract — the `MushafAssetSource` abstraction, layout + word-script parsing, page rendering with per-page fonts, lazy font loading, the page↔ayah coordinate API, and the mode-agnostic event-emitting `MushafView` widget. The package is publishable and depends on no app code.

### Modified Capabilities

- `mushaf-reader`: page mode is rebuilt on `tarteel_qul` instead of `qcf_quran_plus`; the `MushafLocator` seam is re-backed by `QulMushafLocator`; QUL page rendering is a progressive enhancement that degrades to text mode when assets are unavailable; the QCF attribution requirement is replaced by a QUL attribution requirement.

## Impact

- **New package** `packages/tarteel_qul/` — Flutter workspace member, `publish_to` unset (publishable), with `README.md` / `CHANGELOG.md` / `LICENSE` / `example/`. Depends only on leaf packages (`flutter`, `sqflite_common_ffi`, `archive` or similar for the per-page font unzip); never on `package:quran_player/`.
- **`pubspec.yaml`** — add `tarteel_qul` path dependency; declare `assets/qul/` assets; remove `qcf_quran_plus`. Root `workspace:` gains `packages/tarteel_qul`.
- **`.gitignore`** — add `assets/qul/` (the downloaded QUL files are never committed).
- **`lib/data/quran/`** — `QulMushafLocator` replaces `mushaf_locator_qcf.dart`; new host `MushafAssetSource` implementation reading the bundled Flutter assets.
- **`lib/features/reader/widgets/page_mushaf_view.dart`** — rebuilt on `tarteel_qul`'s `MushafView`, preserving desktop affordances (mouse-drag paging, keyboard arrows, prev/next buttons) and active-ayah playback highlighting.
- **Tests** — `tarteel_qul` gets its own test suite (layout/word parsing, the coordinate API, `MushafView` event emission with a fake `MushafAssetSource`). The host `mushaf_locator` tests and reader tests are updated for `QulMushafLocator`. The qcf import-boundary test is replaced. The pre-commit hook and `just test` are extended to run `packages/tarteel_qul/test/`.
- **Docs** — `README.md` gains a contributor "download QUL mushaf assets" setup step; `AGENTS.md` *Project state* / *Lib layout* / *Notes for future work* updated; `THIRD_PARTY_NOTICES.md` swaps the `qcf_quran_plus` entry for the QUL V4 layout / script / fonts (the app redistributes them; the `tarteel_qul` package does not).
- **Out of scope:** the mode/workspace system; tafsir UI; verse context menus; Tasmi'; a multi-layout picker (MVP wires QPC V4 15-line only, though the package stays layout-agnostic); committing QUL assets; any end-user download flow.
- **Hard constraints:** canonical Quran text stays Tanzil via `QuranRepository` — the QUL glyph layer is never a text source for copy/search/audio/MCP; `kMushafPageCount = 604` and the existing reader routes/deep links keep working; one change → one branch → one PR.
