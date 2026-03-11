#!/bin/bash
# Shared functions for project-scoped session notes
# Used by session-start.sh and pre-compact.sh

get_project_name() {
    # Try git remote first (stable across directory renames and worktrees)
    local remote_url
    remote_url=$(git remote get-url origin 2>/dev/null || echo "")
    if [[ -n "$remote_url" ]]; then
        # Extract repo name from URL (handles both HTTPS and SSH)
        # git@github.com:wanderu/canopy.git → canopy
        # https://github.com/wanderu/canopy.git → canopy
        basename "$remote_url" .git
        return
    fi
    # Fallback: directory name of git root (or cwd if not in a repo)
    basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
}

get_unpromoted_corrections() {
    return
}

get_recent_session_notes() {
    local project_name
    project_name=$(get_project_name)
    local session_notes_dir="$HOME/.claude/session-notes/$project_name"

    if [[ ! -d "$session_notes_dir" ]]; then
        return
    fi

    # Find the most recently modified .md file in the project subdir
    local latest_file
    latest_file=$(find "$session_notes_dir" -maxdepth 1 -name "*.md" -exec stat -f '%m %N' {} \; 2>/dev/null \
        | sort -rn | head -1 | cut -d' ' -f2-)

    if [[ -z "$latest_file" || ! -f "$latest_file" ]]; then
        return
    fi

    # Get the last 2 session entries (each starts with ## followed by date)
    awk '
        /^## \[?[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            if (section != "") sections[++count] = section
            section = $0 "\n"
            next
        }
        section != "" { section = section $0 "\n" }
        END {
            if (section != "") sections[++count] = section
            start = count > 2 ? count - 1 : 1
            for (i = start; i <= count; i++) {
                printf "%s", sections[i]
            }
        }
    ' "$latest_file" 2>/dev/null || true
}
