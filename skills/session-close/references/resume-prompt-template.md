─────────────────────────────────────────
You're resuming a tracked build session. Execute these steps exactly.

Project:     [PROJECT_NAME]
Repo:        [PRIMARY_REPO_URL]
Logged:      [YYYY-MM-DD]
Phase:       [CURRENT_PHASE]
Ran on:      [SESSION_MODEL]  (close-out was done on Opus)
Commit SHA:  [resume SHA - the session-log commit]

1. Inspect current repo state:
   git status --porcelain
   git log --oneline -5
   git rev-parse HEAD

2. Compare HEAD to the logged SHA above.
   If HEAD differs, flag the drift before continuing.

3. Read the tracker: [TRACKER_PATH]
4. Read onboarding: [ONBOARDING_DOC_PATH]
5. Read install files if relevant: [INSTALLER_FILES]
6. Read session summary: docs/session-logs/[YYYY-MM-DD]-session-summary.md

7. Brief me in 150 words or less:
   - what happened last session
   - current repo state
   - whether there is drift from the logged commit
   - current phase
   - most likely next step
   - what is verified / blocked / unverified

8. End with: Ready to continue - what's next?
─────────────────────────────────────────
