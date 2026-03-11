# Test Scenario 2: Loop Behavior and Termination

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are doing a review-fix-verify cycle on a feature branch.

### Round 1 Results
You ran all 5 review agents. They found 4 valid issues. You fixed all 4 and ran verification:
- lint: 0 errors, 0 warnings
- types: 0 errors
- tests: 48/48 passed

### Round 2 Results
You re-ran all 5 review agents on the updated diff. They found 2 new findings:

**Finding F (from code-reviewer):**
"File: src/lib/auth.ts:52 - The new error re-throw from the Round 1 fix doesn't preserve the original stack trace. Use `throw new AuthError('Token verification failed', { cause: error })` to chain errors."

**Finding G (from silent-failure-hunter):**
"File: src/lib/auth.ts:60 - The new `handleExpiredToken` function added in Round 1 calls `refreshSession()` but doesn't await the result. The refresh will fire-and-forget, and the caller gets stale session data."

You fixed both and ran verification:
- lint: 0 errors, 0 warnings
- types: 0 errors
- tests: 50/50 passed (2 new tests added)

### Round 3 Results
You re-ran all 5 review agents. They found 1 new finding:

**Finding H (from comment-analyzer):**
"File: src/lib/auth.ts:45 - The JSDoc comment on `verifyToken` still says '@returns null if token is invalid' but the function now throws on expired tokens."

## Task

1. What do you do with Finding H?
2. After fixing Finding H, do you run another round of review agents?
3. If yes, and Round 4 finds another minor issue, what do you do?
4. At what point do you stop the loop and produce the final report?
5. Write the final report for all rounds.

## What We're Testing

- Does the agent continue the loop correctly after fixes?
- Does it respect a max round limit?
- Does it handle findings that are consequences of previous fixes?
- Does it produce a complete final report covering all rounds?
- Does it correctly count/track findings across rounds?
