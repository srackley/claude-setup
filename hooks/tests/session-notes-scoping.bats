#!/usr/bin/env bats

# Tests for project-scoped session notes
# Tests the get_project_name, get_unpromoted_corrections, and get_recent_session_notes functions

setup() {
    # Create temp directories for isolation
    export TEST_TMPDIR="$(mktemp -d)"
    export HOME="$TEST_TMPDIR/home"
    mkdir -p "$HOME/.claude/session-notes"
    mkdir -p "$HOME/.claude"

    # Create a fake git repo
    export FAKE_REPO="$TEST_TMPDIR/repo"
    mkdir -p "$FAKE_REPO"
    cd "$FAKE_REPO"
    git init -q
    git remote add origin "git@github.com:wanderu/canopy.git"

    # Source the functions we're testing
    source "$BATS_TEST_DIRNAME/../lib/session-notes.sh"
}

teardown() {
    rm -rf "$TEST_TMPDIR"
}

# --- get_project_name tests ---

@test "get_project_name extracts repo name from SSH remote" {
    cd "$FAKE_REPO"
    run get_project_name
    [ "$status" -eq 0 ]
    [ "$output" = "canopy" ]
}

@test "get_project_name extracts repo name from HTTPS remote" {
    cd "$FAKE_REPO"
    git remote set-url origin "https://github.com/wanderu/canopy.git"
    run get_project_name
    [ "$status" -eq 0 ]
    [ "$output" = "canopy" ]
}

@test "get_project_name strips .git suffix" {
    cd "$FAKE_REPO"
    git remote set-url origin "https://github.com/wanderu/canopy.git"
    run get_project_name
    [ "$output" = "canopy" ]
    [[ "$output" != *".git"* ]]
}

@test "get_project_name falls back to directory name when no remote" {
    cd "$FAKE_REPO"
    git remote remove origin
    run get_project_name
    [ "$status" -eq 0 ]
    [ "$output" = "repo" ]
}

@test "get_project_name works in a git worktree" {
    cd "$FAKE_REPO"
    git commit --allow-empty -m "init" -q
    git worktree add -q "$TEST_TMPDIR/worktree" -b test-branch
    cd "$TEST_TMPDIR/worktree"
    run get_project_name
    [ "$status" -eq 0 ]
    [ "$output" = "canopy" ]
}

# --- get_unpromoted_corrections tests ---

@test "get_unpromoted_corrections only reads from project subdir" {
    # Create corrections in two project subdirs
    mkdir -p "$HOME/.claude/session-notes/canopy"
    mkdir -p "$HOME/.claude/session-notes/polish-stash"
    echo "- [CORRECTION] canopy-specific fix" > "$HOME/.claude/session-notes/canopy/notes.md"
    echo "- [CORRECTION] polish-specific fix" > "$HOME/.claude/session-notes/polish-stash/notes.md"

    # Touch files to make them recent
    touch "$HOME/.claude/session-notes/canopy/notes.md"
    touch "$HOME/.claude/session-notes/polish-stash/notes.md"

    cd "$FAKE_REPO"  # remote = canopy
    run get_unpromoted_corrections
    [ "$status" -eq 0 ]
    [[ "$output" == *"canopy-specific fix"* ]]
    [[ "$output" != *"polish-specific fix"* ]]
}

@test "get_unpromoted_corrections skips corrections already in CLAUDE.md" {
    mkdir -p "$HOME/.claude/session-notes/canopy"
    cat > "$HOME/.claude/session-notes/canopy/notes.md" << 'EOF'
- [CORRECTION] Never skip TDD for any reason
- [CORRECTION] Brand new correction not yet promoted
EOF
    touch "$HOME/.claude/session-notes/canopy/notes.md"

    # Create CLAUDE.md with the first correction already promoted
    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
## Corrections
- **NEVER**: Skip TDD for any reason
EOF

    cd "$FAKE_REPO"
    run get_unpromoted_corrections
    [ "$status" -eq 0 ]
    [[ "$output" == *"Brand new correction not yet promoted"* ]]
    [[ "$output" != *"Never skip TDD"* ]]
}

@test "get_unpromoted_corrections returns nothing when all corrections are promoted" {
    mkdir -p "$HOME/.claude/session-notes/canopy"
    echo "- [CORRECTION] Already promoted thing" > "$HOME/.claude/session-notes/canopy/notes.md"
    touch "$HOME/.claude/session-notes/canopy/notes.md"

    cat > "$HOME/.claude/CLAUDE.md" << 'EOF'
- **ALWAYS**: Already promoted thing
EOF

    cd "$FAKE_REPO"
    run get_unpromoted_corrections
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "get_unpromoted_corrections ignores files older than 14 days" {
    mkdir -p "$HOME/.claude/session-notes/canopy"
    echo "- [CORRECTION] Old stale correction" > "$HOME/.claude/session-notes/canopy/old-notes.md"
    # Make file appear old (15 days)
    touch -t "$(date -v-15d '+%Y%m%d%H%M')" "$HOME/.claude/session-notes/canopy/old-notes.md"

    cd "$FAKE_REPO"
    run get_unpromoted_corrections
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

# --- get_recent_session_notes tests ---

@test "get_recent_session_notes reads from project subdir only" {
    mkdir -p "$HOME/.claude/session-notes/canopy"
    mkdir -p "$HOME/.claude/session-notes/polish-stash"

    cat > "$HOME/.claude/session-notes/canopy/2026-02-23-canopy.md" << 'EOF'
## [2026-02-23 10:00] Session: main (canopy)
### Current Task
Working on canopy stuff
EOF

    cat > "$HOME/.claude/session-notes/polish-stash/2026-02-23-polish.md" << 'EOF'
## [2026-02-23 10:00] Session: main (polish-stash)
### Current Task
Working on polish stuff
EOF

    cd "$FAKE_REPO"
    run get_recent_session_notes
    [ "$status" -eq 0 ]
    [[ "$output" == *"canopy stuff"* ]]
    [[ "$output" != *"polish stuff"* ]]
}

@test "get_recent_session_notes reads most recently modified file" {
    mkdir -p "$HOME/.claude/session-notes/canopy"

    # Create an older file
    cat > "$HOME/.claude/session-notes/canopy/2026-02-20-old-session.md" << 'EOF'
## [2026-02-20 10:00] Session: main (canopy)
### Current Task
Old session notes
EOF
    # Make it appear older
    touch -t "202602201000" "$HOME/.claude/session-notes/canopy/2026-02-20-old-session.md"

    # Create a newer file
    cat > "$HOME/.claude/session-notes/canopy/2026-02-23-new-session.md" << 'EOF'
## [2026-02-23 14:00] Session: feat/my-feature (canopy)
### Current Task
Latest session notes found
EOF

    cd "$FAKE_REPO"
    run get_recent_session_notes
    [ "$status" -eq 0 ]
    [[ "$output" == *"Latest session notes found"* ]]
}
