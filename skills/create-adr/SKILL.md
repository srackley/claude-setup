---
name: create-adr
description: Use when recording an architecture decision. Asks for context, generates from template, handles supersession.
---

# Create ADR

You are helping create a new Architecture Decision Record.

## Step 1: Determine the next ADR number

List files in `.docs/ADR/` matching the pattern `NNNN-*.md` (skip `README.md` and any other non-ADR files). Find the highest number among those files. The new ADR gets the next number in sequence, zero-padded to 4 digits (e.g., 0001, 0002, 0013).

If you find any duplicate numbers (two files sharing the same NNNN prefix), flag them to the user. Check the file dates to suggest which order makes sense, and ask whether they want to rename the files to fix the numbering. Do NOT proceed with a broken numbering sequence — wait for the user to resolve it first.

## Step 2: Gather Context

Ask me:

1. What decision are we recording?
2. What's the context — why did this come up?
3. What alternatives did we consider?
4. What did we decide and why?
5. What are the consequences — both positive and negative?
6. Is there a GitHub Issue or PR where this was discussed? (URL if so)
7. Does this supersede an existing ADR?

If any answer is too brief to be useful, ask a follow-up before moving on. ADRs are permanent — a one-word answer is not enough context to be meaningful long-term.

## Step 3: Generate the ADR

Read the template at `.docs/templates/adr-template.md` if one exists. If not, use the standard Nygard format:

```markdown
# NNNN. Title

Date: YYYY-MM-DD

## Status

Accepted

## Context

[Why did this decision come up?]

## Decision

[What was decided?]

## Consequences

[What are the results — positive and negative?]
```

Generate an ADR following that template. Set:

- Status: Accepted (unless I say otherwise)
- Date: today
- Discussion: the URL from step 2 if provided, otherwise omit the line
- Supersedes: the ADR number from step 2 if provided, otherwise omit the line

Save to `.docs/ADR/NNNN-<title-kebab-case>.md`

## Step 4: If this supersedes an existing ADR

Following Nygard convention, do two things:

1. In the new ADR's `Supersedes:` field, link to the old ADR: `[NNNN-old-title](NNNN-old-title.md)`
2. In the old ADR's `Status:` field, update it to: `Superseded by [NNNN-new-title](NNNN-new-title.md)`

Updating the old ADR's Status field is the one permitted edit to an existing ADR — it is not a content change, just a pointer to the replacement.
