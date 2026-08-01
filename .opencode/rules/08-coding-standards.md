# Coding Standards (Dart / Flutter)

## Style

- `dart format` output, `prefer_single_quotes`, trailing commas.
- One public type per file; file name is `snake_case` matching the type.
- `const` everywhere possible (constructors, declarations).
- `final` by default; avoid `var` where the type matters.

## Naming

- Types: `PascalCase` (`Novel`, `HttpSource`, `LibraryScreen`).
- Functions / methods / properties: `camelCase`.
- Enums: `lowerCamelCase` values; constants use a consistent case (`UPPER_SNAKE_CASE` for compile-time consts).
- Files: `snake_case` matching the public type (`novel.dart`, `http_source.dart`).
- Folders: `snake_case`.

## Immutability & models

- Domain models are `freezed` classes: immutable, with generated `==` / `hashCode` / `copyWith`.
- Never expose mutable collections; return `List.unmodifiable` or use `copyWith`.
- `final` fields only; no setters on domain models.

## Error handling

- Prefer typed exceptions (`SourceException`, `NetworkException`, `DatabaseException`) over bare `Exception` / `Error`.
- Use `sealed class` result types where failure is a meaningful outcome; otherwise throw and `try/catch` at boundaries.
- Never swallow errors: log with `core/utils/logger` and rethrow or map. No `print()` (`avoid_print`).
- Never write a silent `catch (_) {}` (`empty_catches`).

## Async

- Use `async` / `await`; avoid raw `.then()` chains.
- Fire-and-forget futures must be wrapped with `unawaited()`.
- Never `await` inside `build`; use providers.
- After an `await`, guard `context` usage with `if (!context.mounted)` (`use_build_context_synchronously`).

## API design

- Repository methods return domain types; no DB/network types leak into features.
- Prefer streams over callbacks for reactive data.
- Keep methods small and focused; no god-objects.
- Document public APIs with doc comments (`///`). Do not add comments that merely restate the code.
