#!/bin/bash
# Blocks dangerous git operations: force push, reset --hard, --no-verify, push to main.
# Auto-approves safe read-only commands (status, diff, log, branch, fetch, rev-parse,
# remote, show) to reduce permission prompts.

set -euo pipefail

if ! command -v jq &>/dev/null; then
  echo "BLOCKED: git-safety hook requires jq. Install jq to continue." >&2
  exit 2
fi

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Extract only lines that start with git commands (ignore heredocs, strings, PR bodies)
GIT_LINES=$(echo "$COMMAND" | grep -E '^\s*git\s+' || true)

if [ -z "$GIT_LINES" ]; then
  exit 0
fi

# Normalize: strip -C <path> so 'git -C /repo push -f' matches push patterns.
# Three passes handle single-quoted, double-quoted, and unquoted paths.
NORMALIZED_LINES=$(echo "$GIT_LINES" \
  | sed "s/ -C '[^']*'//g" \
  | sed 's/ -C "[^"]*"//g' \
  | sed 's/ -C [^ ]*//g')

# Block bare force push (allow --force-with-lease which is safe after rebase).
# Check per-line so --force-with-lease on one line can't excuse --force on another.
# The || [[ -n "$line" ]] handles the last line when it has no trailing newline.
while IFS= read -r line || [[ -n "$line" ]]; do
  if echo "$line" | grep -qE 'git\s+push\s+.*(-f\b|-f[a-zA-Z]|--force\b)'; then
    if ! echo "$line" | grep -q -- '--force-with-lease'; then
      echo "BLOCKED: Force push is not allowed. Use --force-with-lease or ask the user." >&2
      exit 2
    fi
  fi
done <<< "$NORMALIZED_LINES"

# Block reset --hard
if echo "$NORMALIZED_LINES" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard can destroy work. Use git stash or ask the user." >&2
  exit 2
fi

# Block --no-verify on git commands
if echo "$NORMALIZED_LINES" | grep -qE 'git\s+.*--no-verify'; then
  echo "BLOCKED: --no-verify skips safety hooks. Fix the underlying issue instead." >&2
  exit 2
fi

# Block push to main/master — positional arg or refspec syntax (HEAD:main)
if echo "$NORMALIZED_LINES" | grep -qE 'git\s+push\s+(origin\s+)?(main|master)\b|git\s+push\s+.*:(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master. Create a PR instead." >&2
  exit 2
fi

# Safe git commands — auto-approve to reduce permission prompts.
# stdout must stay clean for this JSON to parse; send any debug output to >&2.
if echo "$NORMALIZED_LINES" | grep -qE 'git\s+(status|diff|log|branch|fetch|rev-parse|remote|show)\b'; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Safe read-only git command"
  }
}
EOF
  exit 0
fi

exit 0
