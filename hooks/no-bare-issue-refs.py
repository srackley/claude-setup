#!/usr/bin/env python3
"""Block bare #N references in GitHub comment/PR/issue bodies.

A bare `#N` in a GitHub body auto-links to issue/PR N in that repo. When `#N`
was meant as an enumeration ("point 1", "finding 3") it silently links to an
unrelated issue. Cross-repo references need the `owner/repo#N` form.

Fires only on `gh` commands that write a body to GitHub. Allows:
  - closing keywords: `Closes #N`, `Fixes #N`, `Resolves #N` (and tenses)
  - scoped refs: `owner/repo#N` (e.g. `wanderu/canopy#742`)
  - a ref glued to a word char (`alice#42`), which GitHub renders as plain text
Blocks anything else that looks like a bare `#N`.

Write surfaces: `gh pr|issue comment|create|review|edit`, plus `gh pr merge` and
`gh release create` when given a body/notes flag (both render and autolink), plus
`gh api` carrying a body field or `--input`.

The body text is scanned both inline (`-b`, `--body`, `-f body=`) and via file
references (`$(cat file)`, `--body-file`/`--notes-file file`, `body=@file`,
`--input file`) so a body passed through a file is caught too.

Every rule about what GitHub does or does not autolink was checked against its
Markdown API (POST /markdown, mode gfm) rather than reasoned about. Re-verify the
same way before widening or narrowing either boundary class.

Behavior is covered by tests/no-bare-issue-refs.bats. The bash port in canopy
(.claude/hooks/no-bare-issue-refs.sh) is kept behaviorally equivalent.
"""
import json
import os
import re
import sys

# `gh` must be the command being invoked, not a substring inside a quoted message
# (e.g. a commit message that mentions "gh api"). Anchor to a command position:
# start of string, a newline, or after a shell operator or block delimiter, then
# any number of tokens that don't change WHAT runs — env assignments
# (`GH_TOKEN=x gh ...`), `time`, and the keywords opening a compound command
# (`if ...; then gh ...`). `}` is included so `xargs -I{} gh ...` counts.
#
# Recognition is biased toward firing. A shape this misses doesn't degrade the
# scan, it skips the hook outright — a silent false negative, the one outcome this
# hook exists to prevent. Firing on a command that publishes nothing costs at most
# a loud, recoverable false block. When in doubt, widen this rather than narrow it.
_CMD_START = r"(?:^|[\n;&|`(){}])\s*(?:\w+=\S*\s+|(?:time|then|else|do)\s+)*"

# gh subcommands that always publish a body.
_WRITE_SUBCOMMAND = re.compile(_CMD_START + r"gh\s+(?:pr|issue)\s+(?:comment|create|review|edit)\b")

# Subcommands that publish only when given a body/notes flag. A merge commit
# message and release notes both render on GitHub and autolink like any body.
_PR_MERGE = re.compile(_CMD_START + r"gh\s+pr\s+merge\b")
_RELEASE_CREATE = re.compile(_CMD_START + r"gh\s+release\s+create\b")
_BODY_FLAG = re.compile(r"(?:^|\s)(?:-b|--body|--body-file)(?:\s|=|$)")
_NOTES_FLAG = re.compile(r"(?:^|\s)(?:-n|--notes|--notes-file)(?:\s|=|$)")

# `gh api` carries a body as a field or via --input. `\b` keeps field names like
# `request_body=` from counting.
_GH_API = re.compile(_CMD_START + r"gh\s+api\b")
_API_BODY = re.compile(r"\bbody[=@]|(?:^|\s)--input(?:\s|=)")

# Closing keywords GitHub honors: close/closes/closed, fix/fixes/fixed, resolve/resolves/resolved.
_CLOSING = r"(?:close[sd]?|fix(?:e[sd])?|resolve[sd]?)"
# The keyword must start on a word boundary, or a word merely ENDING in a stem
# reads as a closing reference and lets a bare ref through: `bugfix #3`,
# `prefix #1`, `suffix #2`, `hotfix #9` all end in fix/fixes.
#
# A leading non-word char is REQUIRED rather than optional (`(?:^|[^\w])`, or an
# equivalent negative lookbehind). Both of those are satisfied at position 0 of
# the *window* this is matched against — a 30-char slice, not the whole text — so
# a stem sliced by the window edge (`bug|fix` + 27 spaces + a ref) would match
# and be ALLOWED. Demanding the boundary char makes a window-sliced stem fail to
# match, i.e. block, which is the safe bias for a guardrail. find_bare_refs()
# stands a space in for the char when the window is the true start of the text.
_CLOSING_PREFIX = re.compile(r"[^\w]" + _CLOSING + r"\s*:?\s*$", re.IGNORECASE)

