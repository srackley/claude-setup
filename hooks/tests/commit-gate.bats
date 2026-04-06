#!/usr/bin/env bats

load helpers

HOOK="${HOOK_OVERRIDE:-$BATS_TEST_DIRNAME/../commit-gate.sh}"

# --- Core behavior: block commits without finishing-work ---

@test "blocks git commit when finishing-work not in transcript" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git commit -m 'feat: add thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks git commit --amend when finishing-work not in transcript" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git commit --amend" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "auto-approves git commit when all requirements met" {
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: add thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

# --- Non-commit commands pass through ---

@test "allows non-commit bash commands" {
    input=$(build_bash_input "git status" "/dev/null")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows git add commands" {
    input=$(build_bash_input "git add -A" "/dev/null")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows yarn test commands" {
    input=$(build_bash_input "yarn test" "/dev/null")
    run_and_assert_allowed "$input" "$HOOK"
}

# --- Edge cases ---

@test "blocks commit with other skills but not finishing-work" {
    transcript=$(build_transcript "brainstorming" "test-driven-development")
    input=$(build_bash_input "git commit -m 'feat: stuff'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "allows commit with finishing-work and session notes even without reviewing-code" {
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: stuff'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "block message includes actionable remediation" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git commit -m 'fix: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "finishing-work"
    rm -f "$transcript"
}

@test "handles missing transcript_path gracefully — blocks (fail-safe)" {
    input=$(jq -n '{tool_name: "Bash", tool_input: {command: "git commit -m test"}}')
    run_and_assert_blocked "$input" "$HOOK"
}

@test "auto-approves git commit with heredoc message when all requirements met" {
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m \"\$(cat <<'EOF'
feat: add thing

Co-Authored-By: Claude
EOF
)\"" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "allows git commit-graph commands (not git commit)" {
    input=$(build_bash_input "git commit-graph write" "/dev/null")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "blocks chained command: git add && git commit" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git add -A && git commit -m 'feat: stuff'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks chained command: VAR=x && git commit" {
    transcript=$(build_transcript)
    input=$(build_bash_input "BRANCH=main && git commit -m 'feat: stuff'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks semicolon-chained: echo done; git commit" {
    transcript=$(build_transcript)
    input=$(build_bash_input "echo done; git commit -m 'fix: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks with error message when transcript is unreadable (grep exit > 1)" {
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    chmod 000 "$transcript"
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "grep exit"
    chmod 644 "$transcript"
    rm -f "$transcript"
}

@test "handles transcript_path pointing to non-existent file — blocks" {
    input=$(build_bash_input "git commit -m test" "/tmp/nonexistent-transcript-12345.jsonl")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git commit when reviewing-code present but finishing-work missing" {
    transcript=$(build_transcript "reviewing-code")
    input=$(build_bash_input "git commit -m 'feat: add thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "block message mentions finishing-work when it is missing" {
    transcript=$(build_transcript "reviewing-code")
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "finishing-work"
    rm -f "$transcript"
}

# --- Auto-approve when both skills invoked ---

@test "auto-approves git commit when all three requirements in transcript" {
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: add thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "auto-approve output has correct JSON structure" {
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work" "reviewing-code")
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    # Verify the full structure
    echo "$hook_stdout" | jq -e '.hookSpecificOutput.hookEventName == "PreToolUse"' > /dev/null 2>&1
    echo "$hook_stdout" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' > /dev/null 2>&1
    rm -f "$transcript"
}

@test "auto-approves with all requirements among other skills" {
    transcript=$(build_transcript --session-notes --issue-comment "brainstorming" "reviewing-code" "test-driven-development" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: stuff'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

# --- Session notes enforcement ---

@test "blocks commit when session notes not written" {
    transcript=$(build_transcript "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "block message mentions session notes when missing" {
    transcript=$(build_transcript "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -qi "session.notes"
    rm -f "$transcript"
}

@test "auto-approves when all three requirements met: skills + session notes" {
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "auto-approves when session notes updated via Edit instead of Write" {
    transcript=$(build_transcript "reviewing-code" "finishing-work")
    # Add an Edit to session-notes (not Write)
    echo '{"type":"tool_use","tool_name":"Edit","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-feature.md","old_string":"old","new_string":"new"}}' >> "$transcript"
    add_issue_comment_to_transcript "$transcript" 42
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

# --- Multi-commit scoping: only check skills after last commit ---

@test "blocks second commit when skills were only invoked before the first commit" {
    # Prior commit had reviewing-code + finishing-work, but current commit has none.
    # Current commit is already in transcript when PreToolUse fires (real behavior).
    transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work")
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second thing'"
    input=$(build_bash_input "git commit -m 'feat: second thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "auto-approves second commit when skills re-invoked after first commit" {
    transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work" --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second thing'"
    input=$(build_bash_input "git commit -m 'feat: second thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "block message for second commit mentions missing finishing-work" {
    transcript=$(build_transcript --prior-commit --pre-commit-skills "finishing-work")
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second thing'"
    input=$(build_bash_input "git commit -m 'feat: second thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "finishing-work"
    rm -f "$transcript"
}

# --- Bug fix: "git commit" text in non-command fields ---

@test "ignores 'git commit' mentions in skill text — does not shift search window" {
    # Skill content (e.g., finishing-work) mentions "git commit" in documentation.
    # The hook must NOT treat this as a prior commit boundary.
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    # Add noise AFTER the skills — simulates skill text appearing later in transcript
    add_noise_line "$transcript" "skill-text"
    add_noise_line "$transcript" "hook-prompt"
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "ignores 'git commit' in agent hook prompts — does not shift search window" {
    # The compliance reviewer agent hook prompt mentions "git commit" in instructions.
    # This must not become the "last commit" boundary.
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_noise_line "$transcript" "hook-prompt"
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "blocks first commit with current commit in transcript when skills missing" {
    # First commit (no prior commits). Current commit is in transcript but skills are missing.
    # The hook must still block even though the current commit is in the transcript.
    transcript=$(build_transcript)
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: first thing'"
    input=$(build_bash_input "git commit -m 'feat: first thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "current commit attempt in transcript does not shift window past skills" {
    # Claude Code writes the tool_use to transcript BEFORE PreToolUse fires.
    # The hook must exclude the current commit from the "last commit" search.
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    # Add the current commit to the transcript (simulates what Claude Code does)
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: current'"
    input=$(build_bash_input "git commit -m 'feat: current'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "ignores grep diagnostic commands containing 'git commit' — does not shift search window" {
    # Bug: a Bash command like `grep 'git commit' transcript.jsonl` matched the
    # hook's prior-commit detection (line 76), shifting the search window past
    # valid skill invocations and causing false blocks.
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_noise_line "$transcript" "grep-diagnostic"
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: thing'"
    input=$(build_bash_input "git commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "grep diagnostic between prior commit and skills does not create false boundary" {
    # Two commits in one session. After the first commit, a grep diagnostic runs,
    # then skills are re-invoked for the second commit. The grep must not become
    # a second "prior commit" boundary that hides the re-invoked skills.
    transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work" --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_noise_line "$transcript" "grep-diagnostic"
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second'"
    input=$(build_bash_input "git commit -m 'feat: second'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "second commit with noise lines still works when skills re-invoked" {
    # Prior commit + noise lines + re-invoked skills = should pass
    transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work" --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_noise_line "$transcript" "skill-text"
    add_noise_line "$transcript" "hook-prompt"
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second'"
    input=$(build_bash_input "git commit -m 'feat: second'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

# --- Continuation session: stale transcript_path fix ---

@test "uses session_id to find correct transcript when transcript_path is stale" {
    # Simulates continuation session: transcript_path points to OLD session's JSONL
    # (which has no skills), but session_id matches a DIFFERENT JSONL in the same
    # directory that has all required skills.
    local tmpdir
    tmpdir=$(mktemp -d /tmp/claude-continuation-test-XXXXXX)

    # Stale transcript (old session — no skills)
    local stale_transcript="${tmpdir}/old-session-aaa.jsonl"
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' > "$stale_transcript"

    # Real transcript (current session — has all required skills + session notes)
    local real_session_id="current-session-bbb"
    local real_transcript="${tmpdir}/${real_session_id}.jsonl"
    build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work" > /dev/null
    # Can't use build_transcript directly for a specific path, so build manually
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' > "$real_transcript"
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"reviewing-code"}}' >> "$real_transcript"
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"finishing-work"}}' >> "$real_transcript"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-03-02-feature.md"}}' >> "$real_transcript"
    add_issue_comment_to_transcript "$real_transcript" 42

    # Build input with stale transcript_path but correct session_id
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: continuation fix'" \
        --arg tp "$stale_transcript" \
        --arg sid "$real_session_id" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp,
            session_id: $sid
        }')

    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"

    rm -rf "$tmpdir"
}

@test "falls back to transcript_path when session_id JSONL does not exist" {
    # If session_id-based path doesn't exist, the hook should still use transcript_path
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg tp "$transcript" \
        --arg sid "nonexistent-session-xyz" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp,
            session_id: $sid
        }')
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "blocks when stale transcript has no skills and no session_id provided" {
    # No session_id at all — hook uses transcript_path as-is (existing behavior)
    local tmpdir
    tmpdir=$(mktemp -d /tmp/claude-continuation-test-XXXXXX)
    local stale_transcript="${tmpdir}/stale.jsonl"
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' > "$stale_transcript"

    input=$(build_bash_input "git commit -m 'feat: thing'" "$stale_transcript")
    run_and_assert_blocked "$input" "$HOOK"

    rm -rf "$tmpdir"
}

# --- Phase 2: Timeline extraction (no status file) ---

@test "Phase 2: does NOT create a status file after successful commit gate" {
    # After removing the status file mechanism, commit-gate.sh should only
    # create the summary file, not the status file.
    local session_id="phase2-no-status-$$"
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp,
            session_id: $sid
        }')
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    # Status file should NOT exist (agent hooks can't write files, so status file is dead weight)
    if [[ -f "/tmp/claude-compliance-status-${session_id}" ]]; then
        echo "Status file should not exist but found: /tmp/claude-compliance-status-${session_id}" >&2
        echo "Contents: $(cat /tmp/claude-compliance-status-${session_id})" >&2
        rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt" "/tmp/claude-compliance-status-${session_id}"
        return 1
    fi
    rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt"
}

@test "Phase 2: creates summary file but not status file" {
    local session_id="phase2-summary-only-$$"
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp,
            session_id: $sid
        }')
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    # Summary file should exist (for agent hook to Read)
    if [[ ! -f "/tmp/claude-compliance-summary-${session_id}.txt" ]]; then
        echo "Summary file should exist but not found" >&2
        rm -f "$transcript"
        return 1
    fi
    # Status file should NOT exist
    if [[ -f "/tmp/claude-compliance-status-${session_id}" ]]; then
        echo "Status file should not exist but found with contents: $(cat /tmp/claude-compliance-status-${session_id})" >&2
        rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt" "/tmp/claude-compliance-status-${session_id}"
        return 1
    fi
    rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt"
}

@test "Phase 2: log entry does not include status field" {
    local session_id="phase2-log-no-status-$$"
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    input=$(jq -n \
        --arg cmd "git commit -m 'feat: thing'" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp,
            session_id: $sid
        }')
    run_hook_capture_stdout "$input" "$HOOK"
    # Find the log entry for this session
    local log_entry
    log_entry=$(grep "$session_id" "$HOME/.claude/logs/compliance-review.jsonl" | tail -1)
    # Log entry should NOT contain "status" key
    if echo "$log_entry" | jq -e '.status' > /dev/null 2>&1; then
        echo "Log entry should not contain 'status' field but found: $(echo "$log_entry" | jq '.status')" >&2
        rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt" "/tmp/claude-compliance-status-${session_id}"
        return 1
    fi
    rm -f "$transcript" "/tmp/claude-compliance-summary-${session_id}.txt" "/tmp/claude-compliance-status-${session_id}"
}

# --- Phase 3: GitHub issue update check ---

@test "blocks commit when no gh issue comment and no escape hatch file" {
    local session_id="issue-block-test-$$"
    transcript=$(build_transcript --session-notes "reviewing-code" "finishing-work")
    input=$(build_bash_input_with_session "git commit -m 'feat: thing'" "$transcript" "$session_id")
    rm -f "/tmp/no-issues-${session_id}.txt"
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "block message mentions gh issue comment command" {
    local session_id="issue-block-msg-$$"
    transcript=$(build_transcript --session-notes "reviewing-code" "finishing-work")
    input=$(build_bash_input_with_session "git commit -m 'feat: thing'" "$transcript" "$session_id")
    rm -f "/tmp/no-issues-${session_id}.txt"
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "gh issue comment"
    rm -f "$transcript"
}

@test "block message shows correct no-issues file path with session_id" {
    local session_id="issue-block-path-$$"
    transcript=$(build_transcript --session-notes "reviewing-code" "finishing-work")
    input=$(build_bash_input_with_session "git commit -m 'feat: thing'" "$transcript" "$session_id")
    rm -f "/tmp/no-issues-${session_id}.txt"
    run_and_assert_blocked "$input" "$HOOK"
    echo "$stderr_output" | grep -q "no-issues-${session_id}"
    rm -f "$transcript"
}

@test "auto-approves when gh issue comment present in transcript" {
    local session_id="issue-allow-comment-$$"
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    add_issue_comment_to_transcript "$transcript" 123
    input=$(build_bash_input_with_session "git commit -m 'feat: thing'" "$transcript" "$session_id")
    rm -f "/tmp/no-issues-${session_id}.txt"
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "auto-approves when escape hatch file exists" {
    local session_id="issue-escape-$$"
    transcript=$(build_transcript --session-notes --issue-comment "reviewing-code" "finishing-work")
    echo "no related issues: this is a docs-only change" > "/tmp/no-issues-${session_id}.txt"
    input=$(build_bash_input_with_session "git commit -m 'feat: thing'" "$transcript" "$session_id")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript" "/tmp/no-issues-${session_id}.txt"
}

@test "gh issue comment before last commit does not satisfy check for new commit" {
    local session_id="issue-scoping-$$"
    transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work" --session-notes "reviewing-code" "finishing-work")
    # Issue comment was posted BEFORE the prior commit marker — should not count
    # We need to insert it before the prior commit in the transcript
    # build_transcript puts prior commit after pre-commit-skills, so add comment to pre-commit section
    # Instead, build manually: Read → issue comment → prior commit → skills → session notes
    transcript2=$(mktemp /tmp/claude-issue-scoping-XXXXXX)
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' >> "$transcript2"
    add_issue_comment_to_transcript "$transcript2" 99
    echo '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":"git commit -m '\''feat: prior'\''"}}' >> "$transcript2"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-prior.md"}}' >> "$transcript2"
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"finishing-work"}}' >> "$transcript2"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-feature.md"}}' >> "$transcript2"
    # Add current commit to transcript so sed '$d' correctly identifies the prior commit boundary
    add_current_commit_to_transcript "$transcript2" "git commit -m 'feat: second'"
    input=$(build_bash_input_with_session "git commit -m 'feat: second'" "$transcript2" "$session_id")
    rm -f "/tmp/no-issues-${session_id}.txt"
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript" "$transcript2"
}

# --- git -C <path> support (worktree commits) ---

@test "auto-approves git -C /path commit when all requirements met" {
    transcript=$(build_transcript --session-notes --issue-comment "finishing-work")
    input=$(build_bash_input "git -C /path/to/repo commit -m 'feat: thing'" "$transcript")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
    rm -f "$transcript"
}

@test "blocks git -C /path commit when finishing-work not in transcript" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git -C /path/to/repo commit -m 'feat: add thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks chained git -C add && git -C commit" {
    transcript=$(build_transcript)
    input=$(build_bash_input "git -C /path/to/repo add -A && git -C /path/to/repo commit -m 'feat: stuff'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "allows git -C /path commit-graph write (not git commit)" {
    input=$(build_bash_input "git -C /path/to/repo commit-graph write" "/dev/null")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "detects prior git -C commit as boundary — blocks second commit without re-invoked skills" {
    # Prior commit used git -C, current uses plain git commit.
    # The prior-commit boundary detection must recognize git -C as a commit.
    transcript=$(mktemp /tmp/claude-tdd-transcript-XXXXXX)
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' >> "$transcript"
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"finishing-work"}}' >> "$transcript"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-prior.md"}}' >> "$transcript"
    jq -n -c --arg cmd "gh issue comment 42 --body \"Progress: prior\"" '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":$cmd}}' >> "$transcript"
    # Prior commit used git -C
    jq -n -c '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":"git -C /path/to/repo commit -m '\''feat: prior'\''"}}' >> "$transcript"
    # No skills re-invoked after prior commit — current commit should be blocked
    add_current_commit_to_transcript "$transcript" "git commit -m 'feat: second thing'"
    input=$(build_bash_input "git commit -m 'feat: second thing'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks git -C commit (current) when skills only invoked before prior plain commit" {
    # Prior commit used plain git commit, current uses git -C.
    # Gate check must catch git -C as a commit command.
    transcript=$(build_transcript --prior-commit --pre-commit-skills "finishing-work")
    add_current_commit_to_transcript "$transcript" "git -C /path/to/repo commit -m 'feat: second'"
    input=$(build_bash_input "git -C /path/to/repo commit -m 'feat: second'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}

@test "blocks when both prior and current commits use git -C without re-invoked skills" {
    # Both commits use git -C — boundary detection AND gate must handle -C.
    transcript=$(mktemp /tmp/claude-tdd-transcript-XXXXXX)
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' >> "$transcript"
    echo '{"type":"tool_use","tool_name":"Skill","tool_input":{"skill":"finishing-work"}}' >> "$transcript"
    echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-prior.md"}}' >> "$transcript"
    jq -n -c --arg cmd "gh issue comment 42 --body \"Progress: prior\"" '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":$cmd}}' >> "$transcript"
    # Prior commit used git -C
    jq -n -c '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":"git -C /path/to/repo commit -m '\''feat: prior'\''"}}' >> "$transcript"
    # No skills re-invoked — current commit (also git -C) should be blocked
    add_current_commit_to_transcript "$transcript" "git -C /path/to/repo commit -m 'feat: second'"
    input=$(build_bash_input "git -C /path/to/repo commit -m 'feat: second'" "$transcript")
    run_and_assert_blocked "$input" "$HOOK"
    rm -f "$transcript"
}
