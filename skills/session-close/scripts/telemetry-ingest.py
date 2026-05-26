#!/usr/bin/env python3
"""telemetry-ingest.py - load hook telemetry JSONL into the SQLite analysis DB.

The hook (telemetry-hook.sh) appends raw events to /root/.claude/telemetry/*.jsonl.
This script loads new lines into telemetry.db (schema: telemetry-schema.sql) so the
operator can run cross-session cost analysis. It is idempotent: a per-file line
watermark in ingest_state means re-running only loads lines added since last run, so
nothing is double-counted and same-second duplicate events are never dropped.

Usage:
    telemetry-ingest.py                 # ingest new lines, then exit
    telemetry-ingest.py --report        # ingest, then print a summary
    telemetry-ingest.py --report-only   # just print the summary, no ingest

Paths default to $CLAUDE_TELEMETRY_DIR (or /root/.claude/telemetry). Stdlib only.
"""
import argparse
import json
import os
import sqlite3
import sys
from datetime import datetime, timezone

DEFAULT_DIR = os.environ.get("CLAUDE_TELEMETRY_DIR", "/root/.claude/telemetry")
JSONL_FILES = ["activity.jsonl", "tool-usage.jsonl"]
COLUMNS = ["ts", "session_id", "event", "tool", "skill", "cwd", "source", "model", "prompt_len"]


def ensure_schema(conn, schema_path):
    with open(schema_path, "r", encoding="utf-8") as f:
        conn.executescript(f.read())
    conn.commit()


def ingest_file(conn, path, filename):
    """Load lines beyond the stored watermark; reset if the file was rotated."""
    if not os.path.exists(path):
        return 0
    with open(path, "r", encoding="utf-8") as f:
        lines = f.readlines()
    total = len(lines)

    row = conn.execute(
        "SELECT lines_ingested FROM ingest_state WHERE filename = ?", (filename,)
    ).fetchone()
    watermark = row[0] if row else 0
    if total < watermark:  # file truncated or rotated -> re-read from the start
        watermark = 0

    inserted = 0
    for i in range(watermark, total):
        line = lines[i].strip()
        if not line:
            continue
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            rec = {"ts": "", "event": "unparsed"}
        values = [rec.get(c) for c in COLUMNS]
        if not values[COLUMNS.index("event")]:
            values[COLUMNS.index("event")] = "unknown"
        conn.execute(
            f"INSERT INTO skill_events ({', '.join(COLUMNS)}) "
            f"VALUES ({', '.join(['?'] * len(COLUMNS))})",
            values,
        )
        inserted += 1

    now = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    conn.execute(
        "INSERT INTO ingest_state (filename, lines_ingested, updated_at) VALUES (?, ?, ?) "
        "ON CONFLICT(filename) DO UPDATE SET lines_ingested = excluded.lines_ingested, "
        "updated_at = excluded.updated_at",
        (filename, total, now),
    )
    conn.commit()
    return inserted


def report(conn):
    def q(sql):
        return conn.execute(sql).fetchall()

    total_events = q("SELECT COUNT(*) FROM skill_events")[0][0]
    total_sessions = q("SELECT COUNT(DISTINCT session_id) FROM skill_events WHERE session_id IS NOT NULL")[0][0]
    total_tools = q("SELECT COUNT(*) FROM skill_events WHERE event='PostToolUse'")[0][0]

    print(f"\n== Telemetry totals ==")
    print(f"  events: {total_events}   sessions: {total_sessions}   tool calls: {total_tools}")

    print(f"\n== Recent sessions (skill_runs) ==")
    rows = q(
        "SELECT session_id, started_at, duration_secs, model, tool_calls, prompts, skill_invocations "
        "FROM skill_runs ORDER BY started_at DESC LIMIT 15"
    )
    if not rows:
        print("  (no sessions yet)")
    for sid, start, dur, model, tools, prompts, skills in rows:
        dur_str = "?" if dur is None else f"{dur // 60}m{dur % 60:02d}s"
        sid_str = (sid or "?")[:8]
        print(f"  {sid_str}  {start}  {dur_str:>7}  tools={tools or 0:<4} prompts={prompts or 0:<3} "
              f"skills={skills or 0:<3} {model or ''}")

    print(f"\n== Skill usage (skill_usage) ==")
    rows = q("SELECT skill, invocations, sessions FROM skill_usage ORDER BY invocations DESC")
    if not rows:
        print("  (no skill invocations captured yet)")
    for skill, inv, sess in rows:
        print(f"  {skill:<40} invocations={inv:<4} sessions={sess}")
    print()


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    ap = argparse.ArgumentParser(description="Ingest hook telemetry JSONL into SQLite.")
    ap.add_argument("--dir", default=DEFAULT_DIR, help="telemetry directory with the JSONL files")
    ap.add_argument("--db", default=None, help="SQLite db path (default <dir>/telemetry.db)")
    ap.add_argument("--schema", default=os.path.join(here, "telemetry-schema.sql"))
    ap.add_argument("--report", action="store_true", help="print a summary after ingest")
    ap.add_argument("--report-only", action="store_true", help="skip ingest, only print a summary")
    args = ap.parse_args()

    db_path = args.db or os.path.join(args.dir, "telemetry.db")
    os.makedirs(os.path.dirname(db_path), exist_ok=True)
    conn = sqlite3.connect(db_path)
    try:
        ensure_schema(conn, args.schema)
        if not args.report_only:
            total = 0
            for fn in JSONL_FILES:
                total += ingest_file(conn, os.path.join(args.dir, fn), fn)
            print(f"Ingested {total} new event(s) into {db_path}")
        if args.report or args.report_only:
            report(conn)
    finally:
        conn.close()


if __name__ == "__main__":
    main()
