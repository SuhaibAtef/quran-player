## ADDED Requirements

### Requirement: MCP Status shows server and permission state

The MCP Status top-level destination SHALL show the local MCP server lifecycle state, local-only transport mode, exposed read-only and playback capabilities, pending playback permission requests, and recent in-session command decisions.

#### Scenario: Status page shows local server state

- **WHEN** the user opens MCP Status while the server is disabled, starting, running, stopped, or failed
- **THEN** the page displays the current lifecycle state without leaving the app shell

#### Scenario: Status page identifies local-only mode

- **WHEN** the MCP Status page renders
- **THEN** it indicates that the MCP server is local-only and does not advertise remote access

#### Scenario: Status page lists exposed capabilities

- **WHEN** the MCP server capabilities are available
- **THEN** the page shows the read-only Quran/reciter tools and playback-control tools exposed by this change

#### Scenario: Pending playback command is reviewable

- **WHEN** an MCP playback command is waiting for approval
- **THEN** MCP Status shows the requested command, Quran reference or range when applicable, and approve/deny controls

#### Scenario: Recent decision is visible for the session

- **WHEN** the user approves, denies, or a pending playback command times out
- **THEN** MCP Status shows the recent in-session decision without requiring a persistent audit log
