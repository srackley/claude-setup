---
name: handoff
description: Use when ending a session, switching context, or wrapping up a task — produces a handoff doc, updates memories, recommends /clear or /compact, and generates the next-session starter prompt
---

# Handoff

## Overview

Wraps up a session cleanly so the next session can start immediately without reconstruction overhead.

## Step 1 — Assess what happened

Ask (or infer from context):
- Is there in-progress work on a branch? (code changed, uncommitted, or unmerged)
- Is the user continuing in this session right now, or truly wrapping up?
- Was anything discovered worth preserving across sessions?

```
digraph assess {
    "Work in flight?" [shape=diamond];
    "Continuing now?" [shape=diamond];
    "Full wrap-up" [shape=box];
    "/compact only — skip rest" [shape=box];
    "Minimal wrap-up" [shape=box];

    "Work in flight?" -> "Continuing now?" [label="yes"];
    "Work in flight?" -> "Minimal wrap-up" [label="no (read-only session)"];
    "Continuing now?" -> "/compact only — skip rest" [label="yes"];
    "Continuing now?" -> "Full wrap-up" [label="no"];
}
```

**Minimal wrap-up** (read-only session): no handoff doc, no starter prompt. Just check memory and recommend `/clear`.

**Full wrap-up**: all steps below.

## Step 2 — Update memories

Review the conversation for anything non-obvious and cross-session relevant:
- New user preferences or feedback → update/create memory file + MEMORY.md index
- New project context (decisions, constraints) → same
- New references to external systems → same

Do NOT write memory for task state or current progress — that goes in the handoff doc.

Memory files: `~/.claude/projects/<project-key>/memory/`

Project key = working directory with every `/` replaced by `-`, including the leading one.
Example: `/Users/shelbyrackley/work/my-app` → `-Users-shelbyrackley-work-my-app`

## Step 3 — Write the handoff doc

Path: `~/.claude/projects/<project-key>/memory/handoffs/<branch-name>.md`

Branch name: replace `/` with `-`. Example: `feat/new-dashboard` → `feat-new-dashboard.md`

One file per branch. Overwrite each session. Delete once merged.

```markdown
# Handoff: <branch>

**Date:** YYYY-MM-DD
**Status:** In progress | Ready to commit | Ready to PR | Done

## What was done
- <bullet summary>

## Next steps
1. <first action>

## Context / gotchas
<Decisions, workarounds, known issues worth rediscovering>
```

## Step 4 — Output the handoff path

Always print it explicitly:

```
Handoff written to:
~/.claude/projects/<project-key>/memory/handoffs/<name>.md
```

## Step 5 — Generate next-session starter prompt

Output a ready-to-paste prompt:

```
Continue work on branch `<branch>`.

Previous session (<date>): <one-sentence summary>.

Handoff doc: ~/.claude/projects/<project-key>/memory/handoffs/<name>.md

Next: <first action from next steps>
```

## Step 6 — Recommend /clear or /compact

- **`/clear`** — session is over, or next topic is different
- **`/compact`** — staying in this session on the same task (but at this point you already exited in Step 1)

## Common mistakes

- **Writing memory for task state** — put it in the handoff doc
- **Writing a handoff for a read-only session** — skip it if nothing is in flight
- **Skipping the starter prompt** — highest-value output, never omit for in-flight work
- **Recommending /compact at true session end** — if wrapping up and moving on, always `/clear`
- **Ambiguous project key** — every `/` becomes `-`, including the leading slash
