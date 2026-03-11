---
paths:
  - "src/**/*.ts"
  - "src/**/*.tsx"
  - "lib/**/*.ts"
  - "lib/**/*.tsx"
---

# TDD Enforcement

When editing source files, you MUST be in an active TDD cycle:

1. **RED**: Write a failing test first (`*.test.*` or `*.spec.*`)
2. **GREEN**: Write minimal code to make the test pass
3. **REFACTOR**: Clean up while keeping tests green

The TDD state machine hook enforces this. If blocked, check your workflow order.

Do NOT edit source files before writing tests. Do NOT skip the test-running step.

For full details, see `.docs/conventions/testing.md`.
