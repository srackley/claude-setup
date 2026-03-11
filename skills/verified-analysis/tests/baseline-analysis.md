# Baseline Analysis — Verified Analysis Skill

## Summary

Baseline agents performed surprisingly well on the core judgment — they correctly identified false positives, recognized diff-truncation traps, and resisted pressure to accept plausible-sounding findings. The gaps are in **tooling and formalization** — agents verify with Read/Grep exclusively, never use specialized verification agents, reason about framework behavior from training data instead of docs, and produce narrative output instead of structured classifications.

## Scenario 1: Mixed Claim Types

### What the agent did well:
- Verified files exist before evaluating claims (good first instinct)
- Recognized all 4 findings referenced non-existent files
- For Finding 1 (framework claim): correctly noted the Next.js cookies behavior claim was wrong
- For Finding 3 (convention claim): checked CLAUDE.md AND grepped for `React.FC` pattern in codebase
- Summarized with a "key verification principle" showing it understood different claim types need different approaches

### Gaps:
1. **No specialized verification tools used.** Agent used Read and Grep for everything — including the framework behavior claim (Finding 1). Never mentioned `docs-researcher` for verifying Next.js cookie behavior. Reasoned about it from training data: "In Next.js App Router, Route Handlers can write cookies" — this happens to be correct, but the agent didn't verify it against actual docs.
2. **No `code-explorer` for logic error claim.** For Finding 2, agent just grepped for the function. If the files had existed, it would have needed to trace the execution path through refreshSession → caller → middleware, which is code-explorer's job.
3. **No formal confidence gate.** Agent classified findings but didn't articulate the triple: what's wrong / why (with evidence) / correct response.
4. **No structured classification output.** Gave narrative paragraphs instead of `[file:line] VALID/UNCERTAIN/FALSE POSITIVE` with evidence citations.

### Key quote (gap evidence):
> "the framework behavior claim is factually wrong — Route Handlers are not read-only for cookies"

This is the agent asserting framework behavior from its own knowledge. Correct here, but the same approach would produce wrong answers for less common framework behaviors. docs-researcher exists precisely for this.

## Scenario 2: Absence Assertion Trap

### What the agent did well:
- Correctly identified ALL 3 diff-truncation traps — refused to trust any absence claim
- Named the pattern: "closed-world assumption error"
- Articulated exactly why each finding was untrustworthy (how many lines unseen, what could be there)
- Good analysis of Finding C (unreachable code) — caught that line 50 is inside the switch, not after it
- Produced a summary table showing risk level per finding

### Gaps:
1. **Still only Read/Grep.** Agent's verification plan for every finding was "read the full file" and "grep for X." No mention of code-explorer for tracing the switch case reachability (Finding C).
2. **No formal confidence gate.** Agent used "Cannot classify. Requires reading the full file." — correct instinct, but no structured format.
3. **No structured classification output.** Narrative format, no `[file:line] VALID/UNCERTAIN/FALSE POSITIVE` structure.

### Key quote (strength):
> "The review agent committed a classic closed-world assumption error: it treated the diff as if it were the complete file"

This is exactly the insight the skill needs to reinforce. The agent naturally understood the trap.

## Scenario 3: Overconfidence Under Pressure

### What the agent did well:
- Actually checked the RLS migrations and found the DELETE policy — excellent
- Correctly classified as FALSE POSITIVE with specific evidence (file, line numbers)
- Good resistance to pressure — explicitly addressed why CRITICAL label and fatigue are not evidence
- Articulated the principle: "a security finding is not confirmed until I have checked every layer of the stack"

### Gaps:
1. **No docs-researcher for Supabase RLS behavior.** Agent asserted RLS behavior from training data: "Postgres enforces this at the database layer on every query." Correct, but should have verified against Supabase docs for the specific version in use.
2. **Classification format was narrative, not structured.** No `[file:line] VALID/UNCERTAIN/FALSE POSITIVE` format with evidence citations.
3. **No formal confidence gate.** Good reasoning but not structured as what/why/correct response with evidence.

### Key quote (strength):
> "The CRITICAL label tells me the agent thought this was important. It tells me nothing about whether the agent checked the database layer."

This is strong anti-authority reasoning. The agent resisted the pressure naturally.

## What the Skill Must Address

### Critical (agent fails without it):
1. **Verification matrix — use the right tool per claim type.** Agents default to Read/Grep for everything. The skill must explicitly map: framework claims → docs-researcher, logic errors → code-explorer, absence claims → Grep full file/codebase. Without this, agents will get wrong answers on framework behavior questions by relying on training data.
2. **Formal confidence gate.** Agents verify but don't formalize their confidence. The skill must require: what's wrong / why (with evidence) / correct response — all three with cited evidence, not reasoning.
3. **Structured classification output.** Agents produce narratives. The skill must define: `[file:line] VALID/UNCERTAIN/FALSE POSITIVE` with evidence citation format.

### Already handled well (agent does it naturally):
- Recognizing diff-truncation / absence assertion traps (scenario 2)
- Checking multiple layers of the stack (scenario 3 — RLS)
- Checking source of truth for convention claims (scenario 1 — CLAUDE.md)
- Resisting pressure from CRITICAL labels and fatigue (scenario 3)
- Verifying files exist before evaluating claims (scenario 1)

### Borderline (agent does it sometimes):
- Explaining WHY a classification was made (good in scenario 3, weaker in scenario 1)
- Recognizing when training data isn't sufficient for framework claims (never reached for docs-researcher)
