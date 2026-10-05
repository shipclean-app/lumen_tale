// Lumen Tale — the process-scoped database provider, and why it is HERE.
//
// ## ⚠️ It used to live in `features/history/`, and that was the root of a coupling
//
// `appDatabaseProvider` was declared in `features/history/history_providers.dart` and
// imported by **six** files across **four** features: `about`, `library`, `settings`,
// `novel_details`, plus `main.dart` and `history` itself.
//
// `02-architecture.md` forbids `features/*` importing another `features/*`. So a
// **database** provider — the single most-shared thing in the app — was reachable only
// by violating the rule, and every feature that touched storage had to reach through a
// *history* feature to get it. Six imports, four of them violations, and nothing in the
// toolchain noticed.
//
// ⚠️ **THE MOVE IS NOT COSMETIC.** A future feature could have been blocked from using
// the database at all, or — worse — copied the history import to reach it, which would
// have looked like a deliberate choice. The provider's home is now the one place every
// layer may import.
//
// ## It is overridden, and it THROWS until it is
//
// `main.dart` is the only place that override exists, and `main` is `async` and awaits,
// so the override is in place before the first frame. A synchronous `runApp` would leave
// the throw live and the first read of the database would be the first frame — which
// reads as a provider bug rather than a missing bootstrap.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database.dart';

/// The process-scoped database: the library, the reading positions and the journal (B7).
///
/// ⚠️ **Throws until `main.dart` overrides it**, on purpose. The alternative — opening
/// the file lazily inside the provider — would move the platform channel call away from
/// the one file whose job is to decide what the process opens.
final appDatabaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError(
    'appDatabaseProvider is overridden at the bootstrap, because a ProviderScope '
    'that outlives every screen is what lets the connection be closed once',
  ),
);
