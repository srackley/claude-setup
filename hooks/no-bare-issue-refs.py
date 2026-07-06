#!/usr/bin/env python3
"""Block bare #N references in GitHub comment/PR/issue bodies.

A bare `#N` in a GitHub body auto-links to issue/PR N in that repo. When `#N`
was meant as an enumeration ("point 1", "finding 3") it silently links to an
unrelated issue. Cross-repo references need the `owner/repo#N` form.

Fires only on `gh` commands that write a body to GitHub. Allows:
  - closing keywords: `Closes #N`, `Fixes #N`, `Resolves #N` (and tenses)
  - scoped refs: `owner/repo#N` (e.g. `wanderu/canopy#742`)
Blocks anything else that looks like a bare `#N`.

The body text is scanned both inline (`-b`, `--body`, `-f body=`) and via file
references (`$(cat file)`, `--body-file file`, `body=@file`) so a body passed
through a file is caught too.
"""
import json
import os
import re
import sys

# `gh` must be the command being invoked, not a substring inside a quoted message
# (e.g. a commit message that mentions "gh api"). Anchor to a command position:
# start of string, a newline, or after a shell operator.
_CMD_START = r"(?:^|[\n;&|`(])\s*"
# gh subcommands that publish a body, plus `gh api` calls carrying a body field.
_WRITE_SUBCOMMAND = re.compile(_CMD_START + r"gh\s+(?:pr|issue)\s+(?:comment|create|review|edit)\b")
_GH_API = re.compile(_CMD_START + r"gh\s+api\b")
_API_BODY = re.compile(r"\bbody[=@]")

# Closing keywords GitHub honors: close/closes/closed, fix/fixes/fixed, resolve/resolves/resolved.
_CLOSING = r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)"
_CLOSING_PREFIX = re.compile(_CLOSING + r"\s*:?\s*$", re.IGNORECASE)

# A bare `#N`: not preceded by a repo-slug/word char (which would make it owner/repo#N),
# and followed by a word boundary.
_BARE_REF = re.compile(r"(?<![\w./-])#(\d+)\b")

# File references whose contents should also be scanned.
_CAT_SUBST = re.compile(r"\$\(\s*cat\s+([^\s)]+)\s*\)")
_BODY_FILE = re.compile(r"--body-file(?:=|\s+)([^\s\"']+)")
_API_BODY_FILE = re.compile(r"body=@([^\s\"']+)")


def is_github_write(cmd: str) -> bool:
    if _WRITE_SUBCOMMAND.search(cmd):
        return True
    return bool(_GH_API.search(cmd) and _API_BODY.search(cmd))


def _strip_quotes(path: str) -> str:
    return path.strip().strip("'\"")


def gather_scan_text(cmd: str) -> str:
    # The raw command already contains inline bodies (`-b "..."`, `-f body="..."`,
    # heredoc text), so scan it directly, then append any referenced file contents.
    chunks = [cmd]
    paths = []
    for pat in (_CAT_SUBST, _BODY_FILE, _API_BODY_FILE):
        paths.extend(m.group(1) for m in pat.finditer(cmd))
    for raw in paths:
        path = os.path.expanduser(_strip_quotes(raw))
        try:
            with open(path, "r", encoding="utf-8", errors="replace") as fh:
                chunks.append(fh.read())
        except OSError:
            # Unreadable file — the raw-command scan is still the safety net.
            continue
    return "\n".join(chunks)


def find_bare_refs(text: str):
    bad = []
    for m in _BARE_REF.finditer(text):
        prefix = text[max(0, m.start() - 30):m.start()]
        if _CLOSING_PREFIX.search(prefix):
            continue
        bad.append("#" + m.group(1))
    return bad


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    if data.get("tool_name") != "Bash":
        sys.exit(0)

    cmd = (data.get("tool_input") or {}).get("command", "")
    if not cmd or not is_github_write(cmd):
        sys.exit(0)

    bad = find_bare_refs(gather_scan_text(cmd))
    if not bad:
        sys.exit(0)

    refs = ", ".join(dict.fromkeys(bad))  # de-dupe, keep order
    sys.stderr.write(
        f"BLOCKED: GitHub body contains bare reference(s) {refs} — a bare #N auto-links "
        "to issue/PR N in this repo.\n"
        "Use 'point N' / 'item N' for enumeration, or 'owner/repo#N' for a real cross-repo "
        "reference (e.g. wanderu/canopy#742). Closing keywords (Closes/Fixes/Resolves #N) are allowed.\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
