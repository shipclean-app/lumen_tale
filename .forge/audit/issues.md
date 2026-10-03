# Incident log — Lumen Tale

> **Origin** column: `forge` = the skill guided this badly · `project` = the plan,
> the PRD or the architecture was ambiguous · `environment` = a site, a device or
> a toolchain moved.
>
> **A control is not validated until it has been seen to fail.** Every row below
> that names a control records what that control reported **before** it existed,
> or what it failed to catch while it did.

---

## 2026-10-03 — `state.js finding` minted a duplicate finding id

**Origin**: forge
**Severity**: critique
**Status**: fixed in the skill, 2026-10-03

### Symptom

Preparing to raise the fifteenth finding on this project, `state.js finding`
allocated **`F-014`** — an id that already existed.

### Cause

`state.findings.length + 1` for the next number. That expression is only the
highest id when ids are dense and none has ever been retired. This project's
findings had a gap (`F-011` never allocated) and one entry kept after being
resolved (`F-007`, 2026-09-28), so `length` was 13 while the highest id was 14.

```
entries: 13 | highest: F-014 | naive length+1 -> F-014 | COLLIDES: true
gap present (F-011 absent): true
resolved-but-kept: F-007
```

### Why it is expensive

Nothing reports the collision, because both writes succeeded. From that point
`--resolve F-014` marks whichever finding was found first, the second stays open
for ever, and every reference to `F-014` — in this file, in a rule file, in a
plan — becomes ambiguous and stays ambiguous.

### Fix

`scripts/state.js`, `cmdFinding`:

1. The next number is now **max(existing ids) + 1**, parsed from the ids
   themselves, plus a `while` that skips any id already present. The `while` is
   redundant with the max and is kept deliberately: it makes the collision
   *impossible to write* rather than merely unlikely.
2. `--resolve` stamps `retired_at`. The entry is **kept** on resolve, and keeping
   it is the tombstone — deleting it would release the id, which is the opposite
   of a cleanup. `retired_at` makes that legible in `state.json` without opening
   the script.

### Proof it was validated, not just written

A witness on each side, as `SKILL.md` requires:

| | Evidence |
|---|---|
| **fails before** | the arithmetic above: 13 entries, gap present, `length + 1` = `F-014` = an id in use |
| **passes after** | the same command on the same state returned **`F-015`**, and the probe entry was then removed from `state.json` |

The probe is absent from `state.json`; its `finding_raised` line is still in
`audit/run-log.jsonl`, because the log is append-only and the probe did happen.

---

## 2026-10-03 — the tracking file said four slices had **zero** tests; they had 138

**Origin**: forge
**Severity**: critique
**Status**: fixed in the skill, 2026-10-03

### Symptom

`consistency-check.js all` reported four slices `validated` with
`test_count: 0` and the detail *« aucun fichier de test ne porte le nom de la
slice »*. Their real counts: `0-2` **27**, `0-3` **24**, `2-6` **41**, `6-3`
**46**.

### Cause — two causes, and the second is the expensive one

1. **The heuristic.** `path.basename(f).includes(sliceName)` requires the test
   **file name** to contain the slice key. `royalroad_pagination_test.dart` does
   not contain `0-3`. The comment above the code promised *« ou un test qui la
   cite »* and the second branch was never written.
2. **The fact had two representations.** `state.js` and `consistency-check.js`
   each carried their own copy, with **different regexes**. They did not agree,
   and nothing reconciled them.

A tracking file that is false is worse than no tracking file: it produces either
work already done redone, or a report claiming *this project has no tests*.

### Fix

`L.countSliceTests(root, sliceName)` in `scripts/lib/forge-lib.js` — one
implementation, both branches, called by both scripts. Word-boundary regex
(`0-2` must not match `0-20`). Exports `test_files` so the reader sees which
files were counted.

### Proof, in both directions

| | Evidence |
|---|---|
| **fails before** | the defect reinstated temporarily: `attendu F-010 (max+1), obtenu F-003 — c'est length + 1 : un identifiant deja utilise` |
| **passes after** | `selftest.js` → **228 passed**, 8 skipped, 0 failed |

The selftest also carries a **clean witness**: a slice no test mentions still
returns `0`. Without it the citation branch could count anything and the check
would still be green — a control that cannot fail proves nothing.

---

## 2026-10-03 — four guards that reported the truth as failure, or the reverse

**Origin**: forge
**Severity**: majeur
**Status**: fixed in the skill, 2026-10-03

### 1. `register` accepted a second key for one path

`.forge/design/design-system.md` was registered under `design-system` **and**
`design_system`, with two different `content_hash`. Registering one did not
update the other; the other drifted, and `forge-guard` announced
`content_hashes_current` in failure — **a wrong diagnosis**, which sends a reader
looking for an editor when the defect is a double registration.

Now refused, with the existing key named. Witness on both sides: the refusal
leaves `state.json` byte-identical, and re-registering the *canonical* key still
passes.

### 2. `forge-guard version_pins_agree` read a build directory

`.dart_tool/package_graph.json` carries `"version": "…"` per resolved package.
The JSON pattern read the **field name** as a package name and declared 27
versions of 27 unrelated packages to be in conflict on a package named `version`,
on a tree whose `pubspec.lock` is untouched. A check that can never pass is a
check nobody reads — and, worse, one a genuine conflict hides behind.

