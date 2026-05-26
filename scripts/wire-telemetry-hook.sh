#!/usr/bin/env bash
# wire-telemetry-hook.sh — Install the session-close telemetry hook on a server.
#
# Run this script ON the target server (THOTH or ZEUS) to:
#   1. Copy telemetry-hook.sh, telemetry-schema.sql, and telemetry-ingest.py
#      from the build-workflow repo into /root/.claude/skills/session-close/scripts/
#   2. Merge the hook block into /root/.claude/settings.json
#   3. Add the 30-min ingester cron
#
# Usage (from THOTH or ZEUS, after pulling build-workflow):
#   bash /root/build-workflow/scripts/wire-telemetry-hook.sh
#
# Idempotent: safe to re-run. Skips steps already done.

set -euo pipefail

REPO_DIR="/root/build-workflow"
SKILL_SCRIPTS="$REPO_DIR/skills/session-close/scripts"
LIVE_SCRIPTS="/root/.claude/skills/session-close/scripts"
SETTINGS="/root/.claude/settings.json"
TELEMETRY_DIR="/root/.claude/telemetry"

echo "=== Step 1: verify build-workflow repo is present ==="
if [ ! -f "$SKILL_SCRIPTS/telemetry-hook.sh" ]; then
  echo "ERROR: $SKILL_SCRIPTS/telemetry-hook.sh not found."
  echo "Pull build-workflow first:  cd /root/build-workflow && git pull"
  exit 1
fi
echo "PASS: repo present"

echo ""
echo "=== Step 2: copy skill scripts to live location ==="
mkdir -p "$LIVE_SCRIPTS"
cp "$SKILL_SCRIPTS/telemetry-hook.sh"       "$LIVE_SCRIPTS/"
cp "$SKILL_SCRIPTS/telemetry-schema.sql"    "$LIVE_SCRIPTS/"
cp "$SKILL_SCRIPTS/telemetry-ingest.py"     "$LIVE_SCRIPTS/"
chmod +x "$LIVE_SCRIPTS/telemetry-hook.sh"
echo "PASS: scripts copied to $LIVE_SCRIPTS"

echo ""
echo "=== Step 3: create telemetry dir ==="
mkdir -p "$TELEMETRY_DIR"
echo "PASS: $TELEMETRY_DIR ready"

echo ""
echo "=== Step 4: merge hook block into settings.json ==="
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 required to update settings.json"
  exit 1
fi

python3 - "$SETTINGS" "$LIVE_SCRIPTS/telemetry-hook.sh" << 'PYEOF'
import json, sys, os

settings_path = sys.argv[1]
hook_cmd = "/root/.claude/skills/session-close/scripts/telemetry-hook.sh"

# Load or create settings
if os.path.exists(settings_path):
    with open(settings_path) as f:
        cfg = json.load(f)
else:
    cfg = {}

hooks = cfg.setdefault("hooks", {})

def hook_entry(matcher=None):
    entry = {"hooks": [{"type": "command", "command": hook_cmd, "timeout": 5}]}
    if matcher:
        entry["matcher"] = matcher
    return entry

def already_wired(event, matcher=None):
    for block in hooks.get(event, []):
        for h in block.get("hooks", []):
            if h.get("command") == hook_cmd:
                return True
    return False

changed = False
for event in ["PostToolUse", "SessionStart", "UserPromptSubmit", "Stop", "SessionEnd"]:
    if not already_wired(event):
        matcher = "*" if event == "PostToolUse" else None
        hooks.setdefault(event, []).append(hook_entry(matcher))
        changed = True
        print(f"  wired: {event}")
    else:
        print(f"  already wired: {event}")

if changed:
    with open(settings_path, "w") as f:
        json.dump(cfg, f, indent=2)
    print(f"PASS: {settings_path} updated")
else:
    print(f"PASS: {settings_path} already complete (no changes)")
PYEOF

echo ""
echo "=== Step 5: add ingester cron (if not already present) ==="
CRON_CMD="*/30 * * * * python3 /root/.claude/skills/session-close/scripts/telemetry-ingest.py >> /root/.claude/telemetry/ingest.log 2>&1"
if crontab -l 2>/dev/null | grep -q "telemetry-ingest.py"; then
  echo "PASS: ingester cron already installed"
else
  (crontab -l 2>/dev/null; echo ""; echo "# Telemetry ingester - runs every 30 min (idempotent)"; echo "$CRON_CMD") | crontab -
  echo "PASS: ingester cron added"
fi

echo ""
echo "=== Step 6: smoke test - run ingester now ==="
python3 "$LIVE_SCRIPTS/telemetry-ingest.py" --report-only
echo ""
echo "======================================================"
echo "Telemetry hook wired on $(hostname) ($(hostname -I | awk '{print $1}'))"
echo "Hook fires on next Claude session. Run --session latest after your first session."
echo "======================================================"
