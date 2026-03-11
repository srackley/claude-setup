---
name: triaging-issues
description: Use when checking on open issues, asking what to work on next, reviewing issue backlog, or starting a work session and wanting to know what needs attention
---

# Triaging Issues

Answer "what should I work on next?" by analyzing open GitHub Issues. Groups by parent issue hierarchy, filters issues with active PRs, recommends a top pick, offers worktree setup. Uses `gh` CLI exclusively.

## Config

Default repos for `--all`: wanderu/canopy, wanderu/ui-react

| User says                         | Scope             |
|-----------------------------------|-------------------|
| `what should I work on?`         | current repo      |
| `triage issues for canopy`       | specific repo     |
| `triage issues --all`            | all config repos  |
| `check issues across all repos`  | all config repos  |

## Process

**1. Gather** — For each repo, run in a subagent:

```bash
gh issue list --state open --limit 50 --json number,title,labels,assignees,createdAt,updatedAt,comments,url,author,closedByPullRequestsReferences -R <owner/repo>
```

The `closedByPullRequestsReferences` field returns open PRs that will close each issue (via "Closes #N" etc.). This replaces the need for a separate `gh pr list` call.

**2. Filter**:
- Remove issues labeled `wontfix`, `duplicate`, or `invalid`.
- Remove issues where `closedByPullRequestsReferences` contains an open PR. Note these briefly when rendering (e.g., "Note: #107 filtered — active PR #89").

**3. Detect parent/child hierarchy** — Check each remaining issue for sub-issues:

```bash
gh api /repos/{owner}/{repo}/issues/{number}/sub_issues --jq '.[].number' 2>/dev/null
```

An issue is a **parent** if the API returns sub-issues. An issue is a **child** ONLY if it appears in the API response of another issue's sub-issues endpoint — do NOT guess parent/child from proximity, similar topics, or labels. Run calls in parallel. To avoid unnecessary API calls, check titles first — issues with titles like "Parent issue tracking..." are likely parents. Target those first.

**4. Organize** — Two-level structure: parent groups first, then standalone issues by label tier.

**Parent groups:** Each parent becomes a section. Its open children are rows in that section. The parent's own label determines its priority relative to other parents (use the tier table below). Children that are themselves filtered (active PR) get a note, not a row.

**Standalone issues** (no parent, not a child): Group by label tier. **"First match wins"** means check labels top-to-bottom against the tier table — if an issue has both `enhancement` and `chore`, it's a Feature (tier 2), not Maintenance (tier 3):

| Priority | Group         | Labels                              |
|----------|---------------|-------------------------------------|
| 1        | Bugs          | `bug`                               |
| 2        | Features      | `enhancement`                       |
| 3        | Maintenance   | `chore`, `testing`, `documentation` |
| 4        | Needs triage  | `question`, `help wanted`           |
| 5        | Uncategorized | *(none of the above)*               |

**Sort** within any group — Unassigned first → oldest first → most comments first.

**5. Recommend** — Parent-track issues take priority over standalones. Walk parent groups first (ordered by tier of the parent's label), then standalone tiers top-down from Bugs. Within each group, pick the first unassigned, actionable issue. A child of a Feature parent is recommended BEFORE a standalone Bug (parent tracks represent coordinated work). **Skip issues that are on hold** — scan comments for "on hold", "blocked", "waiting for". Note skipped issues with reason.

**6. Adaptive columns** — Only include columns that carry information:
- **Assigned**: Omit column entirely when ALL issues are unassigned.
- **Labels**: Omit when every row in a group shares the same label (heading already says it).

**7. Render** output in this order:

1. **Recommendation**: total count, breakdown, top pick with rationale. Note any skipped on-hold issues.
2. **Parent-grouped tables** then **Standalone tables** (plain markdown, NOT code-fenced):

| Issue | Title | Labels | Age |

- Issue column: plain `#84` — no markdown links (they break table width)
- Parent heading: `## Parent Title — #N (X open sub-issues)`
- Standalone heading: `## Group Name (N)` — count MUST equal rows. Count after building.
- `---` between sections. Omit empty groups entirely.
- Age: `3d`, `2w`, `4mo`.
- Multi-repo: `### repo-name` header per repo. Note disabled/errored repos briefly.
- After each section, note filtered issues briefly (e.g., "Note: #107 filtered — active PR #89")

3. **Summary**: **N open issues: X in parent tracks, Y standalone — W unassigned**
4. **Worktree offer**: `fix/<N>-<slug>` for bugs, `feat/<N>-<slug>` for features, `chore/<N>-<slug>` for maintenance/uncategorized

**8. Worktree** — If accepted, **REQUIRED SUB-SKILL:** Use superpowers:using-git-worktrees.

## Red Flags

| Thought | Reality |
|---------|---------|
| "A flat list by label is fine" | Parent/child grouping shows the SHAPE of work — tracks vs one-offs. Always check. |
| "I should read every issue body" | Use titles, labels, comments, and sub-issues API. Only read bodies if hierarchy is ambiguous. |
| "I'll use my own priority scheme" | Use the label tiers for standalones. Parent groups use the parent's tier. |
| "User can pick from the table" | Lead with a recommendation. That's the point. |
| "This maintenance issue feels more impactful" | Tier order is the priority for standalones. Always. |
| "I'll link issue numbers" | Plain `#84` only. Links break tables. |
| "I'll show empty groups for completeness" | Omit them. No "## Bugs (0)". |
| "This issue looks good to work on" | Check `closedByPullRequestsReferences` first — an open PR may already close it. |
| "I'll show the Assigned column" | Only if some issues are assigned. Don't waste space on an empty column. |
| "Labels column is always useful" | If every row has the same label, the heading already says it. Omit. |
| "I'll call the sub-issues API for every issue" | Use title/comment signals to target likely parents. Don't make 50 API calls blindly. |
| "This on-hold issue is the highest priority" | Check comments. On-hold issues are not actionable — skip with a note. |
| "This issue is related so it must be a child" | ONLY the sub-issues API determines children. Similar topic or adjacent numbering means nothing. |
| "This issue has `chore` so it's Maintenance" | Check ALL labels against the tier table top-down. `enhancement` + `chore` = Feature (tier 2 wins). |
| "Standalone issues could be more impactful" | Parent-track children are recommended first. Coordinated tracks > isolated tasks. |
