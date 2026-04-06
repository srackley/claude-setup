#!/usr/bin/env bats

load helpers

# The extract_timeline function is sourced from commit-gate.sh.
# We test it by calling the extraction script directly.
EXTRACTOR="$BATS_TEST_DIRNAME/../extract-timeline.sh"

# --- Basic event extraction ---

@test "extracts SKILL events from transcript" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    echo "$output" | grep -q 'SKILL: superpowers:test-driven-development'
    echo "$output" | grep -q 'SKILL: reviewing-code'
    echo "$output" | grep -q 'SKILL: finishing-work'
}

@test "extracts AGENT events from transcript" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:code-reviewer'
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:silent-failure-hunter'
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:code-simplifier'
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:pr-test-analyzer'
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:comment-analyzer'
}

@test "extracts WRITE events from transcript" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    echo "$output" | grep -q 'WRITE: src/lib/slugify.test.ts'
    echo "$output" | grep -q 'WRITE: src/lib/slugify.ts'
}

@test "extracts TEST events with pass/fail from transcript" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    echo "$output" | grep -q 'TEST:.*FAIL'
    echo "$output" | grep -q 'TEST:.*PASS'
}

@test "extracts USER messages from transcript" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-violations.jsonl)
    echo "$output" | grep -q 'USER: Use the docs-researcher agent'
}

@test "extracts RESEARCH events from transcript" {
    # The clean fixture has no research tools; the violations fixture
    # has a general-purpose agent (NOT docs-researcher) — no RESEARCH events
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    ! echo "$output" | grep -q '^.*RESEARCH:'
}

# --- Line numbers ---

@test "each line includes a line number" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    # Every non-empty line should start with [LINE N]
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^\[LINE\ [0-9]+\] ]]
    done <<< "$output"
}

@test "line numbers are monotonically increasing" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    prev=0
    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        num=$(echo "$line" | sed 's/\[LINE \([0-9]*\)\].*/\1/')
        [[ "$num" -ge "$prev" ]]
        prev=$num
    done <<< "$output"
}

# --- Edge cases ---

@test "handles empty transcript" {
    empty=$(mktemp /tmp/compliance-empty-XXXXXX)
    output=$("$EXTRACTOR" "$empty")
    [[ -z "$output" ]]
    rm -f "$empty"
}

@test "handles missing transcript file" {
    run "$EXTRACTOR" /tmp/nonexistent-transcript-999.jsonl
    [[ "$status" -ne 0 ]]
}

@test "output is compact (under 200 lines for fixture)" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    line_count=$(echo "$output" | wc -l)
    [[ "$line_count" -lt 200 ]]
}

# --- Substitution detection support ---

@test "violations fixture shows substitution: user asked for docs-researcher, got general-purpose" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-violations.jsonl)
    # USER message should mention docs-researcher
    echo "$output" | grep 'USER:' | grep -q 'docs-researcher'
    # Next AGENT should be general-purpose (not docs-researcher)
    echo "$output" | grep -q 'AGENT: general-purpose'
}

# --- Incomplete review loop detection support ---

@test "clean fixture shows 5 agents after reviewing-code" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-clean.jsonl)
    # Count AGENT lines after the reviewing-code SKILL line
    in_review=false
    agent_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q 'SKILL: reviewing-code'; then
            in_review=true
            continue
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q '^.*SKILL:'; then
            break
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q 'AGENT:'; then
            agent_count=$((agent_count + 1))
        fi
    done <<< "$output"
    [[ "$agent_count" -eq 5 ]]
}

# --- Real transcript format (nested in .message.content[]) ---

@test "extracts SKILL events from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'SKILL: superpowers:test-driven-development'
    echo "$output" | grep -q 'SKILL: reviewing-code'
    echo "$output" | grep -q 'SKILL: finishing-work'
}

@test "extracts AGENT events from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:code-reviewer'
    echo "$output" | grep -q 'AGENT: pr-review-toolkit:silent-failure-hunter'
}

@test "extracts WRITE and EDIT events from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'WRITE: src/lib/slugify.test.ts'
    echo "$output" | grep -q 'WRITE: src/lib/slugify.ts'
    echo "$output" | grep -q 'EDIT: src/lib/slugify.ts'
}

@test "extracts TEST events from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'TEST:.*bats'
}

@test "extracts USER messages from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'USER: implement the slugify function'
}

@test "extracts RESEARCH events from real transcript format" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    echo "$output" | grep -q 'RESEARCH: WebSearch'
}

@test "real format: 5 agents after reviewing-code" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-real-format.jsonl)
    in_review=false
    agent_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q 'SKILL: reviewing-code'; then
            in_review=true
            continue
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q '^.*SKILL:'; then
            break
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q 'AGENT:'; then
            agent_count=$((agent_count + 1))
        fi
    done <<< "$output"
    [[ "$agent_count" -eq 5 ]]
}

@test "violations fixture shows only 2 agents after reviewing-code" {
    output=$("$EXTRACTOR" /tmp/compliance-fixture-violations.jsonl)
    in_review=false
    agent_count=0
    while IFS= read -r line; do
        if echo "$line" | grep -q 'SKILL: reviewing-code'; then
            in_review=true
            continue
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q '^.*SKILL:'; then
            break
        fi
        if [[ "$in_review" == true ]] && echo "$line" | grep -q 'AGENT:'; then
            agent_count=$((agent_count + 1))
        fi
    done <<< "$output"
    [[ "$agent_count" -eq 2 ]]
}
