#!/usr/bin/env bats

load helpers

teardown() {
    rm -f /tmp/claude-tdd-transcript-*
}

HOOK="$BATS_TEST_DIRNAME/../skill-enforcement.sh"

# --- Existing rules should still work ---

@test "blocks story file edits" {
    input=$(build_file_input "Edit" "/path/to/Button.stories.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "blocks skill file edits without transcript" {
    input=$(build_file_input "Edit" "$HOME/.claude/skills/my-skill.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "allows regular tsx files" {
    input=$(build_file_input "Edit" "/path/to/Button.tsx")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Rule 4: Test file TDD warning ---

@test "warns on .test.tsx file edits" {
    input=$(build_file_input "Edit" "/path/to/packages/wanderu-components/src/Button/tests/Button.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "warns on .test.ts file edits" {
    input=$(build_file_input "Edit" "/path/to/utils.test.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "warns on .test.jsx file edits" {
    input=$(build_file_input "Edit" "/path/to/Header.test.jsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "warns on .test.js file edits" {
    input=$(build_file_input "Edit" "/path/to/helpers.test.js")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "warns on .spec.ts file edits" {
    input=$(build_file_input "Edit" "/path/to/api.spec.ts")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "warns on .spec.tsx file edits" {
    input=$(build_file_input "Edit" "/path/to/api.spec.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "test file warning mentions TDD" {
    input=$(build_file_input "Edit" "/path/to/Button.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    echo "$output" | jq -r '.reason' | grep -qiE "test-driven-development|TDD"
}

@test "warns on new test file creation (Write)" {
    input=$(build_file_input "Write" "/path/to/NewFeature.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

# --- Regression: test files under components/ should warn (Rule 4), not block (Rule 3) ---

@test "Writing component test file gets TDD warn, not component block" {
    input=$(build_file_input "Write" "/path/to/src/components/ui/color-dot.test.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "Writing component spec file gets TDD warn, not component block" {
    input=$(build_file_input "Write" "/path/to/src/components/ui/button.spec.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

# --- Rule overlap: stories under components/ should get story block (Rule 2), not component block (Rule 3) ---

@test "Writing story file under components/ gets story block, not component block" {
    input=$(build_file_input "Write" "/path/to/src/components/ui/Button.stories.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
    echo "$output" | jq -r '.reason' | grep -q "Storybook"
}

@test "Editing story file under components/ gets story block" {
    input=$(build_file_input "Edit" "/path/to/src/components/ui/Dialog.stories.tsx")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
    echo "$output" | jq -r '.reason' | grep -q "Storybook"
}

# --- Rule overlap: test files under skills/ should get skill warn (Rule 1), not TDD warn (Rule 4) ---

@test "Editing test-like file under skills/ gets skill block, not TDD warn" {
    input=$(build_file_input "Edit" "$HOME/.claude/skills/my-skill.test.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
    echo "$output" | jq -r '.reason' | grep -q "writing-skills"
}

# --- Negative cases: non-test files should not trigger Rule 4 ---

@test "does not warn on regular .ts files" {
    input=$(build_file_input "Edit" "/path/to/utils.ts")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "does not warn on regular .js files" {
    input=$(build_file_input "Edit" "/path/to/config.js")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Rule 5: Plan docs require writing-plans skill ---

@test "blocks plan doc edit without transcript" {
    input=$(build_file_input "Edit" "/path/to/project/docs/plans/2026-02-28-feature.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "blocks plan doc Write without transcript" {
    input=$(build_file_input "Write" "/path/to/project/docs/plans/2026-02-28-new-plan.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "blocks plan doc in worktree without transcript" {
    input=$(build_file_input "Edit" "/Users/me/project/.worktrees/feature/docs/plans/my-plan.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "plan doc block mentions writing-plans" {
    input=$(build_file_input "Edit" "/path/to/docs/plans/2026-02-28-feature.md")
    output=$(echo "$input" | bash "$HOOK")
    echo "$output" | jq -r '.reason' | grep -q "writing-plans"
}

@test "does not warn on docs/ files outside plans/" {
    input=$(build_file_input "Edit" "/path/to/docs/conventions/testing.md")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "does not warn on plans in non-docs directories" {
    input=$(build_file_input "Edit" "/path/to/src/plans/something.md")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Rule 1: Transcript-aware skill file enforcement ---

@test "Rule 1: blocks skill file edit when writing-skills NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Edit" "$HOME/.claude/skills/my-skill.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 1: allows skill file edit when writing-skills IS in transcript" {
    transcript=$(build_transcript "writing-skills")
    input=$(build_file_input_with_transcript "Edit" "$HOME/.claude/skills/my-skill.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 1: allows skill file edit when superpowers:writing-skills IS in transcript" {
    transcript=$(build_transcript "superpowers:writing-skills")
    input=$(build_file_input_with_transcript "Edit" "$HOME/.claude/skills/my-skill.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 1: blocks skill file edit when transcript path is missing" {
    input=$(build_file_input "Edit" "$HOME/.claude/skills/my-skill.md")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

# --- Rule 2: Transcript-aware story file enforcement ---

@test "Rule 2: blocks story file edit when storybook-stories NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 2: allows story file edit when storybook-stories IS in transcript" {
    transcript=$(build_transcript "storybook-stories")
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 2: allows story file edit when superpowers:storybook-stories IS in transcript" {
    transcript=$(build_transcript "superpowers:storybook-stories")
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 2: blocks story file Write when storybook-stories NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Write" "/path/to/Dialog.stories.ts" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

# --- Rule 3: Transcript-aware component file enforcement ---

@test "Rule 3: blocks new component Write when creating-component NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Write" "/path/to/src/components/ui/color-dot.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 3: allows new component Write when creating-component IS in transcript" {
    transcript=$(build_transcript "creating-component")
    input=$(build_file_input_with_transcript "Write" "/path/to/src/components/ui/color-dot.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 3: still does not apply to Edit (only Write)" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Edit" "/path/to/src/components/ui/color-dot.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 3: blocks new wanderu-components Write without skill" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Write" "/path/to/wanderu-components/Button.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 3: allows new wanderu-components Write with skill" {
    transcript=$(build_transcript "creating-component")
    input=$(build_file_input_with_transcript "Write" "/path/to/wanderu-components/Button.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

# --- Rule 5: Transcript-aware plan doc enforcement ---

@test "Rule 5: blocks plan doc edit when writing-plans NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Edit" "/path/to/docs/plans/2026-03-02-feature.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 5: allows plan doc edit when writing-plans IS in transcript" {
    transcript=$(build_transcript "writing-plans")
    input=$(build_file_input_with_transcript "Edit" "/path/to/docs/plans/2026-03-02-feature.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 5: allows plan doc edit when superpowers:writing-plans IS in transcript" {
    transcript=$(build_transcript "superpowers:writing-plans")
    input=$(build_file_input_with_transcript "Edit" "/path/to/docs/plans/2026-03-02-feature.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}

@test "Rule 5: blocks plan doc Write when writing-plans NOT in transcript" {
    transcript=$(build_transcript)
    input=$(build_file_input_with_transcript "Write" "/path/to/docs/plans/2026-03-02-new-plan.md" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

# --- Edge cases: transcript behavior ---

@test "Empty transcript file causes block (fail-closed)" {
    tmpfile=$(mktemp /tmp/claude-tdd-transcript-XXXXXX)
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$tmpfile")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Nonexistent transcript path causes block (fail-closed)" {
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "/tmp/nonexistent-transcript-abc123.jsonl")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Rule 4 still warns regardless of transcript content" {
    transcript=$(build_transcript "superpowers:test-driven-development")
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.test.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_warned "$output"
}

@test "Unrelated skill in transcript does not satisfy Rule 2" {
    transcript=$(build_transcript "creating-component")
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    assert_blocked "$output"
}

@test "Multiple skills in transcript — correct one satisfies rule" {
    transcript=$(build_transcript "creating-component" "storybook-stories")
    input=$(build_file_input_with_transcript "Edit" "/path/to/Button.stories.tsx" "$transcript")
    output=$(echo "$input" | bash "$HOOK")
    [[ -z "$output" ]]
}
