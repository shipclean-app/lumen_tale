// Lumen Tale — a route that exists but has no screen yet.
//
// ⚠️ **Not an empty page and not a spinner.** B24 forbids an action that fails
// silently to a blank screen, and this is the same failure at a different
// address: the address is what makes it *reportable*. `source-unavailable.md` § 8
// asks a failure state to be describable **in words** to someone who has to report
// it (C12); "the screen for `/more/downloads` does not exist yet" is such a
// sentence, and an exclamation mark on a blank page is not.

import 'package:flutter/material.dart';

import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Stands in for a screen that has not been written.
///
/// It disappears **route by route**, not all at once: each screen slice fills
/// exactly one of these. Until then the destination is reachable and it says what
/// it is standing in for.
///
/// Its copy is `commonErrorTitle` / `commonErrorBody` — keys that **already
/// exist in both ARB files**. No new string is invented for a screen that is a
/// placeholder: it will be deleted when the real screen lands, and a deleted
/// screen that added a string leaves an orphan key that nothing then maintains.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.screenKey});

  /// The path this stands in for. Shown **verbatim**, so it can be quoted back.
  final String screenKey;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    return AppScaffold(
      titleBar: AppBar(title: Text(l10n.appTitle)),
      content: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              // The path first. C12 asks for a failure the reader can describe in
              // words to the owner; this is the sentence they would say.
              Text(
                screenKey,
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                l10n.commonErrorTitle,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.commonErrorBody,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
