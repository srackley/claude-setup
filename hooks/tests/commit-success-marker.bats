#!/usr/bin/env bats

load helpers

HOOK="${HOOK_OVERRIDE:-$BATS_TEST_DIRNAME/../commit-success-marker.sh}"

# --- Core behavior: record line number after successful git commit ---

@test "writes transcript line count to marker file on successful git commit" {
    local session_id="marker-basic-$$"
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")
    # Transcript has some lines — marker should record the count
    local expected_lines
    expected_lines=$(wc -l < "$transcript" | tr -d ' ')

    input=$(build_post_bash_success "git commit -m 'feat: thing'" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local marker_file="/tmp/last-commit-${session_id}.line"
    [[ -f "$marker_file" ]]
    local recorded
    recorded=$(cat "$marker_file")
    [[ "$recorded" == "$expected_lines" ]]

    rm -f "$transcript" "$marker_file"
}

@test "updates marker file on second successful commit" {
    local session_id="marker-update-$$"
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")

    # First commit
    input=$(build_post_bash_success "git commit -m 'feat: first'" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local marker_file="/tmp/last-commit-${session_id}.line"
    local first_line
    first_line=$(cat "$marker_file")

    # Add more lines to transcript (simulating more work)
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"finishing-work"}}' >> "$transcript"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-second.md"}}' >> "$transcript"

    # Second commit
    input=$(build_post_bash_success "git commit -m 'feat: second'" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local second_line
    second_line=$(cat "$marker_file")
    [[ "$second_line" -gt "$first_line" ]]

    rm -f "$transcript" "$marker_file"
}

# --- Non-commit commands: no marker written ---

@test "does not write marker for non-commit commands" {
    local session_id="marker-noncommit-$$"
    transcript=$(build_transcript "finishing-work")
    input=$(build_post_bash_success "git status" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local marker_file="/tmp/last-commit-${session_id}.line"
    [[ ! -f "$marker_file" ]]

    rm -f "$transcript"
}

@test "does not write marker for git add commands" {
    local session_id="marker-add-$$"
    transcript=$(build_transcript "finishing-work")
    input=$(build_post_bash_success "git add -A" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    [[ ! -f "/tmp/last-commit-${session_id}.line" ]]
    rm -f "$transcript"
}

@test "does not write marker for git commit-graph commands" {
    local session_id="marker-commitgraph-$$"
    transcript=$(build_transcript "finishing-work")
    input=$(build_post_bash_success "git commit-graph write" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    [[ ! -f "/tmp/last-commit-${session_id}.line" ]]
    rm -f "$transcript"
}

# --- Chained commands ---

@test "writes marker for chained git add && git commit" {
    local session_id="marker-chained-$$"
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")
    local expected_lines
    expected_lines=$(wc -l < "$transcript" | tr -d ' ')

    input=$(build_post_bash_success "git add -A && git commit -m 'feat: thing'" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local marker_file="/tmp/last-commit-${session_id}.line"
    [[ -f "$marker_file" ]]
    local recorded
    recorded=$(cat "$marker_file")
    [[ "$recorded" == "$expected_lines" ]]

    rm -f "$transcript" "$marker_file"
}

# --- git -C <path> commit support ---

@test "writes marker for git -C /path commit" {
    local session_id="marker-dashc-$$"
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")
    local expected_lines
    expected_lines=$(wc -l < "$transcript" | tr -d ' ')

    input=$(build_post_bash_success "git -C /path/to/repo commit -m 'feat: thing'" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    local marker_file="/tmp/last-commit-${session_id}.line"
    [[ -f "$marker_file" ]]
    local recorded
    recorded=$(cat "$marker_file")
    [[ "$recorded" == "$expected_lines" ]]

    rm -f "$transcript" "$marker_file"
}

# --- Edge cases ---

@test "handles missing session_id gracefully — exits 0 no marker" {
    transcript=$(build_transcript "finishing-work")
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg tp "$transcript" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            tool_response: { stdout: "1 file changed", stderr: "" },
            transcript_path: $tp,
            hook_event_name: "PostToolUse"
        }')
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    rm -f "$transcript"
}

@test "handles missing transcript_path gracefully — exits 0 no marker" {
    local session_id="marker-no-transcript-$$"
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg sid "$session_id" \
        '{
            session_id: $sid,
            tool_name: "Bash",
            tool_input: { command: $cmd },
            tool_response: { stdout: "1 file changed", stderr: "" },
            hook_event_name: "PostToolUse"
        }')
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ ! -f "/tmp/last-commit-${session_id}.line" ]]
}

@test "does not write marker for grep command containing git commit" {
    local session_id="marker-grep-$$"
    transcript=$(build_transcript "finishing-work")
    input=$(build_post_bash_success "grep -c 'git commit' /tmp/transcript.jsonl" "$transcript" "$session_id")
    echo "$input" | bash "$HOOK"

    [[ ! -f "/tmp/last-commit-${session_id}.line" ]]
    rm -f "$transcript"
}
