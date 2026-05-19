## ADDED Requirements

### Requirement: QuranRepository supports basic ayah search

The `QuranRepository` contract SHALL expose a read-only basic search method that accepts a plain text query and returns bounded `QuranSearchResult` entries from the bundled Quran corpus. The method MUST return `Result<T>` rather than throwing for invalid input, storage failures, or query parsing failures. Search result text MUST come from canonical `ayahs.text`, not from a secondary source or generated summary.

#### Scenario: Search returns canonical ayah results

- **WHEN** `searchAyahs("الله")` is called against a healthy repository
- **THEN** it returns `Result.ok` with one or more `QuranSearchResult` entries whose `key` values identify real ayahs and whose `text` values are non-empty canonical Quran text

#### Scenario: Search results include surah display metadata

- **WHEN** a search returns ayah `2:255`
- **THEN** the corresponding result includes the ayah key, canonical ayah text, Arabic surah name, and Latin surah name without requiring the caller to perform additional surah lookups

#### Scenario: Empty query is rejected

- **WHEN** `searchAyahs("")` or `searchAyahs("   ")` is called
- **THEN** it returns `Failure.invalidInput` and does not query the database

#### Scenario: Result count is bounded

- **WHEN** `searchAyahs` is called with a query that matches more rows than the configured limit
- **THEN** it returns no more than that limit and does not stream an unbounded result set

#### Scenario: Malformed search syntax does not escape the repository boundary

- **WHEN** `searchAyahs` receives user text containing punctuation or characters that SQLite FTS could otherwise interpret as query syntax
- **THEN** the repository returns either safe search results or a `Failure.invalidInput`, and no raw SQLite exception escapes the repository boundary

#### Scenario: Search uses the bundled read-only corpus

- **WHEN** `searchAyahs` serves any query at runtime
- **THEN** it reads from the existing bundled SQLite database and performs no network request
