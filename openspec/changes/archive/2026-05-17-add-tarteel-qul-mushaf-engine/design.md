## Context

The reader's page mode currently renders through `qcf_quran_plus` — turnkey but sealed: it owns the layout, the fonts, and the rendering, and the app only hands it a page number. The framework-free `MushafLocator` seam abstracts the *coordinate* side (`AyahKey ↔ page`), but the actual rendering widget ([lib/features/reader/widgets/page_mushaf_view.dart](lib/features/reader/widgets/page_mushaf_view.dart)) imports `qcf` directly.

Tarteel QUL distributes mushaf rendering as open data. Inspecting the actual downloaded QPC V4 files (spike, task 1) confirmed the model:

```
  qpc-v4-tajweed-15-lines.db   pages(page_number, line_number, line_type,
  (layout, 241 KB SQLite)            is_centered, first_word_id, last_word_id,
                                     surah_number)
                               line_type ∈ { ayah, surah_name, basmallah }
                               — only ONE table; no `info` table (see spike).
                               number_of_pages / lines_per_page are derived
                               from MAX(page_number) / MAX(line_number).

  qpc-v4.db                    words(id, location, surah, ayah, word, text)
  (word script, 2.4 MB SQLite) text = the glyph-code string for that word
                               (1–3 codepoints); layout.first_word_id /
                               last_word_id → words.id

  ttf.zip                      p1.ttf .. p604.ttf  — one font per page,
  (604 fonts, 167 MB unzipped) glyphs pre-shaped/pre-justified for that page
```

A page is drawn by joining all three. The per-page font is the device that makes "exactly like the printed mushaf" possible — each page's glyphs are baked to fill that page's lines.

Stakeholders: the user (wants control + 28 layouts + escape from a `0.0.x` dep); future Reader/Tasmi' modes (need an event-emitting render surface); pub.dev consumers of `tarteel_qul` (need a clean, asset-free, app-independent package); contributors (must download QUL files to build).

## Goals / Non-Goals

**Goals**

- A standalone, publishable `tarteel_qul` Flutter package that renders a printed-mushaf page from QUL layout + word + font data, supplied by the consumer through one `MushafAssetSource` abstraction. Zero bundled assets.
- A mode-agnostic `MushafView` widget — emits `onWordTap`/`onAyahTap`, accepts decorations — so future modes plug behaviour onto it without the package knowing modes exist.
- Rebuild the reader's page mode on `tarteel_qul`; re-back `MushafLocator`; drop `qcf_quran_plus`.
- Keep the 604-page coordinate system, reader routes, deep links, audio-follow, and text-mode fallback exactly as they are.
- Quran Companion bundles the QUL files at build time (contributor download → gitignored `assets/qul/` → in the binary); end users download nothing.

**Non-Goals**

- The mode/workspace system, tafsir UI, verse context menus, Tasmi' — later pieces.
- A multi-layout picker. The package is layout-agnostic; the app wires QPC V4 15-line only.
- Committing QUL assets, or any end-user download/configuration flow.
- Reworking text mode beyond what shared reader plumbing requires.
- Byte-deterministic asset rebuilds (QUL files are third-party downloads, not project-built like `quran.sqlite`).

## Decisions

### D1: `tarteel_qul` is a publishable, asset-agnostic Flutter package

`packages/tarteel_qul/` is a Flutter workspace member (it draws widgets and loads fonts, so it cannot be pure Dart like `quran_mcp_server`). Unlike the app and `quran_mcp_server`, `publish_to` is **not** set to `none` — it ships its own `README.md`, `CHANGELOG.md`, `LICENSE`, and `example/`. It never depends on `package:quran_player/` — a published package cannot path-depend back into the app.

It bundles **no QUL data**. A pub.dev package legally cannot redistribute KFGQPC fonts, and 167 MB has no business in a package. The entire consumer contract is one abstraction:

