#!/bin/bash
# Blocks dangerous git operations: force push, reset --hard, --no-verify, push to main

set -euo pipefail

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

# Block bare force push (allow --force-with-lease which is safe after rebase)
if echo "$GIT_LINES" | grep -qE 'git\s+push\s+.*(-f\b|-f[a-zA-Z]|--force\b)'; then
  if ! echo "$GIT_LINES" | grep -q -- '--force-with-lease'; then
    echo "BLOCKED: Force push is not allowed. Use --force-with-lease or ask the user." >&2
    exit 2
  fi
fi

# Block reset --hard
if echo "$GIT_LINES" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard can destroy work. Use git stash or ask the user." >&2
  exit 2
fi

# Block --no-verify on git commands
if echo "$GIT_LINES" | grep -qE 'git\s+.*--no-verify'; then
  echo "BLOCKED: --no-verify skips safety hooks. Fix the underlying issue instead." >&2
  exit 2
fi

# Block push to main/master
if echo "$GIT_LINES" | grep -qE 'git\s+push\s+(origin\s+)?(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master. Create a PR instead." >&2
  exit 2
fi

# Safe git commands — auto-approve to reduce permission prompts
if echo "$GIT_LINES" | grep -qE 'git\s+(status|diff|log|branch|stash|fetch|rev-parse|remote|show)\b'; then
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
