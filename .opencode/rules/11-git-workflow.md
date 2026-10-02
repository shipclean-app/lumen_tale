# Git Workflow

## Conventions

- **Branches**: feature branches from `main`, named `feature/<slug>`, `fix/<slug>`, `chore/<slug>`.
- **Commits**: Conventional Commits — `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`. Imperative mood, summary ≤ 72 chars.
- **Scope** (optional): `feat(source): add novelupdates source`.
- **Frequency**: small, focused commits that each compile and pass `flutter analyze`.
- **PRs**: linked to issues; include a summary, test notes, and screenshots for UI changes. Keep PRs reviewable (≈ < 400 lines when possible).
- **Do not commit**: `build/`, `.dart_tool/`, secrets, `.env`. Verify with `git status` before committing. The secrets rule itself is owned by `17-security.md` rules 11–13; this is only the staging checklist.
- **Generated code is committed**: `*.g.dart`, `*.freezed.dart`, `*.drift.dart`, and `lib/l10n/generated/` are all tracked. A reviewer must be able to build the project from a clean clone without running a generator.

## Before you finish any task

The definition of done is defined **once**, in `AGENTS.md` §Definition of Done — format, analyze, test, commit, in that order. Read it there; do not restate or reorder it.

What is specific to git, and therefore owned here: the commit message, the branch, and what must not be staged.
