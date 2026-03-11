#!/bin/bash
# UserPromptSubmit hook — minimal skill reminder for non-hook-enforced skills.
# Uses negative framing ("Why NOT?") which is more effective than positive ("Do X").
# Hook-enforced skills omitted — hooks block if skipped.

set -euo pipefail

if ! command -v jq &>/dev/null; then
    exit 0
fi

input=$(cat)
prompt=$(echo "$input" | jq -r '.prompt // empty' 2>/dev/null)
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

if ! echo "$prompt_lower" | grep -qE '\b(implement|fix|add|create|build|write|commit|refactor|deploy|update|change|move|remove|delete|rename|extract|convert|migrate|install|configure|setup|set up)\b'; then
    exit 0
fi

cat << 'EOF'
<system-reminder>
Before acting, answer silently:
- Committing? → Why does finishing-work NOT apply?
- Creating PR? → Why does creating-pr NOT apply?
- Creative/design work? → Why does brainstorming NOT apply?
- Reviewing someone's PR? → Why does reviewing-prs NOT apply?
- Code ready for commit? → Why does reviewing-code NOT apply?
- Claiming done? → Why does verification-before-completion NOT apply?
- Starting implementation on a plan? → Why does executing-plans NOT apply?
Can't answer → invoke the skill.
</system-reminder>
EOF
exit 0
