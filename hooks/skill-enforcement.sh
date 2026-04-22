#!/bin/bash
# PreToolUse hook for Edit/Write tools
# Enforces skill invocation based on file patterns.
#
# Rules 1, 2, 3, 5 are transcript-aware: they grep the session transcript
# for the required skill invocation. If found, the edit is allowed. If not
# found (or transcript unavailable), the edit is blocked.
#
# Rule 4 (test files → TDD) remains a stateless warn — it prompts TDD
# skill entry; the TDD state machine enforces the process once entered.
#
# Fail-closed: missing or unreadable transcript → block (require skill).

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only handle Edit and Write tools
if [[ "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
    exit 0
fi

# Skip if no file path
if [[ -z "$file_path" ]]; then
    exit 0
fi

# Get filename for pattern matching
filename=$(basename "$file_path")

# Read transcript_path and session_id from input (used by transcript-aware rules)
transcript_path=$(echo "$input" | jq -r '.transcript_path // empty' 2>/dev/null)
session_id=$(echo "$input" | jq -r '.session_id // empty' 2>/dev/null)

# Fallback: transcript_path is missing or stale when the session CWD changes
# (e.g., after EnterWorktree). Search by session_id across all project dirs.
if [[ (-z "$transcript_path" || ! -f "$transcript_path") && -n "$session_id" ]]; then
    transcript_path=$(find "$HOME/.claude/projects" -name "${session_id}.jsonl" -maxdepth 2 2>/dev/null | head -1)
fi

# Check whether a skill was invoked in the current session transcript.
# Returns 0 (true) if found, 1 (false) if not found or transcript unavailable.
# Fail-closed: missing/unreadable transcript → skill not verified → returns 1.
#
# IMPORTANT: Matches the actual Skill tool_use JSON pattern ("skill":"...<name>...")
# not just any mention of the skill name. This prevents false positives from
# block messages, Claude's own text, or hook output that references the skill name.
skill_invoked() {
    local skill_name="$1"
    local transcript="$2"
    [[ -n "$transcript" && -f "$transcript" ]] && \
        grep -qE "\"skill\"[[:space:]]*:[[:space:]]*\"[^\"]*${skill_name}[^\"]*\"" "$transcript" 2>/dev/null
}

# ============================================================================
# SKILL ENFORCEMENT RULES
# Add new rules here. Each rule checks a pattern and outputs a block/warn JSON.
# ============================================================================

# Rule 1: Skill files → writing-skills (transcript-aware)
# Applies to: .claude/skills/**/*.md and ~/.claude/skills/**/*.md
# Allows if writing-skills was already invoked in this session.
if [[ "$file_path" == *"/.claude/skills/"*".md" ]] || \
   [[ "$file_path" == "$HOME/.claude/skills/"*".md" ]]; then
    if skill_invoked "writing-skills" "$transcript_path"; then
        exit 0
    fi
    cat << 'EOF'
{"decision": "block", "reason": "STOP: You are editing a skill file.\n\n**MANDATORY:** Invoke the `writing-skills` skill first.\n\nThe skill ensures TDD for documentation: baseline test, write, close loopholes.\n\nIf you already invoked it, the transcript check failed — invoke it again."}
EOF
    exit 0
fi

# Rule 2: Story files → storybook-stories (transcript-aware)
# Applies to: *.stories.tsx, *.stories.ts
# Allows if storybook-stories was already invoked in this session.
if [[ "$filename" == *.stories.tsx ]] || [[ "$filename" == *.stories.ts ]]; then
    if skill_invoked "storybook-stories" "$transcript_path"; then
        exit 0
    fi
    cat << 'EOF'
{"decision": "block", "reason": "STOP: You are editing a Storybook story file.\n\n**MANDATORY:** Invoke the `storybook-stories` skill first.\n\nKey requirements:\n- Every story MUST have a play function with assertions\n- No exceptions for 'minimal' or 'quick' stories\n- Include CustomClassName story for className prop verification\n\nRead the skill before proceeding."}
EOF
    exit 0
fi

# Rule 3: New component files → creating-component (Write only, transcript-aware)
# Applies to: */components/**/*.tsx, */wanderu-components/**/*.tsx, */wanderu-component-*/**/*.tsx
# (excluding stories, tests, specs)
# Allows if creating-component was already invoked in this session.
if [[ "$tool_name" == "Write" ]] && \
   [[ "$filename" != *.stories.tsx ]] && \
   [[ "$filename" != *.test.tsx ]] && \
   [[ "$filename" != *.spec.tsx ]] && \
   [[ "$filename" == *.tsx ]] && \
   ( [[ "$file_path" == */components/ui/* ]] || \
     [[ "$file_path" == */components/* ]] || \
     [[ "$file_path" == */wanderu-components/* ]] || \
     [[ "$file_path" == */wanderu-component-* ]] ); then
    if skill_invoked "creating-component" "$transcript_path"; then
        exit 0
    fi
    cat << 'EOF'
{"decision": "block", "reason": "STOP: You are creating a new UI component file.\n\n**MANDATORY:** Invoke the `creating-component` skill first.\n\nThe skill ensures you:\n1. Read conventions FIRST (project docs, existing examples)\n2. Read existing examples of similar component types\n3. Follow the correct file structure and patterns\n\nDon't guess at patterns - read the docs."}
EOF
    exit 0
fi

# Rule 4: Test files → test-driven-development warning
# Applies to: *.test.tsx, *.test.ts, *.test.jsx, *.test.js, *.spec.tsx, *.spec.ts, *.spec.jsx, *.spec.js
if [[ "$filename" == *.test.tsx ]] || [[ "$filename" == *.test.ts ]] || \
   [[ "$filename" == *.test.jsx ]] || [[ "$filename" == *.test.js ]] || \
   [[ "$filename" == *.spec.tsx ]] || [[ "$filename" == *.spec.ts ]] || \
   [[ "$filename" == *.spec.jsx ]] || [[ "$filename" == *.spec.js ]]; then
    cat << 'EOF'
{"decision": "warn", "reason": "You are editing a test file. Have you invoked the `test-driven-development` skill? TDD requires: RED (failing test) → GREEN (minimal implementation) → REFACTOR. If you're writing implementation code without a failing test first, stop and invoke the skill."}
EOF
    exit 0
fi

# Rule 5: Plan docs → writing-plans (transcript-aware)
# Applies to: **/docs/plans/**/*.md
# Allows if writing-plans was already invoked in this session.
if [[ "$file_path" == */docs/plans/*.md ]]; then
    if skill_invoked "writing-plans" "$transcript_path"; then
        exit 0
    fi
    cat << 'EOF'
{"decision": "block", "reason": "STOP: You are editing a plan document.\n\n**MANDATORY:** Invoke the `writing-plans` skill first.\n\nPlans must be comprehensive with bite-sized tasks, exact file paths, and TDD steps.\n\nIf you already invoked it, the transcript check failed — invoke it again."}
EOF
    exit 0
fi

# No rules matched - allow the operation
exit 0
