# AI Agent Operating Rules

Rules for AI coding sessions in this repo.

## Before coding

1. Read `AGENTS.md` and the relevant `.opencode/rules/*.md` files for the task (sources → `03-source-system.md` + `04-html-to-markdown.md`, UI → `09-widgets-ui.md`, etc.).
2. Explore the codebase before writing: understand existing patterns, providers, and repository shapes. Do not invent parallel structures.
3. Prefer editing existing files; create new files only when necessary.

## While coding

4. Match existing conventions exactly (naming, folder layout, Riverpod codegen, drift style). Never introduce a second pattern for the same concern.
5. Keep changes focused and minimal. No speculative refactors, no dead code.
6. Follow `08-coding-standards.md` — immutability, typed errors, `const`/`final`, no `print`.
7. Never add comments that restate the code; use doc comments (`///`) for public APIs.

## Critical thinking (before non-trivial work)

1. **Is the request clear and coherent with the project?** If not, restate the goal + success criteria and ask 1–2 targeted questions.
2. **Is there a risk?** (multi-file / multi-layer change, impact on navigation / theme / state / data model / performance / security, unstable public API, unverified assumptions) → list risks + mitigations, or options with trade-offs.
3. **Does the request contradict a project rule?** → prioritize project coherence; propose a conforming alternative.
4. **Never modify `android/`, `ios/`, `macos/`, `linux/`, `windows/`, or Gradle files** without explicit intent + justification.
5. **External references** guide structure and patterns only — never a runtime dependency. Adapt to the project (imports, routes, state management). Check licenses before substantial reuse. Copy-paste "as-is" is forbidden.

## Verification (mandatory)

8. After every task, run in order:
   - `dart format .`
   - `flutter analyze`
   - `flutter test`
9. Fix every issue you introduce. `flutter analyze` must end at zero issues and `flutter test` green. Do not finish with a red tree.
10. If a task cannot be completed (external dependency, missing design), stop and report instead of hacking around it.

## Quality bar (senior level)

- **Type-safe**: no `dynamic` where a type is known; no silent `as` casts without checks.
- **Reactive**: use drift streams + Riverpod; avoid imperative refresh hacks.
- **Tested**: source parsing and conversion logic always have tests.
- **Performant**: no N+1 queries, no rebuilds from unscoped providers, no work in `build`.
- **Clear**: names mean something; small functions; extract shared helpers instead of duplicating logic.

## Communication

- When a rule conflicts with a user request, implement the user request but flag the deviation.
- Keep your changes discoverable: mention the files touched and why.
