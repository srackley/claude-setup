#!/bin/bash
# Extracts a compact compliance timeline from a Claude Code transcript JSONL.
#
# Usage: extract-timeline.sh <transcript_path>
# Output: Structured timeline to stdout, one event per line.
#
# Events extracted:
#   [LINE N] SKILL: <skill-name>
#   [LINE N] AGENT: <subagent_type>
#   [LINE N] WRITE: <file_path>
#   [LINE N] EDIT: <file_path>
#   [LINE N] TEST: <command> (PASS|FAIL)
#   [LINE N] USER: <first 200 chars>
#   [LINE N] RESEARCH: <tool/agent>
#
# Supports two transcript formats:
#   1. Real Claude Code transcripts: tool_use nested in .message.content[]
#      {"type":"assistant","message":{"content":[{"type":"tool_use","name":"Skill","input":{...}}]}}
#   2. Test fixtures: tool_use at top level
#      {"type":"tool_use","name":"Skill","input":{...}}
#
# Designed for the compliance reviewer v2 pre-filter. The output is small enough
# (50-100 lines typically) for an LLM agent to reason about, unlike the raw
# transcript (often 1MB+).

set -euo pipefail

transcript_path="${1:-}"

if [[ -z "$transcript_path" || ! -f "$transcript_path" ]]; then
    echo "extract-timeline: transcript file not found: ${transcript_path:-<empty>}" >&2
    exit 1
fi

if ! command -v jq &>/dev/null; then
    echo "extract-timeline: jq not found" >&2
    exit 1
fi

# jq filter that extracts tool_use events from both formats.
# For real transcripts: each JSONL line may contain multiple tool_use entries in .message.content[].
# For test fixtures: tool_use fields are at the top level.
# Output: one JSON object per tool_use with {name, input} fields, plus user messages.
#
# We process each line with jq to extract all tool_use entries, then handle them in bash.

