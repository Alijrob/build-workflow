#!/usr/bin/env bash
# session-close.sh - deterministic git plumbing for the session-close skill.
#
# Stages ONLY the named files, reports any other dirty files (leaves them
# unstaged), scans the staged diff for secrets, commits, pushes (handling new
# branches and a moved remote), proves the remote received the commit, and
# prints the SHA. No model tokens are spent here.
#
# CONCURRENCY: a 5-minute git-sync cron runs `git add . && commit && push` on the
# servers. To stop it interleaving with this script, both wrap their git work in
# an flock on LOCK_PATH. git-sync.sh should be patched to do:
#     exec 9>/tmp/git-sync.lock; flock 9
# Until it is, this script still survives a racing push by rebasing and retrying.
#
# Usage:
#   session-close.sh <repo_path> <commit_message> <file> [<file> ...]
#
# Env:
#   SECRETS_REVIEWED=1   Proceed even if secret-pattern matches are found in the
#                        staged diff. Only set after a human or the Opus layer has
#                        eyeballed the matches and confirmed they are false positives.
#   GIT_SYNC_LOCK=path   Override the coordination lock path (default /tmp/git-sync.lock).
#   LOCK_WAIT=secs       How long to wait for the lock (default 60).
#
# Exit codes:
#   0  committed and pushed, OR nothing to commit (see NOTHING_TO_COMMIT marker)
#   2  usage / environment error (bad args, not a git repo, missing file)
#   3  secret-pattern matches found and SECRETS_REVIEWED not set (nothing committed)
#   4  could not acquire the git-sync coordination lock in time
#   6  push failed for a reason other than a moved remote
#   7  rebase onto the moved remote failed (conflicts) - nothing was force-pushed
set -euo pipefail

LOCK_PATH="${GIT_SYNC_LOCK:-/tmp/git-sync.lock}"
LOCK_WAIT="${LOCK_WAIT:-60}"

REPO="${1:?usage: session-close.sh <repo_path> <commit_message> <file> [<file> ...]}"; shift
MSG="${1:?commit message required}"; shift
if [ "$#" -lt 1 ]; then
  echo "ERROR: at least one file path required" >&2
  exit 2
fi
FILES=("$@")

cd "$REPO" 2>/dev/null || { echo "ERROR: cannot cd to repo: $REPO" >&2; exit 2; }
git rev-parse --is-inside-work-tree >/dev/null 2>&1 || { echo "ERROR: not a git repo: $REPO" >&2; exit 2; }

for f in "${FILES[@]}"; do
  [ -e "$f" ] || { echo "ERROR: file not found in repo: $f" >&2; exit 2; }
done

# --- Coordinate with the git-sync cron: hold the lock for the whole git sequence.
# Released automatically when the script exits (fd 9 closes).
if command -v flock >/dev/null 2>&1; then
  exec 9>"$LOCK_PATH"
  if ! flock -w "$LOCK_WAIT" 9; then
    echo "ERROR: could not acquire git-sync lock ($LOCK_PATH) within ${LOCK_WAIT}s." >&2
    echo "Another git operation (the sync cron?) is holding it. Try again shortly." >&2
    exit 4
  fi
else
  echo "NOTE: flock not available; proceeding without cron coordination." >&2
fi

BRANCH="$(git rev-parse --abbrev-ref HEAD)"
echo "== BRANCH =="
echo "  $BRANCH"
if [ "$BRANCH" = "main" ] || [ "$BRANCH" = "master" ]; then
  echo "  NOTE: committing directly to $BRANCH."
fi
echo

echo "== AUDIT =="
git status --porcelain
echo
echo "== RECENT LOG =="
git log --oneline -5
echo

echo "== PRE-EXISTING DIRTY (left unstaged) =="
mapfile -t DIRTY < <(git status --porcelain | sed 's/^...//')
PREEXISTING=0
if [ "${#DIRTY[@]}" -gt 0 ]; then
  for d in "${DIRTY[@]}"; do
    keep=0
    for f in "${FILES[@]}"; do [ "$d" = "$f" ] && keep=1; done
    if [ "$keep" = 0 ]; then echo "  $d"; PREEXISTING=1; fi
  done
fi
[ "$PREEXISTING" = 0 ] && echo "  (none)"
echo

