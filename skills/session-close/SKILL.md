---
name: session-close
description: Close out a coding/build session with adversarial, verification-first rigor. Gates the close-out onto Opus (the high-judgment work runs on the best model), delegates verbose log-scraping and git plumbing to cheap Haiku subagents so they never pollute the main context, runs deterministic git via a bundled bash script, captures company-cost telemetry (tool/service usage, API usage, time-in-function), commits and pushes, writes a session log to docs/session-logs/, and prints a paste-ready resume prompt. Run at the end of any build session. Trigger on "close the session", "session close", "wrap this session", "/session-close", "save and close out".
---

# Session Close

Closes out a build session: prove repo state, commit only this session's work, push, log it, capture cost telemetry, and emit a resume prompt for the next session. This is the back bookend of the build workflow; the project-setup skill is the front bookend, and this skill writes into and reads from the structure that one creates.

## Operating principles

- **Verification-first, not confidence-first.** Prove repo, file, commit, push, and test state with commands before claiming success. Anything you cannot prove is labeled `unverified`, `inferred`, or `blocked`.
- **Adversarial verification** applies to every repo, phase, commit, push, and the final report unless explicitly overridden.
- **Never use em dashes** in any output, log, or commit message.
- Do not claim files were created, edited, committed, pushed, or tested unless the command or tool operation actually ran.
- Do not sweep unrelated dirty files into the commit.

---

## STEP 0 - Model gate (the first thing that happens)

This close-out runs on Opus. The operator typically works on Sonnet, so the very first action is to confirm the model.

1. Determine your current model from your own system context.
2. **If you are not an Opus model:** output exactly this and STOP. Do nothing else, spawn nothing, run no git commands.

   ```
   Switch to Opus before closing out. The close-out reasoning and verification
   run on the best model. Type:  /model opus
   Then run /session-close again.
   ```

3. **If you are on Opus:** proceed to Step 1.

> A skill cannot pull the `/model` lever itself; that is an operator action. This gate enforces the switch by refusing to run until you are on Opus. Once on Opus, the whole close-out proceeds on Opus, and only the verbose grunt work is pushed down to cheap subagents.

---

## STEP 1 - Assemble the brief (you, on Opus, from session memory)

You lived through this session. Reconstruct from memory; do NOT dump `git diff` into this context to rediscover what you did. Determine:

**Variables** (infer any blank from the git remote, the tracker, or `/root/CLAUDE.md`):
```
PROJECT_NAME        -
GITHUB_OWNER        - Alijrob
REPO_NAME           -
PRIMARY_REPO_URL    -
REPO_LOCAL_PATH     - e.g. /root/pagios-ops
TRACKER_PATH        - pagios-ops/trackers/[project]-phase-tracker.md
ONBOARDING_DOC_PATH - docs/setup/onboarding.md
INSTALLER_FILES     -
PRIMARY_DOMAIN      -
SERVER_PATH         -
CURRENT_PHASE       -
SESSION_GOAL        -
SESSION_MODEL       - model this session ran on before the switch (for telemetry)
```

**Session content** (you author this; subagents only execute or scrape):
- `FILES_THIS_SESSION` - exact paths this session created or changed.
- `COMMIT_MESSAGE` - one clear line, no em dashes.
- `SUMMARY_NARRATIVE` - 4 to 8 sentences, readable cold by someone who was not here.
- `PHASE_STATUS`, `NEXT_STEP`, `KNOWN_BLOCKERS`.
- `VERIFIED` / `BLOCKED` / `UNVERIFIED` lists.
- `TESTS_RUN` - commands and outcomes, or "None".

**Make the doc edits yourself now** (you have the context to do them right):
- Update `TRACKER_PATH` if this session changed phase status, decisions, next steps, install steps, env vars, URLs, or ports.
- Update `ONBOARDING_DOC_PATH` and `INSTALLER_FILES` if installation or deployment changed, so they still match the code.
- Add every file you edit here to `FILES_THIS_SESSION`.

---

## STEP 2 - Cost & Telemetry subagent (Haiku, runs in parallel)

These numbers are company costs the operator analyzes, so capture them every session. The verbose log output must stay out of this Opus context, so delegate the scraping.

Spawn an **Agent** with `subagent_type: general-purpose`, `model: haiku`, `run_in_background: true`, briefed to scrape only the sources that exist and to label every missing source rather than guess:

```
Gather cost/telemetry for a build session. Read ONLY these sources if present; for any
that does not exist or yields nothing, report it as "not captured (no source)". Do not
estimate numbers you cannot read. Return a compact block, nothing verbose.

Sources to check:
- /root/opims/logs/activity.jsonl and /root/opims/logs/tool-usage.jsonl  (hook telemetry)
- pm2 jlist  (process uptime / restarts, for automation runtime)
- n8n execution logs or API if reachable  (workflow executions this window)
- tailscale status  (which tailnet peers were used)
- any project-local API call logs under the repo or /root/*/logs

Return exactly:
## Telemetry
- External services used: [n8n: N execs | tailscale: peers | SSH targets | "none found"]
- API usage: [provider: N calls ~$X each line, or "not captured"]
- Time in function: [automation runtime from pm2/pipeline logs, or "not captured"]
- Source per line: [where each number came from, or "unverified"]
```