```dart
abstract class MushafAssetSource {
  Future<Uint8List> layoutDb();          // QUL layout SQLite bytes
  Future<Uint8List> wordDb();             // QUL word-script SQLite bytes
  Future<Uint8List> pageFont(int page);   // pN.ttf bytes — called lazily, per page
}
```

The consumer decides where bytes come from (Flutter assets, filesystem, network). The package renders whatever it is handed.

**Why:** "engine on us, assets on them." A pure engine is publishable, testable with a fake source, and reusable across QUL layouts. **Alternative considered:** bundle the V4 assets in the package — rejected: unpublishable (licensing + size) and locks the package to one layout.

### D2: Layout-agnostic engine; the app wires V4

The QUL SQLite schema (a `pages` layout table + a `words` table) is uniform across V1/V2/V4/IndoPak layouts. The package codes against that schema, not against V4 specifically — page count and lines-per-page are derived at runtime from the `pages` table (`MAX(page_number)` / `MAX(line_number)`), not hard-coded. (The spike confirmed the QPC V4 layout DB carries **no `info` table** — design assumed one; dimensions are derived from `pages` instead.) Quran Companion supplies the QPC V4 15-line files; that is the app's choice, not the package's.

**Why:** near-zero extra cost, and it keeps the package genuinely reusable. **Risk:** WIP QUL layouts may have schema drift — the package validates the schema on open and surfaces a structured failure rather than rendering garbage.

### D3: The render pipeline

```
MushafController.openPage(P)
  │
  ├─ MushafLayoutRepository (opens layoutDb + wordDb once, in-memory/SQLite)
  │    pageLines(P)  → ordered List<MushafLine>
  │       each line: lineType, isCentered, [words] or headerData
  │    words come from a layout↔word join over first_word_id..last_word_id
  │
  ├─ FontCache.ensure(P)  → registers pP.ttf via Flutter FontLoader,
  │                          family "qul_p{P}", cached process-wide
  │
  └─ MushafView renders each line:
       ayah line       → RTL, justified glyph run in family "qul_p{P}"
       surah_name line → ornamental centered header
       basmallah line  → centered basmala glyph run
```

`MushafLine` carries enough to map a tapped glyph back to a `word` (and thus `surah`/`ayah`). The view emits `onWordTap(MushafWord)` / `onAyahTap(AyahKey)`; it accepts a `decorations` list (currently ayah-highlight rectangles/colours).

**Justification (open, see Risks):** per-page fonts pre-shape glyphs so a line fills its width when rendered at the page's design size. The first implementation trusts the font (render the line's glyph string, scale to fit width). If lines do not fill cleanly, fall back to explicit space distribution. A spike task verifies this before the view is built.

### D4: Re-back `MushafLocator`, do not redesign it

