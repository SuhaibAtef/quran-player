# mushaf-reader Specification

## Purpose
TBD - created by archiving change mushaf-reader. Update Purpose after archive.
## Requirements
### Requirement: Reader exposes page and text render modes

The application SHALL provide a Quran reader feature with two render modes: a page-based mushaf view that renders the printed-mushaf layout via the `tarteel_qul` mushaf engine, and a continuous text view that renders ayahs surah-at-a-time straight from `QuranRepository`. Exactly one mode is active at any time, controlled by a user-visible setting.

#### Scenario: Default mode is page

- **WHEN** the reader is opened on a fresh install with no persisted preference
- **THEN** it renders in page mode using the `tarteel_qul` mushaf engine

#### Scenario: User-selected mode is honored

- **WHEN** the user has selected text mode in Settings and opens the reader
- **THEN** it renders in text mode using `QuranRepository`-supplied ayahs, with no `tarteel_qul` `MushafView` widget in the tree

#### Scenario: Modes do not share rendering paths

- **WHEN** any reader screen is built
- **THEN** it instantiates either the page-mode widget or the text-mode widget, not both, and they share no rendering logic beyond the surrounding chrome

### Requirement: Quran text always originates in QuranRepository

The reader feature MUST source all Quran *text* (anything user-actionable, including ayah resolution, copy, top-bar labels, and text-mode rendering) from the `QuranRepository` defined by the `quran-data` capability. The `tarteel_qul` mushaf engine supplies layout and glyphs for page mode only and MUST NOT be treated as a second source of canonical text.

#### Scenario: Page-mode user actions resolve through the repository

- **WHEN** a user action in page mode requires the textual content of an ayah
- **THEN** the feature obtains the text via `QuranRepository.getAyah(...)` rather than reading glyph data from the `tarteel_qul` engine

#### Scenario: Text mode reads only the repository

- **WHEN** text mode renders a surah
- **THEN** all visible ayah text comes from `QuranRepository.getSurahAyahs(...)` and no import from `tarteel_qul` appears in the text-mode widget tree

### Requirement: Reader is addressable by route

The application SHALL expose three reader routes, registered ahead of the existing unknown-route redirect so unknown paths still fall through:

- `/reader/page/{pageNumber}` — page mode at the given page (1..604).
- `/reader/surah/{surahNumber}` — text mode at the given surah (1..114).
- `/reader/ayah/{surah}/{ayah}` — addressable redirect into the user's currently active mode, scrolled or paginated to that ayah.

Out-of-range or malformed parameters MUST redirect to the existing unknown-route handler rather than rendering a partial reader.

#### Scenario: Page-mode deep link

- **WHEN** the user navigates to `/reader/page/1`
- **THEN** the reader opens in page mode at page 1

#### Scenario: Text-mode deep link

- **WHEN** the user navigates to `/reader/surah/2`
- **THEN** the reader opens in text mode at the start of Al-Baqarah

#### Scenario: Ayah deep link respects active mode

- **WHEN** the active mode is page and the user navigates to `/reader/ayah/2/255`
- **THEN** the reader opens in page mode on the page that contains 2:255, with that ayah scrolled into view if the package supports it

#### Scenario: Ayah deep link in text mode

- **WHEN** the active mode is text and the user navigates to `/reader/ayah/2/255`
- **THEN** the reader opens in text mode at Al-Baqarah with ayah 255 scrolled into view

#### Scenario: Out-of-range page number

- **WHEN** the user navigates to `/reader/page/700`
- **THEN** the router redirects to `/` and surfaces a brief error toast, and no reader is rendered

#### Scenario: Out-of-range surah number

- **WHEN** the user navigates to `/reader/surah/115`
- **THEN** the router redirects to `/` and no reader is rendered

#### Scenario: Out-of-range ayah within a surah

- **WHEN** the user navigates to `/reader/ayah/1/8` (Al-Fatihah has 7 ayahs)
- **THEN** the router redirects to `/` and no reader is rendered

#### Scenario: Unknown-route redirect still applies

- **WHEN** the user navigates to a path that is not a registered route
- **THEN** the unknown-route catch-all still redirects to `/` exactly as before; the new reader routes do not shadow it

### Requirement: Surahs list navigates into the reader

Tapping a tile in the Surahs list SHALL open the reader at the first ayah of that surah, in the user's currently active render mode. The Surahs list itself MUST remain unchanged in shape — only the per-tile tap behavior changes.

