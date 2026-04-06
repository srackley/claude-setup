#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../tdd-state-machine.sh"

teardown() {
    rm -f /tmp/claude-tdd-state-test-*
    rm -f /tmp/claude-tdd-transcript-*
}

# --- NONE state: all edits allowed ---

@test "NONE state: allows source file edits" {
    state_file=$(create_tdd_state "NONE")
    input=$(build_file_input "Edit" "/path/to/src/components/Button.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "NONE state: allows test file edits" {
    state_file=$(create_tdd_state "NONE")
    input=$(build_file_input "Edit" "/path/to/src/components/Button.test.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- No state file: fail-open (same as NONE) ---

@test "missing state file: allows all edits (fail-open)" {
    input=$(build_file_input "Edit" "/path/to/src/utils.ts")
    output=$(echo "$input" | TDD_STATE_FILE="/tmp/nonexistent-tdd-state.json" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- TDD-RED state: only test files allowed ---

@test "TDD-RED: allows test file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/src/Button.test.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows spec file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Write" "/path/to/src/api.spec.ts")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: blocks source file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/src/components/Button.tsx")
    run bash -c "echo '$input' | TDD_STATE_FILE='$state_file' bash '$HOOK'"
    [[ "$status" -eq 2 ]]
}

@test "TDD-RED: block message mentions writing tests first" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/src/utils.ts")
    stderr=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK" 2>&1 || true)
    echo "$stderr" | grep -qi "test"
}

# --- TDD-GREEN state: only source files allowed ---

@test "TDD-GREEN: allows source file edits" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input "Edit" "/path/to/src/components/Button.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-GREEN: blocks test file edits" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input "Edit" "/path/to/src/Button.test.tsx")
    run bash -c "echo '$input' | TDD_STATE_FILE='$state_file' bash '$HOOK'"
    [[ "$status" -eq 2 ]]
}

@test "TDD-GREEN: block message mentions making tests pass" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input "Edit" "/path/to/src/Button.test.tsx")
    stderr=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK" 2>&1 || true)
    echo "$stderr" | grep -qi "implementation\|pass\|green"
}

# --- TDD-REFACTOR state: both allowed ---

@test "TDD-REFACTOR: allows source file edits" {
    state_file=$(create_tdd_state "TDD-REFACTOR")
    input=$(build_file_input "Edit" "/path/to/src/components/Button.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-REFACTOR: allows test file edits" {
    state_file=$(create_tdd_state "TDD-REFACTOR")
    input=$(build_file_input "Edit" "/path/to/src/Button.test.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Always-editable files (bypass TDD state) ---

@test "TDD-RED: allows markdown file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/docs/README.md")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows JSON config edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/tsconfig.json")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows YAML config edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/.github/workflows/deploy.yml")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows CSS file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/src/styles/globals.css")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows story file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/src/Button.stories.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows CLAUDE.md edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/CLAUDE.md")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows session-notes edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Write" "/Users/me/.claude/session-notes/canopy/2026-02-28-notes.md")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows .claude/ directory edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/Users/me/.claude/skills/my-skill.md")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows .bats test file edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/tests/my-hook.bats")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-GREEN: blocks .bats test file edits" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input "Edit" "/path/to/tests/my-hook.bats")
    run bash -c "echo '$input' | TDD_STATE_FILE='$state_file' bash '$HOOK'"
    [[ "$status" -eq 2 ]]
}

@test "TDD-RED: allows eslint.config edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/eslint.config.mjs")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-RED: allows package.json edits" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_file_input "Edit" "/path/to/package.json")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "TDD-GREEN: allows config files in src/" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input "Edit" "/path/to/src/config/app-config.ts")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Non Edit/Write tools: passthrough ---

@test "ignores non-Edit/Write tools" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(jq -n '{tool_name: "Read", tool_input: {file_path: "/path/to/src/Button.tsx"}}')
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Corrupt state file: fail-open ---

@test "corrupt state file: allows all edits (fail-open)" {
    tmpfile=$(mktemp /tmp/claude-tdd-state-test-XXXXXX)
    echo "not json" > "$tmpfile"
    input=$(build_file_input "Edit" "/path/to/src/Button.tsx")
    output=$(echo "$input" | TDD_STATE_FILE="$tmpfile" bash "$HOOK")
    [[ -z "$output" ]]
}

# --- State initialization from transcript ---

@test "initializes TDD-RED when TDD skill in transcript and no state file" {
    transcript=$(build_transcript "superpowers:test-driven-development")
    state_file=$(mktemp /tmp/claude-tdd-state-test-XXXXXX)
    rm -f "$state_file"  # ensure it doesn't exist
    input=$(build_file_input_with_transcript "Edit" "/path/to/src/Button.tsx" "$transcript")
    # Should block (source file in RED state)
    run bash -c "echo '$input' | TDD_STATE_FILE='$state_file' bash '$HOOK'"
    [[ "$status" -eq 2 ]]
    # State file should now exist with TDD-RED
    [[ "$(read_tdd_state "$state_file")" == "TDD-RED" ]]
}

@test "does NOT initialize state when TDD skill NOT in transcript" {
    transcript=$(build_transcript "brainstorming")
    state_file=$(mktemp /tmp/claude-tdd-state-test-XXXXXX)
    rm -f "$state_file"
    input=$(build_file_input_with_transcript "Edit" "/path/to/src/Button.tsx" "$transcript")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    [[ -z "$output" ]]
}

@test "does NOT re-initialize state when state file already exists" {
    transcript=$(build_transcript "superpowers:test-driven-development")
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_file_input_with_transcript "Edit" "/path/to/src/Button.tsx" "$transcript")
    output=$(echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK")
    # Should stay GREEN, not reset to RED
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}
