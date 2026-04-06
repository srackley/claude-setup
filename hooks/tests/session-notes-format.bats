#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../session-notes-format.sh"
SESSION_NOTES_PATH="$HOME/.claude/session-notes/ui-react/2026-03-09-test.md"

# --- Should block: Write with no date heading ---

@test "blocks Write to session-notes with # heading" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg content "# My session notes\n\n## What happened\n\nStuff" \
        '{ tool_name: "Write", tool_input: { file_path: $fp, content: $content } }')
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

@test "blocks Write to session-notes with ## heading but no date" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg content "## My session notes\n\n### What happened\n\nStuff" \
        '{ tool_name: "Write", tool_input: { file_path: $fp, content: $content } }')
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

@test "blocks Edit to session-notes with new_string missing date heading" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg new_string "# Wrong format\n\nsome content" \
        '{ tool_name: "Edit", tool_input: { file_path: $fp, new_string: $new_string } }')
    run bash "$HOOK" <<< "$input"
    assert_blocked "$output"
}

# --- Should allow: correct ## YYYY-MM-DD format ---

@test "allows Write to session-notes with correct ## YYYY-MM-DD heading" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg content "## 2026-03-09: My session\n\n### Context\n\nStuff" \
        '{ tool_name: "Write", tool_input: { file_path: $fp, content: $content } }')
    run bash "$HOOK" <<< "$input"
    assert_allowed "$output"
}

@test "allows Write to session-notes with auto-generated ## [YYYY-MM-DD HH:MM] format" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg content "## [2026-03-09 14:00] Session: abc12345 [AUTO-GENERATED]\n\n### Current Task" \
        '{ tool_name: "Write", tool_input: { file_path: $fp, content: $content } }')
    run bash "$HOOK" <<< "$input"
    assert_allowed "$output"
}

@test "allows Edit to session-notes with correct date heading in new_string" {
    input=$(jq -n \
        --arg fp "$SESSION_NOTES_PATH" \
        --arg new_string "## 2026-03-09: Fix\n\n### Context\n\nStuff" \
        '{ tool_name: "Edit", tool_input: { file_path: $fp, new_string: $new_string } }')
    run bash "$HOOK" <<< "$input"
    assert_allowed "$output"
}

# --- Should allow: not a session-notes file ---

@test "allows Write to non-session-notes .md file" {
    input=$(jq -n \
        --arg fp "$HOME/.claude/skills/finishing-work/session-notes-methodology.md" \
        --arg content "# title\n\nno date heading but not session notes" \
        '{ tool_name: "Write", tool_input: { file_path: $fp, content: $content } }')
    run bash "$HOOK" <<< "$input"
    assert_allowed "$output"
}

@test "allows Bash tool (not a file tool)" {
    input=$(jq -n '{ tool_name: "Bash", tool_input: { command: "echo hello" } }')
    run bash "$HOOK" <<< "$input"
    assert_allowed "$output"
}
