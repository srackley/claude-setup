#!/bin/bash
# PreToolUse hook on Bash — blocks gh pr create until all conditions are met.
#
# Four conditions must all be true before gh pr create is allowed:
# 1. /tmp/pr-verification-<session_id>.md exists with > 200 chars of content
# 2. The current transcript shows Claude wrote that exact file in this session
# 3. The reviewing-code skill was invoked this session
# 4. A gh issue comment was posted OR no-issues escape hatch declared
#
# On success: outputs permissionDecision "allow" (bypasses allowlist check)
# On failure: exits 2 + stderr block message with exact filename Claude must write
#
# The token file is NOT deleted on success — it's a reference artifact.
#
# Known limitation: transcript JSONL schema is not a public API. If Claude Code
# changes the format, this hook may start blocking with confusing errors or
# silently stop enforcing. Smoke-test periodically by verifying a blocked
# attempt produces the expected error message.

set -euo pipefail

input=$(cat)

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# Only intercept gh pr create commands
if ! echo "$command" | grep -qE '(^|&&|;|\|)\s*gh\s+pr\s+create(\s|$)'; then
    exit 0
fi

session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

# Fail-safe: if no session_id, block with explanation
if [[ -z "$session_id" ]]; then
    echo "BLOCKED: Cannot verify PR verification artifact (session_id unavailable in hook input). Create the verification table and retry." >&2
    exit 2
fi

token_file="/tmp/pr-verification-${session_id}.md"

# --- Condition 1: token file must exist with real content (> 200 chars) ---
if [[ ! -f "$token_file" ]]; then
    cat >&2 << EOF
BLOCKED: No PR verification artifact found.

Before running gh pr create, you must:
1. Read the plan/handoff for this branch (check memory/handoffs/<branch>.md)
2. For each task in the plan, read the actual implementation files (don't grep)
3. Write a verification table to: ${token_file}
   Format:
   | Task | Plan Spec | Actual Implementation | Match? | Notes |
   |------|-----------|-----------------------|--------|-------|
   | ...  | ...       | ...                   | YES/NO | ...   |
4. Tell the user: "I've written the verification table. Please review it before I proceed."
5. Wait for explicit user sign-off
6. Then retry gh pr create

"Looks right" is not verification. Grep-checking that functions exist is not verification.
Read the files. Write the table. Get sign-off.
EOF
    exit 2
fi

file_size=$(wc -c < "$token_file" 2>/dev/null || echo 0)
file_size=$(echo "$file_size" | tr -d ' ')
if [[ "$file_size" -lt 200 ]]; then
    cat >&2 << EOF
BLOCKED: PR verification artifact exists but is too short (${file_size} chars, minimum 200).

The table at ${token_file} must contain a real task-by-task comparison.
Write the full verification table with one row per task, then retry.
EOF
    exit 2
fi

# --- Condition 2: transcript must show Claude wrote the token file this session ---
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    cat >&2 << EOF
BLOCKED: Cannot verify that verification table was written in this session (transcript unavailable).

Write the verification table to ${token_file}, show the user, get sign-off, then retry.
EOF
    exit 2
fi

# Look for a Write tool call to this exact file in the transcript
# Handles both "tool_name":"Write" (test format) and "name":"Write" (real transcript format)
write_found=$(grep -E '"(name|tool_name)":"Write"' "$transcript_path" 2>/dev/null \
    | grep -F "\"${token_file}\"" \
    || true)

if [[ -z "$write_found" ]]; then
    cat >&2 << EOF
BLOCKED: Token file ${token_file} exists but no Write to it was found in this session's transcript.

You must write the verification table using the Write tool in this session (not manually create the file).
Write the table, show the user, get sign-off, then retry gh pr create.
EOF
    exit 2
fi

# --- Condition 3: transcript must show reviewing-code was invoked this session ---
reviewing_code_found=$(grep -E '"skill"[[:space:]]*:[[:space:]]*"[^"]*reviewing-code[^"]*"' "$transcript_path" 2>/dev/null || true)

if [[ -z "$reviewing_code_found" ]]; then
    cat >&2 << EOF
BLOCKED: reviewing-code skill was not invoked in this session.

Before running gh pr create, you must:
1. Invoke the reviewing-code skill to run the full 5-agent code review loop
2. Address any issues found
3. Write the verification table to: ${token_file}
4. Get user sign-off
5. Then retry gh pr create
EOF
    exit 2
fi

# --- Condition 4: GitHub issue comment must have been posted this session ---
# Require evidence that Claude posted a progress comment on a related issue,
# OR that Claude explicitly declared no issues apply for this branch.
#
# Two valid states:
#   1. gh issue comment command found in transcript this session
#   2. /tmp/no-issues-<session_id>.txt exists (escape hatch with reason)
no_issues_file="/tmp/no-issues-${session_id}.txt"

if [[ ! -f "$no_issues_file" ]]; then
    issue_comment_found=$(grep -E '"command"[[:space:]]*:[[:space:]]*"[^"]*gh issue comment[^"]*"' "$transcript_path" 2>/dev/null || true)

    if [[ -z "$issue_comment_found" ]]; then
        cat >&2 << EOF
BLOCKED: No GitHub issue update found before PR creation.

Before running gh pr create, either:
1. Post a progress comment on the related GitHub issue:
     gh issue comment <number> --body "Progress: <what was done>"
   Then retry gh pr create.

2. If there are genuinely no related issues, declare it:
     echo "no related issues: <reason>" > /tmp/no-issues-${session_id}.txt
   Then retry gh pr create.
EOF
        exit 2
    fi
fi

# --- All conditions met — allow ---
echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","permissionDecisionReason":"PR gate passed: reviewing-code invoked, verification table written and signed off, issue comment posted or no-issues declared"}}'
exit 0
