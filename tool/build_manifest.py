#!/usr/bin/env python3
"""Lumen Tale — build a fixture manifest from files dropped into a fixture folder.

**What this is for.** Slice `0-1` captures one site's real pages so the source
contract can be written and tested against them rather than against prose. Most
sites answer an honest User-Agent and the capture is a plain `curl`. A site behind
a Cloudflare interstitial does not, and the legitimate route is for the **owner**
to open the page in their own browser and save it. This script turns that drop
into a manifest: it measures, it hashes, and it refuses anything it should.

It does not fetch, does not bypass, and does not invent. Every value it writes is
either measured from a file on disk or supplied by the owner.

## Usage

    python3 tool/build_manifest.py <site> [more sites...]

Reads `<site>/<file>` for each entry already described in
`test/fixtures/sources/<site>/manifest.in.json`, writes
`manifest.json`, and refuses to write on any failed check.

## The input file

`manifest.in.json` is a thin description — the fields a human knows:

```json
{
  "baseUrl": "https://www.fanmtl.com",
  "capturedBy": "0-1",
  "entries": [
    {
      "key": "robots",
      "file": "robots.txt",
      "url": "/robots.txt",
      "httpStatus": 200,
      "contentType": "text/plain; charset=utf-8",
      "kind": "robots",
      "notes": "The site's own robots.txt, saved verbatim.",
      "expected": {}
    }
  ]
}
```

**`bytes` and `sha256` are deliberately ABSENT and deliberately not asked for.**
They are measured here, from the file, so they cannot disagree with it. A
hand-typed length is a promise; a measured one is a fact.

## What it refuses, and why each refusal exists

| Refusal | Rule |
|---|---|
| `bytes`/`sha256` supplied in the input | They must be measured. A hand-typed hash is a promise about a file, and § 3.2 makes `bytes` the ONE field an automatic guard asserts. |
| `url` containing `://` | `03-source-system.md` rules 2-3. A stored absolute URL breaks silently when the host changes. |
| `kind` outside the closed list | § 2.2. A free string becomes a taxonomy nobody maintains. |
| `capturedAt` not ISO 8601 UTC | `18-external-contracts.md` rule 1 — provenance. |
| empty `notes` | § 2.2. `notes` records what was OBSERVED, not a workaround. |
| a file containing a session cookie | C2, B4. A committed session token is the one artefact that can carry reading data off the phone. |
| `Chrome HTML saved` wrapper detected | A browser's "save page" preamble is **not** the site's bytes. Measuring it would record a length and a hash of Chrome's wrapper, and every assertion downstream would be about the wrapper. |
| a `.mht`/`.mhtml` file | MHTML is a MIME envelope. It must be unwrapped to HTML before it can be a fixture, and unwrapping by hand is an edit nobody recorded. |

## The browser-save trap, which is why the last two refusals exist

Chrome's *Save page as* has three modes and only one is usable:

- **Webpage, HTML Only** — one clean file of the site's bytes. **Use this.**
- **Webpage, Single File** — the page with every resource inlined. The prose is
  present but the bytes are not what the server sent, so `bytes` measures
  something no request will ever return again.
- **Webpage, Complete** — one file plus a sibling folder of assets, which lands in
  git.

MHTML (`.mht`) is the same problem in an envelope.

A browser-saved page is a **legitimate reader's view** — the owner read it in
their own browser and saved what they were shown. That is the right provenance and
`capturedBy` records it. What it must not become is a silent claim that these bytes
came off the wire unmodified.
"""

from __future__ import annotations

import hashlib
import json
import re
import sys
from datetime import datetime, timezone
from pathlib import Path

FIXTURES = Path("test/fixtures/sources")

# § 2.2 — the closed list. Mirrored here rather than imported, because this is a
# build-time tool and the Dart constant is the runtime authority; the test suite
# asserts the two agree.
KINDS = {
    "robots",
    "genre-index",
    "catalogue",
    "novel-detail",
    "chapter-list",
    "chapter",
    "failure-page",
    "manufactured",
}

