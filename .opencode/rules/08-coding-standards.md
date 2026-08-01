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

- Repositories and sources throw **typed exceptions** — the `AppException` hierarchy (`SourceException`, `NetworkException`, `DatabaseException`, `ChapterNotAvailableException`). See `13-error-handling.md`. We do **not** use a `Result<T>` / `Either` return type; Riverpod `AsyncValue` already models async failure.
- Never surface `e.toString()` or stacktraces to users — map exceptions to localized messages.
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

## Dependencies (pubspec)

- It is **forbidden** to edit `pubspec.yaml` by hand to add, remove, or pin packages.
- Always use the official commands: `flutter pub add <pkg>`, `flutter pub add dev:<pkg>`, `flutter pub remove <pkg>`.
- Non-package changes (assets, fonts, metadata) are allowed but must stay minimal and justified.

## Codegen (build_runner)

- `freezed`, `riverpod_generator`, and drift generate code — never hand-write what codegen produces (no hand-written `copyWith` / `==` / providers for annotated classes).
- Regenerate with `dart run build_runner build --delete-conflicting-outputs`. Generated files are committed and excluded from analysis (`analysis_options.yaml`).
- Do not mix hand-written and generated models for the same type.
