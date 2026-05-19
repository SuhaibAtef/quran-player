## Context

The data layer lands a verified Tanzil Uthmani corpus exposed via `QuranRepository` and a Surahs list in [lib/features/surahs/](../../../lib/features/surahs/) that currently has nowhere to navigate to. The reader is the next user-visible surface and the linchpin for every later MVP slice — audio anchors highlights at an ayah, search jumps to an ayah, bookmarks save a position, the MCP `get_ayah` deep-link target opens here.

Constraints from the project context:

- Desktop-only MVP (Windows primary; macOS/Linux later). Flutter 3.38.5, Dart 3.10.4, ForUI 0.17.0, Riverpod, `go_router`.
- "Trustworthy before powerful" — the printed-mushaf rendering surface must not become a second source of truth for Quran *text*. Glyph rendering is a presentation concern; canonical text stays in `QuranRepository`.
- Errors flow through `Result<T, Failure>`. No throws across feature boundaries. The reader must degrade gracefully rather than dropping the user into a fatal error screen — wrong-but-survivable presentation is better than a black screen, *as long as* it never serves wrong text.
- Source attribution surfaces in Settings. A second source (QCF fonts via `qcf_quran_plus`) means a second attribution row.
- Future MCP/audio/search must be able to drive the reader to a specific ayah without depending on the rendering package directly.

Stakeholders: end-users (legibility, familiar mushaf), maintainers (one renderer to swap if `qcf_quran_plus` stalls), future audio/search/bookmark changes (need a stable jump-to-ayah seam), reviewers (PR diff size).

## Goals / Non-Goals

**Goals:**

- Render the Quran in two modes: page-based mushaf (default) and continuous text scroll.
- Reach the reader from the Surahs list and from any addressable URL (`/reader/page/{n}`, `/reader/surah/{n}`, `/reader/ayah/{s}/{a}`).
- Persist the user's render-mode choice across launches.
- Define a `MushafLocator` seam so future features can drive the reader by `AyahKey` without importing `qcf_quran_plus`.
- Degrade gracefully if the rendering package fails to load (auto-switch to text mode for the session, never a fatal screen, never wrong text).
- Keep `QuranRepository` as the *only* source of Quran text in the app — the rendering package supplies layout, not text.

**Non-Goals:**

- Tap-to-bookmark, audio playback or audio-anchored highlighting, in-reader search, range repeat, translation rendering, tafsir popovers, themed reciter swap. Each is a follow-up change.
- Custom mushaf editions (IndoPak, Warsh). QCF Madani only, matching `qcf_quran_plus`'s built-in metadata.
- Schema changes to the bundled SQLite. The locator's `(AyahKey ↔ pageNumber)` mapping comes from `qcf_quran_plus` data, not from our DB.
- New top-level shell destinations. The reader is reachable as a drill-down from Surahs (and later from search/bookmarks/MCP); it does *not* get its own sidebar/bottom-nav slot.
- Mobile or web platforms.

## Decisions

### D1: Render = `qcf_quran_plus` for page mode, `QuranRepository` for text mode

- **Why:** `qcf_quran_plus` ships QCF (King Fahd Complex) glyph fonts and the standard 604-page mushaf metadata, giving the printed-mushaf experience users recognize without us shipping fonts ourselves. The data layer's Tanzil text is plain UTF-8 and is the right substrate for plain scrollable rendering and for everything non-visual (search, MCP, audio metadata).
- **Alternatives considered:**
  - *Roll our own QCF integration* — gives full control but adds font licensing, line-break tables, and glyph maps to maintain. Out of scope for an MVP.
  - *Use `quran_flutter` / `flutter_quran`* — competing packages with their own page data; no clear advantage over `qcf_quran_plus`, which CLAUDE.md already names.
  - *Render plain text and skip page mode* — fails the "feels like a mushaf" expectation users have for a Quran reader.
- **Trade-off:** Two presentations, two render paths to maintain. Mitigated by giving each a small, separate widget (`PageMushafView`, `TextReaderView`) with no shared rendering logic — only the surrounding chrome and the `MushafLocator` are shared.

### D2: Text is *always* sourced from `QuranRepository`

- **Why:** `qcf_quran_plus` represents Quran content as glyphs in private-use Unicode ranges driven by its bundled font. That's correct for visual rendering but is not the canonical text. If the user copies an ayah, opens an MCP query that returns the same ayah, or runs a search, all of those flows must speak Tanzil UTF-8 from our integrity-checked DB. Treating QCF glyphs as a second source of truth would silently fork the corpus.
- **Implication:** The page-mode view uses `qcf_quran_plus` for layout/glyphs only. Anything user-actionable (selection, copy, "what ayah am I on?") resolves through the locator back to an `AyahKey`, then asks `QuranRepository` for the actual text. Text mode renders straight from the repository.

