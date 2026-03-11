---
name: verifying
description: Use when completing any code change, before claiming work is done, or before commits and PRs
---

# Verifying

## Overview

Run the full verification suite. No code change is complete without passing all checks.

## Commands

Determine the project's verification commands. Common patterns:

### Node.js (with task runner)
```bash
task lint        # ESLint + Prettier
task lint-types  # TypeScript type checking
task test        # Unit tests
```

### Node.js (npm/pnpm/yarn)
```bash
pnpm lint        # or npm run lint
pnpm typecheck   # or npm run typecheck
pnpm test        # or npm run test
```

### Python
```bash
ruff check .     # Linting
mypy .           # Type checking
pytest           # Tests
```

### Go
```bash
go fmt ./...     # Formatting
go vet ./...     # Static analysis
go test ./...    # Tests
```

### Rust
```bash
cargo fmt --check  # Formatting
cargo clippy       # Linting
cargo test         # Tests
```

**Use the project's preferred tool** (task, make, npm scripts, etc.) rather than raw commands when available.

To fix lint errors automatically: look for an autofix command (e.g., `task lint-fix`, `pnpm lint --fix`, `ruff check --fix`).

## Process (in order)

1. Run linting/formatting check
2. If fails → run autofix if available → re-run check (max 3 attempts)
3. Run type checking
4. If fails → fix type errors → re-run (max 3 attempts)
5. Run tests
6. If fails → fix → re-run (max 3 attempts)
7. Report with actual output evidence

## Reporting

Show actual command output:

```
lint: 0 errors, 0 warnings
types: 0 errors
tests: 57/57 passed
```

## Red Flags - STOP

- "Quick task" or "simple change" - still verify
- "I already know it works" - run the commands
- "Just this once" - no exceptions
- About to say "done" without running commands

## Rationalizations

| Excuse                 | Reality                         |
| ---------------------- | ------------------------------- |
| "It's a quick task"    | Quick tasks break too. Verify.  |
| "File write succeeded" | Write succeeding ≠ code working |
| "Don't overthink it"   | Verification isn't overthinking |
| "Tests passed earlier" | Code changed since then. Re-run.|

## The Rule

**No "done" claim without fresh verification evidence.**
