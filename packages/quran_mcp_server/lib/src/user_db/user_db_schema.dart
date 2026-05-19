/// SQL DDL for the user-writable `user.db`.
///
/// The schema is versioned via the `schema_meta` table. Schema v1 carries the
/// `audit_log` table; schema v2 adds the `bookmark` and single-row
/// `reading_position` tables. Future user-writable surfaces bump the version
/// with their own additive statement list and an explicit migration step.
library;

const userDbSchemaVersion = 2;

const userDbSchemaV1Statements = <String>[
  '''
  CREATE TABLE IF NOT EXISTS schema_meta (
    key TEXT PRIMARY KEY,
    value TEXT NOT NULL
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS audit_log (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    ts_utc          INTEGER NOT NULL,
    tool_name       TEXT NOT NULL,
    args_summary    TEXT NOT NULL,
    result_status   TEXT NOT NULL CHECK(result_status IN
      ('ok','scope_denied','invalid_input','not_found','unavailable','error')),
    scope_at_time   TEXT NOT NULL
  )
  ''',
  '''
  CREATE INDEX IF NOT EXISTS idx_audit_log_ts ON audit_log(ts_utc)
  ''',
];

/// Schema v2 — bookmarks and the last-read reading position.
///
/// `bookmark.UNIQUE(surah, ayah)` keeps an ayah bookmarked at most once.
/// `reading_position` is a single-row table (`CHECK(id = 1)`); callers upsert
/// row 1. All statements are `IF NOT EXISTS`, so applying v1 + v2 on every
/// open is idempotent for a fresh DB and an existing v1 DB alike.
const userDbSchemaV2Statements = <String>[
  '''
  CREATE TABLE IF NOT EXISTS bookmark (
    id              INTEGER PRIMARY KEY AUTOINCREMENT,
    surah           INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
    ayah            INTEGER NOT NULL CHECK(ayah >= 1),
    created_at_utc  INTEGER NOT NULL,
    UNIQUE(surah, ayah)
  )
  ''',
  '''
  CREATE TABLE IF NOT EXISTS reading_position (
    id              INTEGER PRIMARY KEY CHECK(id = 1),
    surah           INTEGER NOT NULL CHECK(surah BETWEEN 1 AND 114),
    ayah            INTEGER NOT NULL CHECK(ayah >= 1),
    updated_at_utc  INTEGER NOT NULL
  )
  ''',
];
