#!/bin/bash
# Shared bats test helpers for Claude Code hook testing.
#
# Usage in .bats files:
#   load helpers

# Ensure jq is available (asdf shim needs explicit version)
export ASDF_JQ_VERSION="${ASDF_JQ_VERSION:-1.8.1}"

# Build a minimal PreToolUse hook input JSON for Bash tool calls.
# Usage: build_bash_input "git commit -m 'foo'" "/path/to/transcript.jsonl"
build_bash_input() {
    local command="$1"
    local transcript="${2:-/dev/null}"
    jq -n \
        --arg cmd "$command" \
        --arg tp "$transcript" \
        '{
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp
        }'
}

# Build a minimal PreToolUse hook input JSON for Edit/Write tool calls.
# Usage: build_file_input "Edit" "/path/to/file.test.tsx"
build_file_input() {
    local tool="$1"
    local file_path="$2"
    jq -n \
        --arg tn "$tool" \
        --arg fp "$file_path" \
        '{
            tool_name: $tn,
            tool_input: { file_path: $fp }
        }'
}

# Build a minimal UserPromptSubmit hook input JSON.
# Usage: build_prompt_input "add a button"
build_prompt_input() {
    local prompt="$1"
    jq -n \
        --arg p "$prompt" \
        '{ prompt: $p }'
}

# Build a mock transcript JSONL with optional skill invocations and tool calls.
# Returns path to a temp file. Caller must rm -f it when done.
# Usage: transcript=$(build_transcript "finishing-work" "reviewing-code")
# Usage with session notes: transcript=$(build_transcript --session-notes "finishing-work" "reviewing-code")
# Usage with prior commit: transcript=$(build_transcript --prior-commit "reviewing-code" "finishing-work")
#   --prior-commit inserts a git commit between the baseline and the skill invocations,
#   simulating a previous commit in the same session. Skills BEFORE the commit marker
#   should NOT count for a new commit.
# Usage combined: transcript=$(build_transcript --session-notes --prior-commit "reviewing-code" "finishing-work")
#   --pre-commit-skills "skill1" "skill2" adds skills BEFORE the commit marker (for the prior commit)
# Usage: transcript=$(build_transcript --prior-commit --pre-commit-skills "reviewing-code" "finishing-work" --session-notes "reviewing-code" "finishing-work")
build_transcript() {
    local tmpfile
    local include_session_notes=false
    local include_prior_commit=false
    local include_issue_comment=false
    tmpfile=$(mktemp /tmp/claude-tdd-transcript-XXXXXX)

    # Parse flags and collect positional args
    local args=()
    local pre_commit_skills=()
    local parsing_pre_commit=false
    for arg in "$@"; do
        if [[ "$arg" == "--session-notes" ]]; then
            include_session_notes=true
            parsing_pre_commit=false
        elif [[ "$arg" == "--prior-commit" ]]; then
            include_prior_commit=true
            parsing_pre_commit=false
        elif [[ "$arg" == "--issue-comment" ]]; then
            include_issue_comment=true
            parsing_pre_commit=false
        elif [[ "$arg" == "--pre-commit-skills" ]]; then
            parsing_pre_commit=true
        elif [[ "$parsing_pre_commit" == true ]]; then
            # Check if this looks like a flag (starts with --)
            if [[ "$arg" == --* ]]; then
                parsing_pre_commit=false
                # Re-process this arg
                if [[ "$arg" == "--session-notes" ]]; then
                    include_session_notes=true
                elif [[ "$arg" == "--prior-commit" ]]; then
                    include_prior_commit=true
                elif [[ "$arg" == "--issue-comment" ]]; then
                    include_issue_comment=true
                fi
            else
                pre_commit_skills+=("$arg")
            fi
        else
            args+=("$arg")
        fi
    done

    # Baseline content (a Read tool call)
    echo '{"type":"tool_use","tool_name":"Read","tool_input":{"file_path":"/tmp/foo.js"}}' >> "$tmpfile"

    # Pre-commit skills (belong to the prior commit's workflow)
    for skill in "${pre_commit_skills[@]}"; do
        echo "{\"type\":\"tool_use\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"${skill}\"}}" >> "$tmpfile"
    done

    # Prior commit marker
    if [[ "$include_prior_commit" == true ]]; then
        echo '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":"git commit -m '\''feat: prior commit'\''"}}' >> "$tmpfile"
        # Also add a session-notes write for the prior commit (so it's complete)
        echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-prior.md"}}' >> "$tmpfile"
    fi

    # Post-commit skills (belong to the current commit's workflow)
    for skill in "${args[@]}"; do
        echo "{\"type\":\"tool_use\",\"tool_name\":\"Skill\",\"tool_input\":{\"skill\":\"${skill}\"}}" >> "$tmpfile"
    done

    if [[ "$include_session_notes" == true ]]; then
        echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/session-notes/ui-react/2026-02-28-feature.md"}}' >> "$tmpfile"
    fi

    if [[ "$include_issue_comment" == true ]]; then
        add_issue_comment_to_transcript "$tmpfile" 42
    fi

    echo "$tmpfile"
}

