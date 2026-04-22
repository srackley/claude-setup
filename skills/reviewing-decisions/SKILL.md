---
name: reviewing-decisions
description: Use when all plan tasks are marked complete and implementation-decisions.md exists in the feature's plan folder — before invoking superpowers:finishing-a-development-branch
---

# Reviewing Implementation Decisions

## Overview

After all plan tasks complete, review the decisions log and present structured findings for user approval. This is a dedicated step — not part of `superpowers:finishing-a-development-branch`.

## When to Use

Invoke when:

1. All plan tasks are marked complete, AND
2. `.docs/plans/{feature}/implementation-decisions.md` exists

If the file doesn't exist, skip this skill entirely and proceed to `superpowers:finishing-a-development-branch`.

## This Is Not superpowers:finishing-a-development-branch

Do not fold decisions review into the `superpowers:finishing-a-development-branch` workflow. Run reviewing-decisions first, get user sign-off on any follow-up actions, then invoke `superpowers:finishing-a-development-branch`.

## Analysis Process

Before categorizing, verify each entry has all required fields (Plan, Task, Context, Decision, Alternatives considered, Ramifications, Actions needed). If any are missing, surface it as a formatting error before proceeding and ask whether to analyze it anyway or skip it.

For each well-formed entry:

1. Did the decision stay within the plan's intent, or did it change scope/behavior?
2. Are the ramifications addressed, or is follow-up work needed?
3. Does it reveal a gap the plan should have covered (reusable pattern, missing rule)?

## Output Format

Present findings using exactly these categories:

```
## Implementation Decisions Review

### ✅ {Title} — Approved
{One-line rationale — no follow-up needed}

### ⚠️ {Title} — Follow-up required
{What the ramification is and why it needs action}
**Proposed action:** {Specific action — file issue, update rule, etc.}

### 🔁 {Title} — Plan improvement
{What gap the decision revealed}
**Proposed action:** {Update plan template / add to project rules / etc.}
```

## Rules

1. **Never auto-apply actions.** Present findings and wait for user approval.
2. For every ⚠️ and 🔁 finding, list a specific proposed action. Don't leave it as "needs follow-up."
3. ✅ findings need no user input — list them for transparency only.
4. Execute approved actions, then invoke `superpowers:finishing-a-development-branch`. If all findings are ✅ (no actions to approve), state "No follow-up required — proceeding to `superpowers:finishing-a-development-branch`" and invoke it without waiting for input.

## Common Mistakes

| Mistake                                                                | Correct behavior                                            |
| ---------------------------------------------------------------------- | ----------------------------------------------------------- |
| Treating this as part of `superpowers:finishing-a-development-branch`  | Run reviewing-decisions first, get approval, then invoke it |
| Presenting decisions as a freeform list without ✅/⚠️/🔁 categories    | Use the ✅/⚠️/🔁 format for every entry                     |
| Auto-applying actions (writing to rules, filing issues) without asking | Present proposed action, wait for approval                  |
| Skipping the review when all tasks pass lint/tests                     | Tests passing doesn't replace decisions review              |
