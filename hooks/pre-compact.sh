#!/bin/bash
# pre-compact.sh — writes session notes directly from transcript JSONL
# No instructional output. No Claude involvement. Always exits 0.

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/lib/session-notes.sh"

# Always exit 0 — a broken hook that blocks is worse than a silent failure
trap 'exit 0' EXIT

# --- Parse hook input ---
input=$(cat)
transcript_path=$(echo "$input"      | jq -r '.transcript_path // empty'    2>/dev/null || true)
session_id=$(echo "$input"           | jq -r '.session_id // empty'         2>/dev/null || true)
custom_instructions=$(echo "$input"  | jq -r '.custom_instructions // empty' 2>/dev/null || true)

today=$(date '+%Y-%m-%d')
now=$(date '+%Y-%m-%d %H:%M')
short_id="${session_id:0:8}"
[[ -z "$short_id" ]] && short_id="unknown"

project=$(get_project_name 2>/dev/null || echo "unknown")
session_notes_dir="$HOME/.claude/session-notes/$project"
mkdir -p "$session_notes_dir" 2>/dev/null || { echo "Cannot create $session_notes_dir" >&2; exit 0; }

# Filename: topic-based if /compact <topic> was given, session-id-based otherwise
if [[ -n "$custom_instructions" ]]; then
    topic_slug="$(echo "$custom_instructions" | tr '[:upper:]' '[:lower:]' | tr -cs 'a-z0-9' '-' | sed 's/-*$//' | cut -c1-40)"
    notes_file="$session_notes_dir/${today}-${project}-${topic_slug}.md"
else
    notes_file="$session_notes_dir/${today}-${project}-${short_id}.md"
fi

# --- Fallback: no transcript ---
if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    {
        echo ""
        echo "## [$now] Session: $short_id [AUTO-GENERATED]"
        echo ""
        echo "*(No transcript available at compaction time — fallback note)*"
        echo ""
    } >> "$notes_file"
    exit 0
fi

# --- Find last compact_boundary, process only lines after it ---
last_boundary_line=$(grep -n '"compact_boundary"' "$transcript_path" 2>/dev/null \
    | tail -1 | cut -d: -f1 || true)

if [[ -n "$last_boundary_line" ]]; then
    relevant=$(tail -n +"$((last_boundary_line + 1))" "$transcript_path" 2>/dev/null || true)
else
    relevant=$(cat "$transcript_path" 2>/dev/null || true)
fi

# --- Extract: recent user messages (string content only, skip tool results) ---
recent_user_msgs=$(echo "$relevant" | jq -r '
    select(.type == "user" and (.message.content | type) == "string") |
    .message.content
' 2>/dev/null | tail -5 \
  | awk '{lines[NR]=$0} END {for(i=NR;i>=1;i--) print lines[i]}' \
  || true)

# --- Extract: files modified via Edit or Write, deduplicated with counts ---
files_modified=$(echo "$relevant" | jq -r '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use" and (.name == "Edit" or .name == "Write")) |
    .name + "|" + .input.file_path
' 2>/dev/null | awk -F'|' '
    $2 != "" {
        if (!($2 in counts)) {
            order[++n] = $2
            tools[$2]  = $1
        }
        counts[$2]++
    }
    END {
        for (i = 1; i <= n; i++) {
            k = order[i]
            if (counts[k] > 1)
                printf "- %s (%s ×%d)\n", k, tools[k], counts[k]
            else
                printf "- %s (%s)\n", k, tools[k]
        }
    }
' 2>/dev/null || true)

# --- Extract: last 10 bash commands ---
all_bash=$(echo "$relevant" | jq -r '
    select(.type == "assistant") |
    .message.content[]? |
    select(.type == "tool_use" and .name == "Bash") |
    .input.command
' 2>/dev/null | tail -10 || true)

last_command=$(echo "$all_bash" | tail -1)

# --- Extract: tool_result errors ---
errors=$(echo "$relevant" | jq -r '
    select(.type == "user") |
    .message.content[]? |
    select(type == "object" and .type == "tool_result" and .is_error == true) |
    .content // ""
' 2>/dev/null | head -c 600 || true)

# --- Write note (append if file exists) ---
{
    echo ""
    echo "## [$now] Session: $short_id [AUTO-GENERATED]"
    echo ""

    echo "### Current Task"
    echo "Inferred from recent user messages:"
    if [[ -n "$recent_user_msgs" ]]; then
        while IFS= read -r msg; do
            [[ -z "$msg" ]] && continue
            short_msg="${msg:0:200}"
            [[ "${#msg}" -gt 200 ]] && short_msg="${short_msg}…"
            echo "- \"$short_msg\""
        done <<< "$recent_user_msgs"
    else
        echo "- (no user messages in this compaction window)"
    fi
    echo ""

    echo "### In-Progress State"
    if [[ -n "$last_command" ]]; then
        echo "Last command: $last_command"
    else
        echo "Last command: (none)"
    fi
    echo ""
    echo "Recent errors: ${errors:-(none)}"
    echo ""

    echo "### Files Modified"
    if [[ -n "$files_modified" ]]; then
        echo "$files_modified"
    else
        echo "- (none detected)"
    fi
    echo ""

    echo "### Corrections Given"
    echo "[Cannot be reliably inferred from transcript — review and fill in manually]"
    echo ""

    echo "### Next Steps"
    echo "[Cannot be reliably inferred — fill in manually after compaction]"
    echo ""
} >> "$notes_file"
