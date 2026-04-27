#!/usr/bin/env bash
# Force background execution for heavy task commands to reduce context flooding.
# Targets: task test, task test-e2e, task storybook-test, task lint, task lint-types

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
ALREADY_BG=$(echo "$INPUT" | jq -r '.tool_input.run_in_background // false')

if [[ "$ALREADY_BG" == "true" ]]; then
  exit 0
fi

# Don't background targeted single-file test runs — they produce bounded output
# and need a real exit code for the TDD state machine to advance correctly.
# Scoped to "task test" only (not lint, not test-e2e) since those run slow.
if echo "$COMMAND" | grep -qE 'task test[[:space:]].*\.(test|spec)\.(ts|tsx|js|jsx)'; then
  exit 0
fi

if echo "$COMMAND" | grep -qE '(^|/)task (test|test-e2e|storybook-test|lint|lint-types)([[:space:]]|$)'; then
  UPDATED_INPUT=$(echo "$INPUT" | jq '.tool_input + {"run_in_background": true}')
  printf '{"hookSpecificOutput":{"hookEventName":"PreToolUse","updatedInput":%s}}' "$UPDATED_INPUT"
fi
