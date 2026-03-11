---
name: triaging-linear-issues
description: Use when checking on Linear issues, asking what to work on next in Linear, reviewing a team's Linear backlog, or wanting to know what Linear issues need attention
---

# Triaging Linear Issues

Answer "what should I work on next?" by analyzing open Linear issues. Groups by priority, recommends a top pick, offers to implement. Uses Linear MCP tools exclusively.

## Config

No hardcoded default team. Always ask which team (or accept inline specification).

| User says                                    | Scope          |
|----------------------------------------------|----------------|
| `triage linear issues`                       | ask which team |
| `triage linear issues for Ticket Portal`     | specific team  |
| `what's in the Linear backlog?`              | ask which team |
| `what Linear issues need work?`              | ask which team |

## Process

**1. Identify team** — Call `mcp__linear-server__list_teams`. If user specified a team, match by name. Otherwise present the list and ask.

**2. Fetch issues** — Call `mcp__linear-server__list_issues` with `team` set to the team name, excluding archived. Do NOT fetch issue bodies, comments, or PRs.

**3. Group by Linear priority** — Use Linear's built-in priority field. One group per issue:

| Priority Value | Group         |
|----------------|---------------|
| 1              | Urgent        |
| 2              | High          |
| 3              | Medium        |
| 4              | Low           |
| 0              | No priority   |

**4. Sort within groups** — Unassigned first → oldest first.

**5. Recommend** — Walk tiers top-down from Urgent. Pick first unassigned issue in highest populated tier. The tier order IS the priority — never skip to a lower tier because it "feels more relevant."

**6. Render** output in this order:

1. **Recommendation**: total count, breakdown, top pick with rationale
2. **Grouped tables** (plain markdown, NOT code-fenced):

| Issue | Title | Labels | Age | Assigned |

- Issue column: plain `TICK-42` — no markdown links (they break table width)
- Heading: `## Priority Group (N)` — count MUST equal rows. Count after building.
- `---` between groups. Omit empty groups entirely.
- Age: `3d`, `2w`, `4mo`. Assigned: name or empty.

3. **Summary**: **N open issues: X urgent, Y high, Z medium — W unassigned**
4. **Implementation offer**: "Want me to implement TICK-42?" → invokes `implementing-linear-issue`

## What This Skill Does NOT Do

- Read issue bodies (list query is sufficient for triage)
- Fetch PRs, comments, or attachments
- Touch issue status
- Look up cycles, sprints, or due dates
- Filter by current user or assignee

## Red Flags

| Thought | Reality |
|---------|---------|
| "Let me also check PRs" | Issues only. PRs have their own triage skill. |
| "I should read issue bodies" | List query is sufficient for triage. |
| "A flat list is fine" | Groups tell you what KIND of work exists. |
| "I'll use my own priority scheme" | Use Linear's priority field. Consistency matters. |
| "User can pick from the table" | Lead with a recommendation. That's the point. |
| "This lower-priority issue feels more impactful" | Tier order is the priority. Always. |
| "I'll link issue numbers" | Plain `TICK-42` only. Links break tables. |
| "I'll show empty groups for completeness" | Omit them. No "## Urgent (0)". |
| "Let me check cycles and sprints too" | Keep it simple. Priority field is enough. |
| "I should personalize by checking the current user" | Show all issues. Let the user decide. |
