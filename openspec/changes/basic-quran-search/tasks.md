## 1. Domain Contract

- [x] 1.1 Add `QuranSearchResult` under `lib/domain/quran/` with ayah key, canonical text, and surah display metadata.
- [x] 1.2 Extend `QuranRepository` with a bounded `searchAyahs` method returning `Future<Result<List<QuranSearchResult>>>`.
- [x] 1.3 Update repository fakes/test doubles to implement the new search method.

## 2. SQLite Search Implementation

- [x] 2.1 Implement `QuranRepositorySqlite.searchAyahs` using `ayah_fts` joined to `ayahs` and `surahs`.
- [x] 2.2 Sanitize or quote user search input so punctuation and FTS operator-like text cannot leak raw SQLite exceptions.
- [x] 2.3 Validate empty queries and invalid limits as `Failure.invalidInput`, and enforce a bounded default result limit.
- [x] 2.4 Ensure displayed result text is selected from `ayahs.text`, not from generated snippets or FTS shadow content.

## 3. Search Feature State

- [x] 3.1 Add Riverpod state/controller under `lib/features/search/` for idle, loading, results, empty, validation, and failure states.
- [x] 3.2 Keep query state feature-local and non-persistent for MVP.
- [x] 3.3 Avoid repository calls for empty or whitespace-only UI submissions.

## 4. Search UI

- [x] 4.1 Replace the Search placeholder with an `FScaffold` page containing a ForUI search input and submit action.
- [x] 4.2 Render trustworthy result rows with reference, surah display name, and canonical Arabic ayah text.
- [x] 4.3 Render idle, loading, empty-results, invalid-input, and failure states without stale results.
- [x] 4.4 Navigate result activation through `/reader/ayah/{surah}/{ayah}` only.

## 5. Tests

- [x] 5.1 Add repository tests against the real bundled DB for a known Arabic query, empty input, bounded results, and punctuation/malformed input.
- [x] 5.2 Add widget tests for Search page idle, loading/results, empty, invalid-input, and failure states.
- [x] 5.3 Add a navigation test proving a result opens `/reader/ayah/{surah}/{ayah}` and does not bypass reader routing.
- [x] 5.4 Run `just format`, `just analyze`, and `just test`.

## 6. Documentation

- [x] 6.1 Update `AGENTS.md` and `README.md` to mark basic Quran search as implemented.
- [x] 6.2 Document MVP search limitations: Arabic canonical text only, no translation, no tafsir, no semantic/fuzzy search.
