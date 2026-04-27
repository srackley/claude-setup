---
name: review-pr-feedback
description: Use when a PR you authored has review comments that need triage and response
---

# Review PR Feedback

## When to Use
When a PR you authored has review comments that need triage and response.

## Behavioral Guide
**REQUIRED:** Invoke `superpowers:receiving-code-review` first — it defines HOW to evaluate and respond (no performative agreement, verify before implementing, push back when wrong). This skill handles the WORKFLOW mechanics.

## Process

### 1. Gather Context
- `gh pr view <number> --json reviews,comments`
- `gh api repos/{owner}/{repo}/pulls/{number}/comments`
- Read the full diff for each commented file

### 2. Read All Feedback First
Do NOT start responding or implementing until you've read every comment. Build a complete picture.

### 3. Evaluate Each Comment

Use this assessment matrix (per `receiving-code-review` principles):

| Dimension | Question |
|-----------|----------|
| **Validity** | Is the concern technically correct? Verify by reading code, tracing execution, checking docs. |
| **Severity** | Bug, code smell, nitpick, or edge case? |
| **Scope** | In-scope for this PR, or follow-up? |
| **Conventions** | Does suggestion match existing codebase patterns? |
| **Effort vs Value** | Is the change worthwhile given complexity? |
| **YAGNI** | Is the suggested addition actually needed? Grep for actual usage. |

### 4. Present Summary Table

Before ANY action, show user a table:

| # | File | Comment Summary | Verdict | Action |
|---|------|----------------|---------|--------|
| 1 | src/foo.ts | "Missing null check" | Valid bug | Apply |
| 2 | src/bar.ts | "Extract to helper" | Over-engineered | Push back |
| 3 | general | "Add logging" | Out of scope | Acknowledge |

**Wait for user approval before proceeding.** Do not implement fixes, draft replies, or take any action until the user confirms the plan.

### 5. Implement Approved Changes

Apply fixes one at a time. Run tests after each fix.

### 6. Draft Replies

- **Apply**: Brief explanation of what you fixed. No performative agreement.
- **Push back**: Lead with technical reasoning for disagreement. No softening.
- **Acknowledge**: Note as follow-up task/issue.
- **Skip**: No reply needed for pure nitpicks.

Reply in the comment thread (`gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies`), not as top-level PR comments.

**Use a variable for the body field** — `--field body="..."` causes backticks to be shell-interpolated and stripped. Assign via heredoc first:
```bash
reply=$(cat <<'EOF'
Your reply text here
EOF
)
gh api repos/{owner}/{repo}/pulls/{pr}/comments/{id}/replies \
  --raw-field body="$reply"
```

### 7. Post Only After User Approval

Show all drafted replies to user. Post only after explicit approval.

## Rules
- Never implement fixes or draft replies before showing the summary table
- Never post replies without user approval
- No performative agreement: ban "Great catch!", "Good point!", "Thanks for...", "Happy to..."
- No hedge phrases that soften valid pushback: "Happy to revisit", "Happy to look at..."
- Let code changes demonstrate understanding — don't narrate agreement
- If anything is unclear, ask for clarification before acting
- If a suggestion conflicts with prior architectural decisions, stop and discuss with user first
