---
name: refactoring
description: Use when refactoring existing code, extracting helpers, restructuring modules, or when you notice code smells that need cleanup
---

# Refactoring

## Overview

Refactor through incremental changes with verified checkpoints.

**Core principle:** Verify BEFORE touching code, not after.

## Process

### 1. Verify Baseline FIRST

**Before any code changes, run full verification using the project's verification commands:**

```bash
# Examples - use whatever the project provides
task lint && task lint-types && task test     # task runner
pnpm lint && pnpm typecheck && pnpm test     # pnpm
yarn lint && yarn typecheck && yarn test     # yarn
```

Then check coverage on the code you're refactoring:

```bash
# Example - use project's test runner
task test --coverage -- path/to/file
```

**No coverage?** Stop. Invoke `test-driven-development` skill NOW to add tests for existing behavior. Do not proceed until tests exist and pass.

**Tests fail?** Stop. Fix failing tests before refactoring. Do not proceed until green.

### 2. Incremental Changes with Checkpoints

For each refactoring step:

1. Make ONE coherent change (extract, rename, move)
2. Run tests - must pass
3. Commit with descriptive message
4. Repeat

**If tests fail:** Revert immediately. Try a smaller step.

### 3. Final Verification

After all changes, invoke `verifying` skill before claiming complete.

## Red Flags - STOP

- About to change code without running tests first
- "I'll verify after the refactor" - verify BEFORE
- "No coverage, so skip tests" - add coverage first
- "Just cleaning up, not changing behavior" - prove it with tests
- Making multiple changes before running tests

## Rationalizations

| Excuse                     | Reality                                                    |
| -------------------------- | ---------------------------------------------------------- |
| "Not changing behavior"    | Refactors hide subtle bugs. Tests prove it.                |
| "I'll mention tests after" | After = too late. Baseline first.                          |
| "No test coverage anyway"  | Then add tests first. Can't safely refactor untested code. |
| "Just extracting a helper" | Extraction can change behavior. Verify.                    |

## The Rule

**No refactoring without passing tests BEFORE you start.**
