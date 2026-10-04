// Lumen Tale — the one way this codebase logs.
//
// `02-architecture.md` §Directory authorities names this file as the logger's home
// (ADR-028: a logger is a general utility, so `core/utils/` is where it belongs, and it
// nearly moved with the exceptions because the two shared a table row). `13-error-handling.md`
// rule 6 requires it — *"Log with `logger`, no `print()`"* — and `analysis_options.yaml`
// forbids `print`. The file was named by two rule files and did not exist.
//
// ## ⚠️ `dart:developer`'s `log`, NOT `debugPrint`
//
// `debugPrint` is Flutter: it throttles through `scheduleMicrotask`, it is a no-op in
// some release configurations, and `core/` is a leaf layer that imports external packages
// only — so a logger that pulled `package:flutter/foundation.dart` into `core/` would
// make the leaf depend on the framework to emit one line. `dart:developer`'s `log`
// reaches the platform log on Android (which is where an owner reads it off the phone)
// and costs nothing in release.
//
// ## ⚠️ WHAT MAY BE LOGGED
//
// Ids, class names, counts and typed codes. **Never** a chapter title, a novel title, a
// URL with a query, a reader's search term or page content: C2 says reading data never
// leaves the phone, and C5 says a failure line is something a borrowed-device reader
// reads **aloud** to the owner.

import 'dart:developer' as developer;

/// A developer-facing note. Never a reader-facing sentence.
void logInfo(String message, {String name = 'lumen'}) {
  developer.log(message, name: name, level: 800);
}

/// A typed failure worth reading: [error]'s class, its message and its [cause].
void logError(
  String context,
  Object error, {
  Object? cause,
  String name = 'lumen',
}) {
  developer.log(
    '$context: ${error.runtimeType} $error${cause == null ? '' : ' (caused by $cause)'}',
    name: name,
    level: 1000,
  );
}
