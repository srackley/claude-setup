#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../skill-tracker-probe.sh"

setup() {
    export SKILL_PROBE_LOG="/tmp/claude-skill-probe-test-$$.log"
    rm -f "$SKILL_PROBE_LOG"
}

teardown() {
    rm -f "$SKILL_PROBE_LOG"
}

@test "logs skill invocation to probe log" {
    input=$(jq -n '{tool_name: "Skill", tool_input: {skill: "finishing-work"}}')
    echo "$input" | bash "$HOOK"
    [[ -f "$SKILL_PROBE_LOG" ]]
    grep -q "finishing-work" "$SKILL_PROBE_LOG"
}

@test "logs tool_name in entry" {
    input=$(jq -n '{tool_name: "Skill", tool_input: {skill: "brainstorming"}}')
    echo "$input" | bash "$HOOK"
    grep -q "tool=Skill" "$SKILL_PROBE_LOG"
}

@test "logs non-Skill tool calls too (for wildcard matcher testing)" {
    input=$(jq -n '{tool_name: "Bash", tool_input: {command: "ls"}}')
    echo "$input" | bash "$HOOK"
    grep -q "tool=Bash" "$SKILL_PROBE_LOG"
}

@test "appends multiple entries" {
    input1=$(jq -n '{tool_name: "Skill", tool_input: {skill: "first"}}')
    input2=$(jq -n '{tool_name: "Skill", tool_input: {skill: "second"}}')
    echo "$input1" | bash "$HOOK"
    echo "$input2" | bash "$HOOK"
    line_count=$(wc -l < "$SKILL_PROBE_LOG")
    [[ $line_count -eq 2 ]]
}

@test "exits with code 0" {
    input=$(jq -n '{tool_name: "Skill", tool_input: {skill: "test"}}')
    echo "$input" | bash "$HOOK"
}
