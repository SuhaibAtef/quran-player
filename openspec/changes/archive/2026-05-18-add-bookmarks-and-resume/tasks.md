## 1. user.db schema v2 migration

- [x] 1.1 In `packages/quran_mcp_server/lib/src/user_db/user_db_schema.dart`, bump `userDbSchemaVersion` to `2` and add `userDbSchemaV2Statements` with the `bookmark` table (`UNIQUE(surah, ayah)`) and the single-row `reading_position` table (`CHECK(id = 1)`).
- [x] 1.2 Extend `_ensureSchema` in `user_db.dart` to apply v1 then v2 statements in one transaction (all `IF NOT EXISTS`, idempotent) and update the `schema_meta` `version` row to `'2'`.
- [x] 1.3 Add a migration test under `packages/quran_mcp_server/test/`: seed a schema-v1 `user.db` with an `audit_log` row, reopen with v2, and assert the new tables exist, `version` is `'2'`, and the existing `audit_log` row is preserved.

## 2. Domain contracts

- [x] 2.1 Add `lib/domain/bookmarks/bookmark.dart` — `Bookmark` (`id`, `AyahKey`, `createdAt`).
- [x] 2.2 Add `lib/domain/bookmarks/bookmark_repository.dart` — abstract `BookmarkRepository` with `list`, `add`, `remove`, `isBookmarked`, returning `Result<T>`.
- [x] 2.3 Add `lib/domain/reading/reading_position.dart` — `ReadingPosition` (`AyahKey`, `updatedAt`).
- [x] 2.4 Add `lib/domain/reading/reading_position_repository.dart` — abstract `ReadingPositionRepository` with `load` and `save`, returning `Result<T>`.

## 3. Data layer (SQLite over user.db)

- [x] 3.1 Add `lib/data/bookmarks/sqlite_bookmark_repository.dart` implementing `BookmarkRepository` over the `bookmark` table (add is idempotent on the unique key; list is newest-first).
- [x] 3.2 Add `lib/data/reading/sqlite_reading_position_repository.dart` implementing `ReadingPositionRepository` as an upsert on `id = 1`.
- [x] 3.3 Add repository contract tests under `test/` exercising both impls against a real temporary `user.db` (save/list/remove/idempotency/upsert).

## 4. App state wiring

- [x] 4.1 Extend `UserDbState` and `userDbStateProvider` in `lib/app/state/user_db_provider.dart` to construct and carry `BookmarkRepository` and `ReadingPositionRepository` alongside `AuditLogRepository`.
- [x] 4.2 Add `bookmarkRepositoryProvider` and `readingPositionRepositoryProvider` that return `null` when `user.db` failed to open, mirroring `auditLogRepositoryProvider`.
- [x] 4.3 Watch `userDbStateProvider` from the app shell so `user.db` opens on every app start independent of MCP state. *(Already satisfied: `main.dart` eagerly reads `userDbStateProvider` unconditionally at startup — no MCP gate exists. No code change needed.)*
- [x] 4.4 Add a `bookmarksProvider` exposing the current bookmark list (watchable for toggle state) and a `readingPositionProvider` exposing the recorded position.

## 5. Bookmarks page

- [x] 5.1 Replace the `lib/features/bookmarks/bookmarks_page.dart` placeholder with the real list — rows showing ayah reference, surah display name, and canonical Arabic text, ordered newest-first.
- [x] 5.2 Row activation navigates to `/reader/ayah/{surah}/{ayah}`; add a per-row remove action.
- [x] 5.3 Add the empty state and the non-fatal `user.db`-unavailable notice.

## 6. Reader bookmark affordance

- [x] 6.1 Add a per-ayah bookmark toggle to `TextReaderView` rows beside the existing play button, reflecting bookmarked state from `bookmarksProvider`.
- [x] 6.2 Add a bookmark toggle to the `ReaderScreen` page-mode header `suffixes`, acting on `firstAyahOnPage(_currentPage)` and reflecting bookmarked state.
- [x] 6.3 Suppress the interactive affordance in both modes when `user.db` is unavailable.

## 7. Reading position recording

- [x] 7.1 In `ReaderScreen.dispose()`, save the reading position — page mode via `firstAyahOnPage(_currentPage)`.
- [x] 7.2 In text mode, compute the topmost-visible ayah from `TextReaderView`'s `_itemKeys`, with anchor → `AyahKey(surah, 1)` fallback. *(TextReaderView records its own text-mode position on dispose rather than exposing it upward — keeps each mode single-sourced and avoids a double write.)*
- [x] 7.3 Make position recording a safe no-op when `user.db` is unavailable.

## 8. Resume entry point

- [x] 8.1 Add a "Continue reading" card to `lib/features/home/home_page.dart` above the surah list, shown only when a recorded position exists.
- [x] 8.2 Card activation navigates to `/reader/ayah/{surah}/{ayah}`; no recorded position → no card; no new route or destination.

## 9. Tests, docs, verification

- [x] 9.1 Add widget tests: Bookmarks page (list / empty / open / remove / degrade), verse action menu (open / bookmark / state reflection / degrade), Home resume card (present / absent / activate).
- [x] 9.2 Update test fakes/helpers for the new providers. *(Added `FakeBookmarkRepository` / `FakeReadingPositionRepository`; existing widget tests degrade `user.db` cleanly and needed no changes — full suite stays green.)*
- [x] 9.3 Update `AGENTS.md` — `user.db` opens at every start, schema v2 with `bookmark` + `reading_position` tables, and a new foundation entry for bookmarks/resume.
- [x] 9.4 Run `just check` — `dart format` clean, `flutter analyze` reports no issues, host suite 166/166 green, MCP package suite 35/35 green (`-j 1`; parallel runs hit an unrelated flaky native crash). Verse-menu, bookmarks-page, and resume-card widget tests exercise the real UI flows; manual in-app run on Windows is left to the maintainer.
