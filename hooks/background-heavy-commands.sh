#!/usr/bin/env bash
# Force background execution for heavy task commands to reduce context flooding.
# Targets: task test, task test-e2e, task storybook-test, task lint, task lint-types
#
# Backgrounding is the mechanism that keeps heavy output out of context: the harness
# writes the FULL log to a file and returns a one-line exit-code notification. A pipe
# like `| tail -8` is the old, lossy way to do the same thing — but piping masks the
# exit code (the reported status is the pipeline's, i.e. tail's 0) and truncates the
# captured log. So before running, we deal with pipes regardless of fore/background:
#   - a trailing truncating pipe (| tail / | head) is redundant (or, for foreground
#     single-file runs, actively harmful) — strip it
#   - any other filter pipe (| grep, | wc, ...) would still mask the exit code, but
#     stripping it would change what the agent asked for — block with guidance instead
#
# Targeted single-file test runs (task test ... foo.test.ts) stay in the FOREGROUND:
# they produce bounded output and the TDD state machine needs their real exit code. They
# still get the pipe treatment above — a foreground `| tail` masks the exit code just as
# badly as a backgrounded one.

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
ALREADY_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false')

if [[ "$ALREADY_BG" == "true" ]]; then
  exit 0
fi

# Classify the command. Single-file test runs stay foreground; other heavy commands get
# backgrounded; everything else is none of our business.
FOREGROUND=false
if echo "$COMMAND" | grep -qE 'task test[[:space:]].*\.(test|spec)\.(ts|tsx|js|jsx)'; then
  FOREGROUND=true
elif ! echo "$COMMAND" | grep -qE '(^|/)task (test|test-e2e|storybook-test|lint|lint-types)([[:space:]]|$)'; then
  exit 0
fi

# Strip any trailing truncating pipes (| tail / | head), looping to handle chains like
# `| tail | head`. Anchored at end-of-string and keyed on the filter command name, so a
# quoted pipe in an argument (e.g. -t 'foo|bar') is never matched.
STRIPPED="$COMMAND"
while :; do
  NEW=$(printf '%s' "$STRIPPED" | sed -E 's/[[:space:]]*\|[[:space:]]*(tail|head)([[:space:]]+[^|]*)?[[:space:]]*$//')
  [[ "$NEW" == "$STRIPPED" ]] && break
  STRIPPED="$NEW"
done

# If a non-truncating filter pipe remains, stripping it would change the agent's intent
# (e.g. a count or a filtered view). Block and explain the lossless pattern instead.
# Keyed on a known filter command right after the pipe so a quoted `|` won't false-trigger.
if printf '%s' "$STRIPPED" | grep -qE '\|[[:space:]]*(grep|awk|sed|wc|less|more|cat|sort|uniq|jq|cut|xargs|column|tr|fmt|nl)\b'; then
  echo "BLOCKED: Piping a heavy 'task' command masks its exit code (the reported status is the pipe's, not the task's) and truncates the captured log. Backgrounded runs write the FULL output to a file; foreground single-file runs need the real exit code for the TDD state machine. Run it bare (drop the pipe), then grep/tail the output afterward. Trailing '| tail'/'| head' are stripped automatically; other pipes are blocked." >&2
  exit 2
fi

if [[ "$FOREGROUND" == "true" ]]; then
  # Keep it foreground (real exit code for TDD). Only rewrite when we actually stripped a
  # pipe — otherwise stay silent so the command runs untouched.
  if [[ "$STRIPPED" != "$COMMAND" ]]; then
    UPDATED_INPUT=$(echo "$INPUT" | jq --arg cmd "$STRIPPED" '.tool_input + {command: $cmd}')
    printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":%s}}' "$UPDATED_INPUT"
  fi
  exit 0
fi

UPDATED_INPUT=$(echo "$INPUT" | jq --arg cmd "$STRIPPED" '.tool_input + {command: $cmd, run_in_background: true}')
printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":%s}}' "$UPDATED_INPUT"
