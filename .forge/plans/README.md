# `.forge/plans/` — house style for Lumen Tale implementation plans

Every plan here is written for **a low-capability implementer** who has not read the
PRD and will not read it. That is the whole design constraint, and it is stricter than
it sounds: the plan must be executable with no interpretation and no judgement calls.

This file is the convention. A plan that contradicts it is wrong even if it passes
`coverage-check.js`.

---

## 1. What the template is, and what it had to become

Forge's `templates/implementation-plan.md.tmpl` was written for a TypeScript/React
stack: Zod, React Hook Form, Redux/Zustand, Chrome MCP, "tablet / desktop" breakpoints.
**None of that exists here.** This project is Flutter 3.47.6 / Dart 3.13.5, offline,
Android-phones-only, Material 3.

**The eleven section headings are kept verbatim, in French, in order.** That is not
optional — `coverage-check.js slice` looks for these exact strings:

```
## 1. Résumé
## 2. Contrats de données
## 3. Algorithmes critiques
## 4. Plan composants
## 5. Gestion d'état
## 6. Traçabilité des règles
## 7. Pièges à éviter
## 8. Dépendances
## 9. Checklist de tâches
## 10. Critères d'acceptation
## 11. Plan de tests
```

Inside them, the substitutions are fixed:

| Template says | This project writes |
|---|---|
| Validation schemas (Zod) | **Drift `Table` classes** and the typed companions. Dart has no runtime schema library here, and inventing one is banned by `08-coding-standards.md` |
| Types and interfaces | **`abstract class` / `final class` in Dart**, or a `freezed` union where a value is genuinely immutable |
| API contracts | **The `Source` contract** — `Future<BrowseOutcome<T>>`. **There is no REST API.** Every method returns `BrowseOutcome`, never a bare list and never `null` (`architecture.md` § 5.1) |
| Component tree | **Flutter widget tree**, Material 3 primitives only. `14-design-tokens.md` § 2 owns the component vocabulary — use the names it declares |
| State management | **Riverpod 3.4.3.** `05-state-management.md` owns provider lifetime, invalidation and the notifier pattern |
| Chrome MCP / responsive breakpoints | **`flutter test` widget tests at one width (360dp)** plus a manual device pass. There is no tablet, no rail, no two-pane (ADR-019), so "check every breakpoint" means *check 360dp and confirm nothing overflows* |
| Forms | **No form library.** Inputs are `TextField` with a validator; submission is an `AsyncValue` transition |
| E2E | **`integration_test` flows**, and only where a device is available (Q-008) |

---

## 2. The mechanical gate

```bash
node "$FORGE/scripts/coverage-check.js" slice /workspaces/lumen_tale <slice>
```

It checks three things, and **each one can pass while reading nothing** — so treat a
green result as necessary, never sufficient:

1. The eleven headings above are present.
2. **Every `rule_ids` entry on the slice appears somewhere in the plan text.** These
   are declared in `state.json` by `scripts` under `.forge/`, not typed by hand.
3. **Every `edge_case_ids` entry appears.** Plus: **no empty section** (a heading
   followed by a blank line and nothing else).

Known limitation, recorded as finding **F-003**: `coverage-check slice` reads
`state.slices` only, so **a foundation's `rule_ids` are never mechanically checked**.
`apk-pipeline`, `local-store`, `failure-discriminator`, `localisation` and `theme-type`
must be verified by reading the plan.

---

## 3. What "executable without interpretation" means here

Concretely, a plan is executable when an implementer never has to decide anything.
So:

- **§ 2 is real Dart.** Copy-pasteable, with the imports. Not a description of types.
- **§ 3 is pseudocode with every branch written out**, including the edge cases named
  in `edge_case_ids`. If an algorithm has a `switch`, all arms appear.
- **§ 7 states traps as contrasts** — *"⚠️ Ne pas X. Le comportement correct (B*n*) est
  Y."* — because a trap written as a prohibition is ignored and a trap written as a
  contrast is obeyed.
- **§ 10 is a list of assertions**, each one mechanically checkable. "Works well" is
  not a criterion. "B6: `downloadedAt` is still null after a crash between the rename
  and the write" is.
- **§ 11 names the test file and the test names**, because `06-database.md` and the
  Phase 4 review both found plans citing test names that do not exist.

### The four traps this project actually has

Every plan must address the ones that apply to it. They are not hypothetical; each
one has already cost this project something:

1. **`downloadedAt` is written AFTER the atomic rename, never before** (ADR-022, B6).
   The reverse order is the bug the whole column exists to prevent.
2. **Nothing returns a bare list or `null`** (B22, SC-6). `BrowseOutcome<T>`, always.
   An empty list and a failure must be distinguishable *by the type system*.
3. **`PRAGMA foreign_keys = ON` is per-connection** (B32's only enforcement). A second
   connection that omits it silently stops enforcing `history_entries`' `RESTRICT`.
4. **`drift_dev schema dump` takes TWO arguments** — with one it prints usage and exits
   0, so it looks like it ran.

---

## 4. Rules a plan must not restate

`AGENTS.md` and `.opencode/rules/` are loaded into every session. A plan that spends
prose on them is a plan with less room for its own content. Cite by id; do not
paraphrase. The exceptions are the four traps above, because those are **not** in any
rule file in a form an implementer would find.

---

## 5. Status vocabulary

Plans are `draft` until the gate. `state.js set-status … slice <key> planned` moves a
slice from `identified` to `planned`, and the plan's front matter `status:` follows.
A plan that says `Status: draft` while its slice says `planned` is a contradiction.