# Add a noise line to a transcript that mentions "git commit" in a non-command context.
# Simulates skill content, hook prompts, or session notes that reference committing.
# Usage: add_noise_line "$transcript" "skill-text"
# Types: skill-text, hook-prompt, session-note
add_noise_line() {
    local tmpfile="$1"
    local noise_type="${2:-skill-text}"

    case "$noise_type" in
        skill-text)
            # Simulates finishing-work skill content loaded into transcript (mentions "git commit" in documentation)
            echo '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"No git commit without fresh verification output AND code review in this session."}]}}' >> "$tmpfile"
            ;;
        hook-prompt)
            # Simulates compliance reviewer agent hook prompt (mentions "git commit" in its instructions)
            echo '{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Check if the command in tool_input.command contains git commit. If NOT, respond immediately."}]}}' >> "$tmpfile"
            ;;
        session-note)
            # Session notes mentioning git commit — uses a DIFFERENT path than real session notes
            # to avoid accidentally satisfying the session-notes/ grep check
            echo '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":"/Users/me/.claude/scratch/commit-notes.md","content":"Run git commit after finishing-work"}}' >> "$tmpfile"
            ;;
        grep-diagnostic)
            # Simulates a diagnostic grep command that searches for 'git commit' in the transcript.
            # Uses single quotes (no JSON escaping) so "git commit" appears unbroken in the
            # command field — this is the real-world pattern that triggers the false positive.
            jq -n -c --arg cmd "grep -c 'git commit' /tmp/transcript.jsonl" \
                '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":$cmd}}' >> "$tmpfile"
            ;;
    esac
}

# Add the current commit attempt to the transcript, simulating what Claude Code
# does before PreToolUse fires (writes tool_use to transcript, then calls hook).
# Usage: add_current_commit_to_transcript "$transcript" "git commit -m 'feat: thing'"
add_current_commit_to_transcript() {
    local tmpfile="$1"
    local command="${2:-git commit -m 'feat: current commit'}"
    jq -n -c --arg cmd "$command" '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":$cmd}}' >> "$tmpfile"
}

# Assert that hook output contains a deny decision (hookSpecificOutput format).
assert_denied() {
    local output="$1"
    echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null 2>&1
}

# Assert that hook output is empty or does not contain a deny decision.
assert_allowed() {
    local output="$1"
    if [[ -z "$output" ]]; then
        return 0
    fi
    # If there's output, it should NOT be a deny
    ! echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "deny"' > /dev/null 2>&1
}

# Assert that hook output contains a block/warn decision (simple format).
assert_blocked() {
    local output="$1"
    echo "$output" | jq -e '.decision == "block"' > /dev/null 2>&1
}

assert_warned() {
    local output="$1"
    echo "$output" | jq -e '.decision == "warn"' > /dev/null 2>&1
}

# Run a hook and assert it exits with code 2 (blocking error).
# Usage: run_and_assert_blocked "$input" "$HOOK"
# Sets $stderr_output for further assertions on the error message.
run_and_assert_blocked() {
    local input="$1"
    local hook="$2"
    stderr_output=$(echo "$input" | bash "$hook" 2>&1 1>/dev/null) && {
        echo "Expected exit code 2 but got 0"
        return 1
    }
    local exit_code=$?
    if [[ $exit_code -ne 2 ]]; then
        echo "Expected exit code 2 but got $exit_code"
        return 1
    fi
    return 0
}

# Run a hook and assert it exits with code 0 (allowed).
# Usage: run_and_assert_allowed "$input" "$HOOK"
run_and_assert_allowed() {
    local input="$1"
    local hook="$2"
    echo "$input" | bash "$hook" 2>/dev/null
}

# Run a hook and capture stdout. Sets $hook_stdout for further assertions.
# Usage: run_hook_capture_stdout "$input" "$HOOK"
run_hook_capture_stdout() {
    local input="$1"
    local hook="$2"
    hook_stdout=$(echo "$input" | bash "$hook" 2>/dev/null)
}

