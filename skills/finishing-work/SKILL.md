---
name: finishing-work
description: Use when about to commit, claim work is done, or completing a feature
---

# Finishing Work

## Overview

Pause before committing. Reflect on learnings, update docs, verify code, review code. No commit without this process.

## Prerequisite

Before running this skill, you should have already run `reviewing-code` on the full branch diff. If you haven't, run it now — `finishing-work` step 4 is a lightweight final check on staged changes, not a replacement for the full review-fix-verify loop.

## Process

### 1. Reflect on session learnings

Ask yourself:

- Did the user correct my approach?
- Did I learn something non-obvious?
- Did a pattern emerge that should be documented?
- Did I build any one-off scripts or tools that should be made permanent?
- Did patterns emerge that warrant a new skill?
- Did I create workarounds that should become proper tools?

If codification opportunities apply, present findings to the user via AskUserQuestion multi-select:
- Label: "Codify from this session?"
- Each option: a concise description of what to formalize and where

### 2. Update docs if needed

**Session notes file** (e.g., SESSION-NOTES.md) - Add entry if:

- User corrected your approach
- You discovered a gotcha or pattern
- An architectural decision was made

**Convention docs** - Update or create if:

- Pattern appears 3+ times in session notes
- New gotcha discovered
- Workflow improvement identified

**Skills** - Update if:

- Skill was missing information
- New rationalization discovered

### 3. Run verification

Invoke the `verifying` skill. It handles running the project's full verification suite.

**Do not skip this step.** Do not proceed to commit until all pass.

### 4. Run code review

After verification passes, invoke `code-reviewer` on the staged changes (run `git diff --cached` to get the diff).

This is **not optional.** Verification (lint/types/tests) checks that code is mechanically correct. Code review checks that it is logically correct — catching bugs, security issues, logic errors, and convention violations that automated checks miss.

**Do not skip this step.** Do not proceed to commit until review is complete and findings are addressed.

**This is not "the PR reviewer's job."** Waiting until PR creation to catch logic errors means you build on flawed foundations for hours. Review each commit incrementally so problems are caught when they're cheap to fix.

### 5. Commit with evidence

Only after verification AND code review pass, commit with actual output:

```
lint: ✓
types: ✓
tests: 52/52 passed
```

## Documentation Preferences

- **One canonical location** - Don't duplicate content, link instead
- **Skills reference docs** - Skills should point to convention docs, not restate them
- **Cross-reference** - Connect related docs with links
- **Extract patterns** - Move recurring session notes patterns to formal docs (3+ occurrences)

## Red Flags - STOP

- About to run `git commit` without running verification
- About to run `git commit` without running code review
- "It's just docs" - docs changes can break linting
- "Quick change" - quick changes break too
- "I already know it works" - prove it with commands
- About to say "done" without verification output
- "Code review is for PRs, not commits" - catch problems early, not late
- "Automated review can't catch real issues" - it catches bugs, security holes, and logic errors you missed

## Rationalizations

| Excuse                      | Reality                                 |
| --------------------------- | --------------------------------------- |
| "It's just documentation"   | Linters check docs too. Verify.         |
| "I ran this earlier"        | State changes. Run again before commit. |
| "Nothing could have broken" | Prove it. Run verification.             |
| "Quick commit"              | Quick commits cause slow debugging.     |
| "I'll verify after"         | After never comes. Verify now.          |
| "Code review belongs on the PR" | By then you've built 8 commits on a flawed foundation. Review each commit. |
| "Automated review adds friction, not value" | It catches bugs, security holes, and logic errors. Friction is the point. |
| "The commit is just a checkpoint" | A checkpoint with unreviewed logic errors is a checkpoint you'll regret. |

## The Rule

**No `git commit` without fresh verification output AND code review in this session.**
