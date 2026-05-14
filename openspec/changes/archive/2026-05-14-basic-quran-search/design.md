## Context

The foundation now has a verified Tanzil Uthmani SQLite asset, a framework-free `QuranRepository`, an FTS5 table named `ayah_fts`, and reader routes that can open a validated ayah. The Search top-level destination still renders a placeholder, while IDEA.md lists basic Quran search as an MVP feature and read-only MCP later needs the same `search_quran` behavior.

Current constraints:

- Quran text must remain exactly the bundled canonical text.
- Runtime Quran data access must stay read-only and offline.
- Domain contracts under `lib/domain/quran/` must remain free of Flutter, Riverpod, SQLite, and rendering-package dependencies.
- Search results must navigate through the existing `/reader/ayah/{surah}/{ayah}` route instead of adding a new reader route.
- UI must stay ForUI-first and fit the existing desktop app shell.

Stakeholders: end users who need fast reference lookup, maintainers who need one reusable search contract, and the future read-only MCP server that must not diverge from app database behavior.

## Goals / Non-Goals

**Goals:**

- Expose basic Arabic Quran text search through `QuranRepository`.
- Use the existing bundled SQLite FTS5 index for bounded, deterministic search.
- Replace the Search placeholder with a real ForUI-based search screen.
- Return results that identify each ayah by `AyahKey`, surah metadata, and canonical ayah text.
- Open selected results in the existing reader deep-link flow.
- Cover repository behavior and UI states with focused tests.

**Non-Goals:**

- Translation, tafsir, transliteration, or semantic search.
- Fuzzy matching, stemming beyond SQLite tokenizer behavior, or ranking claims that imply meaning.
- Search history, saved searches, filters by juz/hizb/page, or advanced query syntax UI.
- MCP server implementation. This change only prepares the repository contract the server will reuse.
- QCF page-glyph text highlighting.

## Decisions

### Add a search-specific domain type

Create a `QuranSearchResult` value type under `lib/domain/quran/` with:

- `AyahKey key`
- canonical `String text`
- enough surah display metadata to render the result without issuing one repository call per row, likely `surahNameArabic` and `surahNameLatin`
- an optional numeric rank/score only if useful for deterministic ordering; do not expose it in UI as a meaning-quality score

Why: the UI and future MCP server need a stable result shape. Returning raw `Ayah` values would force callers to do extra surah lookups and would make result rendering slower or more duplicated.

Alternative considered: return `List<Ayah>` and let UI join surah names. That keeps the repository smaller but pushes data-shaping into every caller, including MCP.

### Extend `QuranRepository` with a bounded search method

Add a method such as:

```dart
Future<Result<List<QuranSearchResult>>> searchAyahs(
  String query, {
  int limit = 50,
});
```

The method validates trimmed input, rejects empty queries, clamps or rejects unreasonable limits, and returns `Result` failures instead of throwing.

Why: search belongs at the same boundary as `getAyah` and `getSurah`, because the future MCP server must search the exact same corpus through the same safety rules.

Alternative considered: feature-local provider directly queries SQLite. That would work for UI but would bypass the domain contract and create a second path for MCP later.

### Implement SQLite FTS as the first search engine

`QuranRepositorySqlite.searchAyahs` should query `ayah_fts` joined back to `ayahs` and `surahs`, returning canonical `ayahs.text` rather than FTS shadow content. Results should be ordered deterministically, preferring FTS rank when available and falling back to `(surah, ayah)`.

Why: the DB already contains `ayah_fts`, so this change can stay small and offline. Joining back to `ayahs` preserves the single-source-of-truth rule.

Alternative considered: linear scan over all ayahs. It is simpler but ignores the existing index and would be the wrong contract to expose through MCP.

### Keep MVP query semantics narrow

The MVP search accepts plain text. It may normalize only safe presentation-level whitespace and should not alter Quran text. The UI should present search as basic text search, not as a semantic answer engine.

Why: Arabic search quality can become complex quickly because of diacritics, hamza forms, and tokenizer behavior. The MVP should be honest and testable before adding query expansion.

Alternative considered: build Arabic normalization/fuzzy matching now. That risks changing perceived text matching semantics before the team has a clear quality target.

### Use existing reader routing for result activation

Tapping a result navigates to `/reader/ayah/{surah}/{ayah}`. The router already validates the ayah and redirects into the active reader mode, including QCF fallback behavior.

Why: it reuses the `MushafLocator` seam and avoids duplicating page/text routing decisions in Search.

Alternative considered: Search computes page/surah targets itself. That would couple Search to reader internals and QCF behavior.

### Search UI is stateful but not global

Use Riverpod providers under `lib/features/search/` for query/result state. The query does not need persistence for MVP. Debounce may be implemented in the feature state layer or the widget/controller layer, but tests should not depend on wall-clock timing where avoidable.

Why: search state belongs to the feature, while the repository remains shared. Avoiding persistence keeps MVP scope tight.

Alternative considered: persist the last query. Useful later, but it adds privacy and UX questions unrelated to basic search.

## Risks / Trade-offs

- Arabic search may feel incomplete for users who expect diacritic-insensitive or semantic matching -> Mitigation: scope UI copy and tests to basic text search; record normalization improvements as a later change.
- FTS query syntax can treat certain characters as operators -> Mitigation: sanitize or quote user input before passing it to `MATCH`, and cover punctuation/malformed input tests.
- A repository interface change breaks test doubles -> Mitigation: update fakes in the same change and keep the method shape minimal.
- Result snippets could accidentally use non-canonical FTS content -> Mitigation: always select displayed text from `ayahs.text`.
- Large result sets could hurt UI responsiveness -> Mitigation: enforce a default bounded limit and render with a lazy scrolling list.
- Search could trigger before Quran integrity is complete -> Mitigation: keep existing boot gating and have failure states avoid partial rendering.

## Migration Plan

No data migration is required because schema v1 already includes `ayah_fts`.

Implementation order:

1. Add domain search result type and repository method.
2. Implement SQLite FTS query and tests against the bundled DB.
3. Add feature state and UI for Search page.
4. Add result navigation tests.
5. Update docs to mark basic search as implemented and document MVP limitations.

Rollback is straightforward: revert the change. The bundled DB format remains unchanged.

## Open Questions

- Should empty input return `Result.ok([])` at the repository boundary or `Failure.invalidInput`? Recommended split: repository rejects empty input, UI treats an empty field as an idle empty state and does not call the repository.
- Should `limit` be caller-controlled for UI? Recommended: allow the repository parameter for MCP reuse, but keep the UI on a fixed MVP limit.
