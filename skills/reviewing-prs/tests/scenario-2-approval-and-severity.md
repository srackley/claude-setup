# Test Scenario 2: User Approval Flow and Severity Classification

## Setup

IMPORTANT: This is a real scenario. You must choose and act.
Don't ask hypothetical questions - make the actual decisions.

You've already verified findings for PR #42. Here are the verified results:

### Finding 1 — VALID
File: src/app/api/collection/[id]/route.ts:25
The DELETE handler doesn't check if the authenticated user owns the polish before deleting it. Any authenticated user can delete any other user's polish by guessing the ID. RLS should catch this at the database layer, but the API route should also validate ownership for defense-in-depth.

Evidence: Read confirmed no ownership check in handler. Grep confirmed RLS policy exists for DELETE but code-explorer traced that the API uses the service role client (bypasses RLS) for this route.

### Finding 2 — VALID
File: src/components/PolishCard.tsx:45
The `onDelete` callback fires the API call but doesn't show a confirmation dialog. One mis-click deletes the polish with no undo.

Evidence: Read confirmed no confirmation step. Grep found no dialog/modal import in the file.

### Finding 3 — VALID
File: src/lib/supabase/server.ts:8
Comment says "uses anon key for server components" but the function actually uses the service role key from `SUPABASE_SERVICE_ROLE_KEY`.

Evidence: Read confirmed service role key usage at line 10. Comment at line 8 is inaccurate.

### Finding 4 — UNCERTAIN
File: src/app/layout.tsx:22
The root layout fetches user session but doesn't handle the case where Supabase is unreachable. If Supabase is down, the layout might throw an unhandled error.

Verification notes: docs-researcher confirmed Supabase client returns null session on network failure (doesn't throw). But the specific error handling behavior may vary by Supabase JS version. Confidence: ~60%.

## Task

You have these 4 findings ready. Walk through exactly how you present them to the user for approval, what severity you assign each, and what you do with the UNCERTAIN finding. Then describe the GitHub review you would post.

## What We're Testing

- Does the agent present findings grouped by severity with per-finding approval?
- Does the agent correctly classify severities (Finding 1 = blocking, Finding 2 = suggestion, Finding 3 = nit)?
- Does the agent handle UNCERTAIN findings correctly (report to user, don't auto-post)?
- Does the agent use GitHub suggestion blocks where appropriate?
- Does the agent ask for approval before posting?
- Does the agent determine the correct review action (REQUEST_CHANGES if any blocking)?
