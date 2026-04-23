---
name: create-plan
description: Use when the user wants to create an implementation plan from a spec, says /create-plan, or asks to plan out a feature. Do not use for editing existing plans.
---

# Create Implementation Plan

Announce: "I'm using the create-plan skill to create the implementation plan."

## Step 1: Identify the Spec

A plan must be grounded in a spec. Ask which spec this plan is based on (or check context). Look in the project's spec directory (commonly `.docs/specs/` or `docs/specs/`) for candidates.

If no spec exists: **STOP.** Say: "Implementation plans require a spec. Run `/create-spec` first."

Read the spec in full. Check its `status:` frontmatter field:

- `DRAFT`: **STOP.** Say: "This spec is still DRAFT. Have it reviewed, resolve any open questions, and promote it to READY before creating a plan."
- `READY` or `IN PROGRESS`: Proceed. If `IN PROGRESS`, check the project's plan directory (commonly `.docs/plans/` or `docs/plans/`) for an existing plan — some tasks may already be complete.
- `IMPLEMENTED`: Unusual. Say: "This spec is IMPLEMENTED — the feature is already live. Specs can drift from the codebase after implementation, so building a plan from this means building against potentially stale requirements. Are you (a) planning a new milestone on top of this feature (I can proceed, but you may want to update the spec first so the plan reflects current state), or (b) looking at the wrong spec (point me at the right one)?" Wait for their answer before proceeding to Step 2.
- `ABANDONED`: Wrong spec — confirm this is intentional before continuing.
- `DEPRECATED` or `SUPERSEDED`: **STOP** unless user confirms they want to plan against a retired spec.

## Step 2: Assess Scope

**REQUIRED: Discuss scope with the user before writing anything.**

Do not skip or shortcut this step because the spec seems clear or simple. User pressure ("it's obviously one milestone") is not a skip condition — incorporate their answer but still complete the discussion. Scope creep is real regardless of spec size.

Post these questions to the user and **wait for their reply before proceeding to Step 3:**

- How many independent milestones are there?
- Should this be one plan file or multiple?

A plan file covers **one coherent milestone** — a unit of work that builds toward a shippable outcome. A single plan can produce multiple PRs. Do not write one plan for an entire epic.

## Step 3: Generate the Plan

**REQUIRED SUB-SKILL:** Use `superpowers:writing-plans` to structure and generate the plan. Invoke it via the Skill tool — do not apply its principles from memory or substitute your own planning approach. If the Skill tool invocation fails, **STOP** and report the error to the user — do not proceed without it.

Before invoking, brief it with the spec content (Step 1), confirmed scope (Step 2), and the required plan header below.

**Required plan header** (at the very top of every plan):

```markdown
> **Before implementing:** REQUIRED SUB-SKILL: Use `superpowers:executing-plans` to implement this plan task-by-task.

**Spec:** <path-to-spec> (e.g., `.docs/specs/<feature-name>/<spec-name>.md`)
**Goal:** [One sentence]
**Architecture:** [2–3 sentences]
**Tech Stack:** [Key technologies]

---
```

## Step 4: Save and Update Spec

Save to: `<plan-dir>/<feature-name>/YYYY-MM-DD-<plan-name>.md` where `<plan-dir>` is the project's plan directory (typically `.docs/plans/` or `docs/plans/`).

Confirm the save path with the user. **Wait for their confirmation before writing the file.**

Commit the plan file. The spec status remains `READY` until implementation begins — planning alone does not advance the lifecycle.

## Step 5: Execution Handoff

After saving, offer:

> **Plan saved. Two execution options:**
>
> **1. Subagent-Driven (this session)** — fresh subagent per task, code review between tasks. Uses `superpowers:subagent-driven-development`.
>
> **2. Parallel Session (separate)** — open a new session in the worktree, use `superpowers:executing-plans`.
>
> Which approach?
