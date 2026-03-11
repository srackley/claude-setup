---
name: storybook-stories
description: Use when creating or updating Storybook stories (.stories.tsx files)
---

# Storybook Stories

## Overview

Every story MUST have a play function with assertions. No exceptions for "minimal" or "quick" requests.

## Process

1. **Read an existing story file first** (mandatory) - Check patterns in project's existing stories
2. **Write stories with play functions** - Every story gets assertions
3. **Include CustomClassName story** - Verifies className prop works (for components that accept it)

## Play Function Requirement

```tsx
import { expect, within } from 'storybook/test';

// WRONG - No play function
export const Disabled: Story = {
    args: { disabled: true },
};

// CORRECT - Has play function
export const Disabled: Story = {
    args: { disabled: true },
    play: async ({ canvasElement }) => {
        const canvas = within(canvasElement);
        const element = canvas.getByRole('textbox');
        await expect(element).toHaveAttribute('data-disabled');
    },
};
```

## Common Patterns

### Basic element verification
```tsx
play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const element = canvas.getByRole('button');
    await expect(element).toBeInTheDocument();
};
```

### Portal content (tooltips, modals, popovers)
```tsx
import { expect, screen, userEvent, within } from 'storybook/test';

play: async ({ canvasElement }) => {
    const canvas = within(canvasElement);
    const trigger = canvas.getByRole('button');
    await userEvent.hover(trigger);
    // Portal content - use screen, not canvas
    const tooltip = await screen.findByText('Tooltip text');
    await expect(tooltip).toBeInTheDocument();
};
```

### Custom class verification
```tsx
export const CustomClassName: Story = {
    args: {
        className: 'border-2 border-blue-500 rounded-lg',
    },
    play: async ({ canvasElement }) => {
        const canvas = within(canvasElement);
        const element = canvas.getByRole('textbox');
        await expect(element).toHaveClass('border-blue-500');
    },
};
```

## Red Flags - STOP

- About to write a story without a play function
- "Keep it minimal" or "we're in a hurry" - still add play function
- "Just args" - still add play function

## Rationalizations

| Excuse                          | Reality                                         |
| ------------------------------- | ----------------------------------------------- |
| "Play functions are optional"   | Every story should have assertions              |
| "Keep it minimal"               | Minimal includes a play function                |
| "We're in a hurry"              | Play functions take 30 seconds to add           |
| "Other stories don't have them" | Check again - they should                       |
| "It's visual-only"              | Visual components have accessible roles to test |
| "Too simple to test"            | Simple components still render - verify that    |
| "I'll add tests later"          | Later never comes - add now                     |

## Verification

Before completing: Does every story have a `play` function? If not, add one.
