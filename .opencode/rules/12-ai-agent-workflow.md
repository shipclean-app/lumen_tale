# AI Agent Operating Rules

Rules for AI coding sessions in this repo. Read `AGENTS.md` first — it carries the ranked priorities, the commands, and the definition of done. This file covers how to work, not what to build.

## Session start

1. Read `AGENTS.md`. Its §Priority Order settles any conflict between two rule files — if two rules disagree, that ranking decides, and you do not silently pick one.
2. Read `SESSION_LOG.md` in full. Its newest entry's `NEXT SESSION SHOULD` tells you where to start; `NEXT SESSION SHOULD NOT` tells you what not to redo.
3. Skim `DECISIONS.md`. If your task touches a closed decision, that decision is settled — see its `Conséquences`. If you believe a closed decision is now wrong, **stop and say so**, naming the ADR and why it no longer holds. Do not build the alternative silently.
4. Read the rule files your task touches (`AGENTS.md` §Rules carries the index). You do not need all eighteen.
5. Explore before writing. Understand the existing providers, repository shapes, and folder conventions. Do not invent a parallel structure next to an existing one.

## Session end

6. Append one entry to `SESSION_LOG.md` **before** you finish, with all eight named fields. `REJECTED` is the field that earns its file — record what you declined and why, because that is the only thing stopping the next session from re-proposing it.
7. Append to `LEARNINGS.md` **only** when you got something wrong twice, or when you discovered a behaviour that contradicts a rule. One line, contrast form, with a `domaine:` target.
8. `DECISIONS.md` gets an ADR when you settle something a future session would otherwise re-litigate. Six fields, `Statut:` included.

This is the **caller** for the promotion path. `LEARNINGS.md` names the rule file each correction will be promoted into; promoting it is a normal part of ending a session, not a separate chore.

## While coding

9. Match existing conventions exactly — naming, folder layout, Riverpod codegen, drift style. Never introduce a second pattern for the same concern.
10. Keep changes focused. No speculative refactors, no dead code, no scaffolding for a feature that does not exist yet.
11. Follow `08-coding-standards.md`. Never add comments that restate the code; use `///` for public APIs.
12. Never edit `pubspec.yaml` by hand — use `flutter pub add` / `flutter pub remove` (`08-coding-standards.md` §Dependencies, `17-security.md` rules 12–13).

## Before non-trivial work

13. **Is the request clear and coherent with the project?** If not, restate the goal and the success criteria, and ask one or two targeted questions.
14. **Is there a risk?** Multi-file or multi-layer change, an impact on navigation / theme / state / data model / performance, an unstable public API, an unverified assumption → list the risks and mitigations, or the options with their trade-offs.
15. **Does the request contradict a project rule?** Say so and propose a conforming alternative. If the user still wants it their way, implement it and flag the deviation in your summary.
16. **Never modify `android/`, `ios/`, or Gradle files** without explicit intent and a stated reason.
17. **Never modify a closed decision** (see session start, step 3).

## Verification

18. Run `AGENTS.md` §Definition of Done. `flutter analyze` must reach zero issues and `flutter test` must pass. Do not finish on a red tree, and do not weaken a test to make it green.
19. If a task genuinely cannot be completed — missing external dependency, no design decision — stop and report it. Do not hack around it.

## Quality bar

- **Type-safe**: no `dynamic` where a type is known; no unchecked `as` casts.
- **Reactive**: drift streams + Riverpod; no imperative refresh hacks.
- **Tested**: source parsing and HTML→Markdown conversion always have tests (`10-testing.md`).
- **Performant**: no N+1 queries, no rebuilds from unscoped providers, no work in `build`.
- **Clear**: names that mean something; small functions; a shared helper instead of a duplicated block.

## Communication

- When a rule conflicts with a request, implement the request but flag the deviation explicitly.
- State which files you touched and why, so the change is reviewable without reconstructing your reasoning.