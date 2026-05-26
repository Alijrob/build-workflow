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
`/root/.claude/telemetry/` (tool name and prompt length only, never tool input or prompt
text). The install block is documented at the bottom of that script. Until the hook is
wired on a box, the close-out reports tool/time telemetry as "not captured".

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
