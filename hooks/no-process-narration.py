#!/usr/bin/env python3
"""Block process narration in GitHub PR/issue bodies and comments.

A PR description is an end-state account of the final diff, written for a reader
who has seen none of the work that produced it. Narration of how the diff came to
exist — earlier passes, review rounds, what the author got wrong and then fixed,
local test counts — documents the author rather than the change. The commit history
already holds it for anyone doing archaeology.

This exists because the prose rule did not hold. It is stated in the
`pr_description_conventions` memory under "Write to a cold reader; never argue a
position nobody took", including the observation that the reflex is strongest
immediately after a correction — and the violation shipped anyway. Only a hook
that blocks counts.

WHAT IT BLOCKS is a curated phrase set with near-zero legitimate use in an
end-state description, not a general judgment about narration. Each pattern below
carries the reason it earns a block. The judgment cases — arguing against a
position nobody took, defending a choice unprompted — are not greppable and stay
the writer's job.

FALSE POSITIVES are the accepted failure mode: the cost is a loud, recoverable
block and a reword toward end state, which is the goal regardless. The
unacceptable failure is a silent pass, so recognition of the write itself is
biased toward firing and the scan fails closed. There is deliberately no bypass
flag.

SCOPE is GitHub bodies and comments (`gh pr|issue create|edit|comment|review`).
Commit messages are excluded on purpose: a commit's subject IS what changed in it,
so process-shaped prose is native to that surface and the false-positive rate
would be far higher. The canopy PR template carries the same rule for the web-UI
path, which never reaches this hook because `--body-file` bypasses the template.

The gh-command recognition and body-file resolution are duplicated from
no-bare-issue-refs.py rather than extracted to a shared module — that hook is a
working guardrail and refactoring it to add this one risks breaking it. If a third
hook needs the same logic, extract then.

Behavior is covered by tests/no-process-narration.bats.
"""
import json
import os
import re
import sys

# --- gh write recognition (mirrors no-bare-issue-refs.py) --------------------
#
# Anchor `gh` to a command position so a body that merely mentions "gh pr" is not
# mistaken for an invocation. Biased toward firing: a shape this misses skips the
# hook outright, which is the one outcome the hook exists to prevent.
_CMD_START = r"(?:^|[\n;&|`(){}])\s*(?:\w+=\S*\s+|(?:time|then|else|do)\s+)*"
_WRITE_SUBCOMMAND = re.compile(_CMD_START + r"gh\s+(?:pr|issue)\s+(?:comment|create|review|edit)\b")

# Every flag that can carry a body needs an entry, or the hook recognizes the
# write and then scans a body it never read — detection without inspection.
_CAT_SUBST = re.compile(r"\$\(\s*cat\s+[\"']?([^\s\"')]+)")
_BODY_FILE = re.compile(r"--(?:body|notes)-file(?:=|\s+)[\"']?([^\s\"']+)")

# --- the patterns ------------------------------------------------------------
_PATTERNS = [
    # An earlier attempt. The reader never saw it and cannot act on it; whatever
    # was durable about it is already the diff.
    (
        r"\b(?:first|second|third|initial|earlier|previous|original)\s+"
        r"(?:pass|attempt|draft|round|version|cut|sweep)\b",
        "Describe what the diff is, not an earlier state of it.",
    ),
    # Organizing a body by commit. Commit boundaries are invisible in the diff a
    # reviewer reads.
    (
        r"\b(?:first|second|third|fourth|last|this|that)\s+commit\b",
        "Organize by area of the codebase, not by commit.",
    ),
    # The review that produced the diff. Its findings ARE the diff now.
    (
        r"\breview(?:ed|s)?\s+(?:found|caught|surfaced|before\s+it)\b"
        r"|\breview\s+rounds?\b"
        r"|\bbefore\s+it\s+was\s+opened\b"
        r"|\b(?:two|three|both)\s+rounds\b",
        "State the defect the diff fixes; drop who or what found it.",
    ),
    # First-person process.
    (
        r"\bI\s+(?:introduced|missed|noticed|got|had|initially|originally|first|"
        r"forgot|realized|assumed|thought|discovered|ran|skipped)\b"
        r"|\bmy\s+(?:own|first|initial|earlier|previous)\b",
        "Rewrite as a property of the code, not an account of your activity.",
    ),
    # Verification-as-narration, and self-congratulation. The property the check
    # established is the part that belongs.
    (
        r"\bconfirmed\s+(?:by|empirically|that\s+I)\b"
        r"|\bverified\s+(?:by\s+(?:breaking|running|deleting)|empirically)\b"
        r"|\bpaid\s+for\s+itself\b"
        r"|\bworth\s+doing\s+rather\s+than\b"
        r"|\bwhich\s+is\s+the\s+part\s+that\s+made\b",
        "Convert to the property the check established.",
    ),
    # Local CI/test readouts. The checks UI owns pass/fail and the number expires
    # on the next merge.
    (
        r"\b\d+\s*/\s*\d+\s+(?:tests?|files?|specs?|checks?|pass)"
        r"|\b\d+\s+(?:tests?|test\s+files?)\s+passed\b"
        r"|\ball\s+(?:tests?|checks?)\s+pass(?:ed|ing)?\b"
        r"|\b(?:lint|types|tsc)\s+clean\b",
        "Delete it — the checks UI reports this, and the count expires.",
    ),
    # A claim pinned to a state with a known expiry.
    (
        r"\bas\s+of\s+(?:today|now|this\s+writing)\b|\bat\s+the\s+time\s+of\s+writing\b",
        "Write what holds on both sides of the change.",
    ),
]
_PATTERNS = [(re.compile(p, re.IGNORECASE), fix) for p, fix in _PATTERNS]

