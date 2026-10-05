#!/usr/bin/env python3
"""Declare in every ARB `@key` block the placeholders its value already uses.

Why this is a committed `tool/` script and not a one-liner
-----------------------------------------------------------
Two reasons, and the second is the one that matters.

1. `AGENTS.md` § "Every helper script goes in `tool/` — always": the moment a script exists to
   make the work easier or to route around a limitation, it is a file in `tool/`, committed.

2. **This script writes the two ARB files, and other agents were editing them at the same
   time.** `6-7` lost twenty-one of `3-3`'s messages to exactly that: two writers read
   `app_*.arb`, then each wrote its own version, and the second write discarded the first
   writer's keys. A read-modify-write done as an inline heredoc has no protection against
   that. This one:

     * reads and hashes the file,
     * computes the new content in memory **by editing the text, not by re-serialising it**,
     * re-hashes immediately before writing and refuses if the file moved,
     * re-verifies after writing that the keys it was asked to protect are still present.

⚠️ **Why the edit is textual and not `json.dumps`.** Re-serialising an 86 KB ARB re-quotes
every description, reflows nothing but touches every byte, and produces a diff of several
thousand lines in a file two other agents are writing. A surgical insert adds exactly one line
per key and leaves every other byte untouched — so a conflict in review is a conflict about
the placeholders, not about whitespace.

What it changes, and why it is safe
----------------------------------
It only ever **adds** a `"placeholders"` map to a key's `@key` metadata, for placeholders the
value already interpolates. It never edits a message, never adds or removes a key, and never
touches `@locale`.

`flutter gen-l10n` already infers an undeclared `{name}` as `String`, so the generated code is
byte-identical before and after. What changes is that the declaration becomes **true** instead
of inferred, which is what `6-7` § 10.3 asserts: *the set of placeholders in a value equals
the set declared in its `@key`, in both files*.

Usage
-----
    python3 tool/declare_arb_placeholders.py            # rewrite in place
    python3 tool/declare_arb_placeholders.py --check    # exit 1 if anything is missing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ARB_FILES = ("lib/l10n/app_en.arb", "lib/l10n/app_fr.arb")

# `{name}` and `{count, plural, …}`. The `[,}]` after the identifier is what keeps a plural
# clause body from being read as a name; the comparison is on SETS, so a `{count}` repeated
# inside a plural body is harmless.
PLACEHOLDER_RE = re.compile(r"\{(\w+)[,}]")


def value_placeholders(value: object) -> set[str]:
    if not isinstance(value, str):
        return set()
    return set(PLACEHOLDER_RE.findall(value))


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def needed(data: dict) -> tuple[dict[str, list[str]], list[str]]:
    """(key -> names to declare, keys whose declared set CONFLICTS with the value's)."""
    todo: dict[str, list[str]] = {}
    conflicts: list[str] = []
    for key, value in data.items():
        if key.startswith("@"):
            continue
        used = value_placeholders(value)
        if not used:
            continue
        meta = data.get("@" + key)
        declared = set()
        if isinstance(meta, dict):
            declared = set((meta.get("placeholders") or {}).keys())
        if used == declared:
            continue
        if declared:
            # A key that declares something AND interpolates something else is a different
            # defect — a value referring to a placeholder that was never declared. Writing a
            # signature for it here would invent an API, so it is reported, not fixed.
            conflicts.append("%s: used=%s declared=%s"
                             % (key, sorted(used), sorted(declared)))
            continue
        todo[key] = sorted(used)
    return todo, conflicts


def insert_declarations(text: str, todo: dict[str, list[str]]) -> str:
    out = text
    for key in sorted(todo, key=len, reverse=True):
        # Longest key first: a shorter key can be a PREFIX of a longer one in the generated
        # text (`@chapterListHeader` vs `@chapterListHeaderAtSource`), and inserting into the
        # shorter block first would corrupt the longer one's search.
        opener = '  "@%s": {\n' % key
        start = out.index(opener) + len(opener)
        closer = out.index("\n  }", start)
        names = ", ".join('"%s": {}' % n for n in todo[key])
        # ⚠️ **The comma goes on the PREVIOUS line, and the new line carries none.**
        # Both ARB files in this repository end a metadata object with NO trailing comma on its
        # last property (`"description": "…"` then `},`). Putting the comma after the new
        # property would fix the JSON and break the file's shape, and putting it after
        # `"description"` is the only edit that produces valid JSON in the house style.
        out = out[:closer] + ',\n    "placeholders": {%s}' % names + out[closer:]
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--check",
        action="store_true",
        help="report what is missing and exit 1; write nothing",
    )
    args = parser.parse_args()

    problems = 0
    for rel in ARB_FILES:
        path = Path(rel)
        before = path.read_text(encoding="utf-8")
        todo, conflicts = needed(json.loads(before))

        for line in conflicts:
            print("%s: CONFLICT %s" % (rel, line))
        problems += len(conflicts)

        if args.check:
            if todo:
                print("%s: %d key(s) need a placeholders declaration: %s"
                      % (rel, len(todo), ", ".join(sorted(todo))))
                problems += len(todo)
            else:
                print("%s: every placeholder is declared" % rel)
            continue

        if not todo:
            print("%s: nothing to declare" % rel)
            continue

        after = insert_declarations(before, todo)

        # ⚠️ The write window. Another agent may have written between the read above and here.
        if digest(path.read_text(encoding="utf-8")) != digest(before):
            print("%s: CHANGED UNDER US — refusing to write. Re-run." % rel)
            return 2
        path.write_text(after, encoding="utf-8")

        # And the proof, read back: every key we declared must still be in the file, with the
        # metadata we wrote. This is the row that would have caught the `3-3` loss.
        written = json.loads(path.read_text(encoding="utf-8"))
        for key, names in todo.items():
            got = sorted((written.get("@" + key, {}).get("placeholders") or {}).keys())
            if got != names or key not in written:
                print("%s: %s did not survive the write (got %s)" % (rel, key, got))
                return 2
        print("%s: declared %d key(s)" % (rel, len(todo)))

    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())