# Setup Instructions

Do this once per project before using either prompt.

---

## 1. Create or confirm a GitHub account

https://github.com

## 2. Create one GitHub repo per project

Example repo names: `client-website`, `lead-intake-system`, `chatbot-widget`,
`crm-dashboard`, `automation-server`

Do not mix unrelated projects in one repo unless intentionally part of the same system.

## 3. Clone the repo onto the development machine or server

```bash
git clone https://github.com/YOUR-GITHUB-USERNAME/YOUR-REPO-NAME.git
cd YOUR-REPO-NAME
```

## 4. Create the project docs structure (Option C hybrid)

Master tracker goes in `pagios-ops/trackers/[project]-phase-tracker.md`.

Each project repo gets:

```
docs/
docs/setup/onboarding.md
docs/session-logs/
docs/reference/
```

## 5. Create a phase tracker in pagios-ops

Use the template at `pagios-ops/trackers/_phase-tracker-template.md`.

Required fields:
- Project Name
- Repo
- Primary Goal
- Deployment Target
- Main App Path
- Server Path
- Current Phase
- Last Updated
- Phase status table
- Decisions Log
- Current State
- Install Notes
- Environment Variables
- Known Risks
- Resume Notes

## 6. Create onboarding documentation

File: `docs/setup/onboarding.md`

Must cover:
- What the project does
- Where the code lives
- How to install
- How to run locally
- How to deploy
- Required environment variables
- Important files
- Current phase
- Known blockers
- Next likely step

## 7. Create install documentation or scripts if needed

If this project installs onto a server, create at least one of:

```
install.sh
bootstrap.sh
docs/setup/install.md
```

Rule: if the install process changes, the install docs must be updated in the
same commit.

## 8. Define phases — keep them small

No phase may exceed 40% of the available context window.

Each phase must be small enough that a fresh AI session can:
- understand the objective
- inspect the relevant files
- complete the work
- test or verify the work
- update documentation and the tracker
- commit cleanly
- produce a handoff prompt

If a phase is too large, split it.

## 9. Fill in project variables before using the prompts

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

---

## Global operating rules

These apply to every project, every session, every commit, every push.

1. Adapt to the actual project. Use real repo, real paths, real names. Do not
   import assumptions from another project.

2. GitHub is the source of truth. All code, trackers, docs, and session logs
   live in the repo.

3. Never start building before setup exists. Every project needs a tracker,
   onboarding doc, and phase breakdown before real build work begins.

4. Never blindly stage files. Inspect `git status --porcelain` before every
   commit. Stage only files changed this session.

5. Never use unsafe Git shortcuts without explicit approval:
   `git push --force`, `git commit --no-verify`, `git reset --hard`, `git clean -fd`

6. Never claim success without verification. Every operational claim must be:
   - Verified: confirmed by a command, file read, test, or tool result
   - Inferred: reasonable conclusion from evidence, not directly verified
   - Unverified: not checked
   - Blocked: cannot be verified due to missing access, credentials, or tools

7. Required final report structure:
   Verified: / Blocked: / Unverified: / Commit: / Push: / Tests:

8. If a command fails, stop. Report the command, the error, what is blocked,
   and what is safe to do next.

9. Scan staged changes for secrets before every commit:
   API_KEY SECRET TOKEN PASSWORD PRIVATE_KEY .env DATABASE_URL GITHUB_TOKEN