#### Scenario: Surah tap in page mode

- **WHEN** the active mode is page and the user taps the Al-Fatihah tile
- **THEN** the reader opens in page mode at the page that contains 1:1

#### Scenario: Surah tap in text mode

- **WHEN** the active mode is text and the user taps the Al-Fatihah tile
- **THEN** the reader opens in text mode at the top of Al-Fatihah

#### Scenario: Surah tap surfaces no error on a healthy install

- **WHEN** the user taps any of the 114 surah tiles on a healthy install
- **THEN** the reader opens without showing the failure banner described under graceful-degrade

### Requirement: MushafLocator seam decouples rendering from features

The system SHALL define a framework-free `MushafLocator` contract under `lib/domain/quran/` that maps `AyahKey ↔ pageNumber` for the standard 604-page printed mushaf. The contract MUST be implemented by `QulMushafLocator` in `lib/data/quran/`, backed by the `tarteel_qul` engine's layout data. `package:tarteel_qul/` MUST be imported by no more than two host-app areas: the `MushafLocator` implementation (coordinate translation) and the page-mode reader widget (rendering). Future audio, search, bookmark, and MCP changes MUST be able to drive the reader to a position by depending on `MushafLocator` without importing `tarteel_qul`.

#### Scenario: Domain layer does not import the rendering package

- **WHEN** the `lib/domain/quran/` directory is compiled in isolation
- **THEN** no import resolves to `package:tarteel_qul/`, `package:flutter/`, `package:flutter_riverpod/`, or any storage package

#### Scenario: Locator round-trip for a known ayah

- **WHEN** `pageForAyah(AyahKey(1, 1))` is called against a healthy locator
- **THEN** it returns `Result.ok` with `1`, and `firstAyahOnPage(1)` returns `Result.ok` with an `AyahKey` whose surah is `1` and ayah is `1`

#### Scenario: Locator returns ayahs on a page

- **WHEN** `ayahsOnPage(1)` is called
- **THEN** it returns `Result.ok` with a non-empty list of `AyahKey` values, all with surah `1`, in ascending order of ayah number

#### Scenario: Locator returns the page for a surah

- **WHEN** `pageForSurah(2)` is called
- **THEN** it returns `Result.ok` with the same value as `pageForAyah(AyahKey(2, 1))`

#### Scenario: Locator rejects out-of-range input

- **WHEN** `pageForAyah(AyahKey(115, 1))` or `firstAyahOnPage(700)` is called
- **THEN** it returns `Failure.invalidInput` and does not throw

### Requirement: Render mode is persisted across launches

The application SHALL persist the user's reader-mode selection in `SharedPreferences` keyed by a stable string (`"page"` or `"text"`), default to page mode when no preference is set or the stored value is unrecognized, and surface a Settings toggle that updates the preference. Persistence failures MUST NOT throw; the runtime falls back to page mode and continues.

#### Scenario: Toggling the Settings preference updates active mode

- **WHEN** the user toggles the reader-mode setting from page to text
- **THEN** subsequent reader screen builds render in text mode, and the value `"text"` is written to `SharedPreferences`

#### Scenario: Preference survives app restart

- **WHEN** the user has selected text mode and the app is restarted
- **THEN** the reader still opens in text mode

#### Scenario: Unknown stored value falls back to page mode

- **WHEN** the persisted value is missing, empty, or not one of `"page"` or `"text"`
- **THEN** the reader opens in page mode and no exception is thrown

### Requirement: Reader degrades gracefully when rendering is unavailable

If the `tarteel_qul` mushaf engine cannot render at runtime — the bundled QUL assets are missing, a QUL database fails structural validation, a page font fails to load, or the locator smoke test fails — the reader SHALL switch the runtime view to text mode for the current session, surface a non-fatal banner, and leave the user's persisted preference unchanged. The data-integrity fatal error screen MUST NOT be triggered by a mushaf-rendering failure.

#### Scenario: Page mode auto-switches to text on render failure

- **WHEN** the page-mode reader is opened and the `tarteel_qul` engine reports the QUL assets are missing or invalid
- **THEN** the reader renders text mode for that screen, displays a banner explaining the degrade, and the persisted preference remains `"page"`

#### Scenario: Persisted preference survives a session-level fallback

