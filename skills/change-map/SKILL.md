---
name: change-map
description: Use before code review, PR review, or review loops to create a compact, neutral map of what changed. Supports own-branch review and reviewing someone else's PR.
---

# Change Map

Create a compact, neutral description of the change so later review agents can avoid rediscovering basic context.

## Rules

- Be descriptive, not judgmental.
- Do not identify bugs, risks, severities, recommendations, or suspected findings.
- Do not say code is wrong, suspicious, brittle, unsafe, incomplete, or likely broken.
- Do not include review conclusions.
- Prefer changed files, diff summaries, PR metadata, linked issue/spec summaries, and test changes.
- Keep the map under 400 words unless explicitly asked for more.
- If information is unavailable, say so briefly.

## Inputs

Use whichever apply:
- Current branch diff
- PR diff
- PR title/body
- Linked issues/specs
- Review comments or author responses
- Worktree path, when reviewing a PR branch

## Output

```markdown
# Change Map

## Intent
[1-2 neutral sentences describing stated purpose]

## Changed Areas
- `path`: neutral summary of mechanical change
- `path`: neutral summary of mechanical change

## Key Flows Touched
- [entry/input] → [module/function] → [output/side effect]

## Tests
- Added/updated:
- Not shown in diff:

## External Context
- Linked issues/specs/comments summarized neutrally, or "none found"

## Suggested Review Slices
- correctness: [files]
- tests: [files]
- error handling: [files]
- comments/docs: [files]
- types: [files]
```

## What Not To Include

Do not include:

- proposed findings
- severity labels
- “likely bug” statements
- recommendations
- main-agent opinions
- claims that require verification
