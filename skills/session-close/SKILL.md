---
name: session-close
description: Close out a coding/build session with adversarial, verification-first rigor. Authors the brief and session log on the context-bearing main thread, runs a single final adversarial verification pass via an Opus subagent, delegates verbose log-scraping and git plumbing to cheap Haiku subagents so they never pollute the main context, runs deterministic git via a bundled bash script, captures company-cost telemetry (tool/service usage, API usage, time-in-function), commits and pushes, writes a session log to docs/session-logs/, and prints a paste-ready resume prompt. Run at the end of any build session. Trigger on "close the session", "session close", "wrap this session", "/session-close", "save and close out".
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

## STEP 0 - How this close-out runs (no model gate)

This skill runs in one action on whatever model the session is already on. Do not ask the operator to switch models, and do not stop to wait for a switch.

- **The main thread authors.** You lived through this session, so you write the brief, the doc edits, and the session log. None of that can be delegated, because a subagent cannot see this conversation.
- **Haiku does the grunt work.** Verbose telemetry scraping (Step 2) and deterministic git plumbing (Step 5) run on cheap Haiku subagents so their output never bloats this context.
- **One Opus subagent verifies at the end.** After the log is written, a single Opus subagent (Step 4) receives the finished artifacts as text and runs the adversarial verification pass. The best-model judgment is spent only where it adds the most value, and only once there is something concrete to check. You apply its findings before anything is committed.

Proceed to Step 1.

---

## STEP 1 - Assemble the brief (you, the main thread, from session memory)

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
SESSION_MODEL       - model this session (and this close-out) ran on (for telemetry)
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

These numbers are company costs the operator analyzes, so capture them every session. The verbose log output must stay out of this context, so delegate the scraping.

Spawn an **Agent** with `subagent_type: general-purpose`, `model: haiku`, `run_in_background: true`, briefed to scrape only the sources that exist and to label every missing source rather than guess:

```
Gather cost/telemetry for a build session. Read ONLY these sources if present; for any
that does not exist or yields nothing, report it as "not captured (no source)". Do not
estimate numbers you cannot read. Return a compact block, nothing verbose.

Sources to check:
- Claude Code hook telemetry. The hook (telemetry-hook.sh) appends raw events to
  /root/.claude/telemetry/*.jsonl; telemetry-ingest.py loads them into telemetry.db and
  computes the per-session rollup via the skill_runs view. Run ONE command:
      python3 /root/.claude/skills/session-close/scripts/telemetry-ingest.py --session latest
  It ingests any new events, then prints the session being closed: wall-clock, model,
  tool-call count, prompt count, skill invocations, and the per-tool breakdown. Use that
  output verbatim. "latest" = the most recently started session; if two Claude sessions
  overlapped on this box, say which one you reported. If it prints "No sessions in
  telemetry yet" or the script/db is missing, report Claude telemetry as "not captured
  (hook not wired on this box)"; do not guess or hand-derive from the raw JSONL.
- pm2 jlist  (process uptime / restarts, for automation runtime)
- n8n execution logs or API if reachable  (workflow executions this window)
- tailscale status  (which tailnet peers were used)
- any project-local API call logs under the repo or /root/*/logs

Return exactly:
## Telemetry
- Claude tool counts: [tool: N per tool from hook telemetry, or "not captured (no hook data)"]
- Session wall-clock: [HH:MM from SessionStart to last event, or "not captured"]
- Prompts this session: [N UserPromptSubmit lines, or "not captured"]
- External services used: [n8n: N execs | tailscale: peers | SSH targets | "none found"]
- API usage: [provider: N calls ~$X each line, or "not captured (hooks do not expose model cost)"]
- Time in function: [automation runtime from pm2/pipeline logs, or "not captured"]
- Source per line: [where each number came from, or "unverified"]
```

Note the agent ID; you will fold its returned block into the session log. Continue to Step 3 while it runs.

---

## STEP 3 - Write the session log (you, the main thread)

Write `docs/session-logs/YYYY-MM-DD-session-summary.md` (use that path if `docs/` exists in the repo; fall back to `session-logs/` at repo root only if there is no `docs/`). Use the template in `references/session-summary-template.md`. Add the telemetry subagent's returned block as the `## Telemetry` section, prepending the model line:

```
## Telemetry
- Model: close-out authored on the main thread ([SESSION_MODEL]); final verification on an Opus subagent; telemetry and git plumbing on Haiku subagents
[then the Claude tool counts / Session wall-clock / Prompts / External services / API usage /
 Time in function / Source lines returned by the subagent. Prefer the subagent's hook-derived
 tool counts over your own recollection; fall back to recollection only if the hook data is missing.]
```

Leave the `Commit SHA` placeholder; the git executor fills it. Add the log path to `FILES_THIS_SESSION`.

---

## STEP 4 - Adversarial verification pass (Opus subagent)

The session log and brief are now drafted but NOT yet committed. Spawn a single **Agent** with `subagent_type: general-purpose`, `model: opus` to adversarially review them. It cannot see this conversation, so paste the artifacts in as text: the full session log, plus the VERIFIED / BLOCKED / UNVERIFIED lists and the exact list of files you are about to commit.

Brief it:

```
You are the adversarial verifier for a build-session close-out. You did NOT witness the
session; judge ONLY the text given. Be skeptical: your job is to catch claims that are
asserted but not proven, not to rubber-stamp.

Review the pasted session log and brief for:
- Confidence-not-proof: any item under "Verified" not backed by a command, tool run, or
  file operation actually shown. Demand it be moved to "Unverified" or proven.
- Internal inconsistency: the summary describes a change missing from "Files Changed", a
  SHA referenced two different ways, a "Next Step" that contradicts "Phase Status", or
  tests claimed run with no command.
- Scope creep: files in the commit list the narrative never explains (a possible sweep of
  unrelated dirty files).
- Em dashes anywhere (banned). Flag each occurrence.
- Missing or hand-waved blockers, next steps, or resume detail.

Return a compact findings list, each tagged MUST-FIX or OPTIONAL, naming the exact line or
phrase and the change to make. If the artifacts are clean, say so explicitly. Do not
rewrite the documents; only report findings.
```

Apply every MUST-FIX to the session log and any doc you already edited. Do NOT proceed to the git executor until each MUST-FIX is resolved, or you have a defensible reason (recorded in the log) to overrule one. This pass runs before the commit so the corrections land in it.

---

## STEP 5 - Git executor subagent (Haiku) runs the bundled script

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

## STEP 6 - Final report and resume prompt (you, the main thread)

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

Then paste the resume block. End with this closing block (copy it verbatim -- do NOT add any session-ending instruction or tell the user to /clear or /exit):

> **Session close complete.** The resume prompt above is paste-ready for the next time you open a new Claude window. This session stays open -- you can keep building, ask follow-up questions, or use `/compact` to free context. Do NOT run `/clear` or `/exit` now; either one drops this session and forces `claude --resume` to get back.

---

## Subagent roster (why each exists)

| Agent | Model | Job | Why here |
|-------|-------|-----|----------|
| main thread | session model | authoring: brief, doc edits, session log, orchestration, applying fixes | only the main thread can see the live session, and authoring needs that context |
| adversarial verifier | Opus | final skeptical review of the finished log and brief | best-model judgment, spent once on concrete artifacts; fed as text since it cannot see the session |
| cost/telemetry scraper | Haiku | reads logs for service/API/time cost | verbose log output would bloat the main context |
| git executor | Haiku | runs the bash script, reports SHAs | git command output would bloat the main context |

The deterministic git work itself lives in `scripts/session-close.sh` and costs zero model tokens; the executor subagent only invokes it.
