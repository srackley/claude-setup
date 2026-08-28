#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../no-process-narration.py"

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

# --- The instances that motivated the hook ---

@test "blocks the review-narration opener that shipped on canopy#1261" {
    input=$(build_bash_input 'gh pr edit 1261 --body "This PR was reviewed before it was opened, and the review found real defects."')
    assert_blocked "$input"
}

@test "blocks self-congratulation about the tooling" {
    input=$(build_bash_input 'gh pr create --title x --body "The lint paid for itself on first run."')
    assert_blocked "$input"
}

@test "blocks an aside referencing the earlier pass" {
    input=$(build_bash_input 'gh pr edit 9 --body "The two config claims, since the first pass got both wrong."')
    assert_blocked "$input"
}

@test "blocks the rather-than-renumbering justification" {
    input=$(build_bash_input 'gh pr create --title x --body "which is the part that made this worth doing rather than renumbering"')
    assert_blocked "$input"
}

# --- Class coverage ---

@test "blocks organizing the body by commit" {
    input=$(build_bash_input 'gh pr create --title x --body "Second commit corrects six comments."')
    assert_blocked "$input"
}

@test "blocks first-person process" {
    input=$(build_bash_input 'gh pr create --title x --body "I noticed the guard was inverted."')
    assert_blocked "$input"
}

@test "blocks my-own-sweep possessives" {
    input=$(build_bash_input 'gh pr create --title x --body "Four of them were my own sweep introducing them."')
    assert_blocked "$input"
}

@test "blocks verification narration" {
    input=$(build_bash_input 'gh pr create --title x --body "Each confirmed by breaking the code and watching it fail."')
    assert_blocked "$input"
}

@test "blocks a local test count" {
    input=$(build_bash_input 'gh pr create --title x --body "task test 3253/3253 passed on this branch."')
    assert_blocked "$input"
}

@test "blocks an all-tests-pass claim" {
    input=$(build_bash_input 'gh pr create --title x --body "All tests pass locally."')
    assert_blocked "$input"
}

@test "blocks lint clean" {
    input=$(build_bash_input 'gh pr create --title x --body "Lint clean and types clean."')
    assert_blocked "$input"
}

@test "blocks a claim pinned to a state with an expiry" {
    input=$(build_bash_input 'gh pr create --title x --body "As of today the endpoint returns 501."')
    assert_blocked "$input"
}

@test "blocks a review round tally" {
    input=$(build_bash_input 'gh pr edit 3 --body "Seventeen findings across two rounds."')
    assert_blocked "$input"
}

# --- Body passed by file, the path actually used ---

@test "blocks narration reached through --body-file" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf 'The review found four defects the first pass introduced.\n' > "$body"
    input=$(build_bash_input "gh pr create --title x --body-file $body")
    assert_blocked "$input"
}

@test "allows a clean body passed through --body-file" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf 'The orders edge row cites the client and the command that lists its call sites.\n' > "$body"
    input=$(build_bash_input "gh pr create --title x --body-file $body")
    assert_allowed "$input"
}

@test "blocks narration reached through a cat substitution" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf 'Second commit fixes the citation.\n' > "$body"
    input=$(build_bash_input "gh pr comment 1 --body \"\$(cat $body)\"")
    assert_blocked "$input"
}

# --- End-state prose is allowed ---

@test "allows an end-state description" {
    input=$(build_bash_input 'gh pr create --title x --body "Every citation names the symbol, the config key path, or the branch condition."')
    assert_allowed "$input"
}

@test "allows a stated limitation" {
    input=$(build_bash_input 'gh pr create --title x --body "Neither script runs in CI: the linter stage runs pnpm lint, and both hang off task lint."')
    assert_allowed "$input"
}

@test "allows a scope boundary and its reason" {
    input=$(build_bash_input 'gh pr create --title x --body "Plans keep their pointers; a dated filename reads as a snapshot."')
    assert_allowed "$input"
}

@test "allows the word review when it is not the review that produced the diff" {
    input=$(build_bash_input 'gh pr create --title x --body "The checklist adds a review step for locale files."')
    assert_allowed "$input"
}

# --- Fenced blocks hold displayed data, not claims ---

@test "allows a test count inside a fenced block" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf 'Run it:\n\n```bash\nbats tests/   # 43 tests passed\n```\n' > "$body"
    input=$(build_bash_input "gh pr create --title x --body-file $body")
    assert_allowed "$input"
}

@test "still blocks after a fenced block closes" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf '```bash\nbats tests/\n```\n\nThe first pass missed four of them.\n' > "$body"
    input=$(build_bash_input "gh pr create --title x --body-file $body")
    assert_blocked "$input"
}

@test "handles an indented fence" {
    body="$BATS_TEST_TMPDIR/body.md"
    printf -- '- Example:\n\n    ```\n    all tests pass\n    ```\n' > "$body"
    input=$(build_bash_input "gh pr create --title x --body-file $body")
    assert_allowed "$input"
}

# --- Surfaces the hook must not touch ---

@test "ignores a non-gh command" {
    input=$(build_bash_input 'git commit -m "the first pass missed four"')
    assert_allowed "$input"
}

@test "ignores a commit message, which is a different surface" {
    input=$(build_bash_input 'git commit -F - <<EOF
Second commit corrects the citation.
EOF')
    assert_allowed "$input"
}

@test "ignores a read-only gh command" {
    input=$(build_bash_input 'gh pr view 1261 --json body')
    assert_allowed "$input"
}

@test "ignores a body that merely mentions gh pr create" {
    input=$(build_bash_input 'echo "run gh pr create when the first pass is done"')
    assert_allowed "$input"
}

# --- Message quality ---

@test "names the offending phrase and how to fix it" {
    input=$(build_bash_input 'gh pr create --title x --body "The first pass got it wrong."')
    run bash -c 'printf "%s" "$2" | python3 "$1"' _ "$HOOK" "$input"
    [[ "$output" == *"first pass"* ]]
    [[ "$output" == *"not an earlier state of it"* ]]
}

@test "explains the end-state rule" {
    input=$(build_bash_input 'gh pr create --title x --body "I noticed it late."')
    run bash -c 'printf "%s" "$2" | python3 "$1"' _ "$HOOK" "$input"
    [[ "$output" == *"end-state account of the final diff"* ]]
}

@test "reports every distinct hit, not just the first" {
    input=$(build_bash_input 'gh pr create --title x --body "I noticed it. The second commit fixed it. All tests pass."')
    run bash -c 'printf "%s" "$2" | python3 "$1"' _ "$HOOK" "$input"
    [[ "$output" == *"I noticed"* ]]
    [[ "$output" == *"second commit"* ]]
    [[ "$output" == *"All tests pass"* ]]
}

# --- Fails closed ---

@test "allows unparseable stdin" {
    run bash -c 'printf "not json" | python3 "$1"' _ "$HOOK"
    [ "$status" -eq 0 ]
}

@test "allows a payload with no command" {
    run bash -c 'printf "%s" "{\"tool_name\":\"Bash\"}" | python3 "$1"' _ "$HOOK"
    [ "$status" -eq 0 ]
}

@test "blocks when a body-file is unreadable but the command itself narrates" {
    input=$(build_bash_input "gh pr create --title x --body-file /nonexistent/body.md --body \"the first pass missed it\"")
    assert_blocked "$input"
}
