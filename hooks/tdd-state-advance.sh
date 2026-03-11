#!/bin/bash
# PostToolUse + PostToolUseFailure hook on Bash — advances TDD state machine.
#
# CRITICAL API DETAIL: PostToolUse fires ONLY on success (exit 0).
# PostToolUseFailure fires ONLY on failure (non-zero exit).
# There is no exit_code field. Success/failure is determined by which event fires.
# This single script is registered on BOTH events.
#
# State transitions:
#   TDD-RED    + failure → TDD-GREEN    (test written and fails, now implement)
#   TDD-RED    + success → TDD-RED      (tests should fail first!)
#   TDD-GREEN  + success → TDD-REFACTOR (tests pass, now refactor)
#   TDD-GREEN  + failure → TDD-GREEN    (keep working on implementation)
#   TDD-REFACTOR + success → TDD-RED    (next cycle)
#   TDD-REFACTOR + failure → TDD-REFACTOR (fix the refactoring)
#   NONE       → no-op
#
# State file: TDD_STATE_FILE env var (testing) or /tmp/claude-tdd-state-${session_id}.json

set -euo pipefail

if ! command -v jq &>/dev/null; then
    echo "tdd-state-advance: jq not found, TDD state advance disabled" >&2
    exit 0
fi

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# Only handle Bash tool
if [[ "$tool_name" != "Bash" ]]; then
    exit 0
fi

command=$(echo "$input" | jq -r '.tool_input.command // empty' 2>/dev/null)

# --- Detect test commands ---
if ! echo "$command" | grep -qE '(^|\s|/)(task\s+test(:\S+)?|npm\s+(run\s+)?test|pnpm\s+(run\s+)?test|yarn\s+test|pnpm\s+vitest|vitest|npx\s+(jest|vitest)|jest|pytest|bats|cargo\s+test|go\s+test)(\s|$|\||;|&|>)'; then
    exit 0
fi

# --- Read state ---
if [[ -z "${TDD_STATE_FILE:-}" ]]; then
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
    state_file="/tmp/claude-tdd-state-${session_id}.json"
else
    state_file="$TDD_STATE_FILE"
fi

if [[ ! -f "$state_file" ]]; then
    exit 0
fi

state=$(jq -r '.state // "NONE"' "$state_file" 2>/dev/null) || {
    echo "tdd-state-advance: corrupt state file $state_file, falling open" >&2
    state="NONE"
}

if [[ "$state" == "NONE" || "$state" == "null" ]]; then
    exit 0
fi

# --- Determine success/failure from hook event name ---
hook_event=$(echo "$input" | jq -r '.hook_event_name // empty' 2>/dev/null)
if [[ -z "$hook_event" ]]; then
    echo "tdd-state-advance: hook_event_name missing, cannot determine test outcome — skipping" >&2
    exit 0
fi
tests_passed=true
if [[ "$hook_event" == "PostToolUseFailure" ]]; then
    tests_passed=false
fi

# --- Advance state ---
new_state="$state"

case "$state" in
    TDD-RED)
        if [[ "$tests_passed" == false ]]; then
            new_state="TDD-GREEN"
        fi
        ;;
    TDD-GREEN)
        if [[ "$tests_passed" == true ]]; then
            new_state="TDD-REFACTOR"
        fi
        ;;
    TDD-REFACTOR)
        if [[ "$tests_passed" == true ]]; then
            new_state="TDD-RED"
        fi
        ;;
    *)
        echo "tdd-state-advance: unrecognized state '$state', no transition" >&2
        ;;
esac

# Write new state only if changed (atomic: write to temp, then mv)
if [[ "$new_state" != "$state" ]]; then
    tmp_state=$(mktemp "${state_file}.XXXXXX")
    if jq -n \
        --arg s "$new_state" \
        --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg prev "$state" \
        '{ state: $s, updated_at: $t, previous_state: $prev }' > "$tmp_state"; then
        mv "$tmp_state" "$state_file"
    else
        echo "tdd-state-advance: failed to write state transition $state → $new_state" >&2
        rm -f "$tmp_state"
    fi
fi

exit 0
