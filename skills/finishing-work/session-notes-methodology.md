# Session Notes Methodology

A pattern for maintaining persistent memory across AI-assisted development sessions.

## Purpose

Session notes serve as a "memory bank" that:
- Reduces repeated mistakes across sessions
- Captures architectural decisions and their rationale
- Documents corrections to the AI's approach
- Preserves patterns that worked well

## Setup

Create a `SESSION-NOTES.md` file at the project root with this structure:

```markdown
# Session Notes

This document tracks learnings, decisions, and corrections from AI-assisted development sessions. It serves as persistent memory across sessions to improve context and avoid repeating mistakes.

**Purpose**: Capture patterns, architectural decisions, and corrections that should inform future development work.

**Maintenance**: Append new entries chronologically. Extract recurring patterns into formal convention docs when they mature.

---

## Guidelines

**DO Track:**

- Architectural decisions and their rationale
- Corrections to the AI's approach or understanding
- Patterns that worked particularly well
- Testing strategies and coverage decisions
- Complex bugs and their root causes
- Performance insights
- Team conventions that emerged from practice

**DON'T Track:**

- Routine bug fixes or typos
- Obvious implementation details
- Standard framework usage
- Changes already documented elsewhere
- Temporary workarounds (unless they reveal systemic issues)

**When to Extract:**

- If a pattern appears 3+ times, consider adding to formal conventions
- If a decision affects architecture, update relevant docs
- If a correction reveals a gap in AI instructions, update CLAUDE.md

---

## Entry Template

> **Required heading format:** `## YYYY-MM-DD: title` — NOT `# title`. The
> `get_recent_session_notes` function identifies entries by scanning for `## YYYY-MM-DD`
> headings. A `#` heading or `## heading-without-date` will be invisible at session start.
> Subsections use `###`.

Only include sections that have meaningful content. Omit empty sections.

## YYYY-MM-DD: [Brief Session Description]

### Context

[What were you working on? What prompted this session?]

### Decisions Made

- [Key architectural or implementation decisions]
- [Technology choices and why]

### Corrections

- [Things the AI did wrong that needed fixing]
- [Anti-patterns to avoid]

### Learnings

- [What worked well]
- [Patterns to repeat]

### Open Questions

- [Unresolved items for future sessions]

### References

- [Relevant files, PRs, or documentation]

---

[Session entries go here, newest at bottom]
```

## Key Principles

### 1. Track Corrections Explicitly

When the user corrects the AI's approach, document it with the original mistake and the correct approach:

```markdown
### Corrections

- **Don't rename existing exports**: When refactoring, keep export names stable (e.g., `Label` should stay `Label`, not become `FieldLabel`)
- **Use `getByRole` for form elements**: `getByLabelText` finds multiple elements for radio buttons and checkboxes. Use `getByRole('radio', { name: '...' })` instead.
```

### 2. Capture Rationalizations

Document the excuses the AI made and why they were wrong. This helps prevent future rationalization:

```markdown
### Corrections

- **"It's a quick task"** - Still need to run verification. Quick tasks break too.
- **"I know the pattern"** - Patterns vary by codebase. Read the docs anyway.
```

### 3. Include Code Examples

When documenting patterns, include concrete code examples:

```markdown
### Learnings

- **Portal content testing**: Use `screen.findByText()` instead of `canvas.findByText()` for content rendered in portals:
    ```tsx
    // For non-portal content
    const button = canvas.getByRole('button');
    // For portal content (tooltips, popovers, modals)
    const tooltip = await screen.findByText('Tooltip text');
    ```
```

### 4. Extract Mature Patterns

When a pattern appears 3+ times in session notes, promote it to formal documentation:

1. Create or update the appropriate convention doc
2. Add a reference in session notes pointing to the new location
3. Don't delete the original entries (they provide historical context)

### 5. Reference Specific Files

Include file paths so the AI can revisit the context:

```markdown
### References

- [Field.tsx](src/components/ui/Field/Field.tsx)
- [Input.tsx](src/components/ui/Input/Input.tsx)
- [design-tokens.css](src/styles/design-tokens.css)
```

## Integration with AI Instructions

Reference SESSION-NOTES.md in your CLAUDE.md (or equivalent AI instructions file):

```markdown
## Session History

See [SESSION-NOTES.md](SESSION-NOTES.md) for learnings from previous sessions.

## During Sessions

**Periodically update docs with preferences learned during the session.** When the user corrects your approach, establishes a preference, or you discover something important:

1. Add an entry to SESSION-NOTES.md with the learnings
2. Update relevant docs if the pattern is reusable
3. Do this proactively without being asked
```

## Benefits

1. **Reduced repetition**: AI doesn't make the same mistakes twice
2. **Preserved context**: Decisions aren't lost between sessions
3. **Evolving conventions**: Patterns naturally mature into formal docs
4. **Accountability**: Clear record of what was tried and what worked
5. **Onboarding**: New team members (human or AI) can catch up quickly

## Common Entry Types

### Architectural Decision
```markdown
## 2024-03-15: Database Migration Strategy

### Decisions Made

- **Incremental migrations**: Use small, reversible migrations instead of large schema changes
- **Shadow tables**: Create shadow tables during transition period for rollback safety

### Learnings

- Test migrations on production-like data volumes before deploying
```

### Bug Investigation
```markdown
## 2024-03-16: Memory Leak in Worker Pool

### Context

Users reported increasing memory usage over time.

### Learnings

- **Root cause**: Event listeners weren't being cleaned up when workers recycled
- **Pattern**: Always pair addEventListener with removeEventListener in cleanup functions
```

### Workflow Improvement
```markdown
## 2024-03-17: Pre-commit Verification

### Decisions Made

- **Always verify before commit**: Added finishing-work skill to enforce lint/type/test before git commit

### Corrections

- **Don't skip verification**: Committed without running tests; caught by CI. Always run locally first.
```
