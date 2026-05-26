-- telemetry-schema.sql - SQLite analysis layer over the hook telemetry JSONL.
--
-- The hook (telemetry-hook.sh) appends raw events to /root/.claude/telemetry/*.jsonl.
-- telemetry-ingest.py loads those lines into this database so the operator can run
-- cross-session cost analysis (which the session-close skill's per-session read path
-- cannot do on its own). SQLite is used on purpose: no service, no port, no shared-DB
-- migration, just a single file at /root/.claude/telemetry/telemetry.db.
--
-- skill_events is the raw table; skill_runs and skill_usage are derived views, so
-- they stay correct automatically as new events are ingested (no rollup to maintain).

-- One row per raw hook event (a SQL mirror of the JSONL append log).
CREATE TABLE IF NOT EXISTS skill_events (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  ts         TEXT NOT NULL,   -- ISO8601 UTC, e.g. 2026-05-26T19:16:20Z
  session_id TEXT,
  event      TEXT NOT NULL,   -- PostToolUse | SessionStart | Stop | UserPromptSubmit | SessionEnd | unparsed
  tool       TEXT,            -- tool name (PostToolUse only)
  skill      TEXT,            -- skill slug when tool='Skill'
  cwd        TEXT,
  source     TEXT,            -- SessionStart source: startup|resume|clear|compact
  model      TEXT,
  prompt_len INTEGER          -- length of the user prompt (UserPromptSubmit), never the text
);

CREATE INDEX IF NOT EXISTS idx_events_session ON skill_events(session_id);
CREATE INDEX IF NOT EXISTS idx_events_event   ON skill_events(event);
CREATE INDEX IF NOT EXISTS idx_events_skill   ON skill_events(skill);

-- Ingestion watermark: how many lines of each JSONL file have already been loaded.
-- The ingester skips that many lines on the next run, so re-running is safe and
-- same-second duplicate events are never lost or double-counted.
CREATE TABLE IF NOT EXISTS ingest_state (
  filename       TEXT PRIMARY KEY,
  lines_ingested INTEGER NOT NULL DEFAULT 0,
  updated_at     TEXT
);

-- Per-session rollup. One row per Claude session.
CREATE VIEW IF NOT EXISTS skill_runs AS
SELECT
  session_id,
  MIN(ts)                                                              AS started_at,
  MAX(ts)                                                              AS last_event_at,
  CAST((julianday(MAX(ts)) - julianday(MIN(ts))) * 86400 AS INTEGER)   AS duration_secs,
  MAX(model)                                                           AS model,
  SUM(event = 'PostToolUse')                                           AS tool_calls,
  SUM(event = 'UserPromptSubmit')                                      AS prompts,
  SUM(tool = 'Skill')                                                  AS skill_invocations
FROM skill_events
WHERE session_id IS NOT NULL
GROUP BY session_id;

-- Per-skill usage. One row per distinct skill slug (the "which skills cost what" view).
CREATE VIEW IF NOT EXISTS skill_usage AS
SELECT
  skill,
  COUNT(*)                    AS invocations,
  COUNT(DISTINCT session_id)  AS sessions,
  MIN(ts)                     AS first_seen,
  MAX(ts)                     AS last_seen
FROM skill_events
WHERE tool = 'Skill' AND skill IS NOT NULL
GROUP BY skill;
