---
name: implementing-linear-issue
description: Use when implementing a Linear issue, working on a specific Linear ticket, or when triaging-linear-issues offers to implement a recommended issue
---

# Implementing a Linear Issue

Orchestrate end-to-end implementation of a Linear issue by fetching context, then delegating to existing skills. This skill owns the Linear bookends; everything in between uses your standard workflow.

## Trigger

- "implement TICK-42"
- "work on TICK-42"
- Offered by `triaging-linear-issues` after recommendation

## Phase 1 — Context & Confirmation

1. Fetch issue via `mcp__linear-server__get_issue` with the identifier. Extract: title, description, labels, priority, status, assignee, comments.
2. Display a summary:

> **TICK-42: [Title]**
> Priority: [priority] | Status: [status] | Labels: [labels]
>
> [Description excerpt]
>
> Is this the right issue?

3. On confirmation, update status to **In Progress** via `mcp__linear-server__update_issue`.

**Note:** If Linear's GitHub integration auto-transitions status on branch creation, this update may be redundant. Check by querying `mcp__linear-server__list_issue_statuses` for the team — if the issue auto-transitions after the worktree/branch is created in Phase 2, skip manual status updates in Phase 4.

## Phase 2 — Setup

4. Determine branch prefix from issue labels:
   - Bug → `fix/`
   - Feature → `feat/`
   - Improvement → `chore/`
   - No label → `feat/` (default)

5. Build branch name: `{prefix}/{TEAM-NUMBER}-{slugified-title}`
   - Example: `feat/TICK-42-booking-lookup-form`
   - Slugify: lowercase, hyphens, truncate to ~50 chars

6. **REQUIRED SUB-SKILL:** Invoke `superpowers:using-git-worktrees` with that branch name.

## Phase 3 — Implementation

7. **REQUIRED SUB-SKILL:** Invoke `superpowers:test-driven-development` — the issue description serves as the spec.
8. Implementation proceeds through the normal TDD cycle.

## Phase 4 — Completion

9. **REQUIRED SUB-SKILL:** Invoke `finishing-work` (verification + commit).
10. **REQUIRED SUB-SKILL:** Invoke `creating-pr` — PR title uses `[TICK-42] Description` format. Include Linear issue URL in PR body.
11. Update Linear issue status to **Done** or **In Review** (unless GitHub sync handles this — see Phase 1 note).
12. Add a comment on the Linear issue linking to the PR via `mcp__linear-server__create_comment`.

## Responsibility Matrix

| This skill owns                     | Delegates to                          |
|-------------------------------------|---------------------------------------|
| Fetching Linear issue context       | `superpowers:using-git-worktrees`     |
| Branch naming convention            | `superpowers:test-driven-development` |
| Updating Linear status              | `finishing-work`                      |
| Linking PR back to Linear           | `creating-pr`                         |

## Red Flags

| Thought | Reality |
|---------|---------|
| "I'll skip the confirmation step" | Always confirm the issue before starting work. |
| "I'll figure out the branch name as I go" | Follow the convention: `{prefix}/{TEAM-NUMBER}-{slug}`. |
| "I don't need to update Linear" | Update status unless GitHub sync does it. Always add a PR comment. |
| "I'll handle TDD myself" | Invoke the TDD skill. Don't improvise the workflow. |
| "The issue description is enough context" | Read comments too — they often contain clarifications. |
| "I'll skip the worktree" | NEVER. Worktree isolation is mandatory. |
| "I can skip finishing-work for a quick change" | No exceptions. Every commit goes through finishing-work. |
