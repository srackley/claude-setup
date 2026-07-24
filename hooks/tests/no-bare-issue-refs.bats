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

@test "blocks bare #N via a double-quoted --body-file path" {
    tmp=$(mktemp)
    printf 'point #2 needs work\n' > "$tmp"
    input=$(build_bash_input "gh pr comment 5 --body-file \"$tmp\"")
    assert_blocked "$input"
    rm -f "$tmp"
}

@test "blocks bare #N via a quoted body=@ path" {
    tmp=$(mktemp)
    printf 'see #3\n' > "$tmp"
    input=$(build_bash_input "gh api repos/o/r/issues/1/comments -F body=@\"$tmp\"")
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

@test "allows a closing keyword opening a markdown bullet" {
    input=$(build_bash_input 'gh pr create --title x --body "- Fixes #742"')
    assert_allowed "$input"
}

# --- Closing keyword must start on a word boundary ---

@test "blocks a bare ref after a word merely ending in a closing stem (bugfix)" {
    input=$(build_bash_input 'gh pr create --title x --body "the bugfix #3 shipped"')
    assert_blocked "$input"
}

@test "blocks bare refs after prefix/suffix (both end in a closing stem)" {
    input=$(build_bash_input 'gh pr create --title x --body "prefix #1 suffix #2"')
    assert_blocked "$input"
}

@test "blocks a closing stem sliced by the 30-char window edge" {
    # `fix` lands exactly at the window start, so its real left boundary (`bug`)
    # sits outside the window. An optional leading boundary (or a lookbehind)
    # would read this as a closing ref and allow it; requiring the boundary char
    # makes it block.
    spaces=$(printf ' %.0s' $(seq 1 27))
    input=$(build_bash_input "gh pr create --title x --body \"Zbugfix${spaces}#3\"")
    assert_blocked "$input"
}

@test "allows a closing keyword opening a body file" {
    printf 'Fixes #5\n\nDetails follow.\n' > "$BATS_TEST_TMPDIR/body.md"
    input=$(build_bash_input "gh pr create --title x --body-file $BATS_TEST_TMPDIR/body.md")
    assert_allowed "$input"
}

# find_bare_refs slices a 30-char window before each ref, and _CLOSING_PREFIX
# REQUIRES a boundary char before the keyword — so a keyword at offset 0 of the
# text has no char to inspect and would block without the start==0 sentinel.
# The hook's own entry point can't reach that (its scan text always opens with
# the `gh` command, never a keyword), so this exercises find_bare_refs directly:
# it pins the helper's contract for any caller that passes body text alone.
@test "find_bare_refs allows a closing keyword at offset 0 of the text" {
    run python3 -c 'import importlib.util,sys
spec=importlib.util.spec_from_file_location("h",sys.argv[1])
m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
print(m.find_bare_refs("Fixes #5"))' "$HOOK"
    [ "$status" -eq 0 ] || { echo "import failed: $output"; return 1; }
    [ "$output" = "[]" ] || { echo "expected no bare refs, got: $output"; return 1; }
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
