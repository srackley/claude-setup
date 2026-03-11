---
name: triaging-pull-requests
description: Use when checking on open PRs, asking what needs attention, reviewing PR backlog, or starting a work session and wanting to know repo status
---

# Triaging Pull Requests

## Overview

Triage open PRs by action needed — not a flat list but grouped by what you should do next. Read-only. Uses `gh` CLI exclusively.

## When to Use

- "Check on PRs" / "what needs attention"
- "Triage PRs" / "PR status" / "PR backlog"
- Starting a work session and wanting repo status
- After merging a PR to see what's unblocked

## Config

Default repos when `--all` is used:

- wanderu/canopy
- wanderu/ui-react

## Scope

| User says                         | Scope                    |
|-----------------------------------|--------------------------|
| `triage PRs`                      | current repo only        |
| `triage PRs for canopy`           | specific repo            |
| `triage PRs --all`                | all repos in config list |
| `triage PRs for canopy ui-react`  | specific multiple repos  |

Determine the repo from context. If ambiguous, use current repo.

## Process

### Step 1: Gather Data

For each repo in scope, run in a **subagent** to keep main context clean:

```bash
gh pr list --json number,title,author,headRefName,baseRefName,createdAt,updatedAt,reviewDecision,reviewRequests,reviews,statusCheckRollup,mergeable,comments,labels,isDraft -R <owner/repo>
```

**You MUST include `mergeable`, `baseRefName`, and `reviews` in the query.** Without `mergeable` you cannot detect conflicts. Without `baseRefName` you cannot detect stacked PRs. Without `reviews` you cannot detect approvals when `reviewDecision` is empty (repos with 0 required approvals).

### Step 2: Classify Each PR

Assign each PR to exactly ONE group. **First match wins** — check in this order:

| Priority | Group             | Condition                                    |
|----------|-------------------|----------------------------------------------|
| 1        | Blocked           | base branch = another open PR's head branch  |
| 2        | Needs rebase      | `mergeable=CONFLICTING`                      |
| 3        | CI failing        | any check in `statusCheckRollup` not passing |
| 4        | Changes requested | `reviewDecision=CHANGES_REQUESTED`           |
| 5        | Needs review      | not approved AND not draft (see below)       |
| 6        | Ready to merge    | approved + CI passing + no conflicts         |
| 7        | Stale             | `updatedAt` older than 30 days               |

**Detecting "approved":** A PR is approved if `reviewDecision=APPROVED` OR if `reviewDecision` is empty but the `reviews` array contains at least one review with `state=APPROVED`. Many repos use rulesets with 0 required approvals, which leaves `reviewDecision` empty even when reviews exist. Always check the `reviews` array as fallback.

Draft PRs: skip main groups, render as a separate "Drafts" table at the end (same 4-column schema, Detail shows age or conflict status).

### Step 3: Build Detail Column

Each group gets a **terse** detail value. Not sentences — short phrases only.

| Group             | Detail                                     |
|-------------------|--------------------------------------------|
| Ready to merge    | `approved by alice, CI passing`             |
| Needs rebase      | `N commits behind main`                    |
| CI failing        | failing check names (e.g. `lint, build`)   |
| Needs review      | `no reviews yet` or `awaiting: alice, bob` |
| Changes requested | `feedback from alice`                      |
| Stale             | `42 days since last update`                |
| Blocked           | `blocked by #38`                           |

**Always append comment count** when > 0: e.g. `approved, CI passing, 2 comments`

### Step 4: Render Output

**CRITICAL:** Output plain markdown tables — do NOT wrap in code fences. This makes them render with borders in Claude Code.

**Table schema is FIXED — always exactly 4 columns:**

```
| PR | Title | Author | Detail |
```

Never add extra columns. Never change column names. The Detail column carries all group-specific info.

**PR column uses plain `#60` format.** Do NOT use markdown links — Claude Code's table renderer expands them to full URLs, breaking table width.

**Multi-repo:** Add `### repo-name` header before each repo's groups. Omit header for single-repo.

**Between groups:** Add `---` horizontal rule.

**Omit empty groups.** Only show groups that have PRs.

**Pad columns** to the widest value for alignment.

### Step 5: Summary Line

End with a **bold one-liner** counting PRs per group:

**N open PRs: X ready to merge, Y CI failing, Z needs review, W drafts**

### Step 6: Dependabot PRs

If any PRs in the "Ready to merge" group are from dependabot, add a note after the summary:

> **Dependabot PRs ready to merge.** Use `dependabot-review` skill for risk assessment and batch merging.

Do NOT inline the full dependabot review — just flag it.

### Example Output

### canopy

## Ready to Merge (2)

| PR   | Title              | Author     | Detail                          |
|------|--------------------|------------|---------------------------------|
| #38  | Fix nav overflow   | shelby     | approved, CI passing            |
| #12  | Bump vite to 6.1   | dependabot | approved, CI passing, 1 comment |

---

## CI Failing (1)

| PR   | Title                | Author | Detail      |
|------|----------------------|--------|-------------|
| #60  | Global claude config | shelby | lint, build |

---

## Needs Review (1)

| PR   | Title            | Author | Detail         |
|------|------------------|--------|----------------|
| #45  | Add search modal | alice  | no reviews yet |

**6 open PRs: 2 ready to merge, 1 CI failing, 1 needs review, 2 drafts**

## Red Flags — STOP

- **Flat list of PRs** — You MUST group by action. Never output a single ungrouped table.
- **Code-fenced tables** — Never wrap tables in triple backticks. They must render with borders.
- **Extra columns** — Always exactly 4: PR, Title, Author, Detail. No "CI Status", "Age", "Review Status" columns.
- **Narrative in Detail column** — Detail values are terse phrases, not sentences. "approved, CI passing" not "This PR has been approved by alice and all CI checks are passing."
- **Missing groups** — Check ALL 7 classification rules. Don't skip blocked/stale detection.
- **PR in multiple groups** — First match wins. Each PR appears exactly once.
- **Skipping comment counts** — Always check and append when > 0.
- **Missing summary line** — Every report ends with a bold one-liner summary.
- **Missing horizontal rules** — Every group is separated by `---`.
- **Ad-hoc grouping** — Use the exact 7 groups in the classification table. Don't invent new groups or rename them.
- **Count mismatch** — The number in the group header (e.g. "Ready to Merge (2)") MUST equal the number of table rows. Count the rows after building the table.

## Rationalizations

| Thought                                    | Reality                                                        |
|--------------------------------------------|----------------------------------------------------------------|
| "A flat list is fine for a few PRs"        | Groups tell you WHAT TO DO. A list just tells you what exists. |
| "I'll skip the secondary API call"         | You need reviewer names for changes-requested details.         |
| "Code fences look cleaner"                 | They don't render with borders. Plain markdown does.           |
| "Stale detection isn't important"          | 30+ day PRs are noise. Surface them so they get closed.        |
| "I don't need to check base branches"      | Stacked PRs that merge out of order break things. Check.       |
| "Let me add more columns for context"      | 4 columns. Detail carries everything. More columns = noise.    |
| "I should explain each PR in detail"       | This is triage, not code review. Terse. Scannable.             |
| "I'll group differently per repo"          | Same 7 groups, same order, every repo. Consistency matters.    |
