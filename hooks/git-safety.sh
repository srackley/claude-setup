#!/bin/bash
# Blocks dangerous git operations: force push, reset --hard, --no-verify, push to main.
# Auto-approves safe non-destructive commands (status, diff, log, branch, fetch, rev-parse,
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

# Normalize: strip global git path options so the subcommand pattern matches.
# -C, --git-dir, --work-tree all appear before the subcommand in the same position.
# Three passes for -C; four for --git-dir/--work-tree (which also support = syntax).
NORMALIZED_LINES=$(echo "$GIT_LINES" \
  | sed "s/ -C '[^']*'//g"          | sed 's/ -C "[^"]*"//g'          | sed 's/ -C [^ ]*//g' \
  | sed "s/ --git-dir '[^']*'//g"   | sed 's/ --git-dir "[^"]*"//g'   | sed 's/ --git-dir=[^ ]*//g'   | sed 's/ --git-dir [^ ]*//g' \
  | sed "s/ --work-tree '[^']*'//g" | sed 's/ --work-tree "[^"]*"//g' | sed 's/ --work-tree=[^ ]*//g' | sed 's/ --work-tree [^ ]*//g')

# Split on inline shell operators (;, |, &) so chained commands can't smuggle a force
# push past a --force-with-lease on the same physical line. Re-filter for git commands.
SPLIT_LINES=$(echo "$NORMALIZED_LINES" | sed 's/&&/\n/g' | sed 's/||/\n/g' | sed 's/[;|&]/\n/g' | grep -E '^\s*git\s+' || true)

if [ -z "$SPLIT_LINES" ]; then
  exit 0
fi

# Block bare force push (allow --force-with-lease alone, which is safe after rebase).
# +<refspec> is git's per-refspec force syntax — treat it as a force push.
# Check per-line so --force-with-lease on one line can't excuse --force on another.
# The || [[ -n "$line" ]] handles the last line when it has no trailing newline.
while IFS= read -r line || [[ -n "$line" ]]; do
  if echo "$line" | grep -qE 'git\s+push\b.*([^-]-f\b|[^-]-f[a-zA-Z]|--force( |$)|[ \t]\+[^ ]+)'; then
    if ! echo "$line" | grep -q -- '--force-with-lease'; then
      echo "BLOCKED: Force push is not allowed. Use --force-with-lease or ask the user." >&2
      exit 2
    fi
    # --force alongside --force-with-lease overrides the lease check in git
    if echo "$line" | grep -qE '(^| )(-f\b|-f[a-zA-Z]|--force( |$))'; then
      echo "BLOCKED: --force overrides --force-with-lease. Use --force-with-lease alone." >&2
      exit 2
    fi
    # +<refspec> targeting main/master is still a push to main — block regardless of lease
    if echo "$line" | grep -qE '[ \t]\+(main|master)\b'; then
      echo "BLOCKED: Force push to main/master is not allowed. Create a PR instead." >&2
      exit 2
    fi
  fi
done <<< "$SPLIT_LINES"

# Block reset --hard
if echo "$SPLIT_LINES" | grep -qE 'git\s+reset\s+--hard'; then
  echo "BLOCKED: git reset --hard can destroy work. Use git stash or ask the user." >&2
  exit 2
fi

# Block --no-verify on git commands
if echo "$SPLIT_LINES" | grep -qE 'git\s+.*--no-verify'; then
  echo "BLOCKED: --no-verify skips safety hooks. Fix the underlying issue instead." >&2
  exit 2
fi

# Block push to main/master — positional arg, +refspec prefix, colon refspec (HEAD:main),
# or full refs/heads/main path.
if echo "$SPLIT_LINES" | grep -qE 'git\s+push\s+(origin\s+)?\+?(main|master)\b|git\s+push\s+.*:(main|master)\b|git\s+push\s+.*/heads/(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master. Create a PR instead." >&2
  exit 2
fi
# --mirror and --all push all branches unconditionally, which includes main.
if echo "$SPLIT_LINES" | grep -qE 'git\s+push\s+.*(--mirror|--all)\b'; then
  echo "BLOCKED: --mirror and --all push all branches including main. Use explicit branch names instead." >&2
  exit 2
fi

# Safe git commands — auto-approve only when ALL split commands are on the safe list.
# stdout must stay clean for this JSON to parse; send any debug output to >&2.
if ! echo "$SPLIT_LINES" | grep -vE 'git\s+(status|diff|log|branch|fetch|rev-parse|remote|show)\b' | grep -qE '^\s*git\s+'; then
  cat <<EOF
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "allow",
    "permissionDecisionReason": "Safe non-destructive git command"
  }
}
EOF
  exit 0
fi

exit 0
