#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../background-heavy-commands.sh"

# Helper: build PreToolUse Bash input with optional run_in_background flag.
build_bg_input() {
    local command="$1"
    local already_bg="${2:-false}"
    jq -n \
        --arg cmd "$command" \
        --argjson bg "$already_bg" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd, run_in_background: $bg }
        }'
}

# Assert hook output requests background execution.
assert_backgrounded() {
    local output="$1"
    [[ -n "$output" ]] && \
        echo "$output" | jq -e '.hookSpecificOutput.updatedInput.run_in_background == true' > /dev/null 2>&1
}

# Assert hook produces no output (command runs in foreground).
assert_foreground() {
    local output="$1"
    [[ -z "$output" ]]
}

# --- Regression: heavy suite runs stay backgrounded ---

@test "full suite 'task test' is backgrounded" {
    input=$(build_bg_input "task test")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task lint' is backgrounded" {
    input=$(build_bg_input "task lint")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task lint-types' is backgrounded" {
    input=$(build_bg_input "task lint-types")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task test-e2e' is backgrounded" {
    input=$(build_bg_input "task test-e2e")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task storybook-test' is backgrounded" {
    input=$(build_bg_input "task storybook-test")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task test' with --reporter flag only (no file) is backgrounded" {
    input=$(build_bg_input "task test -- --reporter=verbose")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

# --- Already-background flag: no-op ---

@test "already-backgrounded command exits silently" {
    input=$(build_bg_input "task test" true)
    output=$(echo "$input" | bash "$HOOK")
    # Hook exits 0 with no output — run_in_background stays true from caller
    [[ -z "$output" ]]
}

# --- Non-task commands: no-op ---

@test "non-task command produces no output" {
    input=$(build_bg_input "git status")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "pnpm vitest run (no task) produces no output" {
    input=$(build_bg_input "pnpm vitest run src/Button.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

# --- Targeted single-file runs: NOT backgrounded ---
# These are fast (bounded output) and need real exit codes for TDD state machine.

@test "targeted .test.ts run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/features/ticket-lookup/actions.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "targeted .test.tsx run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/components/ui/Button.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "targeted .spec.ts run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/lib/utils.spec.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "targeted .spec.tsx run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/features/auth/SessionSync.spec.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "targeted .test.js run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/legacy/helper.test.js")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "targeted .test.jsx run is NOT backgrounded" {
    input=$(build_bg_input "task test -- run src/legacy/Widget.test.jsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

@test "task test with file path but no -- separator is NOT backgrounded" {
    input=$(build_bg_input "task test src/features/ticket-lookup/actions.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}

# --- Scoping: only task test, not other heavy commands ---

@test "'task lint' with a .test.ts path is still backgrounded" {
    input=$(build_bg_input "task lint src/features/foo/bar.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task test-e2e' with a .test.ts path is still backgrounded" {
    input=$(build_bg_input "task test-e2e src/features/foo/e2e.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "'task storybook-test' with a .test.ts path is still backgrounded" {
    input=$(build_bg_input "task storybook-test src/features/foo/bar.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
}

@test "cd prefix before task test with file path is NOT backgrounded" {
    input=$(build_bg_input "cd /some/dir && task test -- run src/features/foo/bar.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}