### D3: Text mode = surah-at-a-time, not whole-Quran scroll

- **Why:** A flat 6,236-row scroll is hostile to screen readers and to anyone trying to find their place. Surah granularity matches the user's mental model and matches every entry point (Surahs list, future search results, future bookmarks).
- **Trade-off:** Continuous reading across a juz boundary requires an explicit "next surah" tap. Acceptable for MVP; a juz-based scroll is a follow-up if anyone asks for it.

### D4: Routes and addressability

```text
/reader/page/{pageNumber}        canonical for page mode (1..604)
/reader/surah/{surahNumber}      canonical for text mode (1..114)
/reader/ayah/{surah}/{ayah}      addressable — redirects into whichever mode is active,
                                  scrolling/paginating to that ayah
```

- The shell stays unchanged; the reader is a drill-down route, not a top-level destination.
- Out-of-range params (e.g. `/reader/page/700`, `/reader/surah/115`, `/reader/ayah/1/8`) redirect to the existing unknown-route handler with a brief error toast — they are user-malformed paths, not data-integrity failures.
- Route names live in `RouteNames` / `RoutePaths` per CLAUDE.md ([lib/app/router/route_names.dart](../../../lib/app/router/route_names.dart)).
- The catch-all unknown-route redirect already in the router stays last; the new routes are added *above* it in declaration order. A regression test guards this.

### D5: `MushafLocator` seam

```dart
// lib/domain/quran/mushaf_locator.dart  (framework-free)
abstract class MushafLocator {
  Result<int>      pageForAyah(AyahKey key);     // 1..604
  Result<AyahKey>  firstAyahOnPage(int page);    // for "what page am I on?" → repo lookup
  Result<List<AyahKey>> ayahsOnPage(int page);   // for selection / copy in page mode
  Result<int>      pageForSurah(int surahNumber);// equals pageForAyah(AyahKey(surah,1))
}
```

- Implementation `QcfMushafLocator` lives in [lib/data/quran/](../../../lib/data/quran/) and is the *only* place that imports `qcf_quran_plus`.
- A no-op fallback `_TextOnlyLocator` is used when the rendering package fails to load — it returns `Failure.unsupported` for every method, which the UI handles by staying in text mode.
- Future audio/search/bookmark changes consume `MushafLocator` through Riverpod and do not import `qcf_quran_plus` directly. This keeps the rendering package swappable.

### D6: Render mode persistence

- A `ReaderModeNotifier` (Riverpod `StateNotifier<ReaderMode>`) over `SharedPreferences`. Default = `ReaderMode.page`.
- The toggle lives in Settings, above the existing "Quran source" attribution section. ForUI `FSelectGroup` or equivalent.
- On read failure (no key yet, or corrupted prefs) → default to page mode. Never throws.
- The reader page reads the current mode and switches between `PageMushafView` and `TextReaderView` — no in-reader toggle in this change. Keeps the reader chrome minimal.

### D7: Graceful degrade when `qcf_quran_plus` fails to load

