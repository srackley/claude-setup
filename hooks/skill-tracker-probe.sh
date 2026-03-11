#!/bin/bash
# PostToolUse probe — tests whether Skill tool calls trigger PostToolUse hooks.
#
# EXPERIMENTAL: If Skill is matchable, this hook fires after every Skill
# invocation and logs it. If it never fires, Skill is not matchable and
# we should rely on transcript parsing instead.
#
# Evidence that it fired: /tmp/claude-skill-probe.log exists and has entries.
#
# INERT until registered in ~/.claude/settings.json PostToolUse hooks.

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
skill_name=$(echo "$input" | jq -r '.tool_input.skill // empty' 2>/dev/null)
timestamp=$(date +%Y-%m-%dT%H:%M:%S)

log_file="${SKILL_PROBE_LOG:-/tmp/claude-skill-probe.log}"

echo "[$timestamp] PostToolUse fired: tool=$tool_name skill=$skill_name" >> "$log_file"

exit 0
