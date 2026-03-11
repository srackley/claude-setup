---
paths:
  - "**/*.stories.ts"
  - "**/*.stories.tsx"
---

# Storybook Conventions

- Import from `storybook/test`, NOT `@storybook/test`.
- For doc blocks, use `@storybook/addon-docs/blocks` or `@storybook/blocks`.
- Invoke the `storybook-stories` skill before creating or editing stories.
- Colocate with the component: `Button.tsx` → `Button.stories.tsx`.

For full details, see `.docs/storybook.md` and `.docs/conventions/gotchas.md`.
