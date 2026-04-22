---
name: logging-decisions
description: Use when executing a plan and encountering a decision the plan does not cover — a gap, correction, forced tradeoff, scope creep choice, or recovery from a task failure
---

# Logging Implementation Decisions

## Overview

When you make a decision during plan execution that the plan didn't specify, record it to `.docs/plans/{feature}/implementation-decisions.md`. Then keep going — do not pause for the user.

## When to Log

| Trigger                  | Description                                                            |
| ------------------------ | ---------------------------------------------------------------------- |
| **Plan gap**             | Plan doesn't address a case you encountered                            |
| **Plan correction**      | A plan step is wrong; you're deviating from it                         |
| **Forced tradeoff**      | Two valid approaches; plan doesn't say which                           |
| **Scope creep decision** | Adjacent thing needs fixing — you chose to include or exclude it       |
| **Recovery decision**    | A task step failed; you chose an alternative approach or recovery path |

**Do NOT log:**

- Typos or obvious errors _in the code being written_ where the fix has exactly one correct answer
- Choices fully covered by existing rules in the project's conventions
- Routine implementation details within the plan's stated scope

**Always log** errors in the plan steps themselves — even when the fix is obvious, deviating from a plan step is a decision. These are **Plan correction** entries.

When uncertain whether a decision qualifies, log it. Over-logging is always preferable to a silent gap.

## Entry Format

Append to `.docs/plans/{feature}/implementation-decisions.md` (e.g., `.docs/plans/auth/implementation-decisions.md`) — create the file if it doesn't exist:

```markdown
## {Short title}

**Plan:** YYYY-MM-DD-{plan-name}.md
**Task:** Task N — {task name}
**Context:** What situation triggered this decision
**Decision:** What was chosen and why
**Alternatives considered:** What else was evaluated
**Ramifications:** What else this could affect
**Actions needed:** Plan updates, issues to file, rules to update (or `None`)
```

If the decision has architectural scope — affecting multiple features, data model, or external contracts — note it in **Actions needed**: "Consider filing an ADR for this decision." The review step will surface it to the user.

## Rules

1. **Log and continue.** Do not pause mid-execution to report the decision to the user. Complete the task step, append the entry, then move on. Always note any affected later tasks in **Ramifications**. If the correction makes a later plan step unexecutable as written, log the entry and then pause to surface the conflict to the user before continuing.
2. **Use the exact format above.** Don't adapt it to match other notes in the file — consistency matters for the review step.
3. **One entry per decision.** If two decisions arise in the same task, write two entries.
4. **File is local only.** Never stage or commit `implementation-decisions.md`. The `.gitignore` entry is the mechanical safeguard against accidental inclusion — but also never delete this file manually before `reviewing-decisions` has run, as it uses the file's presence as its trigger.

## Common Mistakes

| Mistake                                           | Correct behavior                                |
| ------------------------------------------------- | ----------------------------------------------- |
| Pausing to ask the user which approach to take    | Make the call, log it, continue                 |
| Adapting the entry format to match existing notes | Use the exact template — every field            |
| Logging every small implementation choice         | Log only plan deviations, not routine decisions |
| Waiting until the end to log all decisions        | Log immediately after making each decision      |