The framework-free `MushafLocator` contract ([lib/domain/quran/mushaf_locator.dart](lib/domain/quran/mushaf_locator.dart)) is unchanged. A new `QulMushafLocator` (in `lib/data/quran/`, or thin-wrapping a coordinate API the package exposes) replaces `QcfMushafLocator`. It derives `pageForAyah` / `firstAyahOnPage` / `ayahsOnPage` / `pageForSurah` from the QUL layout DB (`pages.surah_number` + the word DB's `surah`/`ayah`). `kMushafPageCount` stays 604.

**Why:** every downstream consumer (audio-follow, routes, search) already depends only on `MushafLocator`. Re-backing it means none of them change. **Consequence:** the package should expose a coordinate API the host's `QulMushafLocator` adapts, OR the host builds the locator directly from `MushafLayoutRepository`. Pick the lighter wiring during apply.

### D5: Text-correctness boundary is unchanged

QUL glyphs are *rendering only*. Anything user-actionable — copy, search results, audio queue, MCP responses, top-bar labels — still resolves through `QuranRepository` (Tanzil) keyed by `AyahKey`. The QUL layer's only contribution to text identity is the `AyahKey` mapping (which page/word belongs to which ayah). `MushafView`'s `onAyahTap` emits an `AyahKey`; the reader feature resolves text from the repository, exactly as it does today with qcf.

**Why:** the project's "trustworthy before powerful" rule — one canonical text source, integrity-checked. QUL's script may differ subtly from Tanzil; we render QUL glyphs but never quote them as text.

### D6: App asset delivery — contributor-bundled, gitignored

Quran Companion's `MushafAssetSource` reads the bundled Flutter assets. The QUL files live in `assets/qul/` which is **gitignored**; a contributor downloads them per a README step; `pubspec.yaml` declares them so `flutter build` bundles them into the binary. End users get a complete app and download nothing.

Font packaging: bundle `ttf.zip` as a single asset and unzip a page's font on demand at runtime — the proven `QcfFontLoader` pattern already in this repo. (604 loose `.ttf` files as individual assets is the alternative; one zip is lighter on the asset manifest.)

**Why:** satisfies all four user constraints — not in the repo, README-documented, engine/asset split, end users download nothing. **Consequence (accepted):** a fresh `git clone` cannot `flutter build` until the download step runs; the README setup section states this as required. No CI exists, so nothing else breaks.

### D7: Progressive enhancement, not fail-closed

The QUL DBs are third-party downloads, not byte-deterministic project assets — so no SHA-256 fail-closed gate like `quran.sqlite`. Instead the app does a light **structural validation** on open (expected tables, `info.number_of_pages == 604`, non-empty `pages`). On any failure — assets missing, unzip fails, schema mismatch, font load throws — page mode shows a non-fatal "mushaf data unavailable" notice and the reader stays in **text mode** for the session. This reuses the existing degrade path (today the reader already falls back to text mode when qcf fails). The data-integrity fatal screen is never triggered by a rendering failure.

**Why:** rendering is an enhancement; text correctness (Tanzil) is the floor and is unaffected.

### D8: Tajweed

The layout is `qpc-v4-tajweed-15-lines`. QPC V4 tajweed fonts encode tajweed colouring intrinsically (coloured glyph runs), unlike a plain mono-colour mushaf font. The existing Settings tajweed toggle ([lib/app/state/tajweed_provider.dart](lib/app/state/tajweed_provider.dart)) currently feeds qcf's `isTajweed` flag. With V4: if tajweed colour is intrinsic to the font, "tajweed off" requires either a non-tajweed V4 font variant or a colour-flattening render pass. The apply phase confirms the V4 font behaviour first; the toggle's mapping is finalized then. Worst case for MVP: tajweed is always on (the V4 tajweed font is what we bundle) and the toggle is hidden until a plain variant is wired — captured as a follow-up rather than blocking this change.

## Risks / Trade-offs

- **Justification may not be free.** [Risk] per-page fonts might not fill lines cleanly at arbitrary widths → [Mitigation] a spike task renders sample pages and measures before `MushafView` is built; explicit space distribution is the fallback.
- **167 MB of fonts in the app binary.** [Risk] large desktop binary → [Mitigation] same order as qcf's ~70 MB was for MVP; lazy per-page unzip keeps the *loaded* footprint small; font pruning is a later optimization.
- **Fresh clone can't build.** [Risk] contributors blocked until the QUL download → [Mitigation] README setup step marked required; the failure is an obvious missing-asset build error, not a silent bug.
- **QUL schema drift on WIP layouts.** [Risk] a different layout DB breaks parsing → [Mitigation] schema validation on open + structured failure; MVP only wires the stable V4.
- **Tajweed toggle semantics.** [Risk] intrinsic-colour fonts make "tajweed off" non-trivial → [Mitigation] D8 — confirm font behaviour during apply, accept always-on for MVP if needed.
- **App redistributes KFGQPC fonts.** [Risk] licensing → [Mitigation] confirm QUL/KFGQPC terms permit shipping in an app binary; record in `THIRD_PARTY_NOTICES.md`. The `tarteel_qul` package redistributes nothing — clean for pub.dev.
- **Package name borrows Tarteel's brand.** [Risk] trademark friction at publish time → [Mitigation] noted; rename before the actual pub.dev publish, out of scope here.

## Migration Plan

1. Scaffold `packages/tarteel_qul/` (publishable Flutter package, workspace member); add to root `workspace:`.
2. Spike: verify per-page-font justification on sample pages; record the result in this design.
3. Build the engine: `MushafAssetSource`, `MushafLayoutRepository` (layout+word parsing + coordinate API), `FontCache`, `MushafController`, `MushafView` — with a fake `MushafAssetSource` and unit/widget tests.
4. App side: gitignore `assets/qul/`; add the QUL assets to `pubspec.yaml`; implement the host `MushafAssetSource`; add structural validation.
5. Re-back the seam: `QulMushafLocator` replaces `QcfMushafLocator`; update `mushaf_locator_provider.dart` and locator tests.
6. Rebuild `page_mushaf_view.dart` on `MushafView`, preserving desktop affordances + playback highlighting; keep the degrade-to-text path.
7. Remove `qcf_quran_plus` from `pubspec.yaml`; delete/replace the qcf import-boundary test; swap Settings attribution + `THIRD_PARTY_NOTICES.md`.
8. Docs: README contributor setup step; `AGENTS.md`; pre-commit hook + `just test` extended for `tarteel_qul`.

Rollback: revert the PR — `qcf_quran_plus` returns. `assets/qul/` is gitignored, so nothing to clean up there.

## Open Questions

All four questions are **resolved** — by the task-1 spike (data inspection of the
downloaded QPC V4 files) and by apply-phase decisions.

- **Justification — RESOLVED (trust the font).** The layout DB carries only
  word-id ranges (`first_word_id..last_word_id`) and an `is_centered` flag — it
  carries **no per-word geometry** (no x-coordinates, no stretch factors). An
  explicit space-distribution renderer would need geometry the DB does not
  provide; the schema is only renderable if the per-page font itself
  pre-justifies non-centered lines so a line's glyph run fills the text-block
  width at the font's natural metrics. The engine therefore renders each line's
  glyph run in `pN.ttf` and scales the whole page uniformly — design.md needs no
  explicit-space-distribution revision. Final visual confirmation lands at the
  manual task 9.3 / 9.5 check.
- **Tajweed colour — RESOLVED (intrinsic).** Every inspected page font
  (`p1.ttf`, `p100.ttf`, `p604.ttf`) ships `COLR` + `CPAL` tables — they are
  layered colour fonts, so tajweed colouring is intrinsic to the glyphs. The
  download contains no plain (non-tajweed) V4 variant. Per D8's worst case:
  MVP renders tajweed always-on and the Settings tajweed toggle no longer feeds
  page mode; finalizing the toggle is a follow-up, not part of this change.
- **`QulMushafLocator` wiring — RESOLVED.** The `mushaf-engine` spec already
  requires the engine to expose a page↔ayah coordinate API; `QulMushafLocator`
  is a thin host adapter over that API (the lighter wiring per D4).
- **`example/` asset source — RESOLVED.** The package `example/` uses a
  checked-in tiny fake/fixture `MushafAssetSource` (task 4.6) so it runs without
  a QUL download.

### Spike findings (task 1, recorded)

- **Layout DB has no `info` table.** Only a `pages` table
  (`page_number, line_number, line_type, is_centered, first_word_id,
  last_word_id, surah_number`), 9046 rows. `number_of_pages` = `MAX(page_number)`
  = 604; `lines_per_page` = `MAX(line_number)` = 15. There is no `font_name`
  column anywhere — irrelevant, since the engine uses per-page fonts. The
  `mushaf-engine` spec's "reads dimensions from the `info` table" wording is
  corrected to "derives dimensions from the `pages` table."
- **Word join verified.** A `pages` row's `first_word_id..last_word_id` range
  against `words.id` yields exactly the expected words for that line, with
  `surah`/`ayah` coordinates intact (e.g. page 1 line 2 → words 1..5 → ayah 1:1).
- **Non-ayah line columns.** For `surah_name` / `basmallah` lines,
  `first_word_id` / `last_word_id` are empty strings (not NULL); `surah_name`
  lines carry `surah_number`, `basmallah` lines carry none. The models treat
  these as optional.
- **`words.text` width.** 1–3 codepoints per word (mostly 1) — the `MushafWord`
  model stores `text` as a `String`, never a single code unit.

### D9: Colour schemes via CPAL palette selection

The QPC V4 per-page fonts are `COLR`/`CPAL` colour fonts carrying **6 palettes**
(inspected during apply): palettes 0/2 are light-background tajweed (black base
text + tajweed colours), 1 is dark-background tajweed (white base text), 3/5
are light-background plain (mono black), 4 is dark-background plain (mono
white). Flutter's text engine renders a colour font with **palette 0 only** —
it exposes no runtime CPAL selection.

The engine therefore selects a palette by **rewriting the font's `CPAL`** before
registering it: the `CPAL` v0 `colorRecordIndices` array is a list of
`uint16`s, one per palette; swapping index `0` with index `N` makes Flutter's
"palette 0" render palette `N`. `FontCache` keys its registry by
`(page, palette)` and registers each variant under a distinct family.
`MushafView` takes a `palette` index.

All six palettes are exposed to the user as selectable **colour styles**
(`MushafColorScheme`) — `tajweed` (0), `tajweed-dark` (1), `tajweed-warm` (2),
`plain` (3), `plain-dark` (4), `plain-soft` (5). Each style carries its
palette index and a `darkPage` flag; the reader renders the per-page font in
`style.palette` on a dark sheet (white-text palettes 1/4) or a light parchment
(the others). The chosen style is a **persisted preference, independent of the
app's light/dark theme** — the mushaf appearance is the user's explicit
choice. The dark styles give a **true dark mushaf** (dark sheet, white-base
glyphs). Settings exposes the picker with a **live preview that renders a real
verse** — page 1 (Sūrat al-Fātiḥah, opening with āyah 1:1) through the actual
`MushafView` in the selected style. This **supersedes** the `qcf`-era tajweed
toggle (D8), which is removed.

### D10: Header and basmala fonts; the Surahs list

`surah_name` / `basmallah` lines carry no addressable glyphs in the layout, so
`MushafView` takes a consumer `headerBuilder`. The host renders them from two
further QUL font resources, bundled under `assets/qul/` like the page fonts:

- **`QCF_SurahHeader_COLOR`** — a `COLR` colour font of ornamental surah
  headers, addressed via its `ligatures.json` (`surah-1`..`surah-114` → a glyph
  string). Used for the reader's `surah_name` lines. It carries the same
  six-palette set as the page fonts; the host registers a light variant
  (palette 0) and a `CPAL`-recoloured dark variant (palette 1).
- **`quran-common`** — supplies the bismillah glyph (`ligatures.json`
  `bismillah` → U+FDFD, rendered in this font), used for `basmallah` lines.

The QUL **`QCF_FullSurah` "surah name" SVG font is not used**: Flutter cannot
render OpenType-`SVG ` colour fonts, and the font ships no `GSUB` ligatures and
no glyph map, so a surah cannot be reliably addressed without risking the wrong
name. The Home Surahs list therefore keeps the plain Arabic surah name from
`QuranRepository` — the ornamental surah-header font is a reader-page element,
not a list element.

The surah *name* a user reads still resolves through `QuranRepository` (D5);
the header font supplies only the ornamental glyph.