echo "== STAGE (named files only) =="
for f in "${FILES[@]}"; do
  git add -- "$f"
  echo "  staged: $f"
done
echo

# --- Nothing-to-commit: the named files may already be committed or unchanged
# (e.g. the cron committed them out from under us). Exit cleanly, do not error.
if git diff --cached --quiet; then
  echo "== NOTHING TO COMMIT =="
  echo "  The named files have no staged changes (already committed or unchanged)."
  echo "SHA=$(git rev-parse HEAD)"
  echo "NOTHING_TO_COMMIT=1"
  exit 0
fi

echo "== SECRET SCAN (staged added lines) =="
PATTERN='API_KEY|SECRET|TOKEN|PASSWORD|PRIVATE_KEY|DATABASE_URL|BEGIN [A-Z ]*PRIVATE KEY|\.env([^a-zA-Z]|$)'
PATTERN="$PATTERN"'|ghp_[A-Za-z0-9]{20,}|gho_[A-Za-z0-9]{20,}|ghs_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}'
PATTERN="$PATTERN"'|AKIA[0-9A-Z]{16}|ASIA[0-9A-Z]{16}|sk_live_[A-Za-z0-9]{10,}|sk_test_[A-Za-z0-9]{10,}|rk_live_[A-Za-z0-9]{10,}'
PATTERN="$PATTERN"'|AIza[0-9A-Za-z_-]{20,}|xox[baprs]-[A-Za-z0-9-]{10,}|eyJ[A-Za-z0-9_-]{10,}\.[A-Za-z0-9_-]{10,}\.'
HITS="$(git diff --cached | grep -nE '^\+' | grep -aiE "$PATTERN" || true)"
if [ -n "$HITS" ]; then
  echo "POTENTIAL SECRETS in staged diff:"
  echo "$HITS"
  if [ "${SECRETS_REVIEWED:-0}" != "1" ]; then
    echo
    echo "ABORT: secret-pattern matches found. Nothing was committed."
    echo "Review the lines above. If they are genuine false positives, re-run with"
    echo "SECRETS_REVIEWED=1. Otherwise remove the secret and re-run."
    git reset -q -- "${FILES[@]}"
    exit 3
  fi
  echo "SECRETS_REVIEWED=1 set - proceeding despite matches."
else
  echo "  (none)"
fi
echo

echo "== COMMIT =="
git commit -m "$MSG"
echo
echo "== VERIFY COMMIT =="
git log --oneline -1
echo

# --- Push: handle a missing upstream (new branch) and a moved remote (cron pushed
# while we worked) by rebasing and retrying once. Never force-push.
do_push() {
  if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
    echo "  No upstream set; pushing with -u origin HEAD."
    git push -u origin HEAD
    return 0
  fi
  local out
  if out="$(git push 2>&1)"; then
    echo "$out"
    return 0
  fi
  echo "$out"
  if echo "$out" | grep -qiE 'non-fast-forward|fetch first|rejected|behind'; then
    echo "  Push rejected (remote moved, likely the sync cron). Rebasing and retrying once."
    if ! git pull --rebase --autostash; then
      git rebase --abort 2>/dev/null || true
      echo "ERROR: rebase onto the moved remote failed (conflicts). Nothing was force-pushed." >&2
      echo "Resolve the conflict manually, then re-run." >&2
      return 7
    fi
    git push
    return 0
  fi
  echo "ERROR: push failed for a reason other than a moved remote." >&2
  return 6
}

echo "== PUSH =="
do_push || exit $?
echo
echo "== VERIFY PUSH (prove the remote has it) =="
git status -sb
LOCAL="$(git rev-parse HEAD)"
UPSTREAM="$(git rev-parse '@{u}' 2>/dev/null || echo none)"
if [ "$LOCAL" = "$UPSTREAM" ]; then
  echo "  PUSH VERIFIED: local HEAD == upstream"
else
  echo "  WARNING: local HEAD ($LOCAL) != upstream ($UPSTREAM)." >&2
  echo "  The remote may have advanced again after our push (cron). Our commit is in its history." >&2
fi
echo

echo "== RESULT =="
echo "SHA=$LOCAL"
echo "BRANCH=$BRANCH"
echo "PREEXISTING_DIRTY=$PREEXISTING"
echo "NOTHING_TO_COMMIT=0"