# A bare `#N`: not glued to a word char on either side.
#
# Both boundaries are word chars because that is GitHub's own rule, checked
# against its Markdown API (POST /markdown, mode gfm) rather than assumed:
# `alice#42`, `match3#99` and `a/b/c#42` render as PLAIN TEXT, so letting them
# through costs nothing — while `foo.#42`, `foo/#42`, `foo-#42` and `v1.2.#42` all
# autolink into the current repo, so they must block. Punctuation before a ref does
# not suppress autolinking; only a word char does. A real `owner/repo#N` passes on
# the same rule, because a repo name ends in a word char — matching the slug itself
# buys nothing over inspecting the single character.
_BARE_REF = re.compile(r"(?<!\w)#(\d+)\b")

# File references whose contents should also be scanned. The optional ["']
# before each captured path lets a quoted path (--body-file "notes.md") match;
# without it the char class stops at the opening quote and the file is silently
# left unscanned — a bare ref in it would slip through.
#
# Every flag is_github_write treats as body-bearing needs an entry here, or the
# hook recognizes the write and then scans a body it never read — detection
# without inspection, which reads as a pass.
_CAT_SUBST = re.compile(r"\$\(\s*cat\s+[\"']?([^\s\"')]+)")
_BODY_FILE = re.compile(r"--(?:body|notes)-file(?:=|\s+)[\"']?([^\s\"']+)")
_INPUT_FILE = re.compile(r"--input(?:=|\s+)[\"']?([^\s\"']+)")
_API_BODY_FILE = re.compile(r"body=@[\"']?([^\s\"']+)")


def is_github_write(cmd: str) -> bool:
    if _WRITE_SUBCOMMAND.search(cmd):
        return True
    if _PR_MERGE.search(cmd) and _BODY_FLAG.search(cmd):
        return True
    if _RELEASE_CREATE.search(cmd) and _NOTES_FLAG.search(cmd):
        return True
    return bool(_GH_API.search(cmd) and _API_BODY.search(cmd))


def _strip_quotes(path: str) -> str:
    return path.strip().strip("'\"")


def gather_scan_text(cmd: str) -> str:
    # The raw command already contains inline bodies (`-b "..."`, `-f body="..."`,
    # heredoc text), so scan it directly, then append any referenced file contents.
    #
    # This catches every ref appearing LITERALLY in the command, including one
    # assigned to a variable before the gh call. The bound worth knowing: a ref the
    # shell BUILDS at runtime is not caught, because what arrives here is the
    # command text, not the expanded arguments — a command substitution, an
    # arithmetic expansion, or a value read from a file none of the path patterns
    # recognize all evade it. That is inherent to scanning a command string rather
    # than a fixable gap, and it is accepted: this guards against an accidental
    # mis-link, not a determined one.
    chunks = [cmd]
    paths = []
    for pat in (_CAT_SUBST, _BODY_FILE, _INPUT_FILE, _API_BODY_FILE):
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
        start = max(0, m.start() - 30)
        prefix = text[start:m.start()]
        # _CLOSING_PREFIX requires a boundary char before the keyword; when the
        # window IS the start of the text there is no char to inspect, so stand a
        # space in for it. That keeps a body opening with `Fixes #5` allowed.
        if start == 0:
            prefix = " " + prefix
        if _CLOSING_PREFIX.search(prefix):
            continue
        bad.append("#" + m.group(1))
    return bad


def main() -> None:
    try:
        data = json.load(sys.stdin)
    except (json.JSONDecodeError, ValueError):
        sys.exit(0)

    # A payload of an unexpected shape carries no command to guard, so treat it the
    # same as unparseable input and allow. Checked explicitly rather than left to
    # raise: an AttributeError here would exit non-2, which the PreToolUse contract
    # treats as non-blocking anyway — so the tool would proceed regardless, just
    # with a traceback in the log.
    if not isinstance(data, dict) or data.get("tool_name") != "Bash":
        sys.exit(0)

    tool_input = data.get("tool_input")
    cmd = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
    if not isinstance(cmd, str) or not cmd or not is_github_write(cmd):
        sys.exit(0)

    # Past this point the command IS a GitHub write, so a failure here means a body
    # may be published without ever being inspected. Only exit 2 blocks a PreToolUse
    # hook — every other non-zero exit is reported as a non-blocking error and the
    # call proceeds — so an unexpected exception would read as a pass. Fail closed.
    #
    # Catch-all on purpose: the point is not to enumerate what can go wrong but to
    # ensure that nothing going wrong is ever mistaken for "no refs found". Armed
    # only after the write is confirmed, because before that nothing has been
    # established about the command and exiting 2 would wedge unrelated Bash calls.
    try:
        bad = find_bare_refs(gather_scan_text(cmd))
    except Exception:
        sys.stderr.write(
            "BLOCKED: no-bare-issue-refs.py failed before it could finish checking "
            "the body. Refusing the write rather than risk publishing an unchecked "
            "reference.\n"
        )
        sys.exit(2)

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
