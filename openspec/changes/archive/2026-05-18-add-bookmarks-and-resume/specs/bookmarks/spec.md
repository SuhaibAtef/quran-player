## ADDED Requirements

### Requirement: Bookmarks persist as individual ayahs

The system SHALL persist each bookmark as a single ayah coordinate (`AyahKey`) in the user-writable `user.db`. A given ayah SHALL be bookmarked at most once. Bookmarks SHALL survive app restarts. Introducing the bookmark schema SHALL NOT alter or remove existing `user.db` data.

#### Scenario: Saving a bookmark persists it

- **WHEN** the user bookmarks ayah `2:255`
- **THEN** a bookmark for `2:255` exists and is still returned after the app is restarted

#### Scenario: Duplicate bookmark is idempotent

- **WHEN** the user bookmarks an ayah that is already bookmarked
- **THEN** no second bookmark is created and the existing one is retained

#### Scenario: Removing a bookmark

- **WHEN** the user removes the bookmark for `2:255`
- **THEN** `2:255` is no longer reported as bookmarked

#### Scenario: Existing user.db upgrades without data loss

- **WHEN** an existing schema-v1 `user.db` is opened by this change
- **THEN** it upgrades to schema v2, the `bookmark` table exists, and any existing `audit_log` rows are preserved

### Requirement: Bookmarks can be added and removed from the reader

Tapping a verse in either reader mode SHALL open a verse action menu. The menu SHALL include a bookmark action that toggles the bookmark for the tapped verse — adding it when absent, removing it when present. The action's label and icon SHALL reflect that verse's current bookmark state.

#### Scenario: Tapping a verse opens the action menu

- **WHEN** the user taps a verse in the reader
- **THEN** a verse action menu opens, offering a bookmark action for that verse

#### Scenario: The menu bookmarks an unsaved verse

- **WHEN** the user opens the verse action menu for an un-bookmarked ayah and activates the bookmark action
- **THEN** that ayah becomes bookmarked

#### Scenario: The menu removes an existing bookmark

- **WHEN** the user opens the verse action menu for an already-bookmarked ayah and activates the bookmark action
- **THEN** that ayah is no longer bookmarked

#### Scenario: The bookmark action reflects current state

- **WHEN** the verse action menu is opened for an ayah that is already bookmarked
- **THEN** the bookmark action presents a "remove bookmark" affordance rather than an "add" one

#### Scenario: Page mode bookmarks the tapped verse

- **WHEN** the user taps a verse while reading in page mode
- **THEN** the verse action menu's bookmark action targets that tapped verse

### Requirement: The Bookmarks page lists saved bookmarks

The Bookmarks top-level destination SHALL list saved bookmarks, most recently added first. Each row SHALL show the ayah reference, the surah display name, and the canonical Arabic ayah text supplied by `QuranRepository`; it MUST NOT invent references or display text from outside the verified Quran database. Activating a row SHALL open the existing `/reader/ayah/{surah}/{ayah}` deep link. The page SHALL show an empty state when no bookmarks exist, and SHALL allow a bookmark to be removed.

#### Scenario: List shows saved bookmarks newest first

- **WHEN** the user opens Bookmarks with `2:255` and a later-added `18:10` saved
- **THEN** both rows are shown with `18:10` first, each row carrying its reference, surah display name, and canonical ayah text

#### Scenario: Empty state

- **WHEN** the user opens Bookmarks with no bookmarks saved
- **THEN** an empty state is shown and no bookmark rows are rendered

#### Scenario: Opening a bookmark opens the reader

- **WHEN** the user activates the Bookmarks row for `2:255`
- **THEN** the app navigates to `/reader/ayah/2/255`

#### Scenario: Removing a bookmark from the page

- **WHEN** the user removes `2:255` from the Bookmarks page
- **THEN** its row disappears and `2:255` is no longer reported as bookmarked

### Requirement: Bookmarks degrade gracefully when user.db is unavailable

WHEN `user.db` cannot be opened, bookmark features SHALL degrade without blocking the app. Quran reading and audio playback SHALL remain fully functional, and the data-integrity fatal screen SHALL NOT be shown for a `user.db` failure.

#### Scenario: Bookmarks page shows a non-fatal notice

- **WHEN** `user.db` is unavailable and the user opens Bookmarks
- **THEN** a concise non-fatal notice is shown instead of a list, and the rest of the app shell stays usable

#### Scenario: Reader bookmark action is suppressed

- **WHEN** `user.db` is unavailable and the user opens the verse action menu
- **THEN** the menu does not offer a bookmark action, its other actions still work, and reading continues normally

#### Scenario: Quran reading is unaffected

- **WHEN** `user.db` is unavailable
- **THEN** surah and ayah reading and audio playback work normally and no fatal error screen is shown
