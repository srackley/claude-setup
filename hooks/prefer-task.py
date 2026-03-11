#!/usr/bin/env python3
"""PreToolUse hook that enforces using task commands over raw package manager scripts.

When a Taskfile.yml exists, this hook blocks pnpm/npm/yarn commands only when
a corresponding task wrapper exists, and suggests the task command instead.
Commands without a task wrapper are allowed through.
"""
import json
import re
import sys
from pathlib import Path


def find_taskfile() -> Path | None:
    """Find Taskfile.yml or Taskfile.yaml in current directory or parents."""
    cwd = Path.cwd()
    for parent in [cwd, *cwd.parents]:
        for name in ["Taskfile.yml", "Taskfile.yaml"]:
            taskfile = parent / name
            if taskfile.exists():
                return taskfile
    return None


def is_package_manager_command(command: str) -> tuple[bool, str]:
    """Check if command is a package manager invocation.

    Returns (is_pm_command, package_manager_name).
    """
    command = command.strip()

    patterns = [
        (r"^pnpm\s+run\s+", "pnpm"),
        (r"^pnpm\s+exec\s+", "pnpm"),
        (r"^pnpm\s+install\b", "pnpm"),
        (r"^npm\s+run\s+", "npm"),
        (r"^npm\s+exec\s+", "npm"),
        (r"^npm\s+install\b", "npm"),
        (r"^npx\s+", "npx"),
        (r"^yarn\s+run\s+", "yarn"),
        (r"^yarn\s+install\b", "yarn"),
        (r"^yarn\s+(?!add|remove|install|init|--)", "yarn"),  # yarn <script> shorthand
    ]

    for pattern, pm in patterns:
        if re.match(pattern, command):
            return True, pm

    return False, ""


def extract_core_command(command: str) -> str:
    """Extract the core PM command without trailing flags/arguments.

    Examples:
        "pnpm run test --coverage" → "pnpm run test"
        "pnpm exec playwright test --list" → "pnpm exec playwright test"
        "pnpm exec playwright install" → "pnpm exec playwright install"
        "pnpm install" → "pnpm install"
        "npx playwright install" → "npx playwright install"
    """
    cmd = re.sub(r"\s+", " ", command.strip())

    # Order matters — try most specific patterns first
    extractors = [
        r"((?:pnpm|npm)\s+run\s+\S+)",           # pnpm run <script>
        r"((?:pnpm|npm)\s+exec\s+\S+\s+\S+)",    # pnpm exec <tool> <subcmd>
        r"((?:pnpm|npm)\s+exec\s+\S+)",           # pnpm exec <tool>
        r"((?:pnpm|npm|yarn)\s+install)\b",        # pnpm install
        r"(npx\s+\S+\s+\S+)",                      # npx <tool> <subcmd>
        r"(npx\s+\S+)",                             # npx <tool>
        r"((?:pnpm|npm|yarn)\s+\S+)",              # pnpm <shorthand>
    ]

    for pattern in extractors:
        m = re.match(pattern, cmd)
        if m:
            return m.group(1)

    return cmd


def find_wrapping_task(core_command: str, taskfile_path: Path) -> str | None:
    """Find which task wraps the given core command.

    Parses task blocks in the Taskfile and checks if the core command appears
    in any task's body. Returns the task name if found, None otherwise.
    """
    try:
        content = taskfile_path.read_text()
    except Exception:
        return None

    if core_command not in content:
        return None

    # Parse task blocks to find which task contains this command
    current_task = None
    yaml_keys = {"version", "tasks", "vars", "env", "includes", "output", "silent"}

    for line in content.splitlines():
        # Match top-level task definitions (2-space indent under tasks:)
        task_match = re.match(r"^  ([\w][\w-]*):", line)
        if task_match:
            name = task_match.group(1)
            if name not in yaml_keys:
                current_task = name
            continue

        if current_task and core_command in line:
            return current_task

    return None


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

    # Only handle Bash
    if tool_name != "Bash":
        sys.exit(0)

    command = tool_input.get("command", "")

    # Check if this is a package manager command
    is_pm_cmd, pm_name = is_package_manager_command(command)
    if not is_pm_cmd:
        sys.exit(0)

    # Only enforce if a Taskfile exists
    taskfile = find_taskfile()
    if not taskfile:
        sys.exit(0)

    # Only block if a task wraps this specific command
    core = extract_core_command(command)
    task_name = find_wrapping_task(core, taskfile)

    if task_name:
        output_decision(
            "deny",
            f"This project uses task runner. Use `task {task_name}` instead of `{pm_name}`. "
            f"Run `task -l` to see all available tasks.",
        )


if __name__ == "__main__":
    main()
