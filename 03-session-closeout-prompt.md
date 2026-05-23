# Session Closeout Prompt

Fill in the variables at the top, then paste this entire file into Claude Code
at the end of every build session.

---

SESSION CLOSEOUT PROMPT

You are closing out this coding/build session. Execute these steps exactly.

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

Global rule:
Adversarial verification applies to every repo, every phase, every install, every
commit, every push, and every final report unless explicitly overridden.

Critical behavior rule:
Claude Code must be verification-first, not confidence-first. Prove repo state,
file state, commit state, push state, and test state with commands before claiming
success. If something cannot be proven, label it unverified, inferred, or blocked.

Claude Code adaptation rules:
- Use the actual repo, branch, tracker path, onboarding file, and installer files
  for this project.
- If any variable is blank, infer it from the repo when possible.
- Do not sweep unrelated dirty files into the commit.
- If there are dirty files not created or changed this session, list them separately
  and leave them unstaged.
- If a command fails, stop and report the exact failure.
- If push fails, stop and do not proceed to the resume prompt.
- Do not claim tests passed unless tests actually ran.

Step 1 — AUDIT

For every repo touched this session:

   git status --porcelain
   git log --oneline -5

Identify which dirty files belong to this session vs. files already dirty before.
Do not assume all dirty files belong to this session.

Step 2 — PHASE TRACKER CHECK

Open TRACKER_PATH. Update if this session changed: phase status, completed work,
blocked work, next steps, decisions, install steps, deployment process, env vars,
public URLs, ports, server paths, or onboarding flow.

Step 3 — INSTALL AND ONBOARDING HYGIENE CHECK

If this session changed anything related to installation or deployment, verify
INSTALLER_FILES and ONBOARDING_DOC_PATH still match the current code.
Changes that trigger this check: install.sh, bootstrap.sh, env vars, ports,
domains, URLs, build steps, package manager commands, deployment commands,
database migrations.
If outdated, update them before committing.

Step 4 — REVIEW ACTUAL CHANGES

   git diff

Confirm: no secrets, no unrelated files, no temp files, no logs, docs match code,
install instructions still work, tracker reflects reality.

Step 5 — STAGE ONLY SESSION FILES

   git add path/to/file1 path/to/file2 path/to/file3

Do not use git add . unless every dirty file is confirmed as this session's.

Step 6 — REVIEW STAGED CHANGES

   git diff --cached
   git status --porcelain

Scan staged changes for: API_KEY SECRET TOKEN PASSWORD PRIVATE_KEY .env
OPENAI_API_KEY ANTHROPIC_API_KEY GITHUB_TOKEN DATABASE_URL
If secrets appear, stop and report.

Step 7 — COMMIT

   git commit -m "clear one-line message describing the session's primary change"

No --no-verify. No skipped hooks.
If commit fails, stop and report the failure.
Verify: git log --oneline -1

Step 8 — PUSH

   git push

No --force. If push fails, stop and report. Do not proceed to the summary.
Verify: git status -sb

Step 9 — CAPTURE COMMIT SHA

   git rev-parse HEAD

Capture the SHA for every repo touched.

Step 10 — CREATE SESSION SUMMARY

Write docs/session-logs/YYYY-MM-DD-session-summary.md with:
- title (one short declarative line)
- summary (4-8 sentences, plain English, readable cold)
- repo URL
- tracker URL pinned to the new SHA
- commit SHA
- files changed (label + GitHub blob URL pinned to SHA)
- phase status
- next likely step
- known blockers
- verified checks
- blocked checks
- unverified items
- tests run

Step 11 — COMMIT SESSION LOG

   git add docs/session-logs/YYYY-MM-DD-session-summary.md
   git diff --cached
   git commit -m "Add session summary log"
   git push
   git rev-parse HEAD

Capture the final SHA.

Step 12 — CREATE RESUME PROMPT

End your reply with this exact structure filled in:

-----------------------------------------------------------
You're resuming a tracked build session. Execute these steps exactly.

Project:     [PROJECT_NAME]
Repo:        [PRIMARY_REPO_URL]
Logged:      [YYYY-MM-DD]
Phase:       [CURRENT_PHASE]
Commit SHA:  [SHA]

1. Inspect current repo state:
   git status --porcelain
   git log --oneline -5
   git rev-parse HEAD

2. Compare HEAD to the logged SHA above.
   If HEAD differs, flag the drift before continuing.

3. Read the tracker:
   [TRACKER_PATH]

4. Read onboarding:
   [ONBOARDING_DOC_PATH]

5. Read install files if relevant:
   [INSTALLER_FILES]

6. Read session summary:
   docs/session-logs/[YYYY-MM-DD]-session-summary.md

7. Brief me in 150 words or less:
   - what happened last session
   - current repo state
   - whether there is drift from the logged commit
   - current phase
   - most likely next step
   - what is verified / blocked / unverified

8. End with: Ready to continue — what's next?
-----------------------------------------------------------

FINAL REPLY FORMAT:

Project:
Repo:
Verified:
Blocked:
Unverified:
Commit:
Push:
Tests:
Tracker path:
Session log path:
Anything not completed:
Resume prompt:

End with: Safe to clear this session now.
