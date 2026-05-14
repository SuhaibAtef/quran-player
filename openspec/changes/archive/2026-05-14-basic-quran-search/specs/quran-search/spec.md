## ADDED Requirements

### Requirement: Search page accepts basic Quran text queries

The Search page SHALL provide a user-facing basic Quran text search surface using ForUI components. The page MUST accept plain text input, submit the query to `QuranRepository.searchAyahs`, and render feature-local idle, loading, result, empty, invalid-input, and failure states.

#### Scenario: Search page starts idle

- **WHEN** the user opens the Search top-level destination before entering a query
- **THEN** the page shows an empty idle state and does not call `QuranRepository.searchAyahs`

#### Scenario: User submits a valid query

- **WHEN** the user enters a non-empty query and submits it
- **THEN** the page shows a loading state while the repository search is pending and then renders the returned results

#### Scenario: Empty query is handled in the UI

- **WHEN** the user submits an empty or whitespace-only query
- **THEN** the page remains in an idle or validation state and does not call the repository with that query

#### Scenario: Repository failure is visible but non-fatal

- **WHEN** the repository returns a failure for a submitted search
- **THEN** the Search page shows a concise non-fatal error state and leaves the rest of the app shell usable

### Requirement: Search results render trustworthy references

Search results SHALL show each ayah's reference, canonical Arabic text, and surah display name from the repository result. The UI MUST NOT invent references, summarize ayah content, or display text from outside the verified Quran database.

#### Scenario: Result row shows reference and text

- **WHEN** a search result for `AyahKey(2, 255)` is rendered
- **THEN** the row shows reference `2:255`, the canonical Arabic ayah text, and the surah display name supplied by the repository

#### Scenario: Empty result set is handled

- **WHEN** a valid search completes with zero matches
- **THEN** the page shows an empty-results state and does not render stale results from a previous query

#### Scenario: Results are bounded in the UI

- **WHEN** a valid search matches more ayahs than the MVP result limit
- **THEN** the page renders only the bounded result set returned by the repository and remains responsive

### Requirement: Search results open the reader

Activating a search result SHALL navigate through the existing ayah reader deep link, `/reader/ayah/{surah}/{ayah}`, so the active reader mode and QCF fallback behavior remain centralized in the router.

#### Scenario: User opens a search result

- **WHEN** the user activates the result for `2:255`
- **THEN** the app navigates to `/reader/ayah/2/255`

#### Scenario: Reader mode remains centralized

- **WHEN** a search result is activated while the user has page mode or text mode selected
- **THEN** Search does not compute a page or surah route itself; the existing reader ayah route resolves the final destination

#### Scenario: Search does not add top-level navigation

- **WHEN** this change ships
- **THEN** the app shell still has the same top-level destinations and no separate Reader or Search Results destination is added
