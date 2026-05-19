## Context

The foundation provides everything bookmarks needs except the persistence and the surfaces:

- `AyahKey` (`lib/domain/quran/ayah_key.dart`) is the canonical, validated ayah coordinate — every bookmark and the resume position are one of these.
- `user.db` already exists at `getApplicationSupportDirectory()/quran/user.db`, opened by `openUserDb` in `packages/quran_mcp_server/lib/src/user_db/`. Schema v1 carries only `audit_log`; `schema_meta` and `userDbSchemaVersion` were put there explicitly so bookmarks could be the first schema bump. `user.db` is the project's one **fail-soft** SQLite file — an open failure surfaces a non-fatal notice, not the data-integrity fatal screen.
- The reader (`lib/features/reader/`) exposes both render modes through one screen: page mode reports page changes via `onPageChanged`; text mode renders per-ayah rows keyed by `AyahKey` with an existing per-ayah play button. `MushafLocator` maps pages ↔ ayahs framework-free.
- The Bookmarks top-level destination and route (`/bookmarks`) already exist; `bookmarks_page.dart` is a placeholder. The Home page is the Surahs list.

Two new capabilities are layered onto this: `bookmarks` (intentional saves) and `reading-position` (automatic resume). They are distinct — one is user-initiated, one is ambient — but share the same storage file and the same `AyahKey` currency.

## Goals / Non-Goals

**Goals:**

- Persist individual ayah bookmarks and a single last-read position across sessions.
- Add/remove bookmarks from inside the reader, in both modes, with the affordance reflecting current state.
- Reopen the last-read position from the Home page.
- Close the IDEA.md MVP with a surgical change — no refactors beyond what bookmarks requires.
- Keep the `user.db` fail-soft contract intact.

**Non-Goals:**

- MCP bookmark tools — deferred to their own change.
- Bookmark labels, notes, folders, or ordering beyond recency.
- Page-as-a-page bookmarks, ayah ranges, or multi-position history.
- Extracting the `user_db` module out of the MCP package (discussed under Risks).
- Coupling resume to audio playback — resume tracks *visual* reading position only.

## Decisions

### A bookmark is a single `AyahKey`

Every bookmark stores `(surah, ayah)`. In page mode, "bookmark this page" resolves to `MushafLocator.firstAyahOnPage(currentPage)` — a page is not an ayah, but its first ayah is a stable, MCP-readable coordinate. One model keeps the domain contract, the v2 table, and a future MCP bookmark tool simple.

*Alternative rejected:* a page-bookmark kind alongside an ayah-bookmark kind — two shapes, a polymorphic table, and a more complex contract for a distinction users rarely care about.

### `user.db` schema v2 — two new tables

```sql
CREATE TABLE IF NOT EXISTS bookmark (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  surah           INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
  ayah            INTEGER NOT NULL CHECK(ayah >= 1),
  created_at_utc  INTEGER NOT NULL,
  UNIQUE(surah, ayah)
);

CREATE TABLE IF NOT EXISTS reading_position (
  id              INTEGER PRIMARY KEY CHECK(id = 1),
  surah           INTEGER NOT NULL,
  ayah            INTEGER NOT NULL,
  updated_at_utc  INTEGER NOT NULL
);
```

`bookmark` has `UNIQUE(surah, ayah)` so an ayah is bookmarked at most once — the reader toggle is genuinely a toggle. `reading_position` is a single-row table (`CHECK(id = 1)`); saving is an upsert on `id = 1`.

**Migration.** `userDbSchemaVersion` bumps to `2`; a `userDbSchemaV2Statements` list holds the two `CREATE TABLE IF NOT EXISTS` statements. `_ensureSchema` runs v1 then v2 statements in one transaction — every statement is `IF NOT EXISTS`, so applying both unconditionally is idempotent for a fresh DB and for an existing v1 DB alike. After applying, `_ensureSchema` updates the `schema_meta` `version` row to `'2'`. No sqflite `onUpgrade` callback is introduced — the manual idempotent approach matches the existing code and is the lowest-risk path for a file that must never fail closed.

*Alternative rejected:* sqflite `onCreate`/`onUpgrade` callbacks — would mean rewriting the working v1 open path and splitting schema knowledge between DDL constants and callback bodies.

### The MCP package keeps owning the `user.db` format

The v2 DDL lives in `packages/quran_mcp_server/lib/src/user_db/user_db_schema.dart` because `openUserDb` — the single place migrations run — is there. The package gains DDL for tables it never queries. This is a known smell: `user.db` is now a general app database, not an MCP artifact, and the `user_db` module arguably belongs in shared host code or its own package.

We accept it for this change. Extracting `user_db` touches the MCP package's `isolation_test`, its public exports, and `user_db_provider.dart` wiring — scope well beyond "close the MVP." The DDL strings are pure Dart and do not violate the package's Flutter-free boundary. The extraction is noted as future cleanup.

### Repositories: contracts in `domain/`, SQLite impls in host `data/`

