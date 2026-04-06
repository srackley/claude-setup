# Compliance Reviewer — Integration Test Results

> Agent hook: `type: "agent"` in Bash PreToolUse, `~/.claude/settings.json`
> Model: claude-haiku-4-5, timeout: 120s
> Registered: 2026-03-02

## Benchmark Results (Task 1)

Agent hook (no-op benchmark) fired on every Bash command. Five commands timed:

| Command | Command Time | Perceived Latency |
|---------|-------------|-------------------|
| `git status` | 0.010s | No noticeable delay |
| `ls` | 0.002s | No noticeable delay |
| `echo "hello"` | ~0s | No noticeable delay |
| `task --list` | 0.071s | No noticeable delay |
| `git log --oneline -3` | 0.008s | No noticeable delay |

**Decision: <500ms overhead. Proceed with agent hook as-is.**

Note: `time` only measures command execution, not hook overhead. Perceived latency
(tool call submission to result) showed no multi-second delays, confirming the
Haiku fast-path (`{"ok": true}` for non-commit commands) is acceptably fast.

## Hook Configuration

Position in Bash PreToolUse chain:
1. `commit-gate.sh` (command) — blocks commits without finishing-work
2. **Compliance reviewer** (agent) — 5-criteria transcript analysis on git commit
3. `enforce-permissions.py` (command) — permission checks
4. `prefer-task.py` (command) — suggests task commands over pnpm

## Integration Test Scenarios

### Scenario 1: Non-commit command (fast path)

**Input:** Any Bash command that is NOT `git commit`
**Expected:** `{"ok": true}` returned immediately (single Haiku turn, no tool use)
**Status:** VERIFIED via benchmark — 5 non-commit commands showed no delay

### Scenario 2: Clean commit (should PASS)

**Steps:**
1. Invoke TDD skill
2. Write test file first
3. Run tests (fail)
4. Write source file
5. Run tests (pass)
6. Invoke reviewing-code skill, run 5 agents
7. Invoke finishing-work
8. Attempt `git commit`

**Expected:** `{"ok": true}` — all 5 criteria pass
**Status:** PASSED (2026-03-02) — Commit `a1d13ca` went through. Full TDD cycle (test→fail→source→pass), 5 review agents, finishing-work all completed. No delay observed on the commit command itself.

### Scenario 3: TDD violation (should BLOCK)

**Steps:**
1. Invoke TDD skill
2. Write source file FIRST (violation — should write test first)
3. Write test file
4. Complete remaining workflow
5. Attempt `git commit`

**Expected:** `{"ok": false, "reason": "TDD CHRONOLOGY: Edit/Write to source file appeared before test file after TDD skill invocation"}`
**Status:** FAILED (2026-03-02) — Commit `66b3ac6` went through despite clear TDD violation (Write to capitalize.ts before capitalize.test.ts after second TDD skill invocation). Compliance reviewer did not block. Reverted in `cd569b8`.

**Root cause analysis (2026-03-02):**

Confirmed via docs-researcher:
- `transcript_path` IS in the hook input (confirmed from official hooks docs)
- Agent hooks **fail open** on error/timeout — defaults to allowing execution
- No observability into what Haiku responded without `claude --debug` mode

Evidence:
- Session transcript at commit time: **1.3MB, 878 JSONL lines**
- Each JSONL line can contain full file contents (large tool outputs)
- Haiku must: parse $ARGUMENTS JSON → detect `git commit` → Read 1.3MB file → parse 878 lines → trace chronological ordering → respond — all within 120s
- Both clean commit (Scenario 2) and violation commit (Scenario 3) showed no perceptible delay, suggesting Haiku may not even be reaching the transcript analysis step

**Root cause: architectural — three compounding problems:**
1. **Fail-open semantics**: Error/timeout silently allows commit (no feedback)
2. **Transcript too large**: 1.3MB is beyond Haiku's practical analysis capability in 120s
3. **No observability**: Can't tell if hook errored, timed out, or reasoned incorrectly

This is NOT fixable by prompt tuning. Even with a perfect prompt, long sessions produce transcripts too large to analyze. The sessions that most need enforcement (complex multi-step workflows) are exactly the ones where the transcript is largest.

### Scenario 4: Incomplete review loop (should BLOCK)

**Steps:**
1. Invoke reviewing-code skill
2. Run only 1-2 agents (should be 5)
3. Invoke finishing-work
4. Attempt `git commit`

**Expected:** `{"ok": false, "reason": "SKILL COMPLETION: Only N/5 review agents dispatched after reviewing-code skill"}`
**Status:** PENDING

### Scenario 5: No skills invoked (should PASS)

**Steps:**
1. Make a config/docs change (no TDD or reviewing-code invoked)
2. Attempt `git commit`

**Expected:** `{"ok": true}` — all criteria skipped (no relevant skills invoked)
**Status:** PENDING

### Scenario 6: Transcript unavailable (should BLOCK)

**Steps:**
1. Somehow trigger a commit where transcript_path is missing/invalid
2. Attempt `git commit`

**Expected:** `{"ok": false, "reason": "Cannot verify compliance — transcript unavailable"}`
**Status:** PENDING

## Known Limitations

1. **Agent hooks require session restart** to pick up settings.json changes
2. **Cannot unit test with bats** — agent hooks need the Claude Code runtime
3. **Matcher is tool-name only** — hook fires on ALL Bash commands, prompt handles fast-path
4. **Transcript size** — long sessions produce large JSONL files; Haiku's 120s timeout may not be enough for very long transcripts
5. **No async support** — agent hooks always block execution

## Session 2 Results (2026-03-02)

### Fast path re-verified
Three commands timed: `git status` (0.009s), `ls` (0.002s), `echo` (~0s). No perceptible delay. Fast path working correctly.

### Scenario 2: PASSED
Clean commit with full TDD + reviewing-code (5 agents) + finishing-work allowed through.

### Scenario 3: FAILED (false negative)
TDD violation (source before test) was NOT blocked. This is the critical finding — the compliance reviewer's enforcement capability is unproven. See hypothesis list above.

### Assessment
The compliance reviewer works as a fast-path pass-through for non-commit commands. However, its ability to actually detect and block violations on commit is unverified. Before investing more time in scenarios 4-6, the Scenario 3 failure needs root cause analysis.

## Root Cause: Agent Hooks Are Broken (2026-03-04)

Debugged with `claude --debug hooks`. The agent hook **never executes**. Every invocation fails immediately with:

```
Hook PreToolUse:Bash (PreToolUse) error:
Failed to run: Messages are required for agent hooks. This is a bug.
```

This is a Claude Code runtime bug — the hook executor doesn't pass `messages` to the agent hook branch. Known issue: anthropics/claude-code#26474 (filed 2026-02-23, open, no maintainer response). Affects ALL hook events, not just UserPromptSubmit. Verified broken v2.1.45 through v2.1.68.

**The agent hook has never executed a single time.** All prior scenario results were actually testing fail-open behavior, not agent reasoning.

### What was fixed
- Agent prompt updated to use `$ARGUMENTS` instead of `${sessionId}` (correct but moot until bug is fixed)
- Dropped TDD chronology criterion (TDD state machine handles this mechanically)

### Path forward when bug is fixed
1. Run `claude --debug hooks` and verify "Messages are required" error is gone
2. Run a hello-world agent hook that returns `{ok: false, reason: "alive"}` — verify it blocks
3. THEN re-run scenarios 2-6 with the real compliance reviewer
4. Promote mechanical checks (criteria 1 and 3) into commit-gate.sh regardless — they don't need LLM reasoning