Note the agent ID; you will fold its returned block into the session log. Continue to Step 3 while it runs.

---

## STEP 3 - Write the session log (you, on Opus)

Write `docs/session-logs/YYYY-MM-DD-session-summary.md` (use that path if `docs/` exists in the repo; fall back to `session-logs/` at repo root only if there is no `docs/`). Use the template in `references/session-summary-template.md`. Add the telemetry subagent's returned block as the `## Telemetry` section, prepending the model line:

```
## Telemetry
- Model: main close-out on [Opus model]; session ran on [SESSION_MODEL]; subagents on Haiku
- Claude tools invoked this session: [Bash, Edit, Write, Read, Agent, ... with rough counts]
[then the External services / API usage / Time in function lines from the subagent]
```

Leave the `Commit SHA` placeholder; the git executor fills it. Add the log path to `FILES_THIS_SESSION`.

---

## STEP 4 - Git executor subagent (Haiku) runs the bundled script

Delegate git plumbing so its output stays out of this context. The script is deterministic and spends no model tokens; the subagent just invokes it and reports back. Spawn an **Agent** with `subagent_type: general-purpose`, `model: haiku`:

```
Run the session-close git plumbing script TWICE in this repo. Report only its RESULT
lines, any PRE-EXISTING DIRTY files, and any secret-scan output. Do not edit any files.
Script: /root/.claude/skills/session-close/scripts/session-close.sh
Usage:  session-close.sh <repo_path> <commit_message> <file> [<file> ...]

1. Work commit - stage and commit the session's code/doc files:
   session-close.sh <REPO_LOCAL_PATH> "<COMMIT_MESSAGE>" <each work file except the session log>
   Capture the SHA it prints.

2. Then edit the session log's "Commit SHA" line to that work-commit SHA (use the Edit tool),
   and run the script again for the log:
   session-close.sh <REPO_LOCAL_PATH> "Add session summary YYYY-MM-DD" docs/session-logs/YYYY-MM-DD-session-summary.md
   Capture this second SHA - it is the resume SHA.

Exit codes - handle each, do not treat them all the same:
- 0 with NOTHING_TO_COMMIT=1: the files were already committed (the sync cron may have beaten us). This is NOT a failure; report it and skip that commit.
- 0 otherwise: committed and pushed; the script already proved local HEAD == upstream.
- 2: usage/environment error. STOP and return the output.
- 3: secret-pattern match. STOP, do NOT bypass.
- 4: could not acquire the git-sync lock (the cron is mid-run). Wait ~15s and retry once; if it fails again, STOP and report.
- 6: push failed for a non-recoverable reason. STOP and report.
- 7: rebase onto the moved remote hit conflicts. STOP and report; do not force anything.

Never pass SECRETS_REVIEWED unless I explicitly tell you to. Never use --force or --no-verify.
Return: work SHA, resume SHA, branch, pre-existing dirty list, secret-scan result, and whether
both pushes verified (HEAD == upstream).
```

If the executor reports a secret-scan abort (exit 3): surface the flagged lines to the operator, do NOT auto-bypass. Only re-dispatch with `SECRETS_REVIEWED=1` after the operator confirms a false positive. If a push fails (6/7): STOP, report it, and do NOT emit a resume prompt.

> The script holds an `flock` on `/tmp/git-sync.lock` for its whole git sequence so the 5-minute auto-sync cron cannot interleave. For this to be airtight, `git-sync.sh` on THOTH and ZEUS must wrap its own git work in the same lock (`exec 9>/tmp/git-sync.lock; flock 9`). Until it does, the script still survives a racing push via rebase-and-retry, but patching `git-sync.sh` is the recommended follow-up.

---

## STEP 5 - Final report and resume prompt (you, on Opus)

Collect the telemetry subagent's result and the git executor's SHAs. Output the final report, then the resume prompt from `references/resume-prompt-template.md` filled in with the resume SHA.

**Final report:**
```
Project:
Repo:
Verified:
Blocked:
Unverified:
Commit:                 [work SHA]
Push:                   [confirmed / failed]
Tests:
Tracker path:
Session log path:
Pre-existing dirty files:
Telemetry:              [one-line cost summary]
Anything not completed:
Resume prompt:          [the filled block below]
```

Then paste the resume block. End with: **Safe to clear this session now.**

---

## Subagent roster (why each exists)

| Agent | Model | Job | Why not on the main thread |
|-------|-------|-----|----------------------------|
| main | Opus | judgment: brief, summary, verification, orchestration | needs full session context and best-model quality |
| cost/telemetry scraper | Haiku | reads logs for service/API/time cost | verbose log output would bloat Opus context |
| git executor | Haiku | runs the bash script, reports SHAs | git command output would bloat Opus context |

The deterministic git work itself lives in `scripts/session-close.sh` and costs zero model tokens; the executor subagent only invokes it.
