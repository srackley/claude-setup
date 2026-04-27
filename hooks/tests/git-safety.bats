#!/usr/bin/env bats

load helpers

HOOK="$BATS_TEST_DIRNAME/../git-safety.sh"

# --- Force push: blocked ---

@test "blocks git push --force" {
    input=$(build_bash_input "git push --force origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push -f" {
    input=$(build_bash_input "git push -f origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push -f when flag appears at end of line" {
    input=$(build_bash_input "git push origin feature-branch -f")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push with merged -f flag (e.g. -fu)" {
    input=$(build_bash_input "git push -fu origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push --force alongside --force-with-lease" {
    input=$(build_bash_input "git push --force-with-lease --force origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

# --- Force push: allowed ---

@test "allows git push --force-with-lease alone" {
    input=$(build_bash_input "git push --force-with-lease origin feature-branch")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows push to branch whose name contains -f substring (e.g. skill-followups)" {
    input=$(build_bash_input "git push origin chore/skill-followups")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows push with -C path when branch name contains -f substring" {
    input=$(build_bash_input "git -C /Users/me/.claude/.worktrees/chore-skill-followups push origin chore/skill-followups")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "allows push --force-with-lease to branch with -f substring" {
    input=$(build_bash_input "git push --force-with-lease origin chore/skill-followups")
    run_and_assert_allowed "$input" "$HOOK"
}

# --- Push to main/master: blocked ---

@test "blocks git push origin main" {
    input=$(build_bash_input "git push origin main")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push origin master" {
    input=$(build_bash_input "git push origin master")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push main with no remote specified" {
    input=$(build_bash_input "git push main")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push to main on non-origin remote" {
    input=$(build_bash_input "git push upstream main")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push to main on arbitrary named remote" {
    input=$(build_bash_input "git push myremote main")
    run_and_assert_blocked "$input" "$HOOK"
}

# --- reset --hard: blocked ---

@test "blocks git reset --hard" {
    input=$(build_bash_input "git reset --hard HEAD~1")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "allows git reset --soft" {
    input=$(build_bash_input "git reset --soft HEAD~1")
    run_and_assert_allowed "$input" "$HOOK"
}

# --- --no-verify: blocked ---

@test "blocks git commit --no-verify" {
    input=$(build_bash_input "git commit --no-verify -m 'skip hooks'")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push --no-verify" {
    input=$(build_bash_input "git push --no-verify origin feature")
    run_and_assert_blocked "$input" "$HOOK"
}

# --- Auto-approve safe read-only commands ---

@test "auto-approves git status" {
    input=$(build_bash_input "git status")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
}

@test "auto-approves git diff HEAD" {
    input=$(build_bash_input "git diff HEAD")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
}

@test "auto-approves git log --oneline" {
    input=$(build_bash_input "git log --oneline -10")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
}

@test "auto-approves git fetch origin" {
    input=$(build_bash_input "git fetch origin")
    run_hook_capture_stdout "$input" "$HOOK"
    assert_auto_approved "$hook_stdout"
}

# --- Do NOT auto-approve destructive branch/remote commands ---

@test "does not auto-approve git branch -D (local branch deletion)" {
    input=$(build_bash_input "git branch -D feature-branch")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}

@test "does not auto-approve git remote remove (remote deletion)" {
    input=$(build_bash_input "git remote remove origin")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}

@test "does not auto-approve git remote set-url (remote mutation)" {
    input=$(build_bash_input "git remote set-url origin https://other.example.com/repo.git")
    run bash "$HOOK" <<< "$input"
    [[ $status -eq 0 ]]
    [[ -z "$output" ]]
}

# --- Bypass prevention: chained commands ---

@test "blocks git push --force chained after git status with &&" {
    input=$(build_bash_input "git status && git push --force origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

@test "blocks git push --force chained with semicolon" {
    input=$(build_bash_input "git fetch; git push --force origin feature-branch")
    run_and_assert_blocked "$input" "$HOOK"
}

# --- Non-git commands pass through ---

@test "passes through non-git commands" {
    input=$(build_bash_input "task lint")
    run_and_assert_allowed "$input" "$HOOK"
}

@test "passes through empty command" {
    input=$(build_bash_input "")
    run_and_assert_allowed "$input" "$HOOK"
}
