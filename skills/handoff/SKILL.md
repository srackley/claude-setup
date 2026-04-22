---
name: handoff
description: Use when ending a session, pausing work on a branch, or switching to a new topic
---

# Handoff

## Overview

Wraps up a session cleanly so the next session can start immediately without reconstruction overhead.

## Step 1 — Decide wrap-up type

1. Is the user **continuing in this session right now?**
   - Yes → recommend `/compact`, stop here. No handoff needed yet.
   - No → continue.
   - If the user is stepping away briefly and returning in the same session, treat as Yes.

2. Is there **in-progress work on a branch?** (uncommitted changes, unmerged branch, open PR)
   - Yes → **Full wrap-up** (all steps below)
   - No → **Minimal wrap-up**: skip Steps 3–5, just do memory check (Step 2) and recommend `/clear`

Note: "no work in flight" is not the same as "nothing happened." A session with architectural decisions, research, or answered questions still warrants a memory check even without code changes.

## Step 2 — Update memories

Review the conversation for anything non-obvious and cross-session relevant:
- New user preferences or feedback → update/create memory file + MEMORY.md index
- New project context (decisions, constraints) → same
- New references to external systems → same
- Session notes: if a significant decision or gotcha was discovered, consider writing a dated entry to `~/.claude/session-notes/` (permanent record, never delete)

**Before writing to memory, ask: does this belong in repo docs instead?**

Memory is for Claude-only, cross-session context. Repo docs (conventions, gotchas, rules) are for team-shared knowledge. When a gotcha or pattern would be useful to any developer on the project — not just to you in a future session — it belongs in repo docs, not memory.

Ask for each item:
- Would a teammate benefit from knowing this? → propose it in the appropriate project docs or rules file
- Is it Claude-specific context (preferences, project state, references)? → memory

When you identify a repo-doc candidate: propose the specific file and the content to add, then add a short memory pointer so future sessions know where to look. Don't duplicate content in both places.

Do NOT write memory for task state or current progress — that goes in the handoff doc.

**Project key** = git repo root path with every `/` and `.` replaced by `-`, including the leading slash.
Use `git rev-parse --show-toplevel` to get the repo root — do NOT use the current working directory (worktrees would produce a wrong key).

Example: `/Users/shelbyrackley/work/my-app` → `-Users-shelbyrackley-work-my-app`
Example with dot: `/Users/shelbyrackley/.claude` → `-Users-shelbyrackley--claude` (`.` becomes `-`, giving `--`)

If unsure, verify by checking `~/.claude/projects/` — the actual directories Claude Code created are the source of truth.

Memory files: `~/.claude/projects/<project-key>/memory/`

## Step 3 — Write the handoff doc

First, resolve the branch name: `git -C <repo-root> branch --show-current`. If empty (detached HEAD), use the short commit SHA instead and note it in the doc.

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

Recommend `/clear` — the handoff doc is the continuity mechanism, not the context window.

## Common mistakes

- **Using CWD instead of git root for project key** — worktrees have a different CWD; always use `git rev-parse --show-toplevel`
- **Treating "no code changes" as "nothing to remember"** — decisions and research are memory-worthy even without commits
- **Saving team-relevant gotchas to memory only** — if a teammate would benefit from knowing it, propose it in repo docs first; memory gets a pointer
- **Writing memory for task state** — put it in the handoff doc
- **Skipping the starter prompt** — highest-value output; never omit for in-flight work
- **Recommending /compact at session end** — if wrapping up and moving on, always `/clear`
