---
name: creating-pr
description: Use when creating a pull request - handles Jira linking, PR creation, and CI monitoring
---

# Creating a Pull Request

## Overview

Create a PR with proper Jira ticket linking, then monitor CI until it's ready for review.

## When to Use

- User asks to "create a PR" or "open a PR"
- User says "let's get this merged" or similar
- After completing work on a feature branch

## Prerequisites

Run the `finishing-work` skill first to ensure verification passes before creating the PR.

**Sync with the base branch and confirm the branch merges cleanly — BEFORE creating the PR, not after.** Fetch and rebase onto the latest base (`git fetch origin && git rebase origin/<base>`). Base can move between when you branched and when you open the PR, so re-check even if it was clean earlier — a PR that conflicts with base wastes a review cycle and forces a rebase mid-review. If the rebase surfaces conflicts:
- Resolve them, then **re-run full verification** — `git rebase --continue` does **not** run the pre-commit hooks, so lint/format/type/test go unchecked on the newly-merged state until you run them yourself.
- Watch for generated files in the conflict set (e.g. next-intl `*.d.json.ts`): resolve the source, then let the generator produce the derived file rather than hand-merging it.
- After pushing, confirm the PR reports `mergeable: MERGEABLE` (`gh pr view <n> --json mergeable`).

## Process

### 1. Run comprehensive PR review

Before creating the PR, invoke `reviewing-code` on the full branch diff (`git diff main...HEAD` or equivalent).

This is **not optional.** This step reviews the complete change holistically — how all commits interact, cross-cutting concerns, test coverage gaps, and architectural issues that only appear at the full-diff level.

**Do not skip this step.** Do not run `gh pr create` until the review is complete and findings are addressed.

**Do not make this conditional.** It applies to every PR — not just "large" or "risky" ones. Small PRs have bugs too.

### 2. Extract Jira Ticket from Branch Name

Look for ticket patterns in the current branch name:

```
feat/MAIN-1234-some-feature  →  MAIN-1234
fix/PLAT-567-bug-fix         →  PLAT-567
```

**Recognized prefixes:** `MAIN`, `PLAT`, `ACQ`, `SUP`, `DE`, `TOPS`

If no ticket found, ask the user for the ticket number or confirm there isn't one.

### 3. Update related GitHub issues

Find issues linked to this PR (check PR body, branch name, commit messages for `#NNN` references or `Closes #NNN`). For each issue with acceptance criteria checkboxes:

1. **Get the full PR chain state** — never rely on memory or prior comments:
   ```bash
   gh pr list --repo <owner>/<repo> --state all --search "<feature keyword>" \
     --json number,title,state,mergedAt
   ```

2. **Verify each criterion in code** — grep, don't trust comments:
   ```bash
   grep -rn "FunctionName\|ComponentName" packages/relevant-package/src/
   ```
   A criterion is ✅ if its implementation is in a merged PR or confirmed in the current branch's code.

3. **Update the issue body** — use `gh api`, not `gh issue edit` (silently fails on long bodies):
   ```bash
   gh api repos/<owner>/<repo>/issues/<number> --jq '.body' > /tmp/body.txt
   # edit /tmp/body.txt: change - [ ] to - [x] for completed items
   gh api --method PATCH repos/<owner>/<repo>/issues/<number> -F body=@/tmp/body.txt
   ```

4. Add a brief status comment if the state changed significantly.

### 4. Create the PR

**Title format:** `[TICKET-123] Description of change`

- If ticket found: `[MAIN-1234] Add user authentication`
- If no ticket: `Description of change` (no brackets)

**Body:** Follow the repo's PR template if one exists (check `.github/PULL_REQUEST_TEMPLATE.md`). Be honest with checklists — never check off items you didn't actually do.

**Issue linking:** Include a `Closes #NNN` line for the related GitHub issue. Use `Related to #NNN` instead when the issue tracks a multi-PR feature with known follow-on work (e.g. E2E tests still pending). GitHub auto-closes on merge for `Closes`; `Related to` just links.

**Checklist verification:** Before submitting, re-read each checklist item and ask "did I literally do this?" If the answer isn't a clear yes, leave the box unchecked and add `(N/A)` with a brief reason. A false checkmark is worse than an unchecked box.

## Notes

- If branch isn't pushed yet, push it first with `git push -u origin HEAD`
- NEVER reference gitignored files (local design docs, session notes, etc.) in PR descriptions — reviewers can't see them
- Write testing instructions for reviewers using `git checkout <branch>`, not `cd .worktrees/...` — reviewers won't have your worktree
