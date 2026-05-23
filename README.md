# build-workflow

Reusable project build workflow for any software, automation, install, or build
project. Use these three pieces together to set up, run, and close out any build
session cleanly.

---

## The three pieces

### 1. Setup instructions — do this once per project

Read `01-setup-instructions.md` before starting any new project. Covers repo
creation, folder structure, tracker setup, onboarding docs, install scripts,
and phase planning rules.

### 2. Project setup prompt — paste at the start of a new project

`02-project-setup-prompt.md` — Fill in the project variables at the bottom and
paste into Claude Code. It will inspect the repo, recommend a structure, break
the project into trackable phases, and create onboarding and install docs.

### 3. Session closeout prompt — paste at the end of every build session

`03-session-closeout-prompt.md` — Fill in the project variables at the top and
paste into Claude Code. It will audit the session, update the tracker, commit
only session files, push, write a session log, and produce a resume prompt for
the next session.

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
