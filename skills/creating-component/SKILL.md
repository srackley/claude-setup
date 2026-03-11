---
name: creating-component
description: Use when creating, editing, or writing any new UI component
---

# Creating Component

## Overview

Create components by reading conventions and existing examples FIRST. Never guess at patterns.

## Process

### 1. Read conventions FIRST (mandatory)

Check the project's CLAUDE.md and convention docs for component patterns. Common locations:

- `docs/conventions/component-workflow.md` - Step-by-step guide with templates
- `docs/conventions/software-design.md` - Patterns, design tokens
- `docs/conventions/` - Other project-specific conventions

If convention docs don't exist, read 2-3 existing component files to learn the project's patterns.

### 2. Determine component type and read examples

Ask user: form, layout, or interactive?

Read BOTH the component AND stories files for similar existing components in the project.

### 3. Identify where components live

Check the project structure. Common patterns:

- Generic UI primitive → `src/components/ui/` or equivalent shared component directory
- Domain-specific → `src/features/{domain}/components/`
- Unclear → ask the user

### 4. Create files following project conventions

Typical file set:
1. `{ComponentDir}/{Name}/{Name}.tsx`
2. `{ComponentDir}/{Name}/{Name}.stories.tsx`
3. Update barrel file (e.g., `index.ts`) - keep alphabetized

### 5. Run verifying skill

## Red Flags - STOP

- About to create component without reading conventions first
- About to create component without reading existing examples
- Guessing at Storybook imports (check existing stories)
- Using raw package manager commands when a task runner is available

## Rationalizations

| Excuse                       | Reality                                      |
| ---------------------------- | -------------------------------------------- |
| "It's a quick component"     | Read conventions and examples anyway         |
| "I know the pattern"         | Patterns vary by codebase - read the docs    |
| "I'll fix lint errors after" | Read examples to avoid errors in first place |
