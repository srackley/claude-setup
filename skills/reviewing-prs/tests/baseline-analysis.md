# Baseline Analysis — Reviewing PRs Skill

## Summary

Baseline agents performed remarkably well on core judgment — they verified findings against real code, caught false positives, classified severities correctly, handled UNCERTAIN findings properly, and required user approval. The gaps are in **formalization and tooling** — agents verify with Read/Grep exclusively, never invoke verified-analysis or specialized agents, produce narrative instead of structured output, and present approval as all-at-once instead of per-finding.

## Scenario 1: Verification Before Posting

### What the agent did well:
- Verified every finding against actual code before deciding to post
- Caught 4 out of 5 findings as false positives (non-existent files/functions)
- Finding A: Correctly identified that `getUser()` is Supabase's recommended pattern — the performance concern was technically accurate but the recommendation was wrong
- Used Grep extensively to check file/function existence
- Read actual files to confirm or deny claims
- Produced a clear summary table of failure modes

### Gaps:
1. **No docs-researcher for Supabase behavior.** Agent asserted Supabase's `getUser()` vs `getSession()` behavior from training data: "From my knowledge: this is correct." Happens to be right, but the same approach would fail for less common library behaviors. Should have verified via docs-researcher.
2. **No verified-analysis invocation.** Agent performed ad-hoc verification — good instincts but no formal framework.
3. **No code-explorer for logic tracing.** If the files had existed, the agent would have needed to trace execution paths. Defaulted to "I'll read the code."
4. **No structured classification output.** Narrative format, no `[file:line] VALID/UNCERTAIN/FALSE POSITIVE` structure with evidence citations.
5. **No severity classification for valid findings.** Since all were false positives, this wasn't tested — but there was no framework for how it would classify if findings were valid.

### Key quote (gap evidence):
> "From my knowledge: this is correct -- `getUser()` calls the Supabase Auth server to verify the JWT"

Training data as evidence. Would fail for version-specific behaviors.

## Scenario 2: Approval Flow and Severity Classification

### What the agent did well:
- Classified severities correctly: Finding 1 = blocking (security), Finding 2 = suggestion (UX), Finding 3 = nit (comment)
- Handled UNCERTAIN Finding 4 correctly — reported to user, not posted
- Used GitHub suggestion block for the simple nit fix
- Required user approval before posting
- Noted the relationship between Finding 3's misleading comment and Finding 1's security issue
- Determined correct review action (REQUEST_CHANGES due to blocking finding)
- Included severity labels in inline comments

### Gaps:
1. **All-at-once approval, not per-finding.** Agent presented everything and asked "Would you like me to post?" with "you can also ask me to adjust." The design calls for per-finding approve/edit/skip/change-severity grouped by severity, with blocking first.
2. **No verified-analysis invocation.** Findings were pre-verified in the scenario, but agent didn't reference the verification framework.
3. **No structured classification output.** Good narrative but no formal format.

### Key quote (strength):
> "UNCERTAIN findings stay out of the PR review. They're reported to the user for awareness only."

Correct instinct — agents naturally understand that uncertain findings shouldn't become public review comments.

### Key quote (gap):
> "Would you like me to post this review? You can also ask me to adjust severity, drop any finding, or add the uncertain one."

This is reactive — user has to ask to adjust. The skill should proactively present per-finding controls.

## Scenario 3: Existing Review State

### What the agent did well:
- Checked existing review state FIRST, before launching any review
- Scoped re-review to new commits only (didn't re-review entire PR)
- Prioritized verifying the blocking fix
- Did NOT re-post old comments (2 and 3)
- Distinguished between "replied to" threads and "ignored" ones
- Planned to verify the author's fix against actual code, not just trust the commit message
- Required user approval before posting

### Gaps:
1. **No verified-analysis or specialized tools.** Plans to "read the full file" and "trace the data flow" manually — no code-explorer for tracing the RLS path.
2. **No docs-researcher for verifying Supabase client behavior.** Would need to confirm that `createServerClient` actually uses the user's JWT (not service role) for RLS enforcement.
3. **No formal verification framework.** Good instincts, ad-hoc execution.

### Key quote (strength):
> "Just changing the function name isn't enough if the underlying implementation still uses the service key."

Excellent skepticism — the agent understood that a rename could be cosmetic.

## What the Skill Must Address

### Critical (agent fails without it):
1. **Require verified-analysis invocation.** Agents never mention it. They verify ad-hoc with good instincts but inconsistent tooling. The skill must require invoking verified-analysis before classifying any finding.
2. **Require docs-researcher for library/framework claims.** All 3 scenarios had agents reasoning about Supabase behavior from training data. They were right this time — they won't always be.
3. **Per-finding approval flow.** Agents default to all-at-once. The skill must enforce grouped-by-severity, per-finding approve/edit/skip/change-severity.

### Important (agent does it poorly without it):
4. **Structured classification output.** Agents produce narrative. The skill should define format for both internal classification and user-facing presentation.

### Already handled well (agent does it naturally):
- Verifying findings against actual code (Read/Grep) before posting
- Catching false positives through file/function existence checks
- Classifying severities correctly (blocking/suggestion/nit)
- Handling UNCERTAIN findings properly (report to user, don't post)
- Checking existing review state before re-reviewing
- Scoping re-reviews to new changes
- Not re-posting old comments
- Using GitHub suggestion blocks for simple fixes
- Requiring user approval before posting
- Determining correct review action (REQUEST_CHANGES vs COMMENT)
- Resisting posting fabricated findings
