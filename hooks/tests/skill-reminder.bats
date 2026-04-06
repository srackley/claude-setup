#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../skill-reminder.sh"

# --- Conditional firing: action-intent prompts ---

@test "fires on action-intent prompt: 'implement'" {
    input=$(build_prompt_input "implement the login form")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'fix'" {
    input=$(build_prompt_input "fix the authentication bug")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'add'" {
    input=$(build_prompt_input "add a logout button")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'create'" {
    input=$(build_prompt_input "create a new component for the sidebar")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'build'" {
    input=$(build_prompt_input "build the API endpoint")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'write'" {
    input=$(build_prompt_input "write tests for the auth module")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'commit'" {
    input=$(build_prompt_input "commit my changes")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'refactor'" {
    input=$(build_prompt_input "refactor the data fetching logic")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

@test "fires on action-intent prompt: 'deploy'" {
    input=$(build_prompt_input "deploy to staging")
    output=$(echo "$input" | bash "$HOOK")
    [[ -n "$output" ]]
}

# --- Does NOT fire on non-action prompts ---

@test "silent on questions: 'what is'" {
    input=$(build_prompt_input "what is the current branch?")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "silent on questions: 'show me'" {
    input=$(build_prompt_input "show me the test results")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "silent on status checks" {
    input=$(build_prompt_input "how is the CI looking?")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "silent on clarifications" {
    input=$(build_prompt_input "yes, that looks right")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "silent on read requests" {
    input=$(build_prompt_input "read the design doc")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Negative framing ---

@test "uses negative framing: asks why skills do NOT apply" {
    input=$(build_prompt_input "implement the feature")
    output=$(echo "$input" | bash "$HOOK")
    echo "$output" | grep -qi "NOT apply\|does not apply\|doesn't apply"
}

@test "output is concise (under 600 chars)" {
    input=$(build_prompt_input "add a button")
    output=$(echo "$input" | bash "$HOOK")
    char_count=${#output}
    [[ $char_count -lt 600 ]]
}

@test "exits with code 0" {
    input=$(build_prompt_input "implement something")
    echo "$input" | bash "$HOOK"
}
