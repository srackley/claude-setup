#!/bin/bash
# PreToolUse hook on Edit/Write — enforces TDD state machine.
#
# Reads TDD workflow state from a session-scoped state file and warns when
# edits target the wrong file type for the current state:
#   NONE       → all edits allowed (default, non-TDD work)
#   TDD-RED    → test files only (write failing tests first)
#   TDD-GREEN  → source files only (make tests pass)
#   TDD-REFACTOR → both test and source files
#
# Currently in WARN mode (not block). Intended to promote to block mode
# after measuring false positive rate — that toggle is not yet implemented.
# Design: ~/.claude/tasks/enforcement-strategy-design.md
#
# State file: TDD_STATE_FILE env var (testing) or /tmp/claude-tdd-state-${session_id}.json
# session_id comes from stdin JSON (common input field), NOT an env var.
# Fail-open: missing or corrupt state file → NONE (all edits allowed)

set -euo pipefail

if ! command -v jq &>/dev/null; then
    echo "tdd-state-machine: jq not found, TDD enforcement disabled" >&2
    exit 0
fi

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)

# Only handle Edit and Write
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
    exit 0
fi

file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
if [[ -z "$file_path" ]]; then
    exit 0
fi

filename=$(basename "$file_path")

# --- Always-editable files (bypass TDD state entirely) ---
# These never require TDD regardless of state.

# Markdown, JSON, YAML, config, CSS, and story files
case "$filename" in
    *.md|*.json|*.yaml|*.yml|*.css|*.scss) exit 0 ;;
    *.config.*|*.config) exit 0 ;;
    *.stories.ts|*.stories.tsx|*.stories.js|*.stories.jsx) exit 0 ;;
esac

# Paths that are always editable
case "$file_path" in
    */docs/*|*/.docs/*|*/.claude/*|*/session-notes/*) exit 0 ;;
    */CLAUDE.md) exit 0 ;;
    */src/config/*) exit 0 ;;
esac

# --- Read TDD state ---
# session_id is in stdin JSON, not an env var. TDD_STATE_FILE overrides for testing.

if [[ -z "${TDD_STATE_FILE:-}" ]]; then
    session_id=$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)
    state_file="/tmp/claude-tdd-state-${session_id}.json"
else
    state_file="$TDD_STATE_FILE"
fi

# --- Initialize state from transcript (if TDD skill was invoked) ---
if [[ ! -f "$state_file" ]]; then
    transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
    if [[ -n "$transcript_path" && -f "$transcript_path" ]]; then
        if grep -qE '"skill"[[:space:]]*:[[:space:]]*"[^"]*test-driven-development[^"]*"' "$transcript_path" 2>/dev/null; then
            # TDD skill was invoked but no state file → initialize to RED
            tmp_init=$(mktemp "${state_file}.XXXXXX")
            if jq -n \
                --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
                '{ state: "TDD-RED", updated_at: $t }' > "$tmp_init"; then
                mv "$tmp_init" "$state_file"
            else
                echo "tdd-state-machine: failed to initialize state file" >&2
                rm -f "$tmp_init"
                exit 0
            fi
            # Fall through to normal state enforcement below
        else
            exit 0
        fi
    else
        exit 0
    fi
fi

state=$(jq -r '.state // "NONE"' "$state_file" 2>/dev/null) || {
    echo "tdd-state-machine: corrupt state file $state_file, falling open" >&2
    state="NONE"
}

# NONE or unrecognized state → allow everything
if [[ "$state" == "NONE" || "$state" == "null" ]]; then
    exit 0
fi

# --- Classify the file being edited ---

is_test_file=false
case "$filename" in
    *.test.ts|*.test.tsx|*.test.js|*.test.jsx) is_test_file=true ;;
    *.spec.ts|*.spec.tsx|*.spec.js|*.spec.jsx) is_test_file=true ;;
    *.bats|test_*.py|*_test.py|*_test.go) is_test_file=true ;;
esac

# --- Logging helper ---
log_block() {
    local reason="$1"
    local log_dir="$HOME/.claude/logs"
    mkdir -p "$log_dir" 2>/dev/null || true
    jq -n -c \
        --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg sid "$(echo "$input" | jq -r '.session_id // "unknown"' 2>/dev/null)" \
        --arg st "$state" \
        --arg fp "$file_path" \
        --arg tl "$tool_name" \
        --arg reason "$reason" \
        '{ timestamp: $ts, session_id: $sid, state: $st, file: $fp, tool: $tl, reason: $reason }' \
        >> "$log_dir/tdd-enforcement.jsonl" 2>/dev/null || true
}

# --- Apply state constraints ---

case "$state" in
    TDD-RED)
        # Only test files allowed
        if [[ "$is_test_file" == false ]]; then
            log_block "source file edit in RED state"
            echo "BLOCKED: TDD state is RED — write a failing test first, not source files." >&2
            exit 2
        fi
        ;;
    TDD-GREEN)
        # Only source files allowed (not test files)
        if [[ "$is_test_file" == true ]]; then
            log_block "test file edit in GREEN state"
            echo "BLOCKED: TDD state is GREEN — write the minimal implementation to make tests pass, not test files." >&2
            exit 2
        fi
        ;;
    TDD-REFACTOR)
        # Both allowed — no constraints
        ;;
    *)
        echo "tdd-state-machine: unrecognized state '$state' in $state_file, falling open" >&2
        ;;
esac

exit 0
