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

# Extract the (possibly rewritten) command the hook hands back.
updated_command() {
    local output="$1"
    echo "$output" | jq -r '.hookSpecificOutput.updatedInput.command'
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

# --- Truncating pipes (| tail / | head) are stripped, then backgrounded ---
# Backgrounding already keeps output out of context, so the pipe is redundant. Stripping
# it makes the backgrounded process the bare task command, which preserves the real exit
# code and writes the full log to the output file.

@test "'task test 2>&1 | tail -8' is stripped to 'task test 2>&1' and backgrounded" {
    input=$(build_bg_input "task test 2>&1 | tail -8")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task test 2>&1" ]]
}

@test "'task test | tail -20' is stripped to 'task test' and backgrounded" {
    input=$(build_bg_input "task test | tail -20")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task test" ]]
}

@test "'task lint | head -50' is stripped to 'task lint' and backgrounded" {
    input=$(build_bg_input "task lint | head -50")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task lint" ]]
}

@test "'task test | tail' (no args) is stripped and backgrounded" {
    input=$(build_bg_input "task test | tail")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task test" ]]
}

@test "chained truncators 'task test | tail | head' are fully stripped" {
    input=$(build_bg_input "task test | tail | head -3")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task test" ]]
}

# --- Non-truncating filter pipes are blocked (stripping would change intent) ---

@test "'task test | grep -c fail' is blocked" {
    input=$(build_bg_input "task test | grep -c fail")
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *BLOCKED* ]]
}

@test "'task lint 2>&1 | wc -l' is blocked" {
    input=$(build_bg_input "task lint 2>&1 | wc -l")
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *BLOCKED* ]]
}

@test "trailing tail does not rescue an upstream grep: 'task test | grep x | tail' is blocked" {
    input=$(build_bg_input "task test | grep x | tail")
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *BLOCKED* ]]
}

# --- Quoted pipe in an argument must not trigger strip or block ---

@test "quoted pipe in a -t pattern is left intact and backgrounded as-is" {
    input=$(build_bg_input "task test -- -t 'foo|bar'")
    output=$(echo "$input" | bash "$HOOK")
    assert_backgrounded "$output"
    [[ "$(updated_command "$output")" == "task test -- -t 'foo|bar'" ]]
}

# --- Targeted single-file runs: stay FOREGROUND, but strip the masking pipe ---
# Single-file runs must keep a real exit code for the TDD state machine, so they are not
# backgrounded. But a trailing `| tail` masks that exit code just as badly — so strip it
# while leaving the command in the foreground.

# Assert hook rewrites the command but keeps it foreground (run_in_background stays false).
assert_foreground_rewrite() {
    local output="$1"
    [[ -n "$output" ]] && \
        [[ "$(echo "$output" | jq -r '.hookSpecificOutput.updatedInput.run_in_background')" == "false" ]]
}

@test "single-file run with '| tail -30' is stripped and stays foreground" {
    input=$(build_bg_input "task test -- run src/features/foo/bar.test.ts | tail -30")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground_rewrite "$output"
    [[ "$(updated_command "$output")" == "task test -- run src/features/foo/bar.test.ts" ]]
}

@test "single-file run with '| head -5' is stripped and stays foreground" {
    input=$(build_bg_input "task test -- run src/lib/utils.spec.ts | head -5")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground_rewrite "$output"
    [[ "$(updated_command "$output")" == "task test -- run src/lib/utils.spec.ts" ]]
}

@test "single-file run piped to grep is blocked" {
    input=$(build_bg_input "task test -- run src/features/foo/bar.test.ts | grep PASS")
    run bash "$HOOK" <<< "$input"
    [ "$status" -eq 2 ]
    [[ "$output" == *BLOCKED* ]]
}

@test "single-file run with no pipe still produces no output (unchanged foreground)" {
    input=$(build_bg_input "task test -- run src/features/foo/bar.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_foreground "$output"
}
