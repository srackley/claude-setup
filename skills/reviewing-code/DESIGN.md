# Review Loop Skill Design

GitHub Issue: #11

## Overview

A global skill that automates the full review-fix-verify cycle. Two modes:
- **Pre-commit mode** (`/review-loop`): Code quality review, fix, re-verify
- **PR mode** (`/review-loop pr`): Full PR readiness review including metadata and CI

## Where It Fits

```
1. Write code (TDD, etc.)
2. Run verification (verifying skill)
3. >>> /review-loop <<<
   - Launch review agents on branch diff
   - Verify findings against actual code/docs
   - Fix what it's confident about (TDD for behavioral changes)
   - Re-verify (lint, types, tests)
   - Re-review until clean (max 3 rounds)
4. finishing-work (reflect, commit)
5. >>> /review-loop pr <<<  (optional, before PR creation)
6. creating-pr
```

## Skill Identity

- **Name:** `review-loop`
- **Location:** `~/.claude/skills/review-loop/SKILL.md`
- **Scope:** Global (works on any project)
- **Inputs:**
  - Scope: `git diff main...HEAD` (full branch diff). Override with argument.
  - Agents: All 5 pr-review-toolkit agents, every round.
  - Max rounds: 3. Report remaining findings if not clean after 3.
- **Does NOT:** Commit (that's `finishing-work`), replace initial verification, or make uncertain fixes.

## Pre-Commit Mode (`/review-loop`)

### The Core Loop

```
ROUND N:
  1. Launch all 5 review agents in parallel (Task tool, background)
     - code-reviewer
     - silent-failure-hunter
     - pr-test-analyzer
     - comment-analyzer
     - type-design-analyzer
     Each receives the branch diff and file list.

  2. Collect findings from all agents.

  3. Deduplicate — multiple agents often flag the same issue.
     When overlapping, merge into one finding with the most specific diagnosis.

  4. VERIFY each unique finding:
     See "Verification Matrix" below.
     Classify: VALID (high confidence) / UNCERTAIN (report only) / FALSE POSITIVE (dismiss)

  5. FIX each VALID finding:
     - Behavioral change → TDD: write failing test, implement fix, confirm green
     - Non-behavioral (comment, type, style, lint warning) → direct fix

  6. Run full verification (lint, types, tests).
     - If verification fails → fix verification errors before next round.

  7. Decision:
     - Fixes were made → start ROUND N+1
     - No valid findings remain → DONE
     - Round 3 reached → DONE (report remaining in Deferred)
```

### Confidence Gate

A finding only becomes VALID if the skill can articulate all three:
1. **What's wrong** — the specific issue
2. **Why it's wrong** — with code or documentation evidence
3. **What the correct fix is** — the specific change to make

If any of those three are unclear, the finding is UNCERTAIN and gets reported for the user to decide. No guessing.

### Verification Matrix

| Finding type | Verification method | Fix method |
|---|---|---|
| Code reference wrong | Direct Read | Direct fix |
| Framework/library claim | docs-researcher agent | Direct fix (informed by research) |
| Logic error / reachability | feature-dev:code-explorer agent | TDD: failing test -> fix |
| Test gap | Grep + code-explorer | TDD: docs-researcher (test library API) -> write test |
| Style/convention | Direct Read + project CLAUDE.md | Direct fix |
| Lint warning | Verification output | Direct fix (autofix where available) |

**Key principle:** Each claim type gets verified by the right tool. No "reading the code and thinking about it" as the sole verification.

### Lint Warnings

Lint warnings in any file in the branch diff are in scope. They're concrete, verifiable, and non-controversial. Fixed directly (non-behavioral, no TDD needed). The verification report targets zero warnings:

```
lint: 0 errors, 0 warnings | types: 0 errors | tests: 54/54 passed
```

## PR Mode (`/review-loop pr`)

Same loop architecture, different focus.

### Scope

Full branch diff (`main...HEAD`) + PR metadata (if PR already exists).

### Agent Set

All 5 code review agents (same as pre-commit mode), plus PR-specific checks run directly by the skill:
- PR description matches `.github/PULL_REQUEST_TEMPLATE.md`
- Checklist items are honestly checked against actual work done
- CI status is green (`gh` query)
- Branch is up to date with base

### Fix Strategy

| Finding | Fix approach |
|---|---|
| Code findings | Same as pre-commit mode |
| Missing PR description | Draft it, show user for approval |
| Unchecked items that were done | Check them |
| CI failures | Investigate and fix if possible, report if not |
| Branch behind base | Rebase |

### Approval Gates

PR mode has approval gates that pre-commit mode does not:
- PR description text must be shown to user before pushing
- Anything that touches GitHub (comments, labels) requires user sign-off

### Handoff

- No PR exists → hands off to `creating-pr` skill
- PR exists → reports "ready to merge" with summary

## Context Management

### Between Rounds

1. Write progress checkpoint to `~/.claude/review-loop-progress.md`:
   - Round number
   - Findings found, fixed, dismissed (with reasons), deferred
   - Serves as recovery state and raw material for final report

2. Run `/compact` if context is heavy (round 2+ should compact)

### Agent Spawning

- All review agents launch in parallel (background) — 5 agents per round
- Verification agents (code-explorer, docs-researcher) launch in parallel per finding batch
- Worst case per round: 5 review agents + N verification agents + N fix cycles
- All are subagents — they don't pollute main context

### Final Report

```
## Review Loop Complete (N rounds)

### Fixed (X findings)
- [file:line] Description of what was wrong -> what was changed
  Evidence: [test added / docs confirmed / code-explorer traced]

### Dismissed (Y findings)
- [file:line] Agent claimed X -> Actually Z because [evidence]

### Deferred (Z findings)
- [file:line] Description — uncertain, needs your judgment
  Context: [what verification found]

### Verification
lint: 0 errors, 0 warnings | types: 0 errors | tests: 54/54 passed
```

## Open Design Decisions (Resolved)

| Question | Decision | Reasoning |
|---|---|---|
| Where does it live? | `~/.claude/skills/review-loop/` | Personal global skill, can promote to plugin later |
| Fix threshold? | Fix most things, but verify aggressively | User wants thoroughness over speed |
| Review scope? | Full branch diff (`main...HEAD`) | Complete picture, no confusion from reverted work |
| Which agents? | All 5, every round | Even round 2+ re-runs all — fixes can cascade across domains |
| TDD for fixes? | Inline TDD for behavioral changes, direct fix for non-behavioral | Right balance of rigor vs overhead |
| PR-level review? | Two modes in one skill | Same architecture, different focus; one skill to learn |
| Should it commit? | No — hands off to `finishing-work` | Separation of concerns |
