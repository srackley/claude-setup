#!/bin/bash
# PreToolUse hook for Read/Edit/Write tools
# Warns when accessing sensitive files that shouldn't be committed

set -euo pipefail

input=$(cat)

tool_name=$(echo "$input" | jq -r '.tool_name // empty' 2>/dev/null)
file_path=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)

# Only handle file access tools
if [[ "$tool_name" != "Read" && "$tool_name" != "Edit" && "$tool_name" != "Write" ]]; then
    exit 0
fi

# Determine action verb for message
case "$tool_name" in
    Read) action="Reading" ;;
    Edit) action="Editing" ;;
    Write) action="Writing to" ;;
esac

# Skip if no file path
if [[ -z "$file_path" ]]; then
    exit 0
fi

# Get just the filename
filename=$(basename "$file_path")

# Check for sensitive file patterns
is_sensitive=false
warning_type=""

case "$filename" in
    .env|.env.local|.env.development|.env.production|.env.*)
        is_sensitive=true
        warning_type="environment variables"
        ;;
    credentials.json|credentials.yaml|credentials.yml)
        is_sensitive=true
        warning_type="credentials"
        ;;
    secrets.json|secrets.yaml|secrets.yml|*secret*)
        is_sensitive=true
        warning_type="secrets"
        ;;
    *.pem|*.key|*.p12|*.pfx)
        is_sensitive=true
        warning_type="private keys"
        ;;
    id_rsa|id_ed25519|id_ecdsa)
        is_sensitive=true
        warning_type="SSH private keys"
        ;;
    .npmrc|.pypirc)
        is_sensitive=true
        warning_type="package registry tokens"
        ;;
esac

# Also check path components
if [[ "$file_path" == *"/secrets/"* ]] || [[ "$file_path" == *"/credentials/"* ]]; then
    is_sensitive=true
    warning_type="sensitive directory"
fi

if [[ "$is_sensitive" == "true" ]]; then
    echo "🔐 $action $warning_type file: $filename"
    echo "   Remember: Do NOT commit sensitive files or include their contents in code."
fi
