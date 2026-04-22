---
description: Create a new feature spec from the project template
---

# Create Feature Spec

## Step 1: Orient

Before starting, gather context:

- Check `.docs/specs/` for existing specs in the same feature area
- Check `.docs/ADR/` for related architecture decisions
- Check for a GitHub issue (ask if you don't have one)
- Scan recent commits on the current branch for relevant context

## Step 2: Surface Architectural Constraints

After gathering context, review any architectural rules or conventions scoped to this project (e.g., in `.claude/rules/` or equivalent). Look for rules that affect spec-level decisions: API conventions, state management patterns, security requirements, observability expectations.

Only surface constraints that affect the spec's design decisions — choices the spec writer needs to make or be aware of. Implementation-time rules (code style, naming conventions, lint rules) don't belong here. Those fire at coding time via the rules themselves.

Present the relevant constraints as a numbered list, grouped by domain:

> **Architectural constraints that apply to this feature:**
>
> 1. **API:** [constraint summary]
> 2. **State:** [constraint summary]
>
> Does this look right? Anything to add or override?

Wait for confirmation before proceeding. The user may add, remove, or modify constraints. These confirmed constraints become inputs to the spec — reference them in the relevant sections (functional requirements, non-functional requirements, technical constraints).

If no rules match, say so and move on.

## Step 3: Brainstorm

Invoke the `superpowers:brainstorming` skill to explore and validate the idea. Let it drive the conversation naturally. When brainstorming saves its design document, save it to `.docs/specs/<feature-name-kebab-case>/design-notes.md` instead of its default location.

> **When brainstorming signals it is finished** (offers to move to implementation, planning, or any next step), **decline and continue to Step 4 instead.**

## Step 4: Gap Check

After brainstorming concludes, review the validated design against the spec template's required fields. Ask targeted follow-up questions for anything not yet covered:

| Spec section                   | What's needed                                           | Likely covered by brainstorming?        |
| ------------------------------ | ------------------------------------------------------- | --------------------------------------- |
| §1 Feature Overview            | Problem statement, goal, **measurable** success metrics | Goal yes — measurable metrics often not |
| §2 User Stories                | Who does what and why                                   | Usually yes                             |
| §3 Functional Requirements     | Testable behaviors                                      | Usually yes                             |
| §4 Non-Functional Requirements | Latency, scale, browser support, access control         | Often missed                            |
| §5 Constraints                 | What we must reuse or must not change                   | Usually yes                             |
| §6 Data Contracts              | API shapes, events, key field definitions               | Often missed                            |
| §7 Acceptance Criteria         | Given / When / Then scenarios                           | Partially — may need formalizing        |
| §8 Risks & Edge Cases          | Empty states, failures, stale data                      | Partially                               |
| §9 Out of Scope                | Explicit non-goals                                      | Usually yes                             |
| §10 Implementation Hints       | Optional — skip if not relevant                         | N/A — fill only if useful               |
| Frontmatter                    | Issue URL, related ADRs                                 | Ask if not provided                     |

Only ask about genuine gaps — don't re-cover ground already settled in brainstorming.

## Step 5: Readiness Check

Before writing the spec, evaluate against this rule:

> "If a junior engineer could build the feature correctly from the document without repeated clarification, the spec is probably good enough."

If there are gaps, ask about them before proceeding.

## Step 6: Generate the Spec

Read the template at `.docs/templates/spec-template.md` if one exists. If not, use the standard 10-section structure matching the gap-check table above.

Read `.docs/specs/<feature-name-kebab-case>/design-notes.md` (saved in Step 3) and use it alongside the gap-check answers as input. Generate a spec from the validated design, following that template. Set:

- status: DRAFT
- last_updated: today's date
- spec_owner and tech_lead: ask if not already known

Present the spec in sections (~200–300 words each), checking after each whether it looks right before continuing.

Place any unresolved questions inline next to the relevant section:

> **OPEN QUESTION:** Your question here?

Do not create a separate Open Questions section. All open questions are blocking — a spec with open questions is not ready for implementation.

Writing conventions:

- Number functional requirements as FR-1, FR-2, etc.
- Number non-functional requirements as NFR-1, NFR-2, etc.
- Number user stories as US-1, US-2, etc.
- Number acceptance criteria as AC-1, AC-2, etc.
- Write requirements as short, testable statements — one behavior per line
- Acceptance criteria use Given / When / Then format

Save to `.docs/specs/<feature-name-kebab-case>/<spec-name>.md` (e.g., `.docs/specs/auth/frontend-design.md`). A feature can have multiple specs.

Before creating the file, check if `.docs/specs/<feature-name-kebab-case>/` already exists. If it does, list the existing specs and ask whether this is a new spec or a replacement.

Not every section needs to be filled. If a section genuinely doesn't apply, leave a brief note saying why.

## Step 7: Review

After saving, tell me:

- What open questions remain (if any)
- What sections you filled and what you left empty (and why)
- Any assumptions you made that I should verify
- Anything you think is missing that would help an implementer

Then ask: "Ready to move to implementation planning?" If yes, invoke the `create-plan` skill.