- `lib/domain/bookmarks/` — `Bookmark` (id, `AyahKey`, `createdAt`) and `abstract BookmarkRepository` (`list`, `add`, `remove`, `isBookmarked`), returning `Result<T>`.
- `lib/domain/reading/` — `ReadingPosition` (`AyahKey`, `updatedAt`) and `abstract ReadingPositionRepository` (`load`, `save`).
- `lib/data/bookmarks/` and `lib/data/reading/` — SQLite implementations taking the opened `Database`.

The impls live in the host, not the MCP package: bookmarks have no MCP consumer yet, and the host already depends on `sqflite`. `AuditLogRepository` lives in the package only because the MCP audit feature uses it — that is not a precedent to follow here. When MCP bookmark tools land, that change decides whether a port belongs in the package.

`userDbStateProvider` constructs all three repositories from the one opened `Database` and exposes them on `UserDbState`. New `bookmarkRepositoryProvider` / `readingPositionRepositoryProvider` mirror `auditLogRepositoryProvider` — they return `null` when `user.db` failed to open, and callers degrade.

### `user.db` opens at app start, independent of MCP

Today `userDbStateProvider` is watched only by MCP code, so `user.db` is effectively created "on first MCP-enabled startup." Bookmarks and resume need it regardless of MCP, so the app shell watches `userDbStateProvider` at start. The 7-day audit-log prune (already inside that provider) therefore also runs every start — harmless and arguably more correct. `AGENTS.md` is updated to drop the "MCP-enabled" qualifier.

<!-- Recording mechanics are described under "Reading position is recorded as
the user reads, never in dispose()" below. -->

### Reader bookmark affordance — a verse action menu

Tapping a verse in either mode opens one shared **verse action menu** (a modal sheet) with three actions: *Play from here*, *Bookmark* / *Remove bookmark*, and a disabled *Highlight* placeholder for a later change. The bookmark action toggles the tapped verse and its label/icon reflect current state.

- **Text mode** — the whole ayah row is the tap target; the menu targets that row's ayah. This replaces the former per-row play button (its action moves into the menu as *Play from here*).
- **Page mode** — the `MushafView` already emits `onAyahTap(AyahKey)`; that opens the menu for the tapped verse. No header toggle.

One menu for both modes keeps the interaction identical and consistent, and works in page mode where there is no per-verse widget to anchor a popover to. When `user.db` is unavailable the menu simply omits the bookmark action — the other actions still work. Search-result and ayah-display bookmark affordances remain out of scope.

### Reading position is recorded as the user reads, never in `dispose()`

`flutter_riverpod`'s `WidgetRef` cannot be used during `State.dispose()`, so the position is recorded from live callbacks instead:

- **Page mode** — `ReaderScreen`'s `onPageChanged` handler records `firstAyahOnPage(page)`. `PageMushafView` fires that callback once for the initial page too, so it covers open + every page turn.
- **Text mode** — `TextReaderView` records on `ScrollEndNotification` (the topmost visible ayah) and once from a post-first-frame callback (the open anchor, or the surah's first ayah).

`ReadingPositionController.record` updates in-memory state synchronously and persists in the background — a write per page turn / scroll settle is a single cheap SQLite upsert.

### Resume entry point — a "Continue reading" card on Home

When a `reading_position` row exists, the Home page renders a card above the surah list showing the surah name + ayah, navigating via the existing `/reader/ayah/{surah}/{ayah}` deep link so the active reader mode resolves centrally. No recorded position → no card. No new route or top-level destination.

## Risks / Trade-offs

- **`user.db` unavailable (fail-soft)** → bookmarks and resume must degrade, not crash. Mitigation: the new providers return `null` on failure; the reader hides/disables the bookmark affordance, the Bookmarks page shows a non-fatal notice, the "Continue reading" card is absent. Quran reading and audio are untouched. Covered by spec scenarios and tests.
- **Migration on an existing v1 `user.db`** → a wrong migration could lose audit rows or fail to open. Mitigation: v2 only *adds* tables with `IF NOT EXISTS`, never alters `audit_log`; a migration test opens a seeded v1 DB and asserts `audit_log` survives and the new tables exist with `version = '2'`.
- **Text-mode topmost-visible detection is approximate** → resume may land a verse or two off after fast scrolling. Mitigation: deterministic fallback chain (anchor → surah first ayah); a small offset is acceptable for a resume hint, and bookmarks cover precise return.
- **MCP package owns DDL it doesn't use** → conceptual coupling. Mitigation: documented as future cleanup; pure-Dart DDL keeps the Flutter-free boundary intact; no functional risk.
- **Force-quit between a scroll settle and the next** → resume slightly stale. Accepted; each page turn and scroll-settle records, so the window is small.

## Migration Plan

1. Ship schema v2 — additive only; an existing v1 `user.db` upgrades in place on first open with no data loss.
2. No rollback step needed: a downgrade would simply ignore the new tables; `audit_log` is untouched either way.
3. No data backfill — `reading_position` is empty until the user first reads; `bookmark` is empty until the first save.

## Open Questions

- None blocking. The `user_db` module extraction is deferred, not open — it is explicitly out of scope for this change.
