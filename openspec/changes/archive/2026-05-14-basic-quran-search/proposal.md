## Why

The app has a verified Quran database with an FTS5 index and a reader that can open a specific ayah, but the Search top-level destination is still a placeholder. Basic search is an MVP requirement and also prepares the read-only MCP `search_quran` tool to reuse the same trusted domain contract as the app UI.

## What Changes

- Add a basic Quran search capability that lets users search Arabic Quran text from the Search page.
- Add a framework-free search result type and repository method backed by the existing `ayah_fts` table.
- Render bounded search results with ayah references and canonical Arabic text from `QuranRepository`.
- Let users open a result in the reader through the existing `/reader/ayah/{surah}/{ayah}` route.
- Provide loading, empty, invalid-input, and failure states without serving partial or alternate Quran text.
- Keep translations, tafsir, fuzzy semantic search, search history, and MCP server implementation out of scope.

## Capabilities

### New Capabilities

- `quran-search`: User-facing Quran text search, search state, result rendering, and result-to-reader navigation.

### Modified Capabilities

- `quran-data`: Extend the repository contract with a read-only search method that uses the bundled SQLite FTS index and remains reusable by the future MCP server.

## Impact

- Affects `lib/domain/quran/` with a search result/value type and repository contract extension.
- Affects `lib/data/quran/` with SQLite FTS query implementation.
- Affects `lib/features/search/` with real UI/state replacing the placeholder page.
- Affects tests for repository search behavior, Search page states, and result navigation.
- Does not add runtime network access, new Quran sources, translations, or new top-level routes.