# Assert that hook stdout contains permissionDecision "allow" (auto-approve).
assert_auto_approved() {
    local output="$1"
    echo "$output" | jq -e '.hookSpecificOutput.permissionDecision == "allow"' > /dev/null 2>&1
}

# Build a PreToolUse hook input JSON for Edit/Write with transcript_path and session_id.
# Usage: build_file_input_with_transcript "Edit" "/path/to/file.ts" "/path/to/transcript.jsonl"
build_file_input_with_transcript() {
    local tool="$1"
    local file_path="$2"
    local transcript="$3"
    local session_id="${4:-test-session-123}"
    jq -n \
        --arg tn "$tool" \
        --arg fp "$file_path" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            session_id: $sid,
            tool_name: $tn,
            tool_input: { file_path: $fp },
            transcript_path: $tp
        }'
}

# Build a PostToolUse hook input JSON for Bash tool calls (successful commands).
# PostToolUse only fires on SUCCESS. tool_response varies by tool.
# Usage: build_post_bash_success "task test" "/path/to/transcript.jsonl"
build_post_bash_success() {
    local command="$1"
    local transcript="${2:-/dev/null}"
    local session_id="${3:-test-session-123}"
    jq -n \
        --arg cmd "$command" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            session_id: $sid,
            tool_name: "Bash",
            tool_input: { command: $cmd },
            tool_response: { stdout: "Tests passed", stderr: "" },
            transcript_path: $tp,
            hook_event_name: "PostToolUse"
        }'
}

# Build a PostToolUseFailure hook input JSON for Bash tool calls (failed commands).
# PostToolUseFailure fires when a tool execution fails. Has error + is_interrupt fields.
# Usage: build_post_bash_failure "task test" "/path/to/transcript.jsonl"
build_post_bash_failure() {
    local command="$1"
    local transcript="${2:-/dev/null}"
    local error_msg="${3:-Command exited with non-zero status code 1}"
    local session_id="${4:-test-session-123}"
    jq -n \
        --arg cmd "$command" \
        --arg tp "$transcript" \
        --arg err "$error_msg" \
        --arg sid "$session_id" \
        '{
            session_id: $sid,
            tool_name: "Bash",
            tool_input: { command: $cmd },
            error: $err,
            is_interrupt: false,
            transcript_path: $tp,
            hook_event_name: "PostToolUseFailure"
        }'
}

# Create a TDD state file with given state. Returns the file path.
# Usage: state_file=$(create_tdd_state "TDD-RED")
create_tdd_state() {
    local state="$1"
    local tmpfile
    tmpfile=$(mktemp /tmp/claude-tdd-state-test-XXXXXX)
    jq -n \
        --arg s "$state" \
        --arg t "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '{ state: $s, updated_at: $t }' > "$tmpfile"
    echo "$tmpfile"
}

# Read the state from a TDD state file.
# Usage: state=$(read_tdd_state "$state_file")
read_tdd_state() {
    local state_file="$1"
    jq -r '.state' "$state_file" 2>/dev/null
}

# Build a PreToolUse hook input JSON for Bash with session_id and transcript_path.
# Usage: build_bash_input_with_session "gh pr create" "/path/to/transcript.jsonl" "my-session-id"
build_bash_input_with_session() {
    local command="$1"
    local transcript="${2:-/dev/null}"
    local session_id="${3:-test-session-abc}"
    jq -n \
        --arg cmd "$command" \
        --arg tp "$transcript" \
        --arg sid "$session_id" \
        '{
            session_id: $sid,
            tool_name: "Bash",
            tool_input: { command: $cmd },
            transcript_path: $tp
        }'
}

# Append a gh issue comment Bash command to a transcript.
# Simulates Claude posting a progress comment on a GitHub issue.
# Usage: add_issue_comment_to_transcript "$transcript" 123
add_issue_comment_to_transcript() {
    local tmpfile="$1"
    local issue_number="${2:-42}"
    jq -n -c --arg cmd "gh issue comment ${issue_number} --body \"Progress: implemented the thing\"" \
        '{"type":"tool_use","tool_name":"Bash","tool_input":{"command":$cmd}}' >> "$tmpfile"
}

# Append a Write tool call for the PR verification file to a transcript.
# Simulates Claude writing the verification table during the session.
# Usage: add_verification_write_to_transcript "$transcript" "test-session-abc"
add_verification_write_to_transcript() {
    local tmpfile="$1"
    local session_id="${2:-test-session-abc}"
    local token_file="/tmp/pr-verification-${session_id}.md"
    jq -n -c --arg fp "$token_file" \
        '{"type":"tool_use","tool_name":"Write","tool_input":{"file_path":$fp}}' >> "$tmpfile"
}
