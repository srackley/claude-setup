#!/bin/bash
# PreToolUse hook for Agent (Task) tool
# Blocks docs-researcher dispatch if ~/.claude/research/ hasn't been read/grepped
# in the current session transcript. Pattern mirrors skill-enforcement.sh.

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
subagent_type=$(echo "$input" | jq -r '.tool_input.subagent_type // empty' 2>/dev/null)

# Only intercept docs-researcher dispatches
if [[ "$tool_name" != "Task" ]] || [[ "$subagent_type" != "docs-researcher" ]]; then
    exit 0
fi

# If no research files exist, nothing to check — allow dispatch
RESEARCH_DIR="${HOME}/.claude/research"
if ! ls "${RESEARCH_DIR}"/*.md 2>/dev/null | head -1 | grep -q .; then
    exit 0
fi

# Check transcript for a prior Read or Grep on the research directory
# Fail-closed: missing/unreadable transcript → block (same pattern as skill-enforcement.sh)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)

research_checked() {
    local transcript="$1"
    if [[ -z "$transcript" || ! -f "$transcript" ]]; then
        return 1
    fi
    if grep -qE '"file_path"[[:space:]]*:[[:space:]]*"[^"]*\.claude/research' "$transcript" 2>/dev/null; then
        return 0
    fi
    if grep -qE '"path"[[:space:]]*:[[:space:]]*"[^"]*\.claude/research' "$transcript" 2>/dev/null; then
        return 0
    fi
    return 1
}

if research_checked "$transcript_path"; then
    exit 0
fi

# Build file list (most recent first, max 10)
file_list=""
while IFS= read -r f; do
    file_list="${file_list}\n- $(basename "$f")"
done < <(ls -t "${RESEARCH_DIR}"/*.md 2>/dev/null | head -10)

cat << EOF
{"decision": "block", "reason": "STOP: Before dispatching docs-researcher, check existing research files.\n\nResearch files in ~/.claude/research/ (most recent first):${file_list}\n\nRead any relevant files first. Only dispatch if the question isn't covered or findings are stale."}
EOF
