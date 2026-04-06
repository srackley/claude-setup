#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../tdd-state-advance.sh"

teardown() {
    rm -f /tmp/claude-tdd-state-test-*
}

# --- Detect test commands ---

@test "ignores non-test commands (PostToolUse)" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_success "git status" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-RED" ]]
}

@test "ignores test commands when state is NONE" {
    state_file=$(create_tdd_state "NONE")
    input=$(build_post_bash_success "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "NONE" ]]
}

# --- TDD-RED: PostToolUseFailure (tests fail) → TDD-GREEN ---

@test "TDD-RED + failing tests (PostToolUseFailure) → TDD-GREEN" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "TDD-RED + passing tests (PostToolUse) → stays TDD-RED" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_success "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-RED" ]]
}

# --- TDD-GREEN: PostToolUse (tests pass) → TDD-REFACTOR ---

@test "TDD-GREEN + passing tests (PostToolUse) → TDD-REFACTOR" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_post_bash_success "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-REFACTOR" ]]
}

@test "TDD-GREEN + failing tests (PostToolUseFailure) → stays TDD-GREEN" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(build_post_bash_failure "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

# --- TDD-REFACTOR: PostToolUse (tests pass) → TDD-RED (next cycle) ---

@test "TDD-REFACTOR + passing tests (PostToolUse) → TDD-RED" {
    state_file=$(create_tdd_state "TDD-REFACTOR")
    input=$(build_post_bash_success "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-RED" ]]
}

@test "TDD-REFACTOR + failing tests (PostToolUseFailure) → stays TDD-REFACTOR" {
    state_file=$(create_tdd_state "TDD-REFACTOR")
    input=$(build_post_bash_failure "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-REFACTOR" ]]
}

# --- Various test command patterns ---

@test "recognizes 'pnpm test' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "pnpm test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'pnpm vitest run' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "pnpm vitest run" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'npx jest' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "npx jest src/Button.test.tsx" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'bats' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "bats tests/my-test.bats" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'pytest' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "pytest tests/" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'npm test' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "npm test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'yarn test' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "yarn test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes standalone 'vitest' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "vitest run src/Button.test.tsx" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes standalone 'jest' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "jest --coverage" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes piped test commands" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "task test | tail -50" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'pnpm run test' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "pnpm run test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'npm run test' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "npm run test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "recognizes 'task test:unit' as a test command" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "task test:unit" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

# --- Missing hook_event_name: no-op (fail-open) ---

@test "missing hook_event_name: does not advance state" {
    state_file=$(create_tdd_state "TDD-GREEN")
    input=$(jq -n --arg sid "test-session-123" '{session_id: $sid, tool_name: "Bash", tool_input: {command: "task test"}}')
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-GREEN" ]]
}

@test "state file records previous_state after transition" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(build_post_bash_failure "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(jq -r '.previous_state' "$state_file")" == "TDD-RED" ]]
}

# --- Missing state file: no-op ---

@test "missing state file: no-op on test commands" {
    input=$(build_post_bash_success "task test" "/dev/null")
    echo "$input" | TDD_STATE_FILE="/tmp/nonexistent-tdd-12345.json" bash "$HOOK"
    # Should not crash, just exit cleanly
}

# --- Ignores non-Bash tools ---

@test "ignores non-Bash tools" {
    state_file=$(create_tdd_state "TDD-RED")
    input=$(jq -n '{tool_name: "Edit", tool_input: {file_path: "/tmp/foo.ts"}, hook_event_name: "PostToolUse"}')
    echo "$input" | TDD_STATE_FILE="$state_file" bash "$HOOK"
    [[ "$(read_tdd_state "$state_file")" == "TDD-RED" ]]
}
