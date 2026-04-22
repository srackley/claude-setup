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
# Also handles worktree pattern: "git -C /path commit" (single -C flag only;
# paths with spaces are not matched — .worktrees/ paths don't contain spaces)
if ! echo "$command" | grep -qE '(^|&&|;)\s*git\s+(-C\s+\S+\s+)?commit(\s|$)'; then
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

# Fallback: transcript_path is missing or stale when the session CWD changes
# (e.g., after EnterWorktree). Search by session_id across all project dirs.
if [[ (-z "$transcript_path" || ! -f "$transcript_path") && -n "$session_id" ]]; then
    transcript_path=$(find "$HOME/.claude/projects" -name "${session_id}.jsonl" -maxdepth 2 2>/dev/null | head -1)
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
# Uses a marker file written by commit-success-marker.sh (PostToolUse hook).
# The marker records the transcript line count after each successful commit.
# Blocked commits never fire PostToolUse, so the anchor never shifts on failed
# retries — this prevents the cascade bug where each blocked attempt shifted
# the search window past valid skill invocations.
marker_file="/tmp/last-commit-${session_id}.line"
if [[ -n "$session_id" && -f "$marker_file" ]]; then
    last_commit_line=$(cat "$marker_file")
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

# --- Phase 3: GitHub issue update check ---
# Require evidence that Claude posted a progress comment on a related issue,
# OR that Claude explicitly declared no issues apply for this branch.
#
# Two valid states:
#   1. gh issue comment command found in transcript since last commit
#   2. /tmp/no-issues-<session_id>.txt exists (escape hatch with reason)

no_issues_file="/tmp/no-issues-${session_id}.txt"

if [[ ! -f "$no_issues_file" ]]; then
    # Re-open search_file region (may have been cleaned up above)
    if [[ -n "$last_commit_line" ]]; then
        search_file_issues=$(mktemp /tmp/claude-commit-gate-issues-XXXXXX)
        tail -n +"$((last_commit_line + 1))" "$transcript_path" > "$search_file_issues"
    else
        search_file_issues="$transcript_path"
    fi

    issue_comment_found=$(grep -E '"command"[[:space:]]*:[[:space:]]*"[^"]*gh issue comment[^"]*"' "$search_file_issues" 2>/dev/null || true)

    if [[ -n "$last_commit_line" ]]; then
        rm -f "$search_file_issues"
    fi

    if [[ -z "$issue_comment_found" ]]; then
        cat >&2 << EOF
BLOCKED: No GitHub issue update found before this commit.

Before committing, either:
1. Post a progress comment on related GitHub issues:
     gh issue comment <number> --body "Progress: <what was done/discovered>"
   Then retry the commit.

2. If there are genuinely no related issues, declare it:
     echo "no related issues: <reason>" > /tmp/no-issues-${session_id}.txt
   Then retry the commit.
EOF
        exit 2
    fi
fi

# All checks passed — auto-approve (no manual permission prompt)
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"All commit requirements verified: finishing-work, session-notes"}}'
exit 0
