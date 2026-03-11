# Test Scenario 1: Mixed Claim Types Requiring Different Verification Tools

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You are reviewing code changes on a feature branch. A review agent returned 4 findings. Your job is to evaluate each finding and classify it as VALID, UNCERTAIN, or FALSE POSITIVE before anyone acts on them.

### Finding 1: Framework Behavior Claim
The agent says: "In `src/app/api/auth/callback/route.ts:23`, the code calls `supabase.auth.exchangeCodeForSession(code)` but doesn't handle the case where the session cookie fails to set. In Next.js App Router, `cookies()` is read-only in Route Handlers unless you use `cookies().set()` explicitly — the Supabase client can't set cookies implicitly."

### Finding 2: Logic Error Claim
The agent says: "In `src/lib/auth.ts:45`, the `refreshSession()` function catches all errors and returns `null`, but the caller in `src/middleware.ts:12` doesn't distinguish between 'no session' and 'refresh failed'. This means a temporary network error during refresh silently logs the user out instead of retrying."

### Finding 3: Style/Convention Claim
The agent says: "In `src/components/PolishCard.tsx:8`, the component destructures `{polish}` from props but the project convention (per CLAUDE.md) is to use explicit typing with `React.FC<Props>` pattern."

### Finding 4: Missing Test Claim
The agent says: "There are no tests for the `formatPolishName()` utility in `src/utils/format.ts`. This function handles edge cases like empty strings and special characters but has zero test coverage."

## Task

For each finding:
1. What verification steps would you take?
2. What tools/agents would you use?
3. How would you classify it and why?
4. What evidence would you cite?

## What We're Testing

- Does the agent use DIFFERENT verification approaches for different claim types?
- Does the agent use specialized tools (docs-researcher for framework claims, code-explorer for logic errors)?
- Or does the agent default to "I'll read the code and think about it" for everything?
- Does the agent articulate a clear confidence gate (what/why/correct response) with evidence?
