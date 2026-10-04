#!/usr/bin/env python3
"""Lumen Tale — capture one site's real pages into its fixture folder.

**What this is for, and what it is not.** Slice `0-1` (§ 3.1) freezes real HTML so
the source contract is written and tested against bytes a server actually returned,
rather than against prose in a rules file. This is the **fetch** half of that
procedure; `tool/build_manifest.py` is the **measure** half. Between them they
replace the "run these curl commands by hand" paragraph — not its judgement.

It **fetches and saves**. It does not parse, clean, normalise, pretty-print,
rewrite a selector, retry a challenge, or invent a page. Every byte written here is
what the server sent.

## The three promises this file keeps

1. **Honest client.** The User-Agent is a plain `LumenTale/<version> (personal
   reader)`. It is never a browser's. ADR-014 measured the difference: a browser UA
   is *refused* on paths the honest one is allowed through, which means a browser UA
   turns a permitted read into an act of impersonation and still gets less.
2. **Permission before traffic.** `robots.txt` is read first and its
   `User-agent: *` block is evaluated per path. A disallowed path is refused before
   a socket is opened — C1: permission is a gate, not a negotiation.
3. **Polite.** A fixed delay between requests, `Retry-After` honoured exactly,
   `429` waited once, `5xx` retried once, and **`403` is a stop, never an attempt to
   get past it**. Defeating a challenge is not rate-limit politeness; it is an
   attack, and § 3.1's table ends that branch with "STOP".

## Usage

    python3 tool/capture.py <site> [--probe] [--only KEY] [--delay SECONDS]

Reads `test/fixtures/sources/<site>/manifest.in.json`, fetches the `url` of every
entry whose path is already discovered, and writes each body to `file`.

| Flag | Effect |
|---|---|
| `--probe` | Fetch every URL and report status/size/content-type. **Writes nothing.** This is the re-measurement table for `18-external-contracts.md`, and the only mode to use when deciding whether a path still exists. |
| `--delay S` | Seconds between requests. Default 3.0 — roughly one request per page of reading, not a burst. |
| `--timeout S` | Per-request timeout. Default 30. |
| `--only KEY` | Capture only the named manifest keys; repeatable. Discovery is cheap when it is two requests instead of thirteen, and re-requesting thirteen paths to add two is traffic nobody asked the site for. |
| `--path P` | Probe one extra **discovered** path through the same permission gate and report status/size. **Writes nothing.** Repeatable. This is how a "à découvrir" line is closed: the parameter is read off a real href, and a probe leaves no file behind so nothing merely looked at becomes a fixture. |
| `--extract RE` | With `--path`, print every match of `RE` in the probed body. Reading a real page to discover what it publishes, at the cost of a request and no file. |

Entries whose `url` is not already a discovered path (a template like
`/list/<genre>/<sort>-0.html`, or a prose `REPLACE: …` line) are **refused**:
§ 7 forbids manufacturing a fixture for a line marked "à découvrir", and a path
invented from a template is exactly that, one level up.

## The five refusal branches

Every one of them comes from § 3.1's table, including its exits:

| Situation | Behaviour | Why that is correct |
|---|---|---|
| `429` + `Retry-After` | wait exactly that long, retry **once** | `17-security.md` rule 6 |
| `429` again | STOP that path | A site that answers twice is telling us something |
| `403` | STOP, record it | The site is declining. ADR-014 forbids the bypass |
| `5xx` | retry **once** after 60 s, then STOP | two `5xx` is the site falling over, not noise |
| path `disallowed` by robots.txt | **no request is issued** | C1 |
| body is not `2xx`-shaped HTML we asked for | saved anyway, `httpStatus` recorded | a `404` on a search path is `search-failure`, the *data* |

The last row is the one that matters for a reader of the output: this tool saves a
non-success status rather than hiding it, because `0-2` needs B22's third state as
evidence, and a tool that refused to save it would make that slice unfalsifiable.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from pathlib import Path

FIXTURES = Path("test/fixtures/sources")

# ADR-014, `17-security.md` rule 5. Honest, versioned, and saying exactly what we
# are: one reader, personal use, no account, no redistribution.
USER_AGENT = "LumenTale/0.1.0 (personal reader)"

DEFAULT_DELAY = 3.0
DEFAULT_TIMEOUT = 30.0
RETRY_AFTER_CAP = 120.0
SERVER_ERROR_WAIT = 60.0

# ⚠️ A `url` must be a PATH (`03-source-system.md` rules 2-3) AND it must already be
# DISCOVERED. The test for "discovered" is that it starts with `/`: a template line
# reads `/list/<genre>/<sort>-0.html` or the prose `REPLACE: the href that ...`,
# and neither is a path. The first draft of this check looked for `<` and `>`, which
# caught templates but let every `REPLACE: ...` string through to the socket layer,
# where `urllib` died on a colon it thought was a port number.
#
# ⚠️ The failure was loud, not silent — a stack trace rather than a wrong capture —
# but "loud" is not the standard. The refusal has to be the one at the spec-reading
# stage, because that is where the reason can still name the rule that was broken.
UNRESOLVED = re.compile(r"[<>\s]|REPLACE:|://")


class Refusal(Exception):
    """A reason not to write a fixture."""


def iso_now() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


# ── the permission gate ────────────────────────────────────────────────────


def robots_rules(body: str) -> dict[str, list[str]]:
    """The `User-agent: *` block of a robots.txt, as allow/disallow path prefixes.

    Only the `*` group is read, and that is deliberate rather than lazy: a named
    group for an agent we are not is a group that does not govern us, and pretending
    otherwise would make the gate answer a question nobody asked. `Allow` entries
    win over `Disallow`, which is the more specific of the two on every crawler
    implementation and is the reading RFC 9309 gives.
    """
    allow: list[str] = []
    disallow: list[str] = []
    in_star = False
    for raw in body.splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line or ":" not in line:
            continue
        field, _, value = line.partition(":")
        field = field.strip().lower()
        value = value.strip()
        if field == "user-agent":
            in_star = value == "*"
        elif field == "allow" and in_star and value:
            allow.append(value)
        elif field == "disallow" and in_star and value:
            disallow.append(value)
    return {"allow": allow, "disallow": disallow}


def is_disallowed(rules: dict[str, list[str]], path: str) -> str | None:
    """The rule that forbids [path], or `None`.

    Longest-match wins, and an empty `Disallow:` is ignored — `Disallow:` with no
    value means *allow everything*, which a naive prefix test reads as "forbid
    nothing after the slash" only by accident. Getting this backwards would refuse
    the whole site.
    """
    allow_hits = [r for r in rules["allow"] if path.startswith(r)]
    disallow_hits = [r for r in rules["disallow"] if path.startswith(r)]
    if not disallow_hits:
        return None
    if allow_hits and max(len(a) for a in allow_hits) >= max(
        len(d) for d in disallow_hits
    ):
        return None
    return max(disallow_hits, key=len)


def fetch(url: str, timeout: float) -> tuple[int, bytes, str, dict[str, str]]:
    """One GET. Returns `(status, body, content_type, headers)`; never raises on 4xx.

    Only transport failures raise. A `403` is a *result*, and a result is what this
    slice records.
    """
    request = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    try:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            return (
                response.status,
                response.read(),
                response.headers.get("Content-Type", ""),
                dict(response.headers.items()),
            )
    except urllib.error.HTTPError as exc:
        # An HTTPError still carries the body and the headers — and for this slice
        # the body of a 404 search page IS the fixture.
        return (
            exc.code,
            exc.read(),
            exc.headers.get("Content-Type", "") if exc.headers else "",
            dict(exc.headers.items()) if exc.headers else {},
        )


def fetch_politely(url: str, timeout: float) -> tuple[int, bytes, str, dict[str, str]]:
    """[fetch], plus the three waits § 3.1 requires. Raises on a hard STOP."""
    status, body, ctype, headers = fetch(url, timeout)
    if status == 429:
        delay = retry_after_seconds(headers)
        print(f"    429 — waiting {delay:.0f}s (Retry-After), once")
        time.sleep(delay)
        status, body, ctype, headers = fetch(url, timeout)
        if status == 429:
            raise Refusal("429 twice — the site is asking us to stop; STOP")
    if status == 403:
        raise Refusal(
            "403 — the site is declining this request. We do not attempt to get "
            "past it; record it in 18-external-contracts.md instead."
        )
    if 500 <= status < 600:
        print(f"    {status} — waiting {SERVER_ERROR_WAIT:.0f}s, retry once")
        time.sleep(SERVER_ERROR_WAIT)
        status, body, ctype, headers = fetch(url, timeout)
        if 500 <= status < 600:
            raise Refusal(f"{status} twice — the site is falling over; STOP")
    return status, body, ctype, headers


def retry_after_seconds(headers: dict[str, str]) -> float:
    """`Retry-After`, in seconds — the *exact* duration, capped so a hostile value
    cannot hang the session forever.

    The cap is a refusal, not a compromise: a `Retry-After` longer than the cap
    means the site's answer is "come back much later", and the honest reading of
    that is to stop, not to retry early.
    """
    raw = headers.get("Retry-After") or headers.get("retry-after")
    if raw is None:
        return RETRY_AFTER_CAP
    try:
        value = float(raw)
    except ValueError:
        return RETRY_AFTER_CAP
    if value < 0 or value > RETRY_AFTER_CAP:
        raise Refusal(
            f"Retry-After: {raw} is longer than the {RETRY_AFTER_CAP:.0f}s cap — "
            "the site is saying 'come back much later', so we stop"
        )
    return value


# ── the run ────────────────────────────────────────────────────────────────


def capture_site(
    site: str,
    probe: bool,
    delay: float,
    timeout: float,
    only: list[str] | None = None,
) -> int:
    root = FIXTURES / site
    spec_path = root / "manifest.in.json"
    if not root.is_dir():
        print(f"  no fixture folder at {root}", file=sys.stderr)
        return 1
    if not spec_path.exists():
        print(f"  no manifest.in.json at {spec_path}", file=sys.stderr)
        return 1

    spec = json.loads(spec_path.read_text(encoding="utf-8"))
    base_url = spec.get("baseUrl", "")
    entries = spec.get("entries", [])
    if not entries:
        print("  manifest.in.json declares no entries", file=sys.stderr)
        return 1

    robots_path = next(
        (e["url"] for e in entries if e.get("kind") == "robots"), "/robots.txt"
    )
    print(f"  permission gate: {base_url}{robots_path}")
    _, robots_body, _, _ = fetch(f"{base_url}{robots_path}", timeout)
    rules = robots_rules(robots_body.decode("utf-8", errors="replace"))
    print(
        f"    User-agent: * allow={rules['allow'] or 'all'} "
        f"disallow={rules['disallow'] or 'none'}"
    )

    failures = 0
    for raw in entries:
        key = raw.get("key", "<missing>")
        url = raw.get("url", "")
        file = raw.get("file", "")
        if only and key not in only:
            continue
        if not url.startswith("/") or UNRESOLVED.search(url):
            print(
                f"    {key:34} SKIPPED — url {url!r} is not a discovered path. "
                "Section 7 forbids inventing this path; find it on a real page "
                "first."
            )
            continue

        if raw.get("kind") == "manufactured":
            # ⚠️ A manufactured artefact is NEVER fetched. Section 3.2 builds it from a
            # capture already on disk with one substitution applied; re-fetching it here
            # would replace a byte-for-byte copy with a second independent request, and
            # the whole test the artefact exists for is that it differs from its source
            # by EXACTLY one edit. Two requests differ by zero edits at best.
            print(
                f"    {key:34} NOT FETCHED — kind=manufactured. It is derived from a "
                "capture already on disk, never re-requested."
            )
            continue

        forbidden = is_disallowed(rules, url)
        if forbidden is not None:
            failures += 1
            print(
                f"    {key:34} REFUSED — robots.txt disallows {forbidden!r} and "
                f"{url} falls under it. No request was issued."
            )
            continue

        try:
            status, body, ctype, headers = fetch_politely(
                f"{base_url}{url}", timeout
            )
        except Refusal as exc:
            failures += 1
            print(f"    {key:34} STOPPED — {exc}")
            continue
        except OSError as exc:
            failures += 1
            print(f"    {key:34} ERROR — {exc}")
            continue

        size = len(body)
        print(
            f"    {key:34} {status} {size:>9,} bytes  {ctype.split(';')[0].strip()}"
            f"  {url}"
        )
        if probe:
            continue

        if file:
            (root / file).write_bytes(body)
            print(f"      wrote {root / file}")
        time.sleep(delay)

    if not probe:
        print(
            "  capture done — run python3 tool/build_manifest.py "
            f"{site} to measure bytes and sha256"
        )
    return 1 if failures else 0


def probe_paths(
    site: str,
    paths: list[str],
    rules: dict[str, list[str]],
    timeout: float,
    extract: str | None,
) -> int:
    """Fetch each [paths] through the same permission gate and report. Writes nothing.

    This is the discovery step of section 3.3's "à découvrir" lines: the parameter
    is **read off a real href**, so a request has to be made to see it. It is a
    probe and not a capture because a discovered path is not a fixture until the
    owner decides it is worth freezing — a probe leaves no file, so nothing that
    was merely looked at ends up asserted against.

    [extract], when given, prints every regex match in the body. It is what closes
    `chapter-short`: the chapter an E22 fixture must be is found by *reading the
    titles a list page publishes*, and scanning seventeen list pages by hand through
    a browser is not a procedure C5's owner can carry out. Sixteen probes that write
    nothing are the cheap version of the same question.
    """
    failures = 0
    base_url = json.loads(
        (FIXTURES / site / "manifest.in.json").read_text(encoding="utf-8")
    ).get("baseUrl", "")
    pattern = re.compile(extract) if extract else None
    for path in paths:
        if not path.startswith("/"):
            print(f"    {path[:70]:70} REFUSED — not a path")
            failures += 1
            continue
        forbidden = is_disallowed(rules, path)
        if forbidden is not None:
            print(f"    {path[:70]:70} REFUSED — robots.txt disallows {forbidden!r}")
            failures += 1
            continue
        try:
            status, body, ctype, _ = fetch_politely(f"{base_url}{path}", timeout)
        except Refusal as exc:
            print(f"    {path[:70]:70} STOPPED — {exc}")
            failures += 1
            continue
        except OSError as exc:
            print(f"    {path[:70]:70} ERROR — {exc}")
            failures += 1
            continue
        print(
            f"    {path[:70]:70} {status} {len(body):>9,} bytes  "
            f"{ctype.split(';')[0].strip()}"
        )
        if pattern is not None:
            text = body.decode("utf-8", errors="replace")
            matches = pattern.findall(text)
            print(f"      {len(matches)} match(es) of /{extract}/:")
            for match in matches:
                print(f"        {match if isinstance(match, str) else match!r}")
        time.sleep(DEFAULT_DELAY)
    return 1 if failures else 0


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("site")
    parser.add_argument(
        "--probe",
        action="store_true",
        help="report status/size/content-type only; write nothing",
    )
    parser.add_argument("--delay", type=float, default=DEFAULT_DELAY)
    parser.add_argument("--timeout", type=float, default=DEFAULT_TIMEOUT)
    parser.add_argument(
        "--only",
        action="append",
        default=[],
        metavar="KEY",
        help="capture only the named manifest keys; repeatable",
    )
    parser.add_argument(
        "--extract",
        metavar="REGEX",
        help="with --path, print every match of REGEX in each probed body — the "
        "read-a-real-page-to-discover step, without leaving a fixture behind",
    )
    parser.add_argument(
        "--path",
        action="append",
        default=[],
        metavar="PATH",
        help="probe one extra discovered path through the permission gate, "
        "writing nothing; repeatable",
    )
    args = parser.parse_args(argv[1:])

    print(f"capturing {args.site} (user-agent: {USER_AGENT})")
    if args.path:
        spec = json.loads(
            (FIXTURES / args.site / "manifest.in.json").read_text(encoding="utf-8")
        )
        robots_path = next(
            (
                e["url"]
                for e in spec.get("entries", [])
                if e.get("kind") == "robots"
            ),
            "/robots.txt",
        )
        base = spec.get("baseUrl", "")
        _, robots_body, _, _ = fetch(f"{base}{robots_path}", args.timeout)
        rules = robots_rules(robots_body.decode("utf-8", errors="replace"))
        print(
            f"  permission gate: allow={rules['allow'] or 'all'} "
            f"disallow={rules['disallow'] or 'none'}"
        )
        print("  probing discovered paths (nothing is written):")
        return probe_paths(
            args.site, args.path, rules, args.timeout, args.extract
        )
    return capture_site(
        args.site, args.probe, args.delay, args.timeout, args.only or None
    )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
