#!/bin/bash
# PreToolUse hook for Edit/Write tools
# Blocks modifications to project files when on main/master branch
# Reading is fine — only writing causes session conflicts

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

# For ~/.claude/ files: block only committed source paths.
# Everything else (todos, plugins, shell-snapshots, projects, etc.) is transient/runtime.
if [[ "$file_path" == "$HOME/.claude/"* ]]; then
    case "$file_path" in
        */hooks/*|*/skills/*|*/agents/*|*/tests/*)
            ;; # fall through to branch check
        */CLAUDE.md|*/settings.json|*/statusline-command.sh)
            ;; # fall through to branch check
        *)
            exit 0
            ;;
    esac
fi

# Resolve the directory containing the file being edited.
# Walk up from the file's parent until we find an existing directory.
# This ensures we check the branch of the FILE's repo, not CWD's repo.
file_dir=$(dirname "$file_path")
while [[ ! -d "$file_dir" && "$file_dir" != "/" ]]; do
    file_dir=$(dirname "$file_dir")
done

# Check if the file's directory is in a git repo
if ! git -C "$file_dir" rev-parse --is-inside-work-tree &>/dev/null; then
    exit 0
fi

# Check the branch of the repo that contains the file
current_branch=$(git -C "$file_dir" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")

if [[ "$current_branch" != "main" && "$current_branch" != "master" ]]; then
    exit 0
fi

# On main — block everything
cat << 'EOF'
{"decision": "block", "reason": "STOP: You are editing a file on the main branch.\n\nNothing gets committed directly to main. Create a worktree first:\n\n1. Invoke `superpowers:using-git-worktrees` to create an isolated workspace\n2. Make your changes there\n3. Merge via PR when done"}
EOF
exit 0
