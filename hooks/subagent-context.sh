#!/bin/bash
# PreToolUse hook for Task tool
# Injects wayfinder context guidance into subagent prompts based on keywords
# Self-detecting: exits silently if wayfinder MCP is not configured

set -euo pipefail

# Check if wayfinder MCP is configured for this project
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$(pwd)}"
has_wayfinder=false
if [[ -f "$PROJECT_DIR/.claude/mcp.json" ]]; then
    if grep -q "wayfinder" "$PROJECT_DIR/.claude/mcp.json" 2>/dev/null; then
        has_wayfinder=true
    fi
fi

# Exit silently if wayfinder is not available
if [[ "$has_wayfinder" != "true" ]]; then
    exit 0
fi

# Read input from stdin
input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
prompt=$(echo "$input" | jq -r '.tool_input.prompt // empty' 2>/dev/null)

# Only handle Task tool
if [[ "$tool_name" != "Task" ]]; then
    exit 0
fi

# Skip if no prompt
if [[ -z "$prompt" ]]; then
    exit 0
fi

# Convert to lowercase for matching
prompt_lower=$(echo "$prompt" | tr '[:upper:]' '[:lower:]')

# Build context suggestions based on keywords
suggestions=""

if [[ "$prompt_lower" =~ (auth|login|logout|jwt|token|session|cookie) ]]; then
    suggestions="${suggestions}\n- Auth patterns: mcp__wayfinder__get_document with path 'domains/auth/overview'"
fi

if [[ "$prompt_lower" =~ (test|spec|tdd|coverage|vitest|playwright) ]]; then
    suggestions="${suggestions}\n- Testing patterns: mcp__wayfinder__get_document with path 'domains/testing/overview'"
fi

if [[ "$prompt_lower" =~ (deploy|infrastructure|helm|k8s|kubernetes|docker) ]]; then
    suggestions="${suggestions}\n- TechOps patterns: mcp__wayfinder__get_document with path 'domains/techops/overview'"
fi

if [[ "$prompt_lower" =~ (search|result|carrier|sort|filter) ]]; then
    suggestions="${suggestions}\n- Search patterns: mcp__wayfinder__get_document with path 'domains/search/overview'"
fi

if [[ "$prompt_lower" =~ (ticket|booking|tix|lookup|reservation) ]]; then
    suggestions="${suggestions}\n- Tix service: mcp__wayfinder__get_document with path 'services/tix/overview'"
fi

# If we found relevant context, output a reminder (not a denial)
if [[ -n "$suggestions" ]]; then
    echo "💡 Relevant wayfinder context for this task:${suggestions}"
fi