line_num=0
while IFS= read -r line || [[ -n "$line" ]]; do
    line_num=$((line_num + 1))
    [[ -z "$line" ]] && continue

    # Try to parse as JSON; skip malformed lines
    type_field=$(echo "$line" | jq -r '.type // empty' 2>/dev/null) || continue

    # --- Real format: assistant messages with tool_use in .message.content[] ---
    if [[ "$type_field" == "assistant" ]]; then
        # Extract all tool_use entries from message.content[]
        tool_uses=$(echo "$line" | jq -c '.message.content[]? | select(.type == "tool_use") | {name, input}' 2>/dev/null) || continue
        while IFS= read -r tu; do
            [[ -z "$tu" ]] && continue
            name=$(echo "$tu" | jq -r '.name // empty' 2>/dev/null)
            [[ -z "$name" ]] && continue

            case "$name" in
                Skill)
                    skill=$(echo "$tu" | jq -r '.input.skill // empty' 2>/dev/null)
                    [[ -n "$skill" ]] && echo "[LINE $line_num] SKILL: $skill"
                    ;;
                Agent)
                    agent_type=$(echo "$tu" | jq -r '.input.subagent_type // empty' 2>/dev/null)
                    if [[ -n "$agent_type" ]]; then
                        [[ "$agent_type" == "docs-researcher" ]] && echo "[LINE $line_num] RESEARCH: docs-researcher"
                        echo "[LINE $line_num] AGENT: $agent_type"
                    fi
                    ;;
                Write)
                    file_path=$(echo "$tu" | jq -r '.input.file_path // empty' 2>/dev/null)
                    [[ -n "$file_path" ]] && echo "[LINE $line_num] WRITE: $file_path"
                    ;;
                Edit)
                    file_path=$(echo "$tu" | jq -r '.input.file_path // empty' 2>/dev/null)
                    [[ -n "$file_path" ]] && echo "[LINE $line_num] EDIT: $file_path"
                    ;;
                Bash)
                    command=$(echo "$tu" | jq -r '.input.command // empty' 2>/dev/null)
                    if echo "$command" | grep -qE '(^|\s|/)(task\s+test|npm\s+(run\s+)?test|pnpm\s+(run\s+)?test|yarn\s+test|vitest|npx\s+(jest|vitest)|jest|pytest|bats)(\s|$|\||;|&|>)'; then
                        echo "[LINE $line_num] TEST: ${command:0:100} (UNKNOWN)"
                    fi
                    ;;
                WebFetch|WebSearch)
                    echo "[LINE $line_num] RESEARCH: $name"
                    ;;
            esac
        done <<< "$tool_uses"
        continue
    fi

    # --- User messages (both formats) ---
    if [[ "$type_field" == "user" ]]; then
        # Real format: userType:"external", content in .message.content (string)
        user_type=$(echo "$line" | jq -r '.userType // empty' 2>/dev/null)
        if [[ "$user_type" == "external" ]]; then
            content=$(echo "$line" | jq -r '.message.content // empty' 2>/dev/null)
            if [[ -n "$content" && "$content" != "null" ]]; then
                echo "[LINE $line_num] USER: ${content:0:200}"
            fi
            continue
        fi
        # Fixture format: isMeta:false, content at top level
        is_meta=$(echo "$line" | jq -r 'if .isMeta == false then "false" else "true" end' 2>/dev/null)
        if [[ "$is_meta" == "false" ]]; then
            content=$(echo "$line" | jq -r '.content // empty' 2>/dev/null)
            if [[ -n "$content" ]]; then
                echo "[LINE $line_num] USER: ${content:0:200}"
            fi
        fi
        continue
    fi

    # --- Test fixture format: tool_use at top level ---
    if [[ "$type_field" == "tool_use" ]]; then
        name=$(echo "$line" | jq -r '.name // empty' 2>/dev/null)
        [[ -z "$name" ]] && continue

        case "$name" in
            Skill)
                skill=$(echo "$line" | jq -r '.input.skill // empty' 2>/dev/null)
                [[ -n "$skill" ]] && echo "[LINE $line_num] SKILL: $skill"
                ;;
            Agent)
                agent_type=$(echo "$line" | jq -r '.input.subagent_type // empty' 2>/dev/null)
                if [[ -n "$agent_type" ]]; then
                    [[ "$agent_type" == "docs-researcher" ]] && echo "[LINE $line_num] RESEARCH: docs-researcher"
                    echo "[LINE $line_num] AGENT: $agent_type"
                fi
                ;;
            Write)
                file_path=$(echo "$line" | jq -r '.input.file_path // empty' 2>/dev/null)
                [[ -n "$file_path" ]] && echo "[LINE $line_num] WRITE: $file_path"
                ;;
            Edit)
                file_path=$(echo "$line" | jq -r '.input.file_path // empty' 2>/dev/null)
                [[ -n "$file_path" ]] && echo "[LINE $line_num] EDIT: $file_path"
                ;;
            Bash)
                command=$(echo "$line" | jq -r '.input.command // empty' 2>/dev/null)
                if echo "$command" | grep -qE '(^|\s|/)(task\s+test|npm\s+(run\s+)?test|pnpm\s+(run\s+)?test|yarn\s+test|vitest|npx\s+(jest|vitest)|jest|pytest|bats)(\s|$|\||;|&|>)'; then
                    exit_code=$(echo "$line" | jq -r '.exit_code // empty' 2>/dev/null)
                    if [[ "$exit_code" == "0" ]]; then
                        result="PASS"
                    elif [[ -n "$exit_code" ]]; then
                        result="FAIL"
                    else
                        result="UNKNOWN"
                    fi
                    echo "[LINE $line_num] TEST: ${command:0:100} ($result)"
                fi
                ;;
            WebFetch|WebSearch)
                echo "[LINE $line_num] RESEARCH: $name"
                ;;
        esac
        continue
    fi

done < "$transcript_path"
