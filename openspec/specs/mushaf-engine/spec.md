# mushaf-engine Specification

## Purpose
TBD - created by archiving change add-tarteel-qul-mushaf-engine. Update Purpose after archive.
## Requirements
### Requirement: The engine is a standalone, asset-agnostic, publishable package

The system SHALL provide a `tarteel_qul` Flutter package at `packages/tarteel_qul/` that renders printed-mushaf pages from Tarteel QUL data. The package SHALL bundle no QUL data or fonts; it SHALL render only from data supplied by the consumer through a `MushafAssetSource` abstraction. The package SHALL NOT depend on `package:quran_player/` or any host-app code, and SHALL be structured for pub.dev publication (`publish_to` not set to `none`, with its own README, CHANGELOG, LICENSE, and example).

#### Scenario: Package carries no bundled QUL assets

- **WHEN** the `packages/tarteel_qul/` directory is inspected
- **THEN** it contains no QUL layout database, word-script database, or mushaf font files
- **AND** rendering data reaches the engine only through a `MushafAssetSource` implementation supplied by the consumer

#### Scenario: Package does not depend on the host app

- **WHEN** `packages/tarteel_qul/pubspec.yaml` and its Dart sources are inspected
- **THEN** no dependency or import resolves to `package:quran_player/`

#### Scenario: MushafAssetSource is the sole data contract

- **WHEN** a consumer wires the engine
- **THEN** it supplies the layout database bytes, the word-script database bytes, and per-page font bytes through a `MushafAssetSource` whose page-font method is called lazily, one page at a time

### Requirement: The engine parses QUL layout and word data into typed page models

The engine SHALL parse a QUL mushaf layout database (a `pages` table) and a QUL word-script database (`words` table) into typed models. For a given page it SHALL produce that page's lines in `line_number` order, each carrying its line type (`ayah`, `surah_name`, `basmallah`), its centered flag, and — for `ayah` lines — the ordered words obtained by joining the layout's `first_word_id..last_word_id` range against the word database.

#### Scenario: A page resolves to ordered typed lines

- **WHEN** the engine is asked for page 1 of a valid QUL layout
- **THEN** it returns that page's lines ordered by line number, each with a line type and centered flag

#### Scenario: Ayah lines carry their words

- **WHEN** a page line has type `ayah`
- **THEN** its words are the word-database rows whose id falls in the line's `first_word_id..last_word_id` range, in id order, each carrying its glyph-code text and its surah/ayah coordinates

### Requirement: The engine reads layout dimensions from data, not hard-coded values

The engine SHALL derive page count and lines-per-page from the layout database's `pages` table (the maximum `page_number` and `line_number`) rather than hard-coding them, so it renders any QUL layout (V1, V2, V4, IndoPak, …) whose schema matches. The host application's choice of a specific layout SHALL NOT be encoded in the package.

#### Scenario: Page count is derived from the pages table

- **WHEN** the engine opens a layout database
- **THEN** it derives the page count and lines-per-page from the `pages` table's maximum `page_number` and `line_number` for bounds and rendering rather than constants

### Requirement: The engine validates layout data and fails structurally

When the supplied layout or word database is missing expected tables, has an unexpected schema, or fails to open, the engine SHALL surface a structured failure to the consumer rather than throwing an unhandled exception or rendering incorrect output.

#### Scenario: Malformed layout database surfaces a structured failure

- **WHEN** the engine is given a database that lacks the expected `pages` or `words` tables
- **THEN** it reports a structured failure the consumer can branch on
- **AND** it does not throw an unhandled exception and does not render a partial page

### Requirement: The engine renders a page with the matching per-page font

The engine SHALL render each page's `ayah` lines as right-to-left glyph runs using that page's font (`pN.ttf`), and SHALL render `surah_name` and `basmallah` lines in their centered/ornamental forms. Page fonts SHALL be loaded lazily on demand and cached for the lifetime of the process.

#### Scenario: A page renders in its own font

- **WHEN** the engine renders page `N`
- **THEN** the page's glyph runs are drawn in the font supplied by `MushafAssetSource.pageFont(N)`

#### Scenario: Page fonts load lazily and are cached

- **WHEN** a page is rendered for the first time
- **THEN** its font is requested from `MushafAssetSource` and registered once
- **AND** rendering the same page again does not request or register the font a second time

#### Scenario: Centered lines render centered

- **WHEN** a page line has type `surah_name` or `basmallah`, or its centered flag is set
- **THEN** the line is rendered centered rather than justified across the full line width

### Requirement: MushafView is a mode-agnostic, event-emitting, decoration-accepting widget

The engine SHALL expose a `MushafView` widget that renders a mushaf page and is mode-agnostic: it SHALL emit semantic interaction events — at least a word-level tap carrying the tapped word and an ayah-level tap carrying an `AyahKey` — and SHALL accept a list of visual decorations (such as ayah highlights) supplied by the consumer. `MushafView` SHALL NOT contain any concept of an application "mode".

#### Scenario: Tapping a word emits a word event

- **WHEN** the user taps a rendered word in `MushafView`
- **THEN** the widget emits a word-tap event carrying that word's identity (and thus its surah/ayah)

#### Scenario: Tapping within an ayah emits an ayah event

- **WHEN** the user taps within a rendered ayah in `MushafView`
- **THEN** the widget emits an ayah-tap event carrying the ayah's `AyahKey`

#### Scenario: Decorations are rendered without the widget knowing why

- **WHEN** the consumer supplies a decoration (for example, an ayah highlight) to `MushafView`
- **THEN** the widget renders the decoration over the matching ayah
- **AND** the widget exposes no API that references application modes

### Requirement: The engine exposes a page-ayah coordinate API

The engine SHALL expose a coordinate API that maps between `AyahKey` and page number for the loaded layout: the page containing a given ayah, the first ayah on a given page, and all ayahs on a given page in canonical order. Out-of-range input SHALL produce a structured failure rather than throwing.

#### Scenario: Coordinate round-trip for a known ayah

- **WHEN** the page for `AyahKey(1, 1)` is requested against a loaded layout
- **THEN** the engine returns page 1
- **AND** the first ayah on page 1 is an `AyahKey` with surah 1 and ayah 1

#### Scenario: All ayahs on a page

- **WHEN** all ayahs on page 1 are requested
- **THEN** the engine returns a non-empty ordered list of `AyahKey` values

#### Scenario: Out-of-range coordinate input fails structurally

- **WHEN** the page for an out-of-range ayah, or the first ayah of an out-of-range page, is requested
- **THEN** the engine returns a structured failure and does not throw

### Requirement: The engine renders a consumer-selected colour palette

The engine SHALL render a page's glyphs in a consumer-selected `CPAL` colour palette of the per-page font, and SHALL render the font's default palette when none is selected. The engine SHALL apply the selection itself — the consumer supplies the same unmodified font bytes regardless of palette.

#### Scenario: A page renders in the selected palette

- **WHEN** `MushafView` renders a page whose font carries multiple `CPAL` palettes, with palette `N` selected
- **THEN** the page's glyphs are drawn in palette `N`'s colours
- **AND** selecting a different palette for the same page re-renders it in the other palette without the consumer changing the supplied font bytes

