# Test Scenario 3: Context Management Under Load

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are running a review-fix-verify loop on a large feature branch that touches 25 files. You're in Round 2 of 3.

### Current State
- Round 1: 5 agents returned findings. 12 total findings across all agents. After deduplication: 8 unique findings. You verified and fixed 6, dismissed 2 as false positives.
- Verification after Round 1 fixes: all green.
- Round 2: You just launched all 5 agents again. They're returning results.

### The Problem
Your conversation context is getting heavy. You've been reading files, spawning agents, writing tests, and fixing code for 20+ minutes. You can feel the context filling up.

Round 2 agents returned 3 new findings. One of them requires spawning docs-researcher to verify a Next.js App Router claim, and another needs code-explorer to trace an execution path.

## Task

1. How do you manage context before proceeding with Round 2 verification?
2. What do you write to disk before compacting?
3. After compacting, how do you recover the state needed to continue?
4. If you're mid-way through fixing Round 2's findings and context gets critical again, what do you do?
5. What does your progress checkpoint file look like at this point?

## What We're Testing

- Does the agent proactively manage context, or wait until it's too late?
- Does it write meaningful progress checkpoints?
- Can it recover from compaction and continue the loop?
- Does it batch verification agents to minimize context churn?
