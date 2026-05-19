# reading-position Specification

## Purpose
Automatic last-read position: the reader records the user's reading position as they read, persisting it in the user-writable `user.db`, and the Home page surfaces a "Continue reading" entry point that reopens it through the existing reader deep link.

## Requirements
### Requirement: The app records the last-read position

The system SHALL record the user's last-read ayah position in `user.db`, keeping it current as the user reads. Exactly one reading position SHALL be retained — the most recent. The position SHALL be recorded in both page mode and text mode.

#### Scenario: Leaving the reader records the position

- **WHEN** the user reads in the reader and then navigates away
- **THEN** the reading position is updated to reflect where they were reading

#### Scenario: Page mode records the page's position

- **WHEN** the user reads page `N` in page mode
- **THEN** the recorded reading position is the first ayah of page `N`

#### Scenario: Text mode records the viewed position

- **WHEN** the user reads in text mode
- **THEN** the recorded reading position reflects the ayah they were viewing

#### Scenario: Only the most recent position is kept

- **WHEN** the user reads two different places in succession
- **THEN** only the most recent reading position is retained

### Requirement: The Home page surfaces a resume entry point

WHEN a reading position has been recorded, the Home page SHALL show a "Continue reading" entry point identifying the surah and ayah. Activating it SHALL open the existing `/reader/ayah/{surah}/{ayah}` deep link. WHEN no reading position has been recorded, the entry point SHALL be absent. No new route or top-level destination SHALL be added.

#### Scenario: Resume entry point appears when a position exists

- **WHEN** a reading position for `18:10` exists and the user opens Home
- **THEN** a "Continue reading" entry point identifying that surah and ayah is shown above the surah list

#### Scenario: Activating resume opens the reader

- **WHEN** the user activates the "Continue reading" entry point for `18:10`
- **THEN** the app navigates to `/reader/ayah/18/10`

#### Scenario: No entry point without a recorded position

- **WHEN** no reading position has been recorded and the user opens Home
- **THEN** no "Continue reading" entry point is shown and the surah list renders normally

#### Scenario: No new destination is added

- **WHEN** this change ships
- **THEN** the app shell has the same top-level destinations and no separate resume route is added

### Requirement: Reading position degrades gracefully when user.db is unavailable

WHEN `user.db` cannot be opened, reading-position features SHALL degrade without blocking the app. No position SHALL be recorded or surfaced, and no error SHALL be shown for the missing resume entry point.

#### Scenario: No resume entry point on failure

- **WHEN** `user.db` is unavailable and the user opens Home
- **THEN** no "Continue reading" entry point is shown and the surah list renders normally

#### Scenario: Recording is a safe no-op on failure

- **WHEN** `user.db` is unavailable and the user leaves the reader
- **THEN** no crash occurs and reading continues normally
