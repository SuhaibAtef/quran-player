## Why

Bookmarks is the only unchecked MVP feature in [IDEA.md](../../../IDEA.md) — every other MVP feature ships today. Readers also have no way to return to where they left off between sessions. Adding intentional ayah bookmarks and an automatic last-read position closes the MVP and makes the reader feel like a place you return to rather than re-navigate.

## What Changes

- **Bookmarks** — users save and remove individual ayahs. The existing placeholder Bookmarks page renders the saved list; activating a row opens the existing `/reader/ayah/{surah}/{ayah}` deep link so reader-mode routing stays centralized.
- **Reader bookmark affordance** — a per-ayah bookmark toggle in text mode (mirroring the existing per-ayah play button) and a header toggle for the current page in page mode. Each reflects whether the target ayah is already bookmarked.
- **Reading position** — the app records the user's last-read ayah automatically as they read, in either mode. The Home page surfaces a "Continue reading" entry point that reopens that position; with no recorded position the entry point is absent.
- **`user.db` schema v1 → v2** — adds a `bookmark` table and a single-row `reading_position` table. This is the first real migration through the existing `schema_meta` machinery (which `user_db_schema.dart` was always designed to grow into).
- **`user.db` opens on every app start**, not only when MCP is enabled — bookmarks and resume are core features independent of MCP. The existing fail-soft behaviour is preserved: if `user.db` is unavailable, Quran reading and audio playback continue unaffected, and the bookmark/resume surfaces degrade to a non-fatal notice or are simply absent.
- MCP bookmark tools remain **out of scope** — deferred to their own change. The `BookmarkRepository` contract is shaped so a future MCP change can read through it the way the MCP host adapters read through `QuranRepository`.

## Capabilities

### New Capabilities

- `bookmarks`: saving, listing, and removing individual ayah bookmarks; the reader bookmark affordance; the Bookmarks page.
- `reading-position`: automatic last-read position tracking and the "Continue reading" resume entry point.

### Modified Capabilities

- none — no existing spec's requirements change. The reader and Home page gain new surfaces, but those are new requirements owned by the two new capabilities.

## Impact

- **`user.db` schema** — `packages/quran_mcp_server/lib/src/user_db/user_db_schema.dart` and `user_db.dart`: v2 DDL plus an idempotent migration step.
- **Domain** — new framework-free contracts under `lib/domain/bookmarks/` and `lib/domain/reading/` (reusing `AyahKey`, `Result`/`Failure`).
- **Data** — new SQLite-backed implementations under `lib/data/bookmarks/` and `lib/data/reading/`, operating on the opened `user.db` `Database`.
- **App state** — `lib/app/state/user_db_provider.dart`: `userDbStateProvider` opens at app start and exposes the two new repositories alongside `AuditLogRepository`; new Riverpod providers for bookmark list and reading position.
- **UI** — `lib/features/bookmarks/bookmarks_page.dart` (placeholder → real list), `lib/features/reader/` (bookmark affordance + position recording), `lib/features/home/home_page.dart` ("Continue reading" card).
- **Docs** — `AGENTS.md` user.db description (always-open, schema v2, bookmarks/resume tables).
- **Tests** — new coverage under `test/` (and the migration under the workspace package's test suite).
- No new dependencies. No MCP, audio, or Quran-data behaviour changes.
