# Error Handling

Typed exceptions. We deliberately do **not** use a `Result<T>` / `Either` return type: Riverpod `AsyncValue` (`.loading` / `.error` / `.data`) already models async failure in the UI layer, and synchronous domain code throws. Adopting `Result<T>` everywhere would add noise without benefit.

## The hierarchy

`core/error/`:

> **This path moved. It was `core/utils/errors/`.** `architecture.md` § 1.2 — the
> folder-structure table, which is the authority on paths — declares `core/error/`
> for the `AppException` hierarchy, and § 5.2 describes it as *one type per cause*.
> Three reasons for `core/error/`: the layer table names it; `failure-discriminator`
> already writes `SourceFailure` there, so the two files sit side by side; and
> `core/utils/` is a *different* directory inside `core`, so a type living under
> `core/utils/errors/` would be an internal `core` import, which the layer table
> forbids (`core` may import external packages only). Recorded here because this
> project has fixed the same fact in one document four times and left the other
> copies behind — if you meet `core/utils/errors` anywhere, this paragraph is the
> answer, and the import to write is `package:lumen_tale/core/error/<file>.dart`.

```dart
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  final String message;        // developer-facing, NOT user-facing
  final Object? cause;
}

final class SourceException extends AppException { ... }     // parsing / source failure
final class NetworkException extends AppException { ... }    // dio failures (timeout, DNS, 5xx...)
final class DatabaseException extends AppException { ... }   // drift failures
final class ChapterNotAvailableException extends AppException { ... } // chapter body not found/not fetched
final class CancelledException extends AppException { ... }  // user-cancelled jobs
```

Keep the hierarchy **small**. Add a subclass only when a caller needs to `on X catch` it specifically.

## Rules

1. **Throw typed exceptions** from repositories, interactors, and sources. Never throw bare `Exception`, `Error`, or `StateError`.
2. **Wrap and rethrow at boundaries**: when a dio/drift error would leak to callers, catch the primitive error and rethrow an `AppException` subclass carrying `cause`.
3. **Catch at the boundary only**: the UI catches once (via `AsyncValue.error` or a `try/catch` in a callback), maps to a localized user message, and shows it. Never propagate stacktraces or `e.toString()` to the UI (see rule 5).
4. **Never swallow**: no silent `catch (_) {}` (`empty_catches`). If a failure is intentionally ignored, log it (`core/utils/logger`) and comment why.
5. **User-facing mapping**: one place maps exceptions → localized messages, in `core/ui/`. Generic messages per exception category, plus a specific message for the cases a user can act on. Display via the app's snackbar wrapper (`core/ui/`), never ad-hoc `ScaffoldMessenger` calls from a feature.
6. **Log with `logger`** (`core/utils/logger`), no `print()`. Log the `AppException` class + message + cause.
7. **Cancellation**: `CancelledException` for user-cancelled downloads/updates — the caller distinguishes "cancelled" from "failed" and does not surface an error.
8. **Streams**: repositories emitting `Stream<T>` deliver errors on the stream and let the UI map them; do not catch-and-emit-nothing.
