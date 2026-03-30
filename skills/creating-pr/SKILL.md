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

## Process

### 1. Run comprehensive PR review

Before creating the PR, invoke `reviewing-code` on the full branch diff (`git diff main...HEAD` or equivalent).

This is **not optional.** The per-commit code reviews in `finishing-work` catch issues incrementally. This step reviews the complete change holistically — how all commits interact, cross-cutting concerns, test coverage gaps, and architectural issues that only appear at the full-diff level.

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

**Deploy URL:** Always add a `## Preview` section to the PR body with the deployment URL. Query the GitHub Deployments API after CI passes — never guess URLs.

- **Vercel:** `gh api "repos/$REPO/deployments?ref=$SHA&per_page=1" --jq '.[0].id'` → then query statuses for `environment_url`
- **EKS:** Same API, filter by `environment=dev`
- If no deployment exists yet, add a placeholder: `> ⏳ Deploy URL will appear once the build completes.`

### 5. Monitor CI Status

Poll `gh pr checks` every 30 seconds until all checks complete:

```bash
gh pr checks <PR_NUMBER> --json name,state,conclusion
```

**On failure:** Report which check failed with link to the run.

### 5. Update PR with Deploy URL

After CI passes, query the GitHub Deployments API for the preview URL:

```bash
REPO="<OWNER/REPO>"
SHA="<HEAD_SHA>"
DEP_ID=$(gh api "repos/$REPO/deployments?sha=$SHA&per_page=1" --jq '.[0].id')
URL=$(gh api "repos/$REPO/deployments/$DEP_ID/statuses" --jq '.[0] | select(.state == "success") | .environment_url')
```

This works for both Vercel and EKS — both create GitHub Deployments with `environment_url`. Query by SHA (not branch name) to avoid sanitization issues.

If the PR body has a placeholder, replace it. If no `## Preview` section exists, add one after `## Summary`.

### 6. Report Results

**On success:**

```
PR created and CI passed!

PR: https://github.com/org/repo/pull/123
Deployment: https://app-branch.dev.example.com (updated in PR body ✅)

All checks:
  ✅ lint
  ✅ test
  ✅ deploy
```

**On failure:**

```
PR created but CI failed.

PR: https://github.com/org/repo/pull/123

Checks:
  ✅ lint
  ❌ test - https://github.com/org/repo/actions/runs/12345
  ⏳ deploy (skipped)
```

## Timeout

Stop polling after 15 minutes. Report current status and let user know they can check manually.

## Notes

- If branch isn't pushed yet, push it first with `git push -u origin HEAD`
- NEVER guess deploy URLs — always query the GitHub Deployments API
- If the repo has no deployment integration at all, skip step 5 entirely
- NEVER reference gitignored files (local design docs, session notes, etc.) in PR descriptions — reviewers can't see them
- Write testing instructions for reviewers using `git checkout <branch>`, not `cd .worktrees/...` — reviewers won't have your worktree
