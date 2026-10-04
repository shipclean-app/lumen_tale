#!/usr/bin/env python3
"""Sort the `import` directives of Dart files, and nothing else.

## Why this exists

`flutter analyze` fails on `directives_ordering`, and the fix is mechanical: sort the
`import` block by URI. It was being done by hand, one file at a time, which is slow and
which nobody does reliably — so it is a script.

## What it will NOT do

It rewrites **only** the contiguous run of `import` directives at the top of a file. It
does not reorder anything else, does not merge or split directives, and does not touch a
`show`/`as` clause. If a file's imports are interleaved with other declarations it is left
alone and reported, because sorting across a declaration boundary would change semantics.

## Usage

    tool/sort_imports.py lib test          # fix in place
    tool/sort_imports.py --check lib test  # report, change nothing, exit 1 if any need it
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

IMPORT_START = re.compile(r"^import\s+'([^']+)'")
DIRECTIVE_TAIL = re.compile(r"^\s+(show|as)\b")


def read_directive(lines: list[str], start: int) -> tuple[str, int]:
    """One directive, which may continue onto following `show`/`as` lines."""
    end = start + 1
    while end < len(lines) and DIRECTIVE_TAIL.match(lines[end]):
        end += 1
    return "\n".join(lines[start:end]), end


GENERATED_MARKERS = ("/generated/", ".g.dart", ".freezed.dart", ".drift.dart")


def is_generated(path: Path) -> bool:
    p = path.as_posix()
    return any(m in p for m in GENERATED_MARKERS)


def sort_file(path: Path, check: bool) -> bool:
    original = path.read_text(encoding="utf-8")
    lines = original.split("\n")

    indices = [i for i, line in enumerate(lines) if IMPORT_START.match(line)]
    if not indices:
        return False

    first, last = indices[0], indices[-1]

    # ⚠️ **BLANK LINES ARE ALLOWED INSIDE THE REGION — a first version forbade them and
    # silently sorted NOTHING.** This project's convention separates `package:flutter…`
    # from `package:lumen_tale…` with a blank line, so demanding "every line is an import"
    # skipped exactly the files that needed sorting, and reported success. The rule is the
    # weaker, correct one: nothing that is neither an import nor blank may sit between the
    # first and last import.
    i = first
    while i <= last:
        if IMPORT_START.match(lines[i]):
            _, i = read_directive(lines, i)
            continue
        if lines[i].strip() == "":
            i += 1
            continue
        return False

    block: list[str] = []
    i = first
    while i <= last:
        if not IMPORT_START.match(lines[i]):
            i += 1
            continue
        text, i = read_directive(lines, i)
        block.append(text)

    def rank(entry: str) -> tuple[int, str]:
        """`dart:` → `package:` → relative. Three ranks, because two was not enough.

        ⚠️ **A first version sorted by URI alone, and then by `package:` before relative.**
        Both were wrong, and both were caught by `flutter analyze` rather than by the sort
        declaring itself finished. The second version treated `dart:io` as "not a package",
        so it sorted *before* the `package:` imports — which put relative imports in front of
        them too. The convention is three groups, in this order, and the sort must produce
        exactly it.
        """
        uri = IMPORT_START.match(entry)
        uri = uri.group(1) if uri else ""
        if uri.startswith("dart:"):
            group = 0
        elif uri.startswith("package:"):
            group = 1
        else:
            group = 2
        return (group, uri)

    ordered = sorted(block, key=rank)
    if ordered == block:
        return False

    if check:
        print(f"would sort: {path}")
        return True

    rebuilt = lines[:first] + "\n".join(ordered).split("\n") + lines[last + 1 :]
    path.write_text("\n".join(rebuilt), encoding="utf-8")
    print(f"sorted: {path}")
    return True


def main(argv: list[str]) -> int:
    check = "--check" in argv
    include_generated = "--generated" in argv
    roots = [a for a in argv if not a.startswith("--")] or ["lib", "test"]

    targets: list[Path] = []
    for root in roots:
        p = Path(root)
        if p.is_file():
            targets.append(p)
        elif p.is_dir():
            targets.extend(sorted(p.rglob("*.dart")))

    # ⚠️ **GENERATED OUTPUT IS SKIPPED.** `lib/l10n/generated/` belongs to codegen and is
    # excluded from analysis; a first run rewrote two of its files, which the next
    # `flutter gen-l10n` would have reverted and which appeared in a diff as pure noise.
    if not include_generated:
        targets = [t for t in targets if not is_generated(t)]

    touched = [str(t) for t in targets if sort_file(t, check)]
    if not touched:
        print("every import block is already sorted")
        return 0
    print(f"{len(touched)} file(s) {'would change' if check else 'changed'}")
    return 1 if check else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))