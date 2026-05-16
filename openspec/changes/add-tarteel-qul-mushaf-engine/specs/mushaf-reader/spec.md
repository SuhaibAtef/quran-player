## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: QUL mushaf attribution surfaces in Settings

The application SHALL credit the Tarteel QUL (Quran Universal Library) mushaf layout, word-script data, and KFGQPC fonts that page mode renders, in the Settings page alongside the existing Tanzil attribution row, and MUST record those resources and their license terms in `THIRD_PARTY_NOTICES.md`. Because Quran Companion bundles the QUL fonts into its built binary, the notice MUST reflect that the application redistributes them; the `tarteel_qul` package itself bundles and redistributes nothing.

#### Scenario: QUL mushaf row appears in Settings

- **WHEN** the user navigates to the Settings page
- **THEN** a row credits the QUL mushaf layout / word-script / KFGQPC fonts used by page mode, separately from the Tanzil source row

#### Scenario: Attribution is recorded in THIRD_PARTY_NOTICES.md

- **WHEN** the change ships
- **THEN** `THIRD_PARTY_NOTICES.md` contains an entry for the QUL mushaf resources and the KFGQPC font license, noting that the application binary redistributes the fonts
- **AND** the previous `qcf_quran_plus` entry is removed

## REMOVED Requirements

### Requirement: QCF source attribution surfaces in Settings

**Reason**: Page mode no longer uses `qcf_quran_plus`; it renders through the `tarteel_qul` engine on Tarteel QUL data. The QCF attribution requirement is replaced by the "QUL mushaf attribution surfaces in Settings" requirement added in this change.

**Migration**: The Settings attribution row and the `THIRD_PARTY_NOTICES.md` entry move from `qcf_quran_plus` + QCF fonts to the QUL mushaf layout / word-script / KFGQPC fonts. No data migration is required; this is a documentation/attribution swap that ships with the `qcf_quran_plus` removal.
