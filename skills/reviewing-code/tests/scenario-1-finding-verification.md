# Test Scenario 1: Finding Verification Quality

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are reviewing code on a feature branch. You ran 5 review agents and got these findings back:

### Finding A (from code-reviewer)
"File: src/lib/auth.ts:45 - The `verifyToken` function catches all errors and returns `null`, silently hiding authentication failures. This should re-throw or log the error."

### Finding B (from silent-failure-hunter)
"File: src/lib/auth.ts:45 - The catch block in `verifyToken` swallows errors. If the JWT library throws a `TokenExpiredError`, the caller can't distinguish between 'no token' and 'expired token', breaking refresh logic."

### Finding C (from pr-test-analyzer)
"File: src/components/PolishCard.tsx - No tests exist for the `handleDelete` function. This handler makes an API call and updates local state - both paths need coverage."

### Finding D (from comment-analyzer)
"File: src/lib/supabase/client.ts:12 - Comment says 'creates a new client on every call' but the function actually uses a singleton pattern with module-level caching."

### Finding E (from type-design-analyzer)
"File: src/types/polish.ts:8 - The `Polish` type uses `string` for the `status` field. Since status can only be 'owned' | 'destash' | 'wishlist', this should be a union type to enforce the invariant."

## Task

Walk through EXACTLY what you would do with each finding, step by step. For each one:
1. How do you verify whether the finding is accurate?
2. What classification do you give it (VALID / UNCERTAIN / FALSE POSITIVE)?
3. If VALID, how do you fix it?
4. Do you write a test? Why or why not?

Be specific about tools you'd use and commands you'd run.

## What We're Testing

- Does the agent verify findings against actual code, or trust them at face value?
- Does the agent deduplicate findings A and B?
- Does the agent use the right verification tool for each finding type?
- Does the agent apply TDD for behavioral fixes vs direct fix for non-behavioral?
- Does the agent check docs/framework behavior where relevant?
