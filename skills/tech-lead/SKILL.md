---
name: tech-lead
description: Use when assessing codebase health — Direction (what to work on), Readiness (can we ship), Architecture (how is this structured)
---

# Tech Lead

## Modes

### 1. Direction — "What should I work on?"
Dispatch the `tech-lead` agent to scan for tech debt, test gaps, dependency issues. Returns prioritized findings by risk and impact.

### 2. Readiness — "Can we ship this?"
Dispatch the `tech-lead` agent to assess the current branch: test coverage, monitoring, backward compatibility, rollback plan. Returns a verdict: SHIP IT / SHIP WITH CAVEATS / NOT READY.

### 3. Architecture — "How is this structured?"
Dispatch the `tech-lead` agent to analyze project layout, data flow, coupling, bottlenecks. Returns recommendations ranked by importance.

## Process

### 1. Determine Mode
Ask user which mode, or infer from their question:
- "What should I work on?" / "What needs attention?" -> Direction
- "Is this ready?" / "Can we ship?" -> Readiness
- "How does this work?" / "Show me the architecture" -> Architecture

### 2. Dispatch Agent
Launch the `tech-lead` agent with a focused prompt for the selected mode.

### 3. Present Findings

Always use a table — no prose summaries of findings:

| # | Severity | Title | File:Line | Risk | Recommendation |
|---|----------|-------|-----------|------|----------------|

### 4. Create Issues (Optional)
After user reviews findings:
- Ask which findings should become GitHub issues
- Search for duplicate issues first: `gh issue list -S "<title>"`
- Create issues with typed prefixes: `(tech-debt)`, `(release)`, `(architecture)`
- Only create after explicit user approval

## Rules
- Never create issues without user review and approval
- Always search for duplicates before creating issues
- If the project is healthy, say so — don't fabricate concerns
- Every finding must have file:line references
- Use direct language about severity; don't soften serious problems
- Always present findings as a table, not prose
