#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../no-edit-on-main.sh"

setup() {
    TEST_REPO=$(mktemp -d /tmp/claude-worktree-test-XXXXXX)
    cd "$TEST_REPO"
    git init -q
    git checkout -b main 2>/dev/null || true
    echo "test" > file.txt
    git add file.txt
    git commit -q -m "init"
}

teardown() {
    rm -rf "$TEST_REPO"
}

# --- Still blocks source files on main ---

@test "blocks .tsx source file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/src/Button.tsx")
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

@test "blocks .ts source file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/src/utils/helpers.ts")
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

@test "blocks .js source file write on main" {
    input=$(build_file_input "Write" "$TEST_REPO/src/index.js")
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

# --- Feature branch allows everything ---

@test "allows source file edit on feature branch" {
    cd "$TEST_REPO"
    git checkout -b feature/test 2>/dev/null
    input=$(build_file_input "Edit" "$TEST_REPO/src/Button.tsx")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}

# --- Non-Edit/Write tools pass through ---

@test "ignores Read tool" {
    input=$(jq -n '{ tool_name: "Read", tool_input: { file_path: "/tmp/foo.ts" } }')
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}
