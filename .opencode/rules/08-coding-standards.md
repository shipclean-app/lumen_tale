# Coding Standards (Dart / Flutter)

Style is the last section of every rule file and the first thing to cut. Where `analysis_options.yaml` already enforces a rule, cite the lint name — a rule with a verifying command is a rule the agent follows.

## Naming

- Types: `PascalCase` (`Novel`, `HttpSource`, `LibraryScreen`).
- Functions / methods / properties: `camelCase`.
- Enums: `lowerCamelCase` values; constants use a consistent case (`UPPER_SNAKE_CASE` for compile-time consts).
- Files: `snake_case` matching the public type (`novel.dart`, `http_source.dart`).
- Folders: `snake_case`. One public type per file.

## Immutability & models

- Domain models are `freezed` classes: immutable, with generated `==` / `hashCode` / `copyWith`.
- Never expose mutable collections; return `List.unmodifiable` or use `copyWith`.
- `final` fields only; no setters on domain models.
- `const` constructors wherever possible; `final` by default; avoid `var` where the type matters.

## Error handling

**One owner: `13-error-handling.md`.** Do not restate the exception hierarchy or the catch/log/map policy here. In short: repositories and sources throw typed `AppException` subclasses, never a bare `Exception`; this project deliberately does **not** use a `Result<T>` / `Either` return type because Riverpod `AsyncValue` already models async failure in the UI layer.

The mechanical half is enforced by lint and needs no prose here: `only_throw_errors`, `empty_catches`, `avoid_print`, `cancel_subscriptions`, `close_sinks`, `unawaited_futures`, `avoid_dynamic_calls`.

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

- It is **forbidden** to edit `pubspec.yaml` by hand to add, remove, or pin packages — not the `dependencies:` block, not `dev_dependencies:`, not a version constraint.
- Always use the official commands: `flutter pub add <pkg>`, `flutter pub add dev:<pkg>`, `flutter pub remove <pkg>`.
- **Never hand-write a resolved version.** `pubspec.lock` is committed and is the record of what resolved; if a rule or doc needs a version, read it from there.
- Non-package changes (assets, fonts, metadata) are allowed but must stay minimal and justified.

## Codegen (build_runner)

- `freezed`, `riverpod_generator`, `json_serializable`, and `drift_dev` generate code — never hand-write what codegen produces (no hand-written `copyWith` / `==` / providers for annotated classes).
- Regenerate with `dart run build_runner build` — `--delete-conflicting-outputs` is removed and silently ignored. Generated files are committed and excluded from analysis — `analysis_options.yaml` excludes `**/*.g.dart`, `**/*.freezed.dart`, and `**/*.drift.dart`. A generator output that is *not* in that exclude list will be analyzed; add the glob, don't silence the file.
- Do not mix hand-written and generated models for the same type.

## Style

- `dart format .` output, `prefer_single_quotes`, trailing commas.
- Everything else in this file that has a lint name is enforced by `flutter analyze` — if a style rule is not in `analysis_options.yaml`, either add the lint or drop the prose.