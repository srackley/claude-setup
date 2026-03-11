---
name: verified-analysis
description: Use when evaluating whether a code review finding, bug report, or structural claim about code is accurate — before fixing, commenting, or dismissing
---

# Verified Analysis

Rules for evaluating whether a claim about code is true. Invoke this skill before acting on any finding from a review agent, bug report, or structural assertion.

**Core principle:** Never trust a claim about code without evidence. Verify first, act second.

## Confidence Gate

A claim is **VALID** only if you can state all three with evidence:

1. **What's wrong** — the specific issue, confirmed by reading actual code
2. **Why it's wrong** — with evidence (docs link, traced execution path, test output)
3. **What the correct response is** — the specific fix, comment, or dismissal, confirmed as accurate

If ANY of the three is unclear → **UNCERTAIN**. Report it for human judgment. Do not fix, do not comment, do not dismiss.

## Verification Matrix

**Do NOT just Read the file and reason about it.** Use the right tool for each claim type:

| Claim type | Verification tool | Why |
|---|---|---|
| Code at location wrong/missing | Direct Read of full function | Confirm the code matches what was claimed |
| Framework/library behavior | `docs-researcher` agent | Claims may reflect stale training data. Verify against actual docs for installed version |
| Logic error / unreachable code | `feature-dev:code-explorer` agent | Trace the full execution path. Don't eyeball reachability |
| Test gap | Grep + `feature-dev:code-explorer` | Check if test exists, then trace what existing tests actually cover |
| Style/convention violation | Direct Read + project CLAUDE.md | Compare against actual project rules |
| Lint warning | Verification output | Already confirmed by tooling — no further verification needed |

**Batch verification agents.** If multiple claims need code-explorer or docs-researcher, launch them in parallel.

## Structural Verification Rules

These prevent the most common false positives.

**Grep before asserting absence.** If a claim says "X is never destructured," "Y doesn't exist," "Z is unused," or "W is never called" — **Grep the full file and codebase** before accepting it. This takes 2 seconds and catches the most common class of false positive: claims based on partial context.

**Read full functions, not diff hunks.** If a claim makes a structural assertion about a function (what it destructures, returns, calls, catches, or imports), **Read the entire function** before classifying. A 3-line diff context can make present code look absent. Diffs show fragments — structural claims require the full picture.

**Verify the claimed values, not just the pattern.** If a claim says "status can only be X, Y, Z" — check the actual source of truth (database schema, enum definition, config file). Don't trust the claimed values without confirming them.

## Evidence Standards

**"I read the code and it looks wrong" is not evidence.** Evidence means:

- docs-researcher confirmed the framework behavior (with version)
- code-explorer traced the path and confirmed reachability
- Grep confirmed no other callers handle this case
- Grep confirmed the claimed absence (zero matches in full file/codebase)
- The test you wrote proves the bug exists
- The database schema / generated types confirm the claimed constraint

**"I read the diff and it seems like..." is also not evidence.** Diffs are fragments. If your evidence would change after reading the full file, it wasn't evidence.

## Classification Output

For each claim, produce:

```
[file:line] VALID / UNCERTAIN / FALSE POSITIVE
  Claim: [what the agent/report said]
  Evidence: [tool used → what it found]
  Reasoning: [why this classification]
```

## Red Flags — STOP

- "This is obviously correct" → Obvious things are wrong often enough. Verify anyway.
- "I don't need docs-researcher for this" → If the claim references framework behavior, you do.
- "I'm confident this is right" → Confidence without evidence is overconfidence. State the evidence.
- "X is never used / Y doesn't exist" → Grep the full file first. Diffs lie by omission.
- "I can see from the diff that..." → Read the full function, not the 3-line hunk.
- "The agent said so" → Agents are wrong regularly. That's why this skill exists.
