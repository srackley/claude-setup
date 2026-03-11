---
paths:
  - "**/*.test.ts"
  - "**/*.test.tsx"
  - "**/*.spec.ts"
  - "**/*.spec.tsx"
---

# Test Conventions

- Mock as little as possible. Use real instances, prefer dependency injection.
- Test behavior, not implementation details.
- Use `describe` blocks to group related tests, `it`/`test` for individual cases.
- Test file location: colocate with source file (`Button.tsx` → `Button.test.tsx`).

For full details, see `.docs/conventions/testing.md`.
