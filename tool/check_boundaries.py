#!/usr/bin/env python3
"""Refuse a cross-feature import, because `02-architecture.md` forbids one and nothing did.

## Why this exists

F-018: `appDatabaseProvider` was declared in `features/history/` and imported by six files
across four features. `libraryRepositoryProvider` and `libraryStreamProvider` lived in
`features/library/library_screen.dart` and were reached by four more imports. **Ten
violations, and no control reported any of them** — `flutter analyze` does not check
architecture, and neither did any script in `tool/`.

The cost was not the violations themselves. It was that a *database* provider — the most
shared thing in the app — was reachable only by breaking a rule, so the next feature to need
storage would either copy the history import or conclude it was not allowed to.

## The rule

`features/<a>/` may import `core`, `domain`, `data` and `app` (router/theme only). It may
NOT import `features/<b>/` for `b != a`.

`lib/main.dart` is the composition root and is exempt: registering a screen by path is its
declared job.

## What it will NOT do

It reads import URIs only. It does not reason about `show` clauses, re-exports, or whether a
particular import is "really" a coupling — a `show` clause narrows the *namespace*, not the
*dependency*, and this counts the dependency.

## A violation must be FIXED or DECLARED

`tool/boundaries.allowlist` lists the accepted crossings, one per line:

    <file>:<line-range>  # <why it is acceptable>

A line that starts with `#` is a comment. **An undeclared violation fails**; a declared one
does not — and the declaration is the record, so it is visible in review rather than living
in someone's memory. A declared crossing is debt with a name on it, which is the difference
between this and a control somebody switches off.

Usage:

    tool/check_boundaries.py            # report, exit 1 on any UNDECLARED violation
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

IMPORT = re.compile(r"^import\s+'([^']+)'")
FEATURE = re.compile(r"package:lumen_tale/features/([^/]+)/")
EXEMPT = {"main.dart"}


def feature_of(path: Path, root: Path) -> str | None:
    rel = path.relative_to(root).as_posix()
    parts = rel.split("/")
    if len(parts) < 3 or parts[0] != "lib" or parts[1] != "features":
        return None
    return parts[2]


def load_allowlist(root: Path) -> list[tuple[str, str]]:
    """`<file>[:<line>]` opens an entry; indented `#` lines below it are its reason.

    ⚠️ **A reason may SPAN LINES.** The first version read only the comment on the entry's
    own line, so a reason written as a paragraph — which is the only length adequate for
    "why is this acceptable" — was reported as `NO REASON GIVEN`. An allowlist that shows
    `NO REASON` for every entry is an allowlist nobody reads, which is worse than none.
    """
    path = root / "tool" / "boundaries.allowlist"
    if not path.exists():
        return []

    out: list[tuple[str, str]] = []
    current: str | None = None
    for raw in path.read_text(encoding="utf-8").split("\n"):
        stripped = raw.strip()
        if not stripped:
            continue
        if stripped.startswith("#"):
            if current is not None and raw.startswith((" ", "\t")):
                out[-1] = (out[-1][0], (out[-1][1] + " " + stripped.lstrip("# ")).strip())
            continue
        current = stripped
        out.append((stripped, ""))
    return out


def main(argv: list[str]) -> int:
    root = Path(argv[0] if argv else ".").resolve()
    allowlist = load_allowlist(root)
    allowed_paths = {a[0].split(":", 1)[0] for a in allowlist}
    reasons = {a[0].split(":", 1)[0]: a[1] for a in allowlist}

    violations: list[str] = []
    declared: list[str] = []

    for path in sorted((root / "lib").rglob("*.dart")):
        rel = path.relative_to(root).as_posix()
        if rel in EXEMPT:
            continue
        owner = feature_of(path, root)
        if owner is None:
            continue
        for n, line in enumerate(path.read_text(encoding="utf-8").split("\n"), 1):
            m = IMPORT.match(line)
            if not m:
                continue
            target = FEATURE.match(m.group(1))
            if target and target.group(1) != owner:
                entry = f"{rel}:{n}"
                if rel in allowed_paths:
                    declared.append(
                        f"{entry}  {owner} -> features/{target.group(1)}"
                        f"   [declared: {reasons.get(rel) or 'NO REASON GIVEN'}]"
                    )
                else:
                    violations.append(
                        f"{entry}  {owner} -> features/{target.group(1)}"
                    )

    if declared:
        print(f"{len(declared)} DECLARED crossing(s) — debt with a name on it:")
        for d in declared:
            print(f"  {d}")
        print()

    if violations:
        print(f"{len(violations)} cross-feature import(s):")
        for v in violations:
            print(f"  {v}")
        print(
            "\n02-architecture.md: `features/*` may import core, domain, data and app\n"
            "(router/theme). It communicates through app/ and shared providers. Move the\n"
            "shared symbol to data/ or core/ rather than importing a feature — or declare\n"
            "the crossing in tool/boundaries.allowlist with a reason."
        )
        return 1

    print("no undeclared cross-feature imports")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))