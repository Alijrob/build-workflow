#!/usr/bin/env bash
# telemetry-hook.sh - Claude Code hook that records session telemetry as JSONL.
#
# Wire this into ~/.claude/settings.json for PostToolUse, SessionStart, Stop,
# UserPromptSubmit, and SessionEnd (see install block at the bottom of this file).
# It reads the hook event JSON on stdin, extracts a few fields with jq, and
# appends one compact line to the telemetry store. The session-close skill reads
# these files to populate its cost telemetry instead of reporting "not captured".
#
# It fires on EVERY tool call, globally, so it is built to be harmless:
#   - Fast: a single jq pass, then an append.
#   - Never blocks or fails a tool: it always exits 0, even on bad input.
#   - Privacy: it records the tool NAME and the prompt LENGTH only, plus the skill
#     slug (not its args) when the tool is "Skill". It never stores tool_input,
#     file contents, command text, or prompt text, so a sensitive value passed to
#     Bash/Write never lands in the telemetry file.
#   - PostToolUse lines go to tool-usage.jsonl; all other events to activity.jsonl.
#
# Output dir: $CLAUDE_TELEMETRY_DIR (default /root/.claude/telemetry).

set -uo pipefail

TELEMETRY_DIR="${CLAUDE_TELEMETRY_DIR:-/root/.claude/telemetry}"
mkdir -p "$TELEMETRY_DIR" 2>/dev/null || exit 0

payload="$(cat 2>/dev/null || true)"
[ -n "$payload" ] || exit 0

ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# One jq pass builds "<event>\t<json-line>". Null fields are dropped, so each
# event type only carries the keys that apply to it. tool_input and prompt text
# are deliberately never selected.
out="$(printf '%s' "$payload" | jq -rc --arg ts "$ts" '
  (.hook_event_name // "unknown") as $ev
  | {
      ts: $ts,
      event: .hook_event_name,
      session_id: .session_id,
      cwd: .cwd,
      tool: .tool_name,
      skill: (if .tool_name == "Skill" then .tool_input.skill else null end),
      source: .source,
      model: .model,
      prompt_len: (if .prompt == null then null else (.prompt | length) end)
    }
  | with_entries(select(.value != null))
  | ($ev + "\t" + tojson)
' 2>/dev/null || true)"

if [ -n "$out" ]; then
  event="${out%%$'\t'*}"
  line="${out#*$'\t'}"
else
  # jq could not parse the payload; record a minimal marker rather than lose it.
  event="unparsed"
  line="{\"ts\":\"$ts\",\"event\":\"unparsed\"}"
fi

if [ "$event" = "PostToolUse" ]; then
  printf '%s\n' "$line" >> "$TELEMETRY_DIR/tool-usage.jsonl" 2>/dev/null || true
else
  printf '%s\n' "$line" >> "$TELEMETRY_DIR/activity.jsonl" 2>/dev/null || true
fi

exit 0

# ---------------------------------------------------------------------------
# Install (add to ~/.claude/settings.json, absolute path to this script):
#
#   "hooks": {
#     "PostToolUse":      [ { "matcher": "*", "hooks": [ { "type": "command",
#       "command": "/root/.claude/skills/session-close/scripts/telemetry-hook.sh", "timeout": 5 } ] } ],
#     "SessionStart":     [ { "hooks": [ { "type": "command",
#       "command": "/root/.claude/skills/session-close/scripts/telemetry-hook.sh", "timeout": 5 } ] } ],
#     "UserPromptSubmit": [ { "hooks": [ { "type": "command",
#       "command": "/root/.claude/skills/session-close/scripts/telemetry-hook.sh", "timeout": 5 } ] } ],
#     "Stop":             [ { "hooks": [ { "type": "command",
#       "command": "/root/.claude/skills/session-close/scripts/telemetry-hook.sh", "timeout": 5 } ] } ],
#     "SessionEnd":       [ { "hooks": [ { "type": "command",
#       "command": "/root/.claude/skills/session-close/scripts/telemetry-hook.sh", "timeout": 5 } ] } ]
#   }
# ---------------------------------------------------------------------------
