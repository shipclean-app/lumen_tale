#!/usr/bin/env python3
"""Lumen Tale — measure a captured fixture, for the discovery steps of `0-1`.

**Why this exists.** Section 7 forbids manufacturing a fixture for a line marked
"à découvrir": a path invented from a template produces a green test that proves
nothing. The only honest way to close such a line is to **read the bytes already on
disk** and record what they say. This is that read.

It is a *measuring* tool, not a fetching one, and it never writes to a fixture. It
answers three questions, all of which `notes` in `manifest.in.json` must answer from
a real page rather than from memory:

- **What containers exist, and how many?** A row count is a number, and a number
  typed from a screenshot is a guess. `expected.novelRowsExact` is asserted later by
  a Dart test that counts with `package:html`, so a wrong value here fails loudly
  instead of lying quietly.
- **What hrefs does this page publish?** A pagination parameter is not designed,
  it is *read off a link the site itself renders*. That is the difference between a
  discovered URL and an invented one.
- **Is there a next-page link at all?** A chapter that does not continue is a fact
  about the site, and the correct output is a written finding, not a missing fixture.

## Usage

    python3 tool/inspect_fixture.py <fixture.html> [options]

| Option | Reports |
|---|---|
| `--classes` | every `class="…"` value, with occurrence counts, most frequent first |
| `--ids` | every `id="…"`, with occurrence counts |
| `--hrefs PREFIX` | every `href` starting with `PREFIX`, in document order, with counts |
| `--count REGEX` | occurrences of a literal-or-regex `REGEX`, as a single number |
| `--context REGEX` | the 200 characters around each `REGEX` hit, for reading markup by eye |

The counting is regex-based on purpose. `package:html` in the test suite is the
authority for assertions; this tool exists to let a human see the shape of a page
once, cheaply, before writing a selector down by hand. Nothing here parses HTML
correctly, and it does not claim to — a real parser is a Dart dependency that
already exists and a new one here would be a second, worse implementation of the
same thing.
"""

from __future__ import annotations

import argparse
import re
import sys
from collections import Counter
from pathlib import Path

CONTEXT_CHARS = 200


def read(path: Path) -> str:
    """UTF-8 with replacement. The charset the manifest records is utf-8 for every
    capture this project has, and `04-html-to-markdown.md` rule 5 says decode with
    the observed charset rather than assume ASCII — so an undecodable byte becomes
    U+FFFD rather than an exception that hides the page."""
    return path.read_bytes().decode("utf-8", errors="replace")


def report_classes(text: str) -> None:
    counter = Counter(re.findall(r'class="([^"]*)"', text))
    for value, count in counter.most_common():
        print(f"  {count:>6}  class=\"{value}\"")


def report_ids(text: str) -> None:
    counter = Counter(re.findall(r'id="([^"]*)"', text))
    for value, count in counter.most_common():
        print(f"  {count:>6}  id=\"{value}\"")


def report_hrefs(text: str, prefix: str) -> None:
    hrefs = re.findall(r'href="([^"]*)"', text)
    hits = [h for h in hrefs if h.startswith(prefix)]
    print(f"  {len(hrefs)} hrefs total, {len(hits)} starting with {prefix!r}")
    seen: dict[str, int] = {}
    for href in hits:
        seen[href] = seen.get(href, 0) + 1
    for href, count in seen.items():
        print(f"  {count:>6}  {href}")


def report_count(text: str, pattern: str) -> None:
    print(f"  {len(re.findall(pattern, text)):>6}  /{pattern}/")


def report_context(text: str, pattern: str) -> None:
    for index, match in enumerate(re.finditer(pattern, text), start=1):
        start = max(0, match.start() - CONTEXT_CHARS // 2)
        end = min(len(text), match.end() + CONTEXT_CHARS // 2)
        snippet = text[start:end].replace("\n", "\\n")
        print(f"  --- hit {index} at offset {match.start()} ---")
        print(f"  {snippet}")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("fixture")
    parser.add_argument("--classes", action="store_true")
    parser.add_argument("--ids", action="store_true")
    parser.add_argument("--hrefs", metavar="PREFIX")
    parser.add_argument("--count", metavar="REGEX")
    parser.add_argument("--context", metavar="REGEX")
    args = parser.parse_args(argv[1:])

    path = Path(args.fixture)
    if not path.is_file():
        print(f"no fixture at {path}", file=sys.stderr)
        return 2

    text = read(path)
    print(f"{path} — {path.stat().st_size:,} bytes on disk")

    if not any(
        [args.classes, args.ids, args.hrefs, args.count, args.context]
    ):
        args.classes = args.ids = True

    if args.classes:
        print("\nclasses:")
        report_classes(text)
    if args.ids:
        print("\nids:")
        report_ids(text)
    if args.hrefs is not None:
        print(f"\nhrefs starting with {args.hrefs!r}:")
        report_hrefs(text, args.hrefs)
    if args.count is not None:
        print(f"\ncount of /{args.count}/:")
        report_count(text, args.count)
    if args.context is not None:
        print(f"\ncontext around /{args.context}/:")
        report_context(text, args.context)
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
