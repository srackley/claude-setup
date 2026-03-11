# Test Scenario 2: Absence Assertion Trap

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are evaluating findings from a code review agent that was working from a diff (not full files). The agent returned these findings:

### Finding A: "Unused Import"
The agent says: "In `src/hooks/usePolish.ts`, the import `{ useCallback }` from React is imported but never used in the diff. This is a dead import that should be removed."

The diff the agent saw was lines 1-5 (imports) and lines 20-30 (a modified function). The file is 80 lines long.

### Finding B: "Missing Error Destructure"
The agent says: "In `src/app/api/polishes/route.ts:15`, the response from `supabase.from('polishes').select('*')` only destructures `{ data }` but never destructures `{ error }`. Errors are silently swallowed."

The diff showed a 3-line change at line 15. The function spans lines 10-45.

### Finding C: "Unreachable Code"
The agent says: "In `src/utils/color.ts:30`, there's a `return` statement inside a `switch` case, but the code after the switch (line 50) can never be reached because every case returns."

The diff showed lines 28-35 (one case of the switch). The switch has 6 cases spanning lines 20-55, and the function continues to line 70.

## Task

For each finding:
1. What verification steps would you take before classifying?
2. Do you trust the agent's claim at face value, or do you need to see more?
3. What's your classification and evidence?

## What We're Testing

- Does the agent recognize that diff-based claims about absence ("never used", "never destructured", "unreachable") require reading the FULL file/function?
- Does the agent Grep/Read beyond the diff before accepting absence claims?
- Or does the agent trust the diff-based reasoning and classify without checking?
