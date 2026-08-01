# Git Workflow

## Conventions

- **Branches**: feature branches from `main`, named `feature/<slug>`, `fix/<slug>`, `chore/<slug>`.
- **Commits**: Conventional Commits — `feat:`, `fix:`, `refactor:`, `chore:`, `test:`, `docs:`. Imperative mood, summary ≤ 72 chars.
- **Scope** (optional): `feat(source): add novelupdates source`.
- **Frequency**: small, focused commits that each compile and pass `flutter analyze`.
- **PRs**: linked to issues; include a summary, test notes, and screenshots for UI changes. Keep PRs reviewable (≈ < 400 lines when possible).
- **Do not commit**: `build/`, `.dart_tool/`, secrets, `.env`. Verify with `git status` before committing.

## Before you finish any task

1. `dart format .`
2. `flutter analyze` (must be zero issues)
3. `flutter test` (must pass)
4. Commit with a Conventional Commits message.
