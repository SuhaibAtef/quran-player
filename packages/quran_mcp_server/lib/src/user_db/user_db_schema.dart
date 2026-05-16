/// SQL DDL for the user-writable `user.db`.
///
/// The schema is versioned via the `schema_meta` table. Schema v1 carries the
/// `audit_log` table only; future user-writable surfaces (bookmarks, playback
/// history) will bump the version with explicit migration steps.
library;

const userDbSchemaVersion = 1;

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
