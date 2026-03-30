---
name: implementing-issue
description: Use when starting work on a GitHub issue — orchestrates fetch, branch, worktree, TDD, finish, and PR creation
---

# Implementing a GitHub Issue

Orchestrate end-to-end implementation of a GitHub issue. Every step marked REQUIRED must be executed — no exceptions.

## Process

### 1. Fetch Issue
`gh issue view <number>`

### 2. Display Summary and Confirm
Show title, description, labels, assignees. **Get user confirmation before proceeding.** Do not start implementation, create branches, or explore code until the user confirms.

### 3. Create Branch
Determine prefix from labels:
- `bug` label -> `fix/`
- `feature` or `enhancement` label -> `feat/`
- Everything else -> `chore/`

Format: `{prefix}/{issue-number}-{slug}`

Example: `feat/17-add-user-search`

If the issue has no labels, ask the user for the branch prefix.

### 4. Create Worktree
**REQUIRED:** Invoke `superpowers:using-git-worktrees` with the branch name from step 3. Do not manually run `git worktree add` — the skill handles worktree creation, directory placement, and setup.

### 5. Implement with TDD
**REQUIRED:** Invoke `superpowers:test-driven-development`. Write tests first, watch them fail, then implement.

### 6. Finish Work
**REQUIRED:** Invoke `finishing-work` skill. This handles commit hygiene, lint, and final checks. Do not skip this even if you already committed — the skill may catch issues.

### 7. Create PR
**REQUIRED:** Invoke `creating-pr` skill. The PR body MUST include:
- `Closes #<issue-number>` to auto-close the issue on merge
- Reference to the original issue for context

## Rules
- EVERY step marked REQUIRED must be invoked as a skill — do not substitute manual commands
- Always confirm with user before starting implementation (after step 2)
- If implementation reveals the issue needs clarification, pause and ask
- Do not skip `finishing-work` because "the code is already committed"
- Do not skip `using-git-worktrees` because "we're already on a feature branch"
- Do not skip TDD because "this is a simple endpoint"
- The full cycle runs in one flow — do not defer PR creation to "later"
