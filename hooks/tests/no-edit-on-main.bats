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

# --- Bypasses for low-risk files on main ---

@test "allows .md file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/README.md")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows .json config file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/package.json")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows .yaml file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/Taskfile.yml")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows .css file edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/src/styles/globals.css")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows .docs/ directory edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/.docs/conventions/gotchas.md")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows CLAUDE.md edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/CLAUDE.md")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows gitignored file edit on main" {
    echo "local-notes/" >> "$TEST_REPO/.gitignore"
    git -C "$TEST_REPO" add .gitignore
    git -C "$TEST_REPO" commit -q -m "add gitignore"
    mkdir -p "$TEST_REPO/local-notes"
    input=$(build_file_input "Edit" "$TEST_REPO/local-notes/scratch.md")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows .gitignore edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/.gitignore")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
}

@test "allows Dockerfile edit on main" {
    input=$(build_file_input "Edit" "$TEST_REPO/Dockerfile")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]] || ! assert_blocked "$output"
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

# --- Global config always allowed ---

@test "allows ~/.claude/ edits regardless of branch" {
    input=$(build_file_input "Edit" "$HOME/.claude/settings.json")
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
