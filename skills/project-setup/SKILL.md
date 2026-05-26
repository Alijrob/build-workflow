---
name: project-setup
description: Front-bookend planning skill for kicking off a new build. Breaks a project into controlled, trackable install/build phases (each small enough for a fresh session to complete without losing context), recommends a repo strategy, and scaffolds the Option C documentation structure - a phase tracker in pagios-ops/trackers/, docs/setup/onboarding.md, docs/session-logs/, docs/reference/ with per-phase start briefs, and idempotent install scaffolding. It plans and scaffolds only; it does NOT build the application unless explicitly told to continue. Pairs with the session-close skill (the back bookend). Run at the start of any new project. Trigger on "set up this project", "plan the phases", "project setup", "/project-setup", "break this into phases", "kick off a new build", "resume the [project] build" (when no tracker exists yet).
---

# Project Setup and Phase Planning

Sets a project up so it can be built in controlled, trackable phases across many sessions without losing context. This is the front bookend of the build workflow; the `session-close` skill is the back bookend and writes into the structure this skill creates.

## Operating principles

- **Verification-first, not confidence-first.** Prove repo, file, commit, and push state with commands before claiming success. Anything you cannot prove is labeled `unverified`, `inferred`, or `blocked`.
- **Adversarial verification** applies to every repo, phase, install, commit, push, and the final report unless explicitly overridden.
- **GitHub is the source of truth.** All code, trackers, setup docs, install instructions, and session logs live in the repo.
- **Never use em dashes** in any output, doc, or commit message.
- Do not overwrite existing project files without explaining the change. If setup files already exist, update them instead of duplicating.
- Do not claim files were created, edited, committed, pushed, or tested unless the operation actually ran.
- **Do not start building the application** unless explicitly told to continue into the build. The deliverable is the plan plus scaffolding.

---

## STEP 0 - Model gate (the first thing that happens)

Planning quality is the whole point of this skill, so it runs on Opus. The operator typically works on Sonnet.

1. Determine your current model from your own system context.
2. **If you are not an Opus model:** output exactly this and STOP.

   ```
   Switch to Opus before planning. Phase planning runs on the best model. Type:  /model opus
   Then run /project-setup again.
   ```

3. **If you are on Opus:** proceed.

---

## STEP 1 - Inspect before assuming

- Inspect the current folder. Do not assume the project structure.
- Decide whether this should be a **new GitHub repo**, an **existing repo**, or a **subfolder inside an existing repo**.
- **If a repo already exists**, run `git status --porcelain` and `git log --oneline -5` before anything else.
- Read `/root/CLAUDE.md` for the server table, GitHub conventions, and any existing tracker for this project.

> For a large existing repo, you may delegate the tree/history inspection to a Haiku subagent (`subagent_type: general-purpose`, `model: haiku`) so its verbose output stays out of this context. Brief it to return only: top-level layout, entry points, existing docs/tracker, and current branch. For a fresh/empty project, inspect directly.

---

## STEP 2 - Recommend the repo strategy

Output a recommendation: new repo / existing repo / subfolder, the recommended repo name (owner is `Alijrob`), and the reasoning. Do not create or rename a repo without the operator confirming the recommendation.

---

## STEP 3 - Break the project into phases

Break the work into phases. **No phase may exceed 40% of the context window** - each must be small enough that a fresh session can understand the task, inspect the relevant files, do the work, update docs, and hand off cleanly. For each phase, capture the fields in `references/phase-brief-template.md`:

phase number and name, objective, scope, files likely created/edited, commands likely run, install/deployment impact, testing requirements, documentation requirements, done criteria, estimated context size (small/medium/large), and a warning if the phase might exceed 40% of the window.

If any phase looks larger than 40%, split it and say so.

---

## STEP 4 - Scaffold the Option C structure

Create (or update, never duplicate) this structure. GitHub is the source of truth, so everything lives in the repo.

**In the project repo:**
```
docs/setup/onboarding.md      from references/onboarding-template.md (Rule 5 fields)
docs/session-logs/            directory the session-close skill writes into (add a .gitkeep)
docs/reference/               long-lived reference material
docs/reference/phase-briefs/  one brief per phase, from references/phase-brief-template.md
```

**In pagios-ops:**
```
pagios-ops/trackers/[project]-phase-tracker.md
```
Build the tracker by following the existing format in `/root/pagios-ops/trackers/_phase-tracker-template.md` (status-emoji Phase Summary table, per-phase checklists, Decisions Log, and a "resume the [project] build" section). Reuse that format; do not invent a new one. The tracker stays lean (status + checklists); the detailed per-phase content lives in the phase briefs.

**Onboarding** (`docs/setup/onboarding.md`) must cover: what the project does, where the code lives, how to install, how to run, how to deploy, required env vars, important files, current phase, known blockers, next likely step.

---

## STEP 5 - Install scaffolding (only if it deploys to a server)

If the project installs onto a server, create install documentation or an `install.sh`. Any install process must be **idempotent** where practical (safe to re-run). Note which server (THOTH / ZEUS / Hostinger), port, PM2 name or systemd unit, and the ZEUS dual-deploy rule if it applies. Do not run the install; just scaffold it.

---

## STEP 6 - Commit the scaffolding (source of truth)

The tracker and docs only become source of truth once pushed. Commit them with the shared plumbing from the session-close skill (it stages only named files, scans for secrets, and pushes):

```
/root/.claude/skills/session-close/scripts/session-close.sh <repo_path> "Scaffold [project] setup: phases, tracker, onboarding" <each created file>
```

Run it once for the project repo and once for `pagios-ops` (the tracker lives there). Report both SHAs. If the script aborts on a secret pattern or a push fails, STOP and report it. Do not proceed to building.

---

## STEP 7 - Final output

Output exactly this format, then stop. Do not start building.

```
Project Name:
Repo Recommendation:
Recommended Repo Name:
Reasoning:
Recommended Folder Structure:
Phase Breakdown:
Tracker File:
Onboarding File:
Install Files:
Phase Start Briefs:
Risks or Warnings:
Verified:
Blocked:
Unverified:
Next Step:
```

End with: **Setup complete. Say "continue into the build" to start Phase [first], or run /session-close when you stop.**

---

## Variables

Fill from the operator's input block; infer blanks from the folder, git remote, or `/root/CLAUDE.md`.
```
PROJECT_NAME=
GITHUB_OWNER=Alijrob
REPO_NAME=
PRIMARY_REPO_URL=
TRACKER_PATH=pagios-ops/trackers/[project]-phase-tracker.md
ONBOARDING_DOC_PATH=docs/setup/onboarding.md
INSTALLER_FILES=
PRIMARY_DOMAIN_OR_DEPLOYMENT_TARGET=
SERVER_PATH=
CURRENT_PHASE=
SESSION_GOAL=
```
