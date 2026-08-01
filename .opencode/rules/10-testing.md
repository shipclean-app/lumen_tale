# Testing

## Commands

- `flutter test`
- Coverage: `flutter test --coverage`

## Conventions

1. **Unit tests** for: source parsing (fixtures), HTML→Markdown conversion, chapter recognition / numbering, repository logic (in-memory drift), interactors.
2. **Widget tests** for: screens with providers overridden, key states (loading / error / empty), navigation.
3. **Golden tests** sparingly, for critical screens only; avoid brittle goldens.
4. **Mocking**: `mocktail`. Mock external boundaries (network, storage); prefer in-memory fakes for drift.
5. **Source fixtures**: each source ships `test/fixtures/sources/<name>/` with saved HTML samples. Assert selectors extract the expected novel / chapter / content. Update fixtures when the site layout changes.
6. **Network**: inject a fake `dio` client (or an interceptor) so tests never hit the network.
7. **Naming**: `test`/`group` blocks read as sentences. Test behavior, not implementation.
8. **Coverage targets**: keep source parsing + conversion coverage high (≥ 80%); these are the risky, change-prone parts.

## Priorities

- **P0 (always keep)**: source parsing (selectors/mappers), HTML→Markdown conversion, chapter recognition / numbering, repository round-trips (in-memory drift), domain value objects, route constants.
- **P1 (add progressively)**: Riverpod notifiers/controllers via `ProviderContainer` + `overrideWith` — state transitions (loading → success / loading → error), cache invalidation.
- **P2 (reusable components)**: widget tests for shared components (async state body, empty/error views, toast, covers) — `tester.tap`, `pumpAndSettle` (with a timeout).
