#!/bin/bash
# PreToolUse hook: enforces session notes entry format
# Blocks Write/Edit to session-notes/*.md unless content contains ## YYYY-MM-DD heading.

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only handle Edit and Write tools
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
    exit 0
fi

# Only handle session-notes files
if [[ "$file_path" != *"/session-notes/"*".md" ]]; then
    exit 0
fi

# Get the content being written/edited
if [[ "$tool_name" == "Write" ]]; then
    content=$(echo "$input" | jq -r '.tool_input.content // empty' 2>/dev/null)
else
    content=$(echo "$input" | jq -r '.tool_input.new_string // empty' 2>/dev/null)
fi

# Check for a dated entry heading (## 20YY-...)
if echo "$content" | grep -qE '^## \[?20[0-9]{2}-'; then
    exit 0
fi

cat << 'EOF'
{"decision": "block", "reason": "STOP: Session notes must use a dated entry heading.\n\nRequired format:\n\n## YYYY-MM-DD: Brief description\n\n### Context\n...\n\nUsing `# title` or `## heading-without-date` makes the file invisible to `get_recent_session_notes` at session start. Fix the heading before writing."}
EOF
exit 0
