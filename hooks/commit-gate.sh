#!/bin/bash
# PreToolUse hook on Bash — blocks git commit without required skill invocations.
#
# Parses the session transcript (JSONL) to verify that finishing-work and a
# session-notes write were performed before allowing a commit.
#
# reviewing-code is enforced at PR creation time (pr-gate.sh), not per-commit.
#
# Expected workflow: TDD → verification → finishing-work → session-notes → commit
# This hook enforces the last two (finishing-work, session-notes).
#
# When all requirements are met, outputs permissionDecision "allow" to
# auto-approve the commit (no manual permission prompt needed). When any is
# missing, exits with code 2 + stderr to block.
#
# Known limitation: transcript JSONL schema is not a public API. If Claude Code
# changes the format, this hook may need updating. The hook fails-safe (blocks)
# when the transcript is missing or unparseable.

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only enforce on git commit commands (not git commit-graph, etc.)
# Match git commit anywhere in the command (handles chained: "git add && git commit")
if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+commit(\s|$)'; then
    exit 0
fi

transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

# Fix for continuation sessions: Claude Code may pass a stale transcript_path
# pointing to a previous session's JSONL. Prefer the session_id-based path
# since session_id always matches the current session.
if [[ -n "$session_id" && -n "$transcript_path" ]]; then
    session_transcript="$(dirname "$transcript_path")/${session_id}.jsonl"
    if [[ -f "$session_transcript" ]]; then
        transcript_path="$session_transcript"
    fi
fi

# Fail-safe: if no transcript available, block
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    echo "BLOCKED: Cannot verify skill invocations (transcript unavailable). Invoke finishing-work skill first, then retry the commit." >&2
    exit 2
fi

# Find the line number of the last COMPLETED git commit in the transcript.
# Only check for skill invocations AFTER the last commit — skills from a prior
# commit in the same session should not count for the current commit.
#
# Important constraints:
# 1. Match only actual Bash tool_use entries containing git commit, not mentions
#    of "git commit" in skill text, hook prompts, or session notes. We require
#    "name":"Bash" or "tool_name":"Bash" on the same line — skill content and
#    tool results won't have this alongside a "command" field.
#    (Real transcripts use "name", test fixtures use "tool_name".)
# 2. Exclude the CURRENT commit attempt (the last match), which is already in
#    the transcript when PreToolUse fires. sed '$d' drops it.
#
# Two-stage grep: first find Bash tool_use lines, then filter for git commit.
# Separating stages preserves the first grep's exit code for error detection.
bash_lines=$(grep -nE '"(name|tool_name)":"Bash"' "$transcript_path" 2>&1) || {
    grep_exit=$?
    if [[ $grep_exit -eq 1 ]]; then
        bash_lines=""
    else
        echo "BLOCKED: Failed to parse transcript for prior commits (grep exit $grep_exit)." >&2
        exit 2
    fi
}
if [[ -n "$bash_lines" ]]; then
    # Match only actual git commit commands, not commands that merely contain
    # "git commit" as an argument (e.g., grep 'git commit' transcript.jsonl).
    # Require git commit to appear at command start or after && / ; separators.
    grep_output=$(echo "$bash_lines" | grep -E '"command":"(([^"]*&&|[^"]*;)\s*)?git\s+commit(\s|\\|")') || grep_output=""
else
    grep_output=""
fi

if [[ -n "$grep_output" ]]; then
    last_commit_line=$(echo "$grep_output" | cut -d: -f1 | sed '$d' | tail -1)
else
    last_commit_line=""
fi

# Extract the region to search: everything after the last commit, or the whole file
# Guard: last_commit_line must be a positive integer (defensive against malformed transcript)
if [[ -n "$last_commit_line" && ! "$last_commit_line" =~ ^[0-9]+$ ]]; then
    echo "BLOCKED: Failed to parse transcript for prior commits (non-numeric line: $last_commit_line)." >&2
    exit 2
fi
if [[ -n "$last_commit_line" ]]; then
    search_file=$(mktemp /tmp/claude-commit-gate-region-XXXXXX)
    tail -n +"$((last_commit_line + 1))" "$transcript_path" > "$search_file"
else
    search_file="$transcript_path"
fi

# Check for required skill invocations in the relevant region
missing=()

if ! grep -qE '"skill"[[:space:]]*:[[:space:]]*"[^"]*finishing-work[^"]*"' "$search_file" 2>/dev/null; then
    missing+=("finishing-work")
fi

# Check for session notes write in the relevant region
if ! grep -qE '"(Write|Edit)".*session-notes/' "$search_file" 2>/dev/null; then
    missing+=("session-notes (Write/Edit to ~/.claude/session-notes/)")
fi

# Clean up temp file if we created one
if [[ -n "$last_commit_line" ]]; then
    rm -f "$search_file"
fi

if [[ ${#missing[@]} -gt 0 ]]; then
    missing_list=$(printf ', %s' "${missing[@]}")
    missing_list=${missing_list:2}  # trim leading ", "
    echo "BLOCKED: Missing before commit: ${missing_list}. finishing-work is required before every commit. Session notes must be updated at every commit. (reviewing-code is enforced at PR creation via pr-gate.sh)" >&2
    exit 2
fi

# --- Phase 2: Timeline extraction for compliance reviewer ---
# Extract a compact summary from the transcript for the agent hook to analyze.
# This runs only when Phase 1 passed (skills + session notes verified).

# session_id already read above (line 33); default to "unknown" for logging
session_id="${session_id:-unknown}"
summary_file="/tmp/claude-compliance-summary-${session_id}.txt"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
extractor="${SCRIPT_DIR}/extract-timeline.sh"

if [[ -x "$extractor" ]]; then
    "$extractor" "$transcript_path" > "$summary_file" 2>/dev/null || true

    # Log pre-filter phase
    log_dir="$HOME/.claude/logs"
    mkdir -p "$log_dir" 2>/dev/null || true
    summary_lines=$(wc -l < "$summary_file" 2>/dev/null || echo 0)
    summary_lines=$(echo "$summary_lines" | tr -d ' ')
    jq -n -c \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg sid "$session_id" \
        --arg phase "prefilter" \
        --argjson lines "$summary_lines" \
        '{ timestamp: $ts, session_id: $sid, phase: $phase, summary_lines: $lines }' \
        >> "$log_dir/compliance-review.jsonl" 2>/dev/null || true
fi

# All checks passed — auto-approve (no manual permission prompt)
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"All commit requirements verified: finishing-work, session-notes"}}'
exit 0
