#!/usr/bin/env python3
"""Lumen Tale — manufacture the E4 broken-layout artefact from a real capture.

**What this is.** Slice `0-1` § 3.2 authorises exactly ONE fabricated artefact, and
this builds it: a byte-for-byte copy of a real capture with ONE literal
substitution. Nothing else changes — not the `<title>`, not the `<meta>`, not the row
count, not the advertising `<script>`, not the whitespace, not the trailing newline.

**Why a fabricated artefact and not a recorded one.** E4 says a site that has
reorganised its pages must be reported as unreadable, never as an empty catalogue.
Proving that needs a page that returns 200, is well formed, is not empty, and no
longer carries the element an adapter looks for. A real page that broke once cannot be
relied on to stay broken, and re-recording it whenever the site is reorganised again
makes the test a function of someone else's release schedule. One substitution away
from a frozen capture is reproducible for ever.

**Why exactly ONE substitution, applied literally, everywhere.** Including inside a
`<style>` block — that is what a real template rename does, and it guarantees no
selector can accidentally find the old name again. One edit is the whole contract: an
artefact nobody can prove is one edit away from a real capture is an artefact nobody
can say what it tests.

**Why the pair is an argument and not a constant.** § 3.2 names
`chapter-content -> chapter-content-v2`, written before any FanMTL page had been
captured. Measured 2026-10-04: `chapter-content` appears on **chapter** pages only,
exactly once each, and on **zero** list, catalogue, novel-detail or genre pages. So
the literal plan pair cannot be applied to the plan's own source file
(`catalogue-genre-page0.html`) — there is nothing there to rename, and the result
would be a copy with nothing broken about it. For a CATALOGUE the element an adapter
looks for is `div.novel-item`, and renaming that is what actually makes a parsed
catalogue come back empty. The pair is therefore supplied at the call site and
echoed into the manifest, so the manifest is what states the edit and the test is
what verifies it — neither hardcodes a class name that measurement can refute.

## The proof, which is the point

The plan's acceptance criterion is the inverse of the edit, and it is byte-for-byte:

    broken.replaceAll(NEW, OLD) == source

If that ever fails, the file is no longer "one edit away from a real capture" and
every assertion made against it is about something nobody can describe.

## Usage

    python3 tool/fabricate_broken_layout.py <site> <source> <target> [--old X --new Y]

Refuses to run if the target already exists (an existing artefact edited by hand is
precisely what the proof is meant to catch), if the source does not contain the old
string, if the source already contains the new one (so the reverse substitution
cannot be the inverse of a single edit), or if the source is not UTF-8.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

FIXTURES = Path("test/fixtures/sources")

DEFAULT_OLD = "chapter-content"
DEFAULT_NEW = "chapter-content-v2"


class Refusal(Exception):
    """A reason not to write the artefact."""


def fabricate(
    site: str, source_file: str, target_file: str, old: str, new: str
) -> tuple[Path, int]:
    root = FIXTURES / site
    source = root / source_file
    target = root / target_file

    if not source.is_file():
        raise Refusal(f"no source capture at {source}")
    if target.exists():
        raise Refusal(
            f"{target} already exists. Refusing to overwrite it: an artefact that "
            "was edited after the fact is exactly what the one-substitution proof "
            "exists to catch, and overwriting would destroy the evidence."
        )

    raw = source.read_bytes()
    try:
        text = raw.decode("utf-8")
    except UnicodeDecodeError as exc:
        raise Refusal(f"{source} is not UTF-8: {exc}") from exc

    occurrences = text.count(old)
    if occurrences == 0:
        raise Refusal(
            f"{source} does not contain {old!r}. The substitution has no target, "
            "so the artefact would be a copy with nothing broken about it. "
            "Measure the container an adapter actually looks for on THIS kind of "
            "page before naming it here."
        )
    # The proof is a reverse `replaceAll`, so a source that already contained the new
    # string would round-trip to something that is not the source. Refusing is the
    # only way that proof can keep meaning "one edit".
    if new in text:
        raise Refusal(
            f"{source} already contains {new!r}, so the reverse substitution could "
            "not be the inverse of a single edit."
        )

    broken = text.replace(old, new)
    if broken.replace(new, old) != text:
        raise Refusal("the reverse substitution did not restore the source")
    # ⚠️ The delta is the LENGTH DIFFERENCE, not the occurrence count. The first
    # version wrote `len(raw) + occurrences`, which is only right when the two
    # strings are the same length — so it refused the very substitution it exists to
    # make, with a message about byte arithmetic that was itself the bug.
    expected_delta = occurrences * (len(new) - len(old))
    if len(broken.encode("utf-8")) != len(raw) + expected_delta:
        raise Refusal(
            f"byte arithmetic disagrees with the substitution: "
            f"{len(raw):,} + {occurrences} x {len(new) - len(old)} != "
            f"{len(broken.encode('utf-8')):,}"
        )

    target.write_text(broken, encoding="utf-8", newline="")
    print(
        f"  {source_file} -> {target_file}: "
        f"{occurrences} substitution(s) of {old!r} -> {new!r}, "
        f"{len(raw):,} -> {target.stat().st_size:,} bytes"
    )
    return target, occurrences


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site")
    parser.add_argument("source")
    parser.add_argument("target")
    parser.add_argument("--old", default=DEFAULT_OLD)
    parser.add_argument("--new", default=DEFAULT_NEW)
    args = parser.parse_args(argv[1:])

    try:
        _, occurrences = fabricate(
            args.site, args.source, args.target, args.old, args.new
        )
    except Refusal as exc:
        print(f"  REFUSED — nothing written:\n  - {exc}", file=sys.stderr)
        return 1
    print(
        f"  {occurrences} substitution(s). Record the pair in the manifest's "
        f"`expected.edit` for '{args.target}', then run "
        f"python3 tool/build_manifest.py {args.site} to measure the artefact."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
