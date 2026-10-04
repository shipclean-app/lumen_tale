// Lumen Tale — the catalogue: what the site said, turned into a screen.
//
// `3-1`, and the file where B22 becomes visible. SC-6 is "a site that cannot be read looks
// like a site with nothing in it", and this is the only place that could happen.
//
// ## ⚠️ Every failure state says what is NOT wrong, first
//
// | state | the sentence leads with |
// |---|---|
// | site unreadable | *your library is fine, nothing was downloaded* |
// | no connection | *your library is unaffected* |
// | empty tag | *nothing is tagged that* — and the tag is echoed back |
//
// The reason is uniform: a reader whose catalogue fails assumes the **app** is broken, and the
// second thing they assume is that the failure ate their downloads. Both assumptions are
// wrong and neither is self-correcting, so the screen says so in the first two sentences.
//
// ## ⚠️ No failure state renders a list footer, a retry spinner, or a "0"
//
// `browse-catalogue.md` § 4: *zéro ligne de roman n'est rendue, et la page ne défile pas*. A
// footer under an error is a promise that more is coming, and there is nothing coming.

import 'package:flutter/material.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/features/browse/catalogue_view_state.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The screen's own states, rendered by ONE dispatcher.
///
/// ⚠️ **A sealed hierarchy with a `switch` and no default**, so a new
/// [CatalogueViewState] is a compile error here rather than a blank screen in a reader's
/// hands.
class CatalogueStates extends StatelessWidget {
  const CatalogueStates({required this.state, super.key});

  final CatalogueViewState state;

  static Widget forState(CatalogueViewState state) => switch (state) {
    CatalogueFilled() => throw StateError(
      'CatalogueStates.forState was given CatalogueFilled — the list is drawn by the screen, '
      'not by this dispatcher. A call here means a state was routed to the wrong place, and '
      'it is better to say so than to draw nothing.',
    ),
    CatalogueEmptyTag() => _CatalogueEmpty(source: state),
    CatalogueSiteSaidNothing() => _SiteSaidNothing(state: state),
    CatalogueSourceUnreadable() => _SourceUnreadable(state: state),
    CatalogueNoConnection() => _NoConnection(state: state),
  };

  @override
  Widget build(BuildContext context) => forState(state);
}

/// The shared shape of every non-list state: a title, a body, and at most two actions.
final class _StateLayout extends StatelessWidget {
  const _StateLayout({
    required this.icon,
    required this.title,
    required this.body,
    this.bodyStyle,
    this.primaryLabel,
    this.onPrimary,
    this.secondaryLabel,
    this.onSecondary,
  });

  final IconData icon;
  final String title;
  final String body;

