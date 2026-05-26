# build-workflow

Reusable project build workflow for any software, automation, install, or build
project. Use these three pieces together to set up, run, and close out any build
session cleanly.

---

## The three pieces

### 1. Setup instructions - do this once per project

Read `01-setup-instructions.md` before starting any new project. Covers repo
creation, folder structure, tracker setup, onboarding docs, install scripts,
and phase planning rules.

### 2. Project setup prompt - paste at the start of a new project

`02-project-setup-prompt.md` - Fill in the project variables at the bottom and
paste into Claude Code. It will inspect the repo, recommend a structure, break
the project into trackable phases, and create onboarding and install docs.

### 3. Session closeout prompt - paste at the end of every build session

`03-session-closeout-prompt.md` - Fill in the project variables at the top and
paste into Claude Code. It will audit the session, update the tracker, commit
only session files, push, write a session log, and produce a resume prompt for
the next session.

---

## Runnable skills

Pieces 2 and 3 also exist as Claude Code skills under `skills/`, so you can invoke
them instead of pasting the prompts:

- `skills/project-setup/` - runnable version of `02-project-setup-prompt.md`.
  Gates onto Opus, plans phases, scaffolds the Option C docs and tracker.
- `skills/session-close/` - runnable version of `03-session-closeout-prompt.md`.
  Gates onto Opus, delegates verbose work to Haiku subagents, and runs deterministic
  git via `skills/session-close/scripts/session-close.sh` (a zero-token plumbing
  script that stages only named files, scans for secrets, coordinates with the
  git-sync cron via flock, handles new branches and a moved remote, and proves the
  push landed). Captures cost telemetry (tool/service/API usage, time-in-function).

The cost telemetry is fed by `skills/session-close/scripts/telemetry-hook.sh`, a Claude
Code hook wired into `~/.claude/settings.json` (PostToolUse, SessionStart, UserPromptSubmit,
Stop, SessionEnd). It appends one JSONL line per tool call and per session boundary to
`/root/.claude/telemetry/` (tool name, skill slug, and prompt length only, never tool
input, skill args, or prompt text). The install block is documented at the bottom of that
script. Until the hook is wired on a box, the close-out reports tool/time telemetry as
"not captured".

For cross-session cost analysis, `telemetry-ingest.py` loads the JSONL into a SQLite db
(`telemetry-schema.sql`, stored at `/root/.claude/telemetry/telemetry.db`). It is idempotent
via a per-file line watermark, so re-running only loads new lines. The schema gives a raw
`skill_events` table plus two views: `skill_runs` (per-session rollup: duration, tool calls,
prompts, skill invocations) and `skill_usage` (per-skill invocation counts, the "which skills
cost what" view). Run it on demand:

```
python3 skills/session-close/scripts/telemetry-ingest.py --report
```

A cron could keep the db current, but that is left to the operator to install (it touches
no shared infra; SQLite is a single local file, no service or port).

Install by copying a skill folder into `.claude/skills/` (or `/root/.claude/skills/`
on the servers), then add the hook block from `telemetry-hook.sh` to `~/.claude/settings.json`.

---

## Hybrid structure (Option C)

All projects follow this pattern:

- Master phase tracker lives in `pagios-ops/trackers/[project]-phase-tracker.md`
- Each project repo gets a lightweight `docs/` layer:

```
docs/setup/onboarding.md    what it does, install, deploy, env vars, important files
docs/session-logs/          one .md per build session
docs/reference/             architecture notes, decision records, reference material
```

---

## Global rules (apply to every project)

- GitHub is the source of truth
- No phase exceeds 40% of the available context window
- Never use `git add .` without inspecting all dirty files first
- Never use `--force`, `--no-verify`, or `reset --hard` without explicit approval
- Never claim success without verification
- Every final reply must include: Verified / Blocked / Unverified / Commit / Push / Tests
