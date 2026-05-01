#!/bin/bash
# Blocks dangerous git operations: force push, reset --hard, --no-verify, push to main.
# Auto-approves safe read-only commands (status, diff, log, fetch, rev-parse, show)
# to reduce permission prompts. branch and remote are NOT auto-approved — both have
# destructive subcommands (branch -D, remote remove/set-url).

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

# Normalize: strip global git path options and flags so the subcommand pattern matches.
# -C, --git-dir, --work-tree all appear before the subcommand in the same position.
# Three passes for -C; four for --git-dir/--work-tree (which also support = syntax).
# -c key=val, --no-pager, --bare, --exec-path are also leading global flags git accepts.
NORMALIZED_LINES=$(echo "$GIT_LINES" \
  | sed "s/ -C '[^']*'//g"          | sed 's/ -C "[^"]*"//g'          | sed 's/ -C [^ ]*//g' \
  | sed "s/ --git-dir '[^']*'//g"   | sed 's/ --git-dir "[^"]*"//g'   | sed 's/ --git-dir=[^ ]*//g'   | sed 's/ --git-dir [^ ]*//g' \
  | sed "s/ --work-tree '[^']*'//g" | sed 's/ --work-tree "[^"]*"//g' | sed 's/ --work-tree=[^ ]*//g' | sed 's/ --work-tree [^ ]*//g' \
  | sed 's/ -c [^ ]*//g' \
  | sed 's/ --no-pager//g' \
  | sed 's/ --bare//g' \
  | sed 's/ --exec-path[^ ]*//g')

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
  if echo "$line" | grep -qE 'git\s+push\b.*( -f\b| -f[a-zA-Z]|--force( |$)|[ \t]\+[^ ]+)'; then
    if ! echo "$line" | grep -q -- '--force-with-lease'; then
      echo "BLOCKED: Force push is not allowed. Use --force-with-lease or ask the user." >&2
      exit 2
    fi
    # --force alongside --force-with-lease overrides the lease check in git
    if echo "$line" | grep -qE '(^| )(-f\b|--force( |$))'; then
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

# Block push to main/master — positional arg (any remote name), +refspec prefix,
# colon refspec (HEAD:main), or full refs/heads/main path.
# Strip surrounding quotes first so `git push origin 'main'` is not bypassed.
DEQUOTED=$(echo "$SPLIT_LINES" | tr -d "'\"")
if echo "$DEQUOTED" | grep -qE 'git\s+push\s+(\S+\s+)?\+?(main|master)\b|git\s+push\s+.*:(main|master)\b|git\s+push\s+.*/heads/(main|master)\b'; then
  echo "BLOCKED: Direct push to main/master. Create a PR instead." >&2
  exit 2
fi
# --mirror and --all push all branches unconditionally, which includes main.
if echo "$SPLIT_LINES" | grep -qE 'git\s+push\s+.*(--mirror|--all)\b'; then
  echo "BLOCKED: --mirror and --all push all branches including main. Use explicit branch names instead." >&2
  exit 2
fi

# Safe git commands — auto-approve only when ALL fragments (including non-git ones) are safe.
# Use ALL_SPLIT (not SPLIT_LINES) because SPLIT_LINES is already filtered to git-only; non-git
# fragments chained with ; | & < > would be invisible to a SPLIT_LINES check and auto-approved.
# stdout must stay clean for this JSON to parse; send any debug output to >&2.
ALL_SPLIT=$(echo "$NORMALIZED_LINES" | sed 's/&&/\n/g' | sed 's/||/\n/g' | sed 's/[;|&<>]/\n/g' | grep -vE '^\s*$' || true)
if [ -n "$ALL_SPLIT" ] && ! echo "$ALL_SPLIT" | grep -vE '^\s*git\s+(status|diff|log|fetch|rev-parse|show)\b' | grep -qE '^\s*\S'; then
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
