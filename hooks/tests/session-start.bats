#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../session-start.sh"

# All tests use ui-react as the project dir (a real git repo with stable remote name)
PROJECT_DIR="/Users/shelbyrackley/Wanderu/ui-react"

# --- Exit code correctness ---

@test "exits 0 on normal session start with empty JSON" {
    run bash -c "echo '{}' | CLAUDE_PROJECT_DIR='$PROJECT_DIR' bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "exits 0 on normal session start with empty stdin" {
    run bash -c "echo '' | CLAUDE_PROJECT_DIR='$PROJECT_DIR' bash '$HOOK'"
    [ "$status" -eq 0 ]
}

@test "exits 0 on compaction session start" {
    run bash -c "echo '{\"source\":\"compact\"}' | CLAUDE_PROJECT_DIR='$PROJECT_DIR' bash '$HOOK'"
    [ "$status" -eq 0 ]
}

# --- Compaction detection ---

@test "shows compaction warning when source is compact" {
    output=$(echo '{"source":"compact"}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOK" 2>/dev/null)
    echo "$output" | grep -q "resumed after compaction"
}

@test "compaction warning includes project-scoped session notes path" {
    output=$(echo '{"source":"compact"}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOK" 2>/dev/null)
    echo "$output" | grep -q "session-notes/ui-react/"
}

@test "no compaction warning on normal session start" {
    output=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOK" 2>/dev/null)
    ! echo "$output" | grep -q "resumed after compaction"
}

# --- Basic output sanity ---

@test "includes session initialization header" {
    output=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT_DIR" bash "$HOOK" 2>/dev/null)
    echo "$output" | grep -q "Session Initialization"
}
