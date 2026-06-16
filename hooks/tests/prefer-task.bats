#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../prefer-task.py"

# Helper: build PreToolUse Bash input for prefer-task.py
build_pt_input() {
    local command="$1"
    jq -n --arg cmd "$command" \
        '{ tool_name: "Bash", tool_input: { command: $cmd } }'
}

# Assert hook output is a deny decision
assert_denied() {
    local output="$1"
    [[ -n "$output" ]] && \
        echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null 2>&1
}

# Assert the deny reason mentions the expected task name
assert_suggests_task() {
    local output="$1"
    local task="$2"
    echo "$output" | jq -r '.hookSpecificOutput.permissionDecisionReason' | grep -q "task $task"
}

# Assert hook produces no output (command allowed through)
assert_allowed() {
    local output="$1"
    [[ -z "$output" ]]
}

# Create a temp project dir with Taskfile + package.json wired like canopy:
#   Taskfile: test task runs "pnpm run test {{.CLI_ARGS}}"
#   package.json: "test" script calls "vitest"
setup_project() {
    local dir
    dir=$(mktemp -d)
    dir=$(cd "$dir" && pwd -P)  # resolve /tmp symlink (macOS)

    cat > "$dir/Taskfile.yaml" <<'EOF'
version: '3'
tasks:
  test:
    desc: Run the tests
    cmd: pnpm run test {{.CLI_ARGS}}
  lint:
    desc: Run lint
    cmd: pnpm run lint
EOF

    cat > "$dir/package.json" <<'EOF'
{
  "scripts": {
    "test": "vitest",
    "lint": "eslint ."
  }
}
EOF

    echo "$dir"
}

# --- Primary scenario: pnpm binary shorthand caught via package.json chain ---

@test "pnpm vitest run x.test.ts is denied and suggests task test" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm vitest run src/features/auth/actions.test.ts")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_denied "$output"
    assert_suggests_task "$output" "test"
}

@test "bare pnpm vitest (no args) is denied and suggests task test" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm vitest")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_denied "$output"
    assert_suggests_task "$output" "test"
}

@test "pnpm vitest with flags is denied and suggests task test" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm vitest --reporter=verbose")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_denied "$output"
    assert_suggests_task "$output" "test"
}

# --- False positives: pnpm's own subcommands must pass through ---

@test "pnpm add foo is allowed" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm add foo")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

@test "pnpm install is allowed" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm install")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

@test "pnpm dlx create-next-app is allowed" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm dlx create-next-app .")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

@test "pnpm why some-package is allowed" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm why some-package")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

# --- Binary not wrapped by any task: should allow through ---

@test "pnpm tsc with no task wrapper is allowed" {
    local dir
    dir=$(setup_project)

    # tsc is not in package.json scripts, so no task wraps it
    local input output
    input=$(build_pt_input "pnpm tsc --noEmit")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

# --- No Taskfile: always allow ---

@test "pnpm vitest with no Taskfile is allowed" {
    local dir
    dir=$(mktemp -d)
    dir=$(cd "$dir" && pwd -P)
    # No Taskfile, no package.json

    local input output
    input=$(build_pt_input "pnpm vitest run x.test.ts")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_allowed "$output"
}

# --- Existing behavior must not regress: pnpm run test still caught ---

@test "pnpm run test is still denied and suggests task test (regression)" {
    local dir
    dir=$(setup_project)

    local input output
    input=$(build_pt_input "pnpm run test --coverage")
    output=$(cd "$dir" && echo "$input" | python3 "$HOOK")

    rm -rf "$dir"

    assert_denied "$output"
    assert_suggests_task "$output" "test"
}