- The reader screen, on first build for the session, attempts to initialize `QcfMushafLocator`. Initialization wraps any package load failure (missing fonts, asset loading exception, `firstAyahOnPage(1)` throws) in a `Result`.
- On failure: switch the *runtime view* to text mode for the session (without writing to `SharedPreferences` — the user's preference is preserved), and surface a non-fatal ForUI banner: "Mushaf rendering unavailable; showing plain text. Try restarting the app."
- This is *not* a data-integrity failure. The Tanzil text is still verified and served — only the visual presentation is degraded. The fatal error screen is reserved for `Failure.dataIntegrity` from the data layer, as before.

### D8: Surahs-list handoff

- The Surahs list tile becomes tappable. On tap → `context.goNamed(RouteNames.readerAyah, pathParameters: {'surah': '<n>', 'ayah': '1'})`.
- The redirect at `/reader/ayah/{s}/{a}` resolves the user's current `ReaderMode`, computes the target page (page mode) or scroll offset (text mode), and navigates there.
- No state is preserved on back-nav for this MVP — pressing back returns to the Surahs list at the top. Persisting last-read position is a bookmarks-change concern.

### D9: Performance and asset budget

- `qcf_quran_plus`'s fonts and metadata add roughly 3–5 MB to the app bundle (verify in implementation; record actual size in the PR description). Combined with the ~5–7 MB Quran SQLite asset, total stays under the 15 MB hand-set ceiling for MVP.
- Page mode lazily loads only the visible page; metadata lookup is in-memory and O(1) per ayah/page query. No global preload.
- Text mode renders one surah at a time. Even Al-Baqarah (286 ayahs) is small enough for `ListView.builder` without any virtualization tricks beyond what Flutter's lazy list gives for free.

### D10: Logging and error surface

- Locator and reader use `appLogger`. Failures map to:
  - `Failure.dataAccess` — repository read failed (delegated to the data layer; surfaces in the reader as a ForUI alert).
  - `Failure.invalidInput` — out-of-range route params; redirected to unknown-route handler.
  - `Failure.unsupported` — locator not initialized (graceful-degrade trigger).
- No `print`. No throws across the feature boundary.

## Risks / Trade-offs

- **`qcf_quran_plus` license / glyph attribution** → record full attribution in `THIRD_PARTY_NOTICES.md` alongside the Tanzil entry, and add a Settings row for it. If the license is unsuitable (e.g. requires runtime acknowledgement we can't satisfy), block the change before merge and pursue alternative renderer.
- **Font load cost on first reader open** → fonts may incur a perceptible delay the first time. Mitigation: pre-warm the font on app startup behind the integrity-check completion (cheap if the package supports it; otherwise on first reader navigation). Measure during implementation.
- **Locator divergence from our DB** → `qcf_quran_plus`'s ayah numbering may differ from Tanzil's at edge cases (basmala counted differently, etc.). Mitigation: a startup smoke test verifies `pageForAyah(AyahKey(1,1))` returns 1, `pageForAyah(AyahKey(2,255))` returns the canonical Ayat al-Kursi page (recorded as a constant in the test), and `firstAyahOnPage(604)` returns a valid surah/ayah from our DB. If smoke fails, log loudly and fall back to text mode for the session — same path as D7.
- **Two presentation widgets to maintain** → mitigated by zero shared rendering logic (each owns its own widget tree). The shared chrome is a thin top bar with surah/page indicator that asks the locator/repository for labels.
- **Router redirect ordering bug** → the new `/reader/ayah/...` redirect could shadow the unknown-route catchall if added in the wrong place. Mitigation: explicit regression test that `/this-does-not-exist` still redirects to home, and that `/reader/ayah/115/1` redirects to home with the toast.
- **`qcf_quran_plus` package abandonment** → mitigated by the `MushafLocator` seam; swapping to a different mushaf package or rolling our own becomes a single-implementation change, not a rip-and-replace.
- **Settings toggle persisted as raw enum index** → if we later add a render mode (e.g. juz-scroll), the index meaning could shift. Mitigation: persist as a string key (`"page"` / `"text"`), parse defensively, default to page on unknown values.

## Migration Plan

Greenfield feature. Deployment steps:

1. PR adds `qcf_quran_plus` to `pubspec.yaml`, the new feature/data/domain files, route entries, and the Settings toggle row.
2. Surahs list tile is wired to navigate to the reader.
3. CI runs `just check` (format + analyze + test). Test suite covers both render modes, locator round-trip, route redirects, settings persistence, and the graceful-degrade path.
4. Manual smoke on Windows: open Surahs → tap a surah → reader opens at ayah 1 in page mode; toggle Settings to text → re-enter reader → text mode renders; try `/reader/page/700` and `/reader/ayah/115/1` → unknown-route redirect.
5. Rollback: revert the PR. Surahs list goes back to inert tiles; the rest of the app is unaffected.

For future `qcf_quran_plus` version bumps: same pattern as any pubspec bump — analyze + test + manual smoke. The `MushafLocator` interface is the firewall.

## Open Questions

- **Does `qcf_quran_plus` ship line-break / juz / hizb metadata, or only page-and-ayah?** Resolve during implementation. If it does, future bookmarks/search changes can use juz/hizb labels for free; if not, that becomes a separate metadata source.
- **Should the reader top-bar show "Page X of 604" in page mode and "Surah X · Ayah Y" in text mode, or unify on one indicator?** Initial answer: mode-specific. Final placement is an Impeccable concern; flag for follow-up if it expands.
- **QCF font license compatibility.** Resolved before merge by maintainer confirmation: the bundled QCF fonts are allowed for this project. Recommended path for this MVP is to keep `qcf_quran_plus`, ship the page-mode renderer, and keep package/font attribution in `THIRD_PARTY_NOTICES.md`.
- **Pre-warm fonts at app startup, or on first reader open?** Decide based on measured cost during implementation. Default plan: lazy on first reader open.