  /// Overrides the body's typography. Used by the one state whose body is a **quotation** —
  /// a quoted line set in the same weight as the app's own prose reads as something the app
  /// said, and the whole point of that state is that the SITE said it.
  final TextStyle? bodyStyle;
  final String? primaryLabel;
  final VoidCallback? onPrimary;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(icon, size: 40, color: theme.colorScheme.onSurfaceVariant),
              const SizedBox(height: 16),
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                body,
                style:
                    bodyStyle ??
                    theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              if (primaryLabel != null && onPrimary != null)
                FilledButton(onPressed: onPrimary, child: Text(primaryLabel!)),
              if (secondaryLabel != null && onSecondary != null)
                TextButton(
                  onPressed: onSecondary,
                  child: Text(secondaryLabel!),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The tag has no novels. **An empty-data state, not an error** — the site was read fine.
final class _CatalogueEmpty extends StatelessWidget {
  const _CatalogueEmpty({required this.source});

  final CatalogueEmptyTag source;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return _StateLayout(
      // ⚠️ **An inbox icon, not an error one.** A warning triangle on "this tag is empty"
      // teaches a reader that an empty tag is a fault, and the next empty tag gets dismissed
      // without being read.
      icon: Icons.inbox_outlined,
      title: copy.browseEmptyTagTitle(source.tag),
      body: copy.browseEmptyTagBody(source.sourceName),
      secondaryLabel: copy.browseActionBrowseAnother,
      onSecondary: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The site published its own "nothing here" marker — shown **verbatim**.
final class _SiteSaidNothing extends StatelessWidget {
  const _SiteSaidNothing({required this.state});

  final CatalogueSiteSaidNothing state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    // ⚠️ **The site's own words, in the site's own words, plus the site's name.** A
    // paraphrase is a translation, and the whole value of this state is that the SITE said it
    // — so the string is kept rather than summarised. The name is here because a reader who
    // searched the wrong site needs to know which one answered.
    final String signal =
        state.siteSuppliedSignal ??
        copy.browseSiteSaidNothingBody(state.sourceName, '');
    return _StateLayout(
      icon: Icons.search_off_outlined,
      title: copy.browseSiteSaidNothingTitle,
      body:
          '“$signal”\n\n${copy.browseSiteSaidNothingBody(state.sourceName, '')}',
      // ⚠️ **`theme` is read for the quoted signal's own colour**, because it is a quotation
      // and not our sentence — and a quotation set in the same weight as our own prose reads
      // as something the app said.
      bodyStyle: theme.textTheme.bodyLarge?.copyWith(
        fontStyle: FontStyle.italic,
        color: theme.colorScheme.onSurface,
      ),
    );
  }
}

/// The site could not be read — **the SC-6 state**.
final class _SourceUnreadable extends StatelessWidget {
  const _SourceUnreadable({required this.state});

  final CatalogueSourceUnreadable state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return _StateLayout(
      icon: Icons.cloud_off_outlined,
      title: copy.browseSourceUnavailableTitle(state.sourceName),
      // ⚠️ **The body's first sentence is what is NOT wrong.** SC-6 is a reader believing the
      // app is broken; the second thing they believe is that the failure ate their downloads.
      body: copy.browseSourceUnavailableBody,
      // ⚠️ **Retry is offered only when the failure says a second attempt is worth making.** A
      // layout change will answer 200 with the same markup tomorrow, so a retry button there
      // teaches a reader that the app does not know what it is doing.
      primaryLabel: state.canRetry ? copy.browseActionRetry : null,
      onPrimary: state.canRetry ? () => Navigator.of(context).maybePop() : null,
      secondaryLabel: copy.browseActionOpenLibrary,
      onSecondary: () => Navigator.of(context).maybePop(),
    );
  }
}

/// No connection — and **not** a broken site.
final class _NoConnection extends StatelessWidget {
  const _NoConnection({required this.state});

  final CatalogueNoConnection state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return _StateLayout(
      icon: Icons.wifi_off_outlined,
      title: copy.browseNoConnectionTitle,
      body: copy.browseNoConnectionBody(state.sourceName),
      primaryLabel: copy.browseActionRetry,
      onPrimary: () => Navigator.of(context).maybePop(),
      secondaryLabel: copy.browseActionOpenLibrary,
      onSecondary: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The sentence for a typed [SourceFailure], from the enum's own vocabulary.
///
/// ⚠️ **In `core/error/`, not in the widget**, and that is B24: the copy belongs with the cause
/// it describes, so a new cause cannot ship without a sentence and an existing one cannot
/// drift from the branch that produces it.
extension SourceFailureCopy on SourceFailure {
  String localised(AppLocalizations copy) => switch (this) {
    NoConnection() => copy.browseFailureNoConnection,
    RateLimited() => copy.browseFailureRateLimited,
    SourceLayoutChanged() => copy.browseFailureLayoutChanged,
    SourceUnavailable() => copy.browseFailureUnavailable,
    ItemRemovedAtSource() => copy.browseFailureItemRemoved,
    ParseFailed() => copy.browseFailureParse,
    // ⚠️ **Its own sentence, and "no connection" would be a guess.** This cause means the app
    // cannot read its own record; it does not mean the phone is offline, and saying so would
    // send a reader to check a setting that is already correct.
    CauseUnknown() => copy.browseFailureUnknownCause,
  };
}
