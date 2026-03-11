#!/usr/bin/env python3
"""PreToolUse hook that enforces Bash/Edit/Write permissions from settings.json.

Works around https://github.com/anthropics/claude-code/issues/18846
"""
import fnmatch
import json
import os
import sys
from pathlib import Path


def load_settings_permissions(settings_path: Path) -> tuple[list[str], list[str]]:
    """Load allow/deny patterns from a settings file."""
    allow = []
    deny = []
    if settings_path.exists():
        try:
            with open(settings_path, "r") as f:
                settings = json.load(f)
                permissions = settings.get("permissions", {})
                allow = permissions.get("allow", [])
                deny = permissions.get("deny", [])
        except (json.JSONDecodeError, IOError):
            pass
    return allow, deny


def load_all_permissions() -> tuple[list[str], list[str]]:
    """Load permissions from global and project-level settings."""
    all_allow = []
    all_deny = []

    # Global settings
    for name in ["settings.json", "settings.local.json"]:
        path = Path.home() / ".claude" / name
        allow, deny = load_settings_permissions(path)
        all_allow.extend(allow)
        all_deny.extend(deny)

    # Project-level settings (check current directory and parents)
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        claude_dir = parent / ".claude"
        if claude_dir.is_dir():
            for name in ["settings.json", "settings.local.json"]:
                path = claude_dir / name
                allow, deny = load_settings_permissions(path)
                all_allow.extend(allow)
                all_deny.extend(deny)
            break  # Only use the nearest .claude directory

    return all_allow, all_deny


def extract_patterns(rules: list[str], tool_prefix: str) -> list[str]:
    """Extract patterns for a specific tool from permission rules."""
    patterns = []
    prefix = f"{tool_prefix}("
    for rule in rules:
        if rule.startswith(prefix) and rule.endswith(")"):
            pattern = rule[len(prefix) : -1]
            patterns.append(pattern)
    return patterns


def command_matches(command: str, pattern: str) -> bool:
    """Check if a command matches a pattern using prefix or wildcard matching."""
    command = command.strip()

    # Handle :* suffix (prefix matching)
    if pattern.endswith(":*"):
        prefix = pattern[:-2]
        return command.startswith(prefix)

    # Handle * wildcards anywhere (fnmatch)
    if "*" in pattern:
        return fnmatch.fnmatch(command, pattern)

    # Exact match or prefix match
    return command == pattern or command.startswith(pattern + " ")


def expand_pattern_path(pattern: str) -> str:
    """Expand ~/  and // prefixes in permission patterns to absolute paths.

    Claude Code permission syntax:
      ~/path  → home-relative
      //path  → absolute filesystem path
      /path   → relative to settings file (not handled here)
    """
    if pattern.startswith("~/"):
        return os.path.join(str(Path.home()), pattern[2:])
    if pattern.startswith("//"):
        return pattern[1:]  # strip one slash → absolute path
    return pattern


def path_matches(file_path: str, pattern: str) -> bool:
    """Check if a file path matches a pattern."""
    file_path = os.path.normpath(file_path)
    pattern = expand_pattern_path(pattern)

    # Handle ** (recursive directory matching)
    if "**" in pattern:
        base_path = pattern.replace("**", "").rstrip("/")
        base_path = os.path.normpath(base_path)
        return file_path.startswith(base_path)

    # Handle * wildcards (fnmatch)
    if "*" in pattern:
        return fnmatch.fnmatch(file_path, pattern)

    # Exact match
    return file_path == os.path.normpath(pattern)


def output_decision(decision: str, reason: str):
    """Output the hook decision in the correct format."""
    print(
        json.dumps(
            {
                "hookSpecificOutput": {
                    "hookEventName": "PreToolUse",
                    "permissionDecision": decision,
                    "permissionDecisionReason": reason,
                }
            }
        )
    )


def main():
    try:
        input_data = json.load(sys.stdin)
    except json.JSONDecodeError:
        sys.exit(0)

    tool_name = input_data.get("tool_name", "")
    tool_input = input_data.get("tool_input", {})

    # Only handle Bash, Edit, Write
    if tool_name not in ("Bash", "Edit", "Write"):
        sys.exit(0)

    all_allow, all_deny = load_all_permissions()

    # Get the value to match against patterns
    if tool_name == "Bash":
        value = tool_input.get("command", "")
        match_fn = command_matches
    else:  # Edit or Write
        value = tool_input.get("file_path", "")
        match_fn = path_matches

    allow_patterns = extract_patterns(all_allow, tool_name)
    deny_patterns = extract_patterns(all_deny, tool_name)

    # Deny takes priority
    for pattern in deny_patterns:
        if match_fn(value, pattern):
            output_decision("deny", f"Denied by pattern: {tool_name}({pattern})")
            sys.exit(0)

    # Check allow
    for pattern in allow_patterns:
        if match_fn(value, pattern):
            output_decision("allow", f"Allowed by pattern: {tool_name}({pattern})")
            sys.exit(0)

    # No match - let Claude Code handle it normally (show prompt)
    sys.exit(0)


if __name__ == "__main__":
    main()
