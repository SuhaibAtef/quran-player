## ADDED Requirements

### Requirement: Localized UI-chrome strings

The app SHALL render all user-visible UI-chrome text — labels, buttons, menu items, titles, and messages — from a localized string catalogue. Complete English and Arabic catalogues SHALL be provided. Chrome text MUST NOT be hardcoded as string literals in widget code.

#### Scenario: Chrome rendered under English

- **WHEN** the app runs with the English locale active
- **THEN** every chrome label, button, and menu item displays its English catalogue value

#### Scenario: Chrome rendered under Arabic

- **WHEN** the app runs with the Arabic locale active
- **THEN** every chrome label, button, and menu item displays its Arabic catalogue value

### Requirement: Locale selection and persistence

The app SHALL let the user select the interface language as English, Arabic, or System from the Settings screen. The selection SHALL persist across app restarts. The System option SHALL resolve the interface language from the operating system locale, falling back to English when the OS locale is not a supported language.

#### Scenario: User selects Arabic

- **WHEN** the user selects Arabic in Settings
- **THEN** the interface switches to Arabic without an app restart

#### Scenario: Selection survives a restart

- **WHEN** the user has selected Arabic and then restarts the app
- **THEN** the interface opens in Arabic

#### Scenario: System option follows the OS locale

- **WHEN** the System option is active and the operating system locale is Arabic
- **THEN** the interface renders in Arabic

#### Scenario: System option falls back for an unsupported OS locale

- **WHEN** the System option is active and the operating system locale is not a language the app supports
- **THEN** the interface renders in English

#### Scenario: First run has no stored preference

- **WHEN** the app runs for the first time with no stored locale preference
- **THEN** the System option is in effect

### Requirement: Right-to-left chrome layout

When an RTL interface locale (Arabic) is active, the app SHALL lay out all UI chrome right-to-left — text direction, the placement of navigation surfaces, directional padding and alignment, and direction-encoding icons. When an LTR locale is active, chrome SHALL lay out left-to-right.

#### Scenario: Arabic locale renders chrome RTL

- **WHEN** Arabic is the active interface locale
- **THEN** UI chrome resolves to `TextDirection.rtl` and reads right-to-left

#### Scenario: Sidebar anchors to the trailing edge

- **WHEN** Arabic is the active interface locale on a wide window that shows the navigation sidebar
- **THEN** the sidebar is anchored to the right (trailing) edge of the window

#### Scenario: Bottom navigation order reverses

- **WHEN** Arabic is the active interface locale on a narrow window that shows the bottom navigation bar
- **THEN** the navigation items are ordered right-to-left

#### Scenario: Switching back to English restores LTR

- **WHEN** the active locale switches from Arabic back to English
- **THEN** chrome returns to a left-to-right layout

### Requirement: Quran content direction is independent of the UI locale

Quran text and tafsir content SHALL always render right-to-left, regardless of the active UI-chrome locale.

#### Scenario: English UI still renders Quran content RTL

- **WHEN** the UI-chrome locale is English
- **THEN** reader content — both the mushaf page view and the continuous text view — still renders as right-to-left Arabic

### Requirement: Localized display numerals

UI-chrome numbers SHALL render using the active locale's digit set, displaying Eastern Arabic digits under an Arabic locale. Stable identifiers — ayah keys, route parameters, persisted storage keys, and MCP arguments — SHALL always use ASCII digits regardless of locale.

#### Scenario: Surah number localized under Arabic

- **WHEN** a surah number is shown in a chrome list while the Arabic locale is active
- **THEN** the number displays using Eastern Arabic digits

#### Scenario: Surah number uses ASCII digits under English

- **WHEN** the same surah number is shown while the English locale is active
- **THEN** the number displays using ASCII digits

#### Scenario: Route parameters stay ASCII

- **WHEN** a verse deep-link route is generated for an ayah while the Arabic locale is active
- **THEN** the route parameters use ASCII digits
