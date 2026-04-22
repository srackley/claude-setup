#!/bin/bash
# PostToolUse hook on Bash — records the transcript line count after a
# successful git commit. commit-gate.sh reads this marker to find the
# correct search anchor, avoiding the cascade bug where blocked commits
# shift the anchor past valid skill invocations.

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+(-C\s+\S+\s+)?commit(\s|$)'; then
    exit 0
fi

session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

if [[ -z "$session_id" || -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    exit 0
fi

line_count=$(wc -l < "$transcript_path" | tr -d ' ')
echo "$line_count" > "/tmp/last-commit-${session_id}.line"
