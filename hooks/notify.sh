#!/bin/bash
# notify.sh — macOS desktop notification via osascript (no dependencies)
# Usage: called by Claude Code hooks; args passed in command string
# $1 = message (default: "Done"), $2 = sound name (default: "Glass")
# Note: hooks use async:true so this doesn't need backgrounding
osascript -e "display notification \"${1:-Done}\" with title \"Claude Code\" sound name \"${2:-Glass}\""
