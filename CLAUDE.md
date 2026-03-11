# Global Preferences

## Worktrees
Pull latest (`git pull`) before working in any existing worktree.
Create worktrees inside the project's `.worktrees/` directory, never at parent level.

## Debugging
When debugging, if your first two approaches fail, STOP. Explain what you tried, why each failed, and what constraint might be wrong. Wait for input before continuing.

## Skill Invocation
Always invoke skills using the Skill tool. Reading a skill file is not a substitute. Never rationalize skipping a skill because you recall its contents.

## Non-Hook-Enforced Skills
These are NOT enforced by hooks — invoke manually before the corresponding action:

| Trigger | Skill |
|---------|-------|
| Before ANY PR creation | `creating-pr` |
| Before ANY design/creative work | `superpowers:brainstorming` |
| Before reviewing someone else's PR | `reviewing-prs` |
| Before claiming work is done | `superpowers:verification-before-completion` |

Hook-enforced skills (TDD, creating-component, storybook-stories, writing-skills, writing-plans, finishing-work, no-edit-on-main, reviewing-code) are omitted — hooks block if skipped. `reviewing-code` is enforced at PR creation by pr-gate.sh, not per-commit.

## Documentation Research
Use `docs-researcher` agent for third-party library questions — don't trust training data.

## Bash Safety
Never run unbounded-output commands in foreground (`gh run watch`, `tail -f`). Background them and tail the log.

## Workflow Preferences
- **Minimal mocking**: Real instances, DI, test behavior not implementation.
- **Proceed autonomously**: Complete multi-step processes without asking at each step.
- **Fix lint warnings**: In files you touch.

## Key Rules
- **Verify claims with evidence.** Grep the codebase, read the full function, check docs. Never accept subagent output at face value.
- **Fix everything you find.** Never use "pre-existing" or "not my PR" to skip. All code in the branch is your responsibility.
- **Never disable lint rules without asking.** Fix the underlying code.
- **PR reviews require user sign-off.** Never post reviews or approvals without showing the user first.
- **PR descriptions from branch diff,** not memory. Follow templates honestly.
