# Testing

## Commands

- `flutter test`
- Coverage: `flutter test --coverage`

## Conventions

1. **Unit tests** for: source parsing (fixtures), HTML→Markdown conversion, chapter recognition / numbering, repository logic (in-memory drift), interactors.
2. **Widget tests** for: screens with providers overridden, key states (loading / error / empty), navigation.
3. **Golden tests** sparingly, for critical screens only; avoid brittle goldens.
4. **Mocking**: `mocktail`. Mock external boundaries (network, storage); prefer in-memory fakes for drift.
5. **Source fixtures**: each source ships `test/fixtures/sources/<name>/` with saved HTML samples. Assert selectors extract the expected novel / chapter / content. Update fixtures when the site layout changes, and record what changed in `18-external-contracts.md`.
6. **Converter fixtures**: the HTML→Markdown converter is written in this repo, not imported (`04-html-to-markdown.md`), so it has its **own** fixture suite under `test/fixtures/converter/` that is independent of any source: nested lists, tables, entities, code blocks, images, and a fully-stripped document. Golden-string assertions on the output, because determinism is a contract.
7. **Network**: inject a fake `dio` client (or an interceptor) so tests never hit the network. No test may reach the public internet.
8. **Naming**: `test`/`group` blocks read as sentences. Test behavior, not implementation.
9. **Coverage targets**: keep source parsing + conversion coverage high (≥ 80%); these are the risky, change-prone parts.

## Priorities

- **P0 (always keep)**: the HTML→Markdown converter (ours — `test/fixtures/converter/`), source parsing (selectors/mappers), chapter recognition / numbering, repository round-trips (in-memory drift), domain value objects, route constants.
- **P1 (add progressively)**: Riverpod notifiers/controllers via `ProviderContainer` + `overrideWith` — state transitions (loading → success / loading → error), cache invalidation.
- **P2 (reusable components)**: widget tests for shared components (async state body, empty/error views, toast, covers) — `tester.tap`, `pumpAndSettle` (with a timeout).
