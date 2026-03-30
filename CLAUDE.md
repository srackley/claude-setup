# Global Preferences

## Intellectual Honesty
- **No performative confidence.** Don't express high certainty unless you have evidence. "I believe X because I checked Y" is better than "X is definitely the case."
- **No performative capitulation.** Don't fold on pushback without new information. If you had reasons, defend them. Caving on zero new evidence means your original confidence was fake.
- **Distinguish "I was wrong" from "I'm agreeing to end the argument."** If you change your position, explain what new information changed your mind. If you can't point to anything, you're probably just capitulating.

## Debugging
When debugging, if your first two approaches fail, STOP. Explain what you tried, why each failed, and what constraint might be wrong. Wait for input before continuing.

## Verification
- **Verify claims with evidence.** Grep the codebase, read the full function, check docs. Never accept subagent output at face value. Before presenting any actionable recommendation from an agent, independently verify the key behavioral claim. State what you verified and how.
- **Surface structural problems, don't silently work around them.** If you notice a real design issue while working around it (hardcoded path, test gap, fragile assumption), flag it as a suggested task before continuing.
- **Fix everything you find.** Never use "pre-existing" or "not my PR" to skip. All code in the branch is your responsibility.

## Workflow Rules
- **Minimal mocking**: Real instances, DI, test behavior not implementation.
- **Proceed autonomously**: Complete multi-step processes without asking at each step.
- **Fix lint warnings** in files you touch. **Never disable lint rules without asking** — fix the underlying code.
- **PR reviews require user sign-off.** Never post reviews or approvals without showing the user first.
- **PR descriptions from branch diff,** not memory. Follow templates honestly.

## Skills
Always invoke skills using the Skill tool. Reading a skill file is not a substitute. Never rationalize skipping a skill because you recall its contents.

These skills are NOT enforced by hooks — invoke manually:

| Trigger | Skill |
|---------|-------|
| Before ANY PR creation | `creating-pr` |
| Before ANY design/creative work | `superpowers:brainstorming` |
| Before reviewing someone else's PR | `reviewing-prs` |
| Before claiming work is done | `superpowers:verification-before-completion` |

Hook-enforced skills (TDD, creating-component, storybook-stories, writing-skills, writing-plans, finishing-work, no-edit-on-main, reviewing-code) are omitted — hooks block if skipped.

## Tools & Conventions

**Git:** Never use `cd <path> && git <cmd>`. Use `git -C <path> <cmd>` instead.

**Bash:** Never run unbounded-output commands in foreground (`gh run watch`, `tail -f`). Background them and tail the log.

**Docs research:** Use `docs-researcher` agent for third-party library questions — don't trust training data. Before dispatching, grep `~/.claude/research/` for the topic first.

## Reference

**Session continuity files:**
- `~/.claude/projects/<project>/memory/handoffs/<name>.md` — transient cross-session handoff docs. Overwrite each session, delete once actioned.
- `~/.claude/session-notes/` — permanent historical record. Never delete.

**Worktrees:** Pull latest (`git pull`) before working in any existing worktree. Create inside `.worktrees/`, never at parent level.
