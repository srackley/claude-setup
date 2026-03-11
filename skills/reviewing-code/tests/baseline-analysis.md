# Baseline Analysis — Review Loop Skill

## Summary

Baseline agents performed better than expected on fundamentals (deduplication, TDD for behavioral changes, basic verification). The gaps are in **systematization** — the agents have good instincts but don't use the right specialized tools, don't enforce hard limits, and don't formalize their confidence reasoning.

## Scenario 1: Finding Verification

### What the agent did well:
- Deduplicated findings A+B correctly (used B's more specific framing)
- Verified each finding against actual code before classifying
- Applied TDD for behavioral changes (A+B, C), direct fix for non-behavioral (D, E)
- Checked database schema for Finding E (didn't trust agent's claimed union values)
- Used Grep to find call sites for impact analysis

### Gaps:
1. **No specialized verification tools.** Agent used Read/Grep for everything. Never considered:
   - `docs-researcher` for verifying framework/library behavior claims
   - `feature-dev:code-explorer` for tracing execution paths on logic error claims
   - These tools exist specifically for rigorous verification — the agent defaulted to "I'll read the code and think about it"
2. **No formal confidence gate.** Agent classified findings as VALID but didn't articulate the triple-check: what's wrong + why (with evidence) + correct fix. Verification was implicit, not explicit.
3. **Finding E gap:** Agent correctly questioned the union values but planned to verify manually. Should have spawned docs-researcher to verify Supabase type generation behavior and whether generated types already have the union.
4. **No structured verification-per-type approach.** Verification was ad-hoc (Read/Grep for everything) rather than systematized by finding type (logic error → code-explorer, framework claim → docs-researcher, etc.)

### Key quote (gap evidence):
> "I would use Read to open src/lib/auth.ts and examine line 45"

This is verification, but it's shallow. For a logic error claim ("the caller can't distinguish error types, breaking refresh logic"), the agent should trace the full execution path through code-explorer, not just read the function.

## Scenario 2: Loop Behavior

### What the agent did well:
- Recognized Finding H as valid (stale JSDoc from earlier fix)
- Good convergence analysis (4 → 2 → 1 pattern)
- Produced a round-by-round report with specifics

### Gaps:
1. **Max rounds: chose 5, not 3.** No firm limit enforced. The agent rationalized: "A reasonable max round limit is 4-5." Our design says 3.
2. **No confidence gate applied.** Assumed all findings in all rounds were valid without verification step.
3. **Report format missing categories.** No Fixed/Dismissed/Deferred structure. No evidence citations for verification.
4. **No context management mentioned.** No progress checkpoints between rounds despite running 3+ rounds.
5. **Stopping criteria too nuanced.** Agent created 4 different stopping conditions instead of a simple rule. This complexity creates ambiguity.

### Key quote (gap evidence):
> "If it is a style/documentation/naming nit: fix it inline without running another round of agents."

This is reasonable but creates a loophole. The skill should enforce: if you made ANY change, you re-run agents. No "this is too small to re-verify" shortcuts.

## Scenario 3: Context Management

### What the agent did well:
- Proactive checkpointing before compaction (not reactive)
- Progressive compression of completed rounds
- Batching sub-agent calls for efficiency
- Recovery strategy from checkpoint
- Explicit next steps in checkpoint

### Gaps:
1. **File path is ad-hoc.** Agent chose `SESSION-PROGRESS.md` in worktree root. Our design specifies `~/.claude/review-loop-progress.md`.
2. **No standard checkpoint schema.** Format was reasonable but invented on the spot. Skill should define the checkpoint structure.
3. **No max round enforcement.** Agent mentioned "Round 3" in next steps but no cap.
4. **No mention of /compact timing rule.** Our design says round 2+ should compact. Agent compacted reactively based on "feeling" context pressure.

### Key quote (strength):
> "The critical rule: never lose work state. Write to disk before compacting."

This is exactly right. The skill should reinforce this.

## What the Skill Must Address

### Critical (agent fails without it):
1. **Verification matrix** — enforce using the RIGHT tool per finding type, not just Read/Grep
2. **Confidence gate** — require explicit "what's wrong / why / correct fix" with evidence before VALID classification
3. **Max 3 rounds** — hard limit, no negotiation

### Important (agent does it poorly without it):
4. **Report format** — standardize Fixed/Dismissed/Deferred with evidence citations
5. **Checkpoint format and path** — standardize the progress file structure
6. **Compact timing** — round 2+ should compact, not "when it feels heavy"

### Already handled (agent does it well naturally):
- Deduplication of overlapping findings
- TDD for behavioral changes, direct fix for non-behavioral
- Basic code verification (reading files, searching for references)
- Progressive compression of checkpoint data
