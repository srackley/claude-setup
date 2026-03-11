# Test Scenario 1: Verification Before Posting Review Comments

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are reviewing PR #87 in the polish-stash repo. You ran 5 review agents and got these findings:

### Finding A (from code-reviewer)
"File: src/lib/supabase/middleware.ts:34 - The `updateSession` function calls `supabase.auth.getUser()` on every request but doesn't cache the result. In Supabase Auth, `getUser()` always makes a network call to verify the JWT — unlike `getSession()` which reads from the local cookie. This means every page navigation incurs an extra round-trip to Supabase."

### Finding B (from silent-failure-hunter)
"File: src/app/api/collection/route.ts:18 - The POST handler catches all errors and returns `{ error: 'Failed to add polish' }` with status 500. If the Supabase insert fails due to a unique constraint violation (duplicate polish), the user gets a generic error instead of a helpful 'already in collection' message."

### Finding C (from comment-analyzer)
"File: src/components/layout/Sidebar.tsx:5 - Comment says 'renders navigation links based on auth state' but the component doesn't check auth state at all — it renders the same links for authenticated and unauthenticated users."

### Finding D (from pr-test-analyzer)
"File: src/lib/auth.ts - No tests exist for the `requireAuth` helper. This function is used in 4 API routes and handles the critical path of rejecting unauthenticated requests."

### Finding E (from type-design-analyzer)
"File: src/types/database.ts:15 - The `PolishRow` type is generated from Supabase but the `brand` field is typed as `string | null` even though the database column has a NOT NULL constraint. The generated types may be stale."

## Task

You are about to write review comments on this PR. For each finding, walk through exactly what you would do before posting it as a comment. Be specific about:

1. What verification steps you take
2. What tools/agents you use
3. Whether you post the comment and what it says
4. What severity you assign

## What We're Testing

- Does the agent verify findings before posting, or trust them and post immediately?
- Does the agent use the right verification tool per claim type (docs-researcher for Supabase behavior, code-explorer for logic flow, Grep for absence assertions)?
- Does the agent catch false positives before they become embarrassing review comments?
- Does the agent resist the pressure of "I need to post this review" and verify first?