# Fenced blocks are skipped: a body legitimately shows a command or its output,
# and `bats tests/  # 43 pass` there is displayed data, not a claim.
_FENCE = re.compile(r"^\s*(?:```|~~~)")


def is_github_write(cmd: str) -> bool:
    return bool(_WRITE_SUBCOMMAND.search(cmd))


def _strip_quotes(path: str) -> str:
    return path.strip().strip("'\"")


def gather_scan_text(cmd: str) -> str:
    # The raw command already contains inline bodies (`-b "..."`, heredoc text),
    # so scan it directly, then append any referenced file contents.
    chunks = [cmd]
    paths = []
    for pat in (_CAT_SUBST, _BODY_FILE):
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


def strip_fences(text: str) -> str:
    out, fenced = [], False
    for line in text.splitlines():
        if _FENCE.match(line):
            fenced = not fenced
            continue
        if not fenced:
            out.append(line)
    return "\n".join(out)


def find_narration(text: str):
    """Return [(matched phrase, how to fix)], de-duped, in document order."""
    hits, seen = [], set()
    prose = strip_fences(text)
    for pattern, fix in _PATTERNS:
        for m in pattern.finditer(prose):
            phrase = " ".join(m.group(0).split())
            key = phrase.lower()
            if key in seen:
                continue
            seen.add(key)
            hits.append((m.start(), phrase, fix))
    hits.sort()
    return [(phrase, fix) for _, phrase, fix in hits]


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # A payload of an unexpected shape carries no command to guard. Checked
    # explicitly rather than left to raise: a traceback exits non-2, which the
    # PreToolUse contract treats as non-blocking, so the call would proceed anyway.
    if not isinstance(data, dict) or data.get("tool_name") != "Bash":
        sys.exit(0)

    tool_input = data.get("tool_input")
    cmd = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(cmd, str) or not cmd or not is_github_write(cmd):
        sys.exit(0)

    # Past this point the command IS a GitHub write, so a failure here means a body
    # may be published without ever being inspected. Only exit 2 blocks a
    # PreToolUse hook — every other non-zero exit is reported as non-blocking and
    # the call proceeds — so an unexpected exception would read as a pass. Fail
    # closed. Armed only after the write is confirmed, because before that nothing
    # is established about the command and exiting 2 would wedge unrelated Bash.
    try:
        hits = find_narration(gather_scan_text(cmd))
    except Exception:
        sys.stderr.write(
            "BLOCKED: no-process-narration.py failed before it could finish checking "
            "the body. Refusing the write rather than risk publishing an unchecked one.\n"
        )
        sys.exit(2)

    if not hits:
        sys.exit(0)

    lines = "\n".join(f'  "{phrase}" — {fix}' for phrase, fix in hits)
    sys.stderr.write(
        "BLOCKED: GitHub body reads as process narration, not end state.\n\n"
        f"{lines}\n\n"
        "A PR description is an end-state account of the final diff, for a reader who\n"
        "has seen none of the work. How the diff came to exist — earlier passes, review\n"
        "rounds, what you got wrong, local test counts — belongs in the commit history,\n"
        "not here. Rewrite so each sentence would read the same on day one.\n"
        "If a match is displayed data (a command, its output), put it in a fenced block.\n"
    )
    sys.exit(2)


if __name__ == "__main__":
    main()