Fixed by skipping generated directories **and** by admitting a JSON-sourced name
only when it is declared in `pubspec.yaml` / `package.json`. Three witnesses:

| Witness | Expected | Got |
|---|---|---|
| real conflict + `.dart_tool` noise | `fail`, on the real conflict only | `fail`, `go_router 17.0.1 / 18.0.2`, no `version` package |
| clean tree | `pass` | `pass`, 0 conflicts |
| **no manifest at all** | still `fail` — the filter must not blind the check | `fail`, same conflict |

### 3. `consistency-check section_references` could not pass

`.opencode/rules/` and `.forge/plans/` were absent from the reference index, so a
document citing a rule file was reported as pointing at nothing.

The index now walks both trees recursively — 113 files, **3 843 references
resolved**. That turned two *false* unknowns into two *true* broken pointers,
which is the correct verdict and which were then fixed:

| Broken pointer | Reality | Fixed to |
|---|---|---|
| `2-2.md:784` → `18-external-contracts.md` § 7 | that file has no § 7; the question was this plan's own | `2-2.md` § 7, question 2 |
| `6-6.md:551` → `06-database.md` § 4.7 | that file has only § 1, § 2, § 3 | `06-database.md` § Rules, rule 7 |

Both were amended with `--reason`, not edited in place, and both plans were
re-registered so their hashes match.

### 4. `selftest.js` failed for a reason that was not its subject

`require(<skill>/../../package.json)` throws `MODULE_NOT_FOUND` when the skill is
installed standalone — which is how it is distributed. One assertion crashed on a
Node stack trace instead of saying what it would have checked. Now it skips, and
**says it skipped**: `skip` is not `pass`, and a test that fails for an unrelated
reason is a test that teaches you to switch failures off.

---

## 2026-10-03 — `2-1` § 3.1's displayed derivation contradicts its own frozen constant

**Origin**: project
**Severity**: majeur
**Status**: decided and implemented, 2026-10-03

The plan writes `novel.id = md5('f321cc5e…31//novel/ke383028.html')` — **two**
slashes — beside the frozen constant `90db9662f191bf2418033ab0bee1e629`, which is
the digest of the **one**-slash string. Checked:

```
md5(sid + "//novel/ke383028.html")   = 071603bb7a4d297df4f11b34ed4e55bd   ← not the plan's value
md5(sid + "/novel/ke383028.html")    = 90db9662f191bf2418033ab0bee1e629   ← the plan's value
md5(nid + "/novel/ke383028_1.html")  = 3003a98742f53c4b4f2ae62d8105a4e9   ← the plan's value
```

**The constant is the authority** — it was computed; the displayed string was
written by hand. `SourceId` therefore strips leading slashes from the relative
url before hashing, so `/novel/x.html` and `novel/x.html` cannot mint two ids for
one novel. Without it the derivation has two shapes and no gate distinguishes
them: one novel, two ids, and nothing reports it.

Both shapes are pinned by `test/domain/sources/source_id_test.dart`.

---

## 2026-10-03 — commit `b49c11e` shipped a tree that does not analyse

**Origin**: project
**Severity**: critique
**Status**: repaired in the next commit

### Symptom

`flutter analyze` reported **18 errors** on a clean working tree at commit
`b49c11e` ("feat(7-2): source contract returns BrowseOutcome<T> everywhere"). All
18 were `uri_does_not_exist` / `undefined_class` / `non_type_as_type_argument`
for the five files `lib/domain/sources/source.dart` imports:
`models/novel.dart`, `models/chapter.dart`, `models/novels_page.dart`,
`models/update.dart`, `models/filter.dart`.

### Cause

The commit added `source.dart` — the contract — and left the models unwritten.
Nothing in the Phase 7 loop that produced it ran `flutter analyze` between the
write and the commit; the previous commit was the last one that had.

### Why it is expensive

It is invisible from `state.json`, which reported every node as `planned` and
`suspect: []`, and from `forge-guard`, which checks artefacts and not whether the
project compiles. The Definition of Done in `AGENTS.md` lists `flutter analyze`
as item 2 — and item 2 is a *gate*, so the only thing that protects it is the
commit actually running it.

### Fix

The five model files were written with the contract they satisfy, plus
`domain/sources/source_id.dart` for the identity derivation the contract's own doc
comment names. `flutter analyze --fatal-infos` → *No issues found*; `flutter test`
→ 457 passed, 9 skipped.

### What was also corrected in the repair

`2-1` § 3.1 **displays** `md5('f321cc5e…31//novel/ke383028.html')` — two
slashes — beside the frozen constant `90db9662f191bf2418033ab0bee1e629`, which is
the digest of the **one-slash** string. Both constants were computed and checked:

```
md5(sid + "//novel/ke383028.html") = 071603bb7a4d297df4f11b34ed4e55bd   ← not the plan's value
md5(sid + "/novel/ke383028.html")  = 90db9662f191bf2418033ab0bee1e629   ← the plan's value
md5(nid + "/novel/ke383028_1.html") = 3003a98742f53c4b4f2ae62d8105a4e9  ← the plan's value
```

`SourceId` therefore **strips leading slashes** from the relative url before
hashing, so `/novel/x.html` and `novel/x.html` cannot mint two ids for one
novel. The constant is the authority; the displayed pseudocode is not.