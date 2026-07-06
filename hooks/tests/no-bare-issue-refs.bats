#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../no-bare-issue-refs.py"

# This is a Python hook; the shared run_and_assert_* helpers invoke `bash "$hook"`,
# so define exit-code assertions that pipe input through python3 instead.
assert_blocked() {
    run bash -c 'printf "%s" "$2" | python3 "$1"' _ "$HOOK" "$1"
    [ "$status" -eq 2 ] || { echo "expected block (exit 2), got $status: $output"; return 1; }
}

assert_allowed() {
    run bash -c 'printf "%s" "$2" | python3 "$1"' _ "$HOOK" "$1"
    [ "$status" -eq 0 ] || { echo "expected allow (exit 0), got $status: $output"; return 1; }
}

# --- Bare #N in a body: blocked ---

@test "blocks bare #N used as enumeration in a pr comment" {
    input=$(build_bash_input 'gh pr comment 42 -b "Fixed point #1 and point #2 as discussed."')
    assert_blocked "$input"
}

@test "blocks bare (#4) in an issue comment" {
    input=$(build_bash_input 'gh issue comment 7 --body "See surface (#4) above."')
    assert_blocked "$input"
}

@test "blocks bare #N in a gh api comment body" {
    input=$(build_bash_input 'gh api repos/o/r/issues/1/comments -f body="point #1 looks good"')
    assert_blocked "$input"
}

@test "blocks bare #N in a pr create body" {
    input=$(build_bash_input 'gh pr create --title x --body "Addresses #3 from the list"')
    assert_blocked "$input"
}

# --- File-delivered body: blocked (the $(cat file) case) ---

@test "blocks bare #N delivered via \$(cat file)" {
    tmp=$(mktemp)
    printf 'Circling back on #1 — you were right.\n' > "$tmp"
    input=$(build_bash_input "gh api repos/o/r/issues/1/comments -f body=\"\$(cat $tmp)\"")
    assert_blocked "$input"
    rm -f "$tmp"
}

@test "blocks bare #N delivered via --body-file" {
    tmp=$(mktemp)
    printf 'point #2 needs work\n' > "$tmp"
    input=$(build_bash_input "gh pr comment 5 --body-file $tmp")
    assert_blocked "$input"
    rm -f "$tmp"
}

# --- Allowed forms ---

@test "allows closing keyword Closes #N" {
    input=$(build_bash_input 'gh pr create --title x --body "Closes #742"')
    assert_allowed "$input"
}

@test "allows closing keyword Fixes #N lowercase" {
    input=$(build_bash_input 'gh pr create --title x --body "fixes #742 and cleans up logging"')
    assert_allowed "$input"
}

@test "allows cross-repo owner/repo#N form" {
    input=$(build_bash_input 'gh pr comment 42 -b "Tracked in wanderu/canopy#742, see there."')
    assert_allowed "$input"
}

@test "allows a body with no issue references" {
    input=$(build_bash_input 'gh pr comment 42 -b "Point 1 and point 2 look good."')
    assert_allowed "$input"
}

@test "allows a markdown heading (# followed by space, not a digit)" {
    input=$(build_bash_input 'gh pr create --title x --body "# Summary

Done."')
    assert_allowed "$input"
}

# --- Out of scope: not a GitHub write ---

@test "ignores non-gh commands containing #N" {
    input=$(build_bash_input 'echo "point #1"')
    assert_allowed "$input"
}

@test "ignores read-only gh commands" {
    input=$(build_bash_input 'gh pr view 42 --json body')
    assert_allowed "$input"
}

@test "ignores a git commit whose message merely mentions gh api and #N" {
    input=$(build_bash_input 'git commit -m "block bodies with a bare #1; fires on gh api with a body"')
    assert_allowed "$input"
}

@test "catches gh comment chained after another command with &&" {
    input=$(build_bash_input 'cd repo && gh pr comment 42 -b "point #1"')
    assert_blocked "$input"
}
