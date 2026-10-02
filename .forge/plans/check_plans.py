#!/usr/bin/env python3
"""Stricter than coverage-check.js.

`coverage-check.js slice` proves three things: the eleven headings are
present, the slice's rule/edge ids appear *somewhere*, and no section is
empty. It cannot tell whether § 2 is real code or prose, whether § 3 has
every branch, or whether § 7 states a trap in contrast form.

This adds the checks that catch a plan which is complete on paper and
unimplementable in practice — the failure mode the whole Phase 4 review
kept finding in documents that passed every structural gate.

Sections are extracted from the `^## ` heading lines, NOT by
`text.split('## 6.')` — because `### 6.1` contains the substring `## 6.`
at offset 1, which silently cut every section short.
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path('/workspaces/lumen_tale')
PLANS = ROOT / '.forge/plans'
FORGE = Path('/home/codespace/.agents/skills/forge')

# (number, exact heading text as coverage-check.js greps for it)
HEADINGS = [
    (1, "## 1. Résumé"),
    (2, "## 2. Contrats de données"),
    (3, "## 3. Algorithmes critiques"),
    (4, "## 4. Plan composants"),
    (5, "## 5. Gestion d'état"),
    (6, "## 6. Traçabilité des règles"),
    (7, "## 7. Pièges à éviter"),
    (8, "## 8. Dépendances"),
    (9, "## 9. Checklist de tâches"),
    (10, "## 10. Critères d'acceptation"),
    (11, "## 11. Plan de tests"),
]

CONTRAST = re.compile(r'Ne pas\s+\S.*?Le comportement correct', re.S)
DART_SHAPE = re.compile(
    # a type declaration, a member, a signature, or a body — anything that is
    # Dart rather than prose. A signature-only block (§ 2.3 "the contract as
    # 2-4 consumes it") is legitimate, so signatures must count.
    r'\b(class|abstract|final|enum|typedef|sealed|mixin|extension)\b'
    r'|=>|\bvoid main\b'
    r'|\b(Future|Stream|Iterable|Provider|Widget|BuildContext)\b'
    r'|@override'
    r'|^\s*(?:[A-Z]\w*(?:<[^;]*>)?|void|bool|int|double|String)\s+\w+\s*\(',
    re.M)

failures = []
warnings = []


def fail(plan, what):
    failures.append(f'{plan.name}: {what}')


def warn(plan, what):
    warnings.append(f'{plan.name}: {what}')


def sections(text):
    """{number: body} for the eleven `## ` sections."""
    marks = [(m.start(), int(m.group(1)))
             for m in re.finditer(r'^## (\d+)\. ', text, re.M)]
    out = {}
    for idx, (start, num) in enumerate(marks):
        end = marks[idx + 1][0] if idx + 1 < len(marks) else len(text)
        out[num] = text[start:end]
    return out


def empty_subsections(text):
    """A heading is empty only if nothing follows before the next heading of
    the SAME OR HIGHER level. `## 3.` followed by `### 3.1` is not empty."""
    heads = [(m.start(), len(m.group(1)), m.group(2))
             for m in re.finditer(r'^(#{2,4}) (.+)$', text, re.M)]
    out = []
    for i, (start, level, title) in enumerate(heads):
        nxt = None
        for s2, l2, _ in heads[i + 1:]:
            if l2 <= level:
                nxt = s2
                break
        body = text[start + len(title) + level + 1:(nxt if nxt else len(text))]
        if not body.strip():
            out.append(title)
    return out


def check(path, rules, edges, is_foundation):
    text = path.read_text(encoding='utf-8')
    name = path.stem
    secs = sections(text)

    # --- the mechanical gate, run as the tool runs it -------------------
    proc = subprocess.run(
        ['node', str(FORGE / 'scripts/coverage-check.js'), 'slice', str(ROOT), name],
        capture_output=True, text=True)
    try:
        res = json.loads(proc.stdout)
        if not res.get('pass'):
            for c in res.get('checks', []):
                if c.get('status') == 'fail':
                    fail(path, f"coverage-check: {c['check']} — {str(c.get('message'))[:80]}")
    except json.JSONDecodeError:
        fail(path, f'coverage-check produced no JSON: {proc.stdout[:120]}')

    # --- headings present, and in order ---------------------------------
    found = [text.find(h) for _, h in HEADINGS]
    for (num, h), i in zip(HEADINGS, found):
        if i < 0:
            fail(path, f'missing heading {h!r}')
    if all(i >= 0 for i in found) and found != sorted(found):
        fail(path, 'headings are not in the template order')
    for num in range(1, 12):
        if num not in secs:
            fail(path, f'§ {num} could not be extracted')

    # --- nothing empty, at any level ------------------------------------
    for title in empty_subsections(text):
        fail(path, f'empty section: {title[:50]!r}')

    # --- traceability ids must be in § 6, not merely somewhere ---------
    s6 = secs.get(6, '')
    for rid in rules:
        if rid not in text:
            fail(path, f'{rid} absent from the plan entirely')
        elif rid not in s6:
            fail(path, f'{rid} appears but NOT in the § 6 tables')
    for eid in edges:
        if eid not in text:
            fail(path, f'{eid} absent from the plan entirely')
        elif eid not in s6:
            fail(path, f'{eid} appears but NOT in § 6')

    # --- § 2 must contain real Dart -------------------------------------
    # NOT every block: a plan legitimately includes a signature table, a
    # doc-entry template (6-11 writes one into 18-external-contracts.md), or
    # a prose note inside a fence. The requirement is that § 2 contains AT
    # LEAST ONE Dart block that declares real types — otherwise a plan can
    # pass by quoting the architecture in prose.
    s2 = secs.get(2, '')
    fences = re.findall(r'```(\w*)\n(.*?)```', s2, re.S)
    if not fences:
        fail(path, '§ 2 has no code block')
    dart_with_types = [
        body for lang, body in fences
        if lang.lower() == 'dart' and DART_SHAPE.search(body)
    ]
    if not dart_with_types:
        fail(path, '§ 2 has no Dart block declaring a real type — the contracts '
                   'must be code, not the architecture quoted back')

    # --- § 3 must be pseudocode, not prose ------------------------------
    s3 = secs.get(3, '')
    if '```' not in s3:
        fail(path, '§ 3 has no code/pseudocode block')

    # --- § 7 traps in contrast form -------------------------------------
    s7 = secs.get(7, '')
    traps = s7.count('⚠️')
    if traps and not CONTRAST.search(s7):
        fail(path, f'{traps} trap(s) declared, none in contrast form '
                   '(needs "Ne pas X … Le comportement correct")')

    # --- § 10 assertions, each citing an id ------------------------------
    s10 = secs.get(10, '')
    if s10.count('- [ ]') == 0:
        fail(path, '§ 10 has no acceptance criteria')
    elif rules and not set(re.findall(r'\b([BEC]\d+)\b', s10)):
        fail(path, '§ 10 criteria cite no rule id at all')
    for word in ('works well', 'fonctionne bien', 'as expected', 'user-friendly'):
        if word in s10.lower():
            warn(path, f'§ 10 non-verifiable wording: {word!r}')

    # --- § 11 names a test path, OR refuses with a reason ----------------
    # A slice may legitimately have no test: `6-11` measures a live site and
    # `10-testing.md` rule 7 forbids a test that reaches the internet. But
    # "no tests" is exactly the kind of omission that reads as thoroughness,
    # so a bare "Aucun" does not pass — it must be justified AND cite the rule
    # or question it rests on. Otherwise this is gameable by writing one word.
    s11 = secs.get(11, '')
    if 'test/' not in s11:
        has_refusal = re.search(r'\b(Aucun|deliberate|délibéré)\b', s11, re.I)
        cites_basis = re.search(r'\b\d\d-rule\b|\bB\d+\b|\bQ-\d+\b|\bC\d+\b', s11)
        if not (has_refusal and cites_basis):
            fail(path, '§ 11 names no test file path, and does not refuse tests '
                       'with both a stated reason and a cited rule or question')

    # --- ADR-019: no rail, no two-pane, no tablet -----------------------
    for bad in ('NavigationRail', 'NavigationDrawer', 'two-pane'):
        for m in re.finditer(re.escape(bad), text):
            around = text[max(0, m.start() - 150):m.start()].lower()
            if not any(w in around for w in ('not', 'exclu', 'jamais', 'aucun', 'refus')):
                warn(path, f'mentions {bad!r} outside an exclusion — check ADR-019')

    # --- no non-Latin characters -----------------------------------------
    for i, line in enumerate(text.split('\n'), 1):
        for ch in line:
            o = ord(ch)
            if (0x2E80 <= o <= 0x9FFF) or (0x0400 <= o <= 0x04FF) or o == 0xFFFD:
                fail(path, f'non-Latin character {ch!r} at line {i}')
                break

    # --- the project's own four traps -----------------------------------
    if name == '2-3' and 'downloadedAt' not in text:
        fail(path, 'never mentions downloadedAt')
    if name in ('2-3', 'local-store') and not (
            'PRAGMA foreign_keys' in text or 'foreign_keys = ON' in text):
        warn(path, 'touches the database but never mentions the FK pragma')
    if name in ('2-1', '6-1', '6-2') and 'BrowseOutcome' not in text:
        fail(path, 'a source slice that never mentions BrowseOutcome (B22, SC-6)')

    if is_foundation:
        warn(path, 'coverage-check.js cannot verify a foundation (F-003)')


# ══ corpus checks ═══════════════════════════════════════════════════════
# Facts that live in MORE THAN ONE document, where fixing one copy has
# already left the other behind four separate times this project. Each is
# asserted mechanically, because "I fixed it" has meant "I fixed one of
# them" more than once.

# A Source method returning a bare Future<...> cannot distinguish an empty
# result from a failure. B22 and SC-6 are that distinction.
BARE_RETURN = re.compile(r'^\s*Future<(?!BrowseOutcome)')
# The seven contract signatures, as they must appear. Bare variants are
# matched by the regex above; this catches a signature quietly deleted.
CONTRACT_METHODS = [
    'getPopularNovels', 'getLatestNovels', 'searchNovels', 'getNovelUpdate',
    'getNovelDetails', 'getChapterList', 'fetchChapterContent',
]


def check_corpus():
    targets = [
        ROOT / '.forge/architecture.md',
        ROOT / '.opencode/rules/03-source-system.md',
    ]
    for path in targets:
        if not path.exists():
            continue
        for i, line in enumerate(path.read_text(encoding='utf-8').split('\n'), 1):
            # An amendment note quoting the old text is legitimate; a live
            # signature is not. Blockquoted lines are the notes.
            if line.lstrip().startswith('>'):
                continue
            if BARE_RETURN.search(line):
                fail(path, f'line {i}: bare Future<…> return in the Source contract '
                           f'— every method returns BrowseOutcome<T> (B22, SC-6): '
                           f'{line.strip()[:70]!r}')
        text = path.read_text(encoding='utf-8')
        for m in CONTRACT_METHODS:
            if m not in text:
                warn(path, f'contract method {m} does not appear at all')


def main():
    check_corpus()
    state = json.loads((ROOT / '.forge/state.json').read_text())
    wanted = {k: (v.get('rule_ids', []), v.get('edge_case_ids', []), False)
              for k, v in state['slices'].items()}
    wanted.update({k: (v.get('rule_ids', []), [], True)
                   for k, v in state['foundations'].items()})

    only = set(sys.argv[1:]) or None
    clean = missing = 0
    for name, (rules, edges, is_f) in sorted(wanted.items()):
        if only and name not in only:
            continue
        path = PLANS / f'{name}.md'
        if not path.exists():
            missing += 1
            print(f'  --  {name:22} MISSING')
            continue
        before = len(failures)
        check(path, rules, edges, is_f)
        good = len(failures) == before
        clean += good
        print(f'  {"ok  " if good else "FAIL"} {name:22} '
              f'{len(path.read_text().splitlines()):4} lines')

    print()
    if warnings:
        print(f'{len(warnings)} warning(s):')
        for w in warnings:
            print('  ~', w)
        print()
    if failures:
        print(f'{len(failures)} FAILURE(S):')
        for f in failures:
            print('  ✗', f)
    else:
        print('no failures')
    print(f'\n{clean} clean · {missing} missing · {len(failures)} failure(s) '
          f'· {len(warnings)} warning(s)')


if __name__ == '__main__':
    main()