# C2, B4. Lower-cased before comparison.
SESSION_MARKERS = (
    "set-cookie",
    "sessionid",
    "phpsessid",
    "jsessionid",
    "cf_clearance",
    "csrf",
    "bearer ",
)

# Chrome writes these into "HTML Only" saves on some versions.
# Chrome's save wrapper. Matched as a bare substring anywhere in the head, NOT as
# an adjacency: the first version required `<!doctype html>` immediately followed
# by the comment, and Chrome emits the comment FIRST, so a real browser save was
# accepted. A wrapper check that only fires on one exact byte sequence is not a
# check.
WRAPPER_MARKERS = (
    "saved by chrome",
    "chrome html saved",
    "<!-- saved by",
)

ISO = re.compile(r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$")

MEASURED = ("bytes", "sha256")


class Refusal(Exception):
    """A reason not to write the manifest. Carries every reason, not just the first."""


def _fail(problems: list[str]) -> None:
    raise Refusal("\n".join(f"  - {p}" for p in problems))


def measure(path: Path) -> tuple[int, str]:
    raw = path.read_bytes()
    return len(raw), hashlib.sha256(raw).hexdigest()


def sniff_content_type(path: Path, declared: str) -> str:
    """Trust the declared type, but catch the case where it is obviously wrong.

    A `text/plain` declaration on a file starting with `<!DOCTYPE html` would let a
    parser pick the wrong decoder, and § 04-html-to-markdown.md rule 5 is explicit
    that the charset must come from the response rather than an assumption.
    """
    head = path.read_bytes()[:512].lstrip().lower()
    looks_html = head.startswith(b"<!doctype html") or head.startswith(b"<html")
    if looks_html and "text/html" not in declared:
        return f"text/html; charset={_declared_charset(declared) or 'utf-8'}"
    return declared


def _declared_charset(declared: str) -> str | None:
    m = re.search(r"charset=([\w-]+)", declared, re.I)
    return m.group(1) if m else None


def build(site: str) -> Path:
    root = FIXTURES / site
    if not root.is_dir():
        _fail([f"{site}: no fixture folder at {root}"])

    source = root / "manifest.in.json"
    if not source.exists():
        _fail([f"{site}: no manifest.in.json at {source}"])

    spec = json.loads(source.read_text(encoding="utf-8"))
    problems: list[str] = []

    # `capturedAt` is read from the TOP LEVEL of the spec, so it must be validated
    # there. Validating it only inside the per-entry loop meant a malformed
    # top-level value was never examined — a probe supplying `"yesterday"` at the
    # top level was ACCEPTED while the same value on an entry was refused. The two
    # placements are not equivalent, and only one of them was checked.
    if "capturedAt" in spec and not ISO.match(str(spec["capturedAt"])):
        problems.append(
            f"capturedAt {spec['capturedAt']!r} is not ISO 8601 UTC "
            f"(YYYY-MM-DDThh:mm:ssZ). Omit the key to have it stamped now."
        )

    entries: list[dict] = []
    seen_keys: set[str] = set()
    seen_files: set[str] = set()

    for raw in spec.get("entries", []):
        key = raw.get("key", "<missing>")
        file = raw.get("file", "")

        # ── the fields that must NOT be supplied ──────────────────────────
        supplied = [f for f in MEASURED if f in raw]
        if supplied:
            problems.append(
                f"{key}: {', '.join(supplied)} must not be supplied. They are "
                f"MEASURED from the file; a hand-typed hash is a promise about "
                f"a file, and section 3.2 makes `bytes` the one field an "
                f"automatic guard asserts."
            )

        if key in seen_keys:
            problems.append(f"{key}: duplicate key in manifest.in.json")
        seen_keys.add(key)

        if file in seen_files:
            problems.append(f"{file}: declared by more than one entry")
        seen_files.add(file)

        # ── the fields a human must supply ─────────────────────────────────
        for required in ("key", "file", "url", "httpStatus", "kind", "notes"):
            if required not in raw:
                problems.append(f"{key}: missing required field '{required}'")

        url = raw.get("url", "")
        if "://" in url:
            problems.append(
                f"{key}: url is absolute ('{url}'). Rule 2/3 of "
                f"03-source-system.md stores a path, never a full URL."
            )

        kind = raw.get("kind", "")
        if kind not in KINDS:
            problems.append(
                f"{key}: kind '{kind}' is not in the closed list {sorted(KINDS)}"
            )

        notes = raw.get("notes", "")
        if not notes.strip():
            problems.append(
                f"{key}: notes is empty. It records what was OBSERVED, not a "
                f"workaround, and an empty string is forbidden."
            )

        # Per-entry override, if the human wants one (a fixture re-captured on a
        # different day). Same rule as the top level: supplied means it must be
        # well formed. The first version guarded this with `is not None`, which
        # meant OMITTING the key skipped the check entirely.
        if "capturedAt" in raw and not ISO.match(str(raw["capturedAt"])):
            problems.append(
                f"{key}: capturedAt {raw['capturedAt']!r} is not ISO 8601 UTC "
                f"(YYYY-MM-DDThh:mm:ssZ). Omit the key to have it stamped now."
            )

        # ── the file itself ────────────────────────────────────────────────
        path = root / file
        if not path.exists():
            problems.append(f"{key}: {file} is declared but absent from {root}")
            continue

        if path.suffix.lower() in (".mht", ".mhtml"):
            problems.append(
                f"{key}: {file} is MHTML, a MIME envelope rather than HTML. "
                f"Save as 'Webpage, HTML Only' instead."
            )
            continue

        size, digest = measure(path)
        body = path.read_bytes().decode("utf-8", errors="replace")
        lowered = body.lower()

        for marker in SESSION_MARKERS:
            if marker in lowered:
                problems.append(
                    f"{key}: {file} appears to contain '{marker}'. C2 and B4 "
                    f"forbid a session token in a committed fixture. If this is "
                    f"inlined page CONTENT rather than a real header, say so in "
                    f"notes and remove the value."
                )
                break

        head = body[:2048].lower()
        for marker in WRAPPER_MARKERS:
            if marker in head:
                problems.append(
                    f"{key}: {file} carries a browser's save wrapper ('{marker}'). "
                    f"That is not the bytes the server sent, so `bytes` would "
                    f"measure Chrome's preamble. Use 'Webpage, HTML Only'."
                )
                break

        declared_type = raw.get("contentType") or sniff_content_type(path, "")
        entries.append(
            {
                "key": key,
                "file": file,
                "url": url,
                "httpStatus": raw.get("httpStatus", 200),
                "contentType": sniff_content_type(path, declared_type),
                "capturedAt": raw.get("capturedAt")
                or datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "bytes": size,
                "sha256": digest,
                "kind": kind,
                "expected": raw.get("expected", {}),
                "notes": notes.strip(),
            }
        )

    if problems:
        _fail(problems)

    manifest = {
        "site": site,
        "baseUrl": spec.get("baseUrl", ""),
        "capturedBy": spec.get("capturedBy", "0-1"),
        "capturedAt": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "entries": entries,
    }
    out = root / "manifest.json"
    out.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    total = sum(e["bytes"] for e in entries)
    print(f"  {site}: {len(entries)} entries, {total:,} bytes -> {out}")
    for e in entries:
        print(f"    {e['key']:38} {e['bytes']:>9,}  {e['kind']}")
    return out


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        print("usage: build_manifest.py <site> [site...]", file=sys.stderr)
        return 2

    failures = 0
    for site in argv[1:]:
        print(f"building manifest for {site}")
        try:
            build(site)
        except Refusal as exc:
            print(f"  REFUSED — nothing written:\n{exc}", file=sys.stderr)
            failures += 1
        except (OSError, json.JSONDecodeError) as exc:
            print(f"  ERROR: {exc}", file=sys.stderr)
            failures += 1
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))