- **WHEN** a session-level fallback to text mode has occurred and the app is restarted
- **THEN** the reader attempts page mode again on the next launch (no permanent mode change was written)

#### Scenario: Rendering failure is not a data-integrity failure

- **WHEN** the `tarteel_qul` engine fails to render but `QuranRepository` is healthy
- **THEN** the data-integrity fatal error screen is not shown, and `QuranRepository` calls continue to succeed

### Requirement: Reader does not introduce top-level navigation

The reader SHALL be reachable only as a drill-down (from the Surahs list, from a deep-link URL, and later from search/bookmarks/MCP). The application shell's top-level destinations (sidebar / bottom navigation) MUST NOT gain a "Reader" entry.

#### Scenario: Shell destinations are unchanged

- **WHEN** the app shell is rendered
- **THEN** the set of top-level destinations is the same as before this change (no Reader entry)

### Requirement: QUL mushaf attribution surfaces in Settings

The application SHALL credit the Tarteel QUL (Quran Universal Library) mushaf layout, word-script data, and KFGQPC fonts that page mode renders, in the Settings page alongside the existing Tanzil attribution row, and MUST record those resources and their license terms in `THIRD_PARTY_NOTICES.md`. Because Quran Companion bundles the QUL fonts into its built binary, the notice MUST reflect that the application redistributes them; the `tarteel_qul` package itself bundles and redistributes nothing.

#### Scenario: QUL mushaf row appears in Settings

- **WHEN** the user navigates to the Settings page
- **THEN** a row credits the QUL mushaf layout / word-script / KFGQPC fonts used by page mode, separately from the Tanzil source row

#### Scenario: Attribution is recorded in THIRD_PARTY_NOTICES.md

- **WHEN** the change ships
- **THEN** `THIRD_PARTY_NOTICES.md` contains an entry for the QUL mushaf resources and the KFGQPC font license, noting that the application binary redistributes the fonts
- **AND** the previous `qcf_quran_plus` entry is removed

### Requirement: Page mode is legible under light and dark themes

The reader's page mode SHALL render the mushaf legibly under both the light and the dark application theme. Under the light theme it SHALL render on a light page with a dark-text colour palette; under the dark theme it SHALL render on a dark page with a light-text colour palette. A theme change MUST NOT leave the mushaf text unreadable against its page.

#### Scenario: Dark theme renders a legible page

- **WHEN** the reader is opened in page mode under the dark application theme
- **THEN** the mushaf page is rendered on a dark page surface with a light-text palette, so the glyphs are legible

#### Scenario: Light theme renders a legible page

- **WHEN** the reader is opened in page mode under the light application theme
- **THEN** the mushaf page is rendered on a light page surface with a dark-text palette

### Requirement: A mushaf colour style is user-selectable

The application SHALL provide a Settings control that lets the user choose a mushaf colour style. It SHALL offer every colour palette the QUL per-page fonts carry — tajweed-coloured and plain (mono) variants, including dark-page variants — as selectable styles, not only a tajweed/plain pair. The control SHALL show a live preview that renders a real mushaf verse in the selected style. The selected style SHALL be persisted and applied to page mode, independent of the application's light/dark theme. This requirement replaces the former `qcf`-era tajweed toggle.

#### Scenario: Colour-style picker appears in Settings with a real-verse preview

- **WHEN** the user navigates to the Settings page
- **THEN** a mushaf colour-style control offers every QUL colour palette as a selectable style
- **AND** it shows a preview rendering a real mushaf verse (Sūrat al-Fātiḥah) in the selected style

#### Scenario: Selected style persists and applies

- **WHEN** the user selects a colour style and reopens the reader in page mode
- **THEN** page mode renders in the selected style
- **AND** the selection survives an app restart

### Requirement: Surah headers and basmala render as ornamental glyphs

The reader's page mode SHALL render `surah_name` lines using the QUL ornamental surah-header colour font and `basmallah` lines using the QUL bismillah glyph, rather than plain placeholders. The surah *name text* a user reads or copies MUST still originate in `QuranRepository`.

#### Scenario: A surah header renders ornamentally

- **WHEN** page mode renders a `surah_name` line
- **THEN** the line shows the ornamental QUL surah-header glyph for that surah, not a plain text or placeholder band

#### Scenario: A basmala line renders the bismillah glyph

- **WHEN** page mode renders a `basmallah` line
- **THEN** the line shows the QUL bismillah glyph

