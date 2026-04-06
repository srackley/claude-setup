#!/usr/bin/env bats

load helpers

HOOK="${HOOK_OVERRIDE:-$BATS_TEST_DIRNAME/../pr-gate.sh}"

# Helper: create a verification token file with real content (> 200 chars)
make_token() {
    local session_id="$1"
    local token_file="/tmp/pr-verification-${session_id}.md"
    printf '| Task | Plan Spec | Actual | Match? |\n|------|-----------|--------|--------|\n| Task 1 | Implement X | src/x.ts exports X with correct types | YES |\n| Task 2 | Tests for X | tests/x.test.ts covers 3 cases | YES |\n' > "$token_file"
    echo "$token_file"
}

# --- Pass through: non-pr-create commands ---

@test "does not intercept command containing 'gh pr create' in text content" {
    input=$(build_bash_input_with_session "echo 'run gh pr create to open a PR'" "/dev/null" "sess-1")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "does not intercept heredoc command with gh pr create in table content" {
    local cmd
    cmd='cat > /tmp/docs.md << '"'"'TABLE'"'"'
| describe gh pr create usage |
TABLE'
    input=$(build_bash_input_with_session "$cmd" "/dev/null" "sess-1")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows non-pr-create bash commands" {
    input=$(build_bash_input_with_session "git status" "/dev/null" "sess-1")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows gh pr list commands" {
    input=$(build_bash_input_with_session "gh pr list" "/dev/null" "sess-1")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows gh pr view commands" {
    input=$(build_bash_input_with_session "gh pr view 123" "/dev/null" "sess-1")
    run_and_assert_allowed "$input" "$HOOK"
}

# --- Block: no token file ---

@test "blocks gh pr create when no token file exists" {
    local session_id="test-no-token-$$"
    rm -f "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    input=$(build_bash_input_with_session "gh pr create --title 'foo'" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "block message includes session_id and expected file path" {
    local session_id="test-msg-$$"
    rm -f "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    stderr_output=$(echo "$input" | bash "$HOOK" 2>&1 1>/dev/null) || true
    echo "$stderr_output" | grep -q "pr-verification-${session_id}.md"
    rm -f "$transcript"
}

# --- Block: token file exists but empty/too short ---

@test "blocks when token file exists but is empty" {
    local session_id="test-empty-$$"
    touch "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    add_verification_write_to_transcript "$transcript" "$session_id"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "/tmp/pr-verification-${session_id}.md"
}

@test "blocks when token file has fewer than 200 chars" {
    local session_id="test-short-$$"
    echo "too short" > "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    add_verification_write_to_transcript "$transcript" "$session_id"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "/tmp/pr-verification-${session_id}.md"
}

# --- Block: token file exists with content but no transcript write ---

@test "blocks when token file exists but transcript has no Write for it" {
    local session_id="test-no-transcript-write-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript)  # no Write to verification file
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "$token_file"
}

# --- Allow: both conditions met ---

@test "auto-approves when token file exists with content AND transcript shows Write AND reviewing-code invoked AND issue comment posted" {
    local session_id="test-allow-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript --issue-comment "reviewing-code")
    add_verification_write_to_transcript "$transcript" "$session_id"
    rm -f "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create --title 'feat: thing'" "$transcript" "$session_id")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript" "$token_file"
}

@test "token file is NOT deleted after allow" {
    local session_id="test-persist-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript --issue-comment "reviewing-code")
    add_verification_write_to_transcript "$transcript" "$session_id"
    rm -f "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    run_hook_capture_stdout "$input" "$HOOK"
    [ -f "$token_file" ]
    rm -f "$transcript" "$token_file"
}

# --- Block: reviewing-code not in transcript ---

@test "blocks when verification table exists but reviewing-code not invoked" {
    local session_id="test-no-review-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript)
    add_verification_write_to_transcript "$transcript" "$session_id"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "$token_file"
}

@test "block message mentions reviewing-code when missing" {
    local session_id="test-review-msg-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript)
    add_verification_write_to_transcript "$transcript" "$session_id"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    stderr_output=$(echo "$input" | bash "$HOOK" 2>&1 1>/dev/null) || true
    echo "$stderr_output" | grep -q "reviewing-code"
    rm -f "$transcript" "$token_file"
}

@test "auto-approves when verification table AND reviewing-code both present AND issue comment posted" {
    local session_id="test-full-allow-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript --issue-comment "reviewing-code")
    add_verification_write_to_transcript "$transcript" "$session_id"
    rm -f "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create --title 'feat: thing'" "$transcript" "$session_id")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript" "$token_file"
}

# --- Condition 4: GitHub issue comment ---

@test "blocks when all other conditions met but no issue comment and no escape hatch" {
    local session_id="test-no-issue-comment-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript "reviewing-code")  # intentionally omits --issue-comment to test Condition 4 block path
    add_verification_write_to_transcript "$transcript" "$session_id"
    rm -f "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create --title 'feat'" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "$token_file"
}

@test "block message mentions gh issue comment when missing" {
    local session_id="test-issue-msg-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript "reviewing-code")  # intentionally omits --issue-comment to test Condition 4 block path
    add_verification_write_to_transcript "$transcript" "$session_id"
    rm -f "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create" "$transcript" "$session_id")
    stderr_output=$(echo "$input" | bash "$HOOK" 2>&1 1>/dev/null) || true
    echo "$stderr_output" | grep -q "gh issue comment"
    rm -f "$transcript" "$token_file"
}

@test "allows when no issue comment but no-issues escape hatch file exists" {
    local session_id="test-escape-hatch-$$"
    token_file=$(make_token "$session_id")
    transcript=$(build_transcript "reviewing-code")
    add_verification_write_to_transcript "$transcript" "$session_id"
    echo "no related issues: personal config repo" > "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "gh pr create --title 'feat'" "$transcript" "$session_id")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript" "$token_file" "/tmp/no-issues-${session_id}.txt"
}

# --- gh pr create variants ---

@test "blocks gh pr create with --fill flag" {
    local session_id="test-fill-$$"
    rm -f "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    input=$(build_bash_input_with_session "gh pr create --fill" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks gh pr create --draft" {
    local session_id="test-draft-$$"
    rm -f "/tmp/pr-verification-${session_id}.md"
    transcript=$(build_transcript)
    input=$(build_bash_input_with_session "gh pr create --draft --title 'wip'" "$transcript" "$session_id")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}
