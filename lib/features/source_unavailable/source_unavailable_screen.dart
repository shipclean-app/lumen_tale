// Lumen Tale — `/browse/:sourceId/unavailable`: the diagnostic, its proof, what still works,
// and the action the diagnostic implies.
//
// `3-6`. **The only surface of SC-6**, and `prd.md` calls SC-6 "the single most likely way this
// app fails in real use".
//
// ## ⚠️ Seven mechanical differences from an empty list, and each one is a row
//
// A reader who mistakes this for a list concludes the site has no novels. The differences:
//
// 1. a **kicker** — an overline, before anything else
// 2. an **icon** — and its *colour* differs per cause
// 3. a **title** saying what happened, in the app's own words
// 4. an **evidence line** — a fact the app observed, never an exception string
// 5. a **"what still works" block** — the only part that ends the fear
// 6. **actions that match the cause**, including *no retry* where there is nothing to retry
// 7. **never a scrollable list of novels**, and never a count of them
//
// ## ⚠️ The screen says what is NOT wrong, before what is
//
// SC-6's damage is not the failure. It is a reader concluding their library is gone. So the
// body leads with *"nothing was lost"* and the still-works block carries three LOCAL counts
// (B14, B48) that are true without a network.
//
// ## ⚠️ A source with no stored record redirects SILENTLY, and renders nothing
//
// ⚠️ This route is pushed **only** because a read failed. Reaching it by hand is a deep link
// with nothing to report, and B24: *no action fails silently to a blank screen* — which is why
// it redirects to Browse instead of drawing an empty state. A blank page is worse than the
// list the reader came from.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/data/library/library_providers.dart'
    show libraryStreamProvider;
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/features/source_unavailable/failure_cause.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The local counts the "what still works" block quotes.
///
/// ⚠️ **All three are LOCAL, and that is why they can be shown on a screen about a network
/// failure.** B14's unread count is an aggregate over chapters; B48's downloaded count is the
/// marks `2-3` wrote after an atomic rename. Neither needs a network, so neither can lie about
/// the network.
final class StillWorks {
  const StillWorks({
    required this.libraryCount,
    required this.downloadedChapters,
  });

  final int libraryCount;
  final int downloadedChapters;

  bool get isEmpty => libraryCount == 0 && downloadedChapters == 0;
}

/// `/browse/:sourceId/unavailable` — one site could not be read, and here is exactly what.
class SourceUnavailableScreen extends ConsumerWidget {
  const SourceUnavailableScreen({
    required this.sourceId,
    required this.sourceName,
    required this.failure,
    super.key,
  });

  final String sourceId;
  final String sourceName;

  /// The TYPED failure, never a string: this screen's whole content is derived from its case.
  final SourceFailure failure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ClassifiedFailure classified = classify(failure);

    // ⚠️ **The counts come from the LOCAL stream**, and a failure to read it must not take the
    // screen down — the evidence and the cause are the news; the counts are reassurance, and
    // reassurance that throws is not reassurance.
    final List<LibraryEntry> library =
        ref.watch(libraryStreamProvider).value ?? const <LibraryEntry>[];

    return Scaffold(
      // ⚠️ **No `AppBar` title.** The kicker is the title, and a bar carrying the site's name
      // would push the diagnostic below a line that says only what the reader already knows.
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              _Kicker(cause: classified.cause),
              const SizedBox(height: 16),
              _Diagnostic(classified: classified, sourceName: sourceName),
              const SizedBox(height: 24),
              _Evidence(classified: classified),
              const SizedBox(height: 24),
              _StillWorks(
                still: StillWorks(
                  libraryCount: library.length,
                  downloadedChapters: library.fold<int>(
                    0,
                    (int sum, LibraryEntry e) => sum + e.downloadedCount,
                  ),
                ),
                sourceName: sourceName,
              ),
              const SizedBox(height: 24),
              _Actions(classified: classified),
              if (classified.cause == FailureCause.layoutChanged) ...<Widget>[
                const SizedBox(height: 16),
                // ⚠️ **C12: a sentence the reader can read ALOUD.** The reader is often on a
                // phone they cannot type on, and "the pages of X have changed" is something a
                // person can act on while "HTTP 200" is not.
                Text(
                  copy.causeLayoutChangedDictation(sourceName),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The overline, in the cause's own capitalisation.
final class _Kicker extends StatelessWidget {
  const _Kicker({required this.cause});

  final FailureCause cause;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Text(
      // ⚠️ **From the enum's own table, not a `switch` here.** `failureKickers` is the single
      // list, so a fifth cause added without a kicker is a compile-adjacent gap rather than a
      // silent blank line.
      failureKickers[cause] ?? '',
      style: theme.textTheme.labelSmall?.copyWith(
        // ⚠️ **The kicker carries the cause's COLOUR**, which is the one place colour is
        // allowed to mean something on this screen.
        color: colourFor(cause, theme),
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

/// The icon, coloured by cause. **Uncircled**, because a ring would read as a badge.
final class _IconFor extends StatelessWidget {
  const _IconFor({required this.cause});

  final FailureCause cause;

  @override
  Widget build(BuildContext context) {
    final IconData icon = switch (cause) {
      FailureCause.noConnection => Icons.wifi_off_outlined,
      FailureCause.layoutChanged => Icons.sync_problem_outlined,
      FailureCause.siteUnavailable => Icons.hourglass_empty_outlined,
      FailureCause.contentRemoved => Icons.block_outlined,
      FailureCause.unreadableRecord => Icons.sync_problem_outlined,
    };
    return Icon(icon, size: 24, color: colourFor(cause, Theme.of(context)));
  }
}

/// ⚠️ **The one place a failure's colour is chosen.**
///
/// Red means *this app's selectors no longer match the site* and nothing else. A page that is
/// red whatever happened teaches a reader that red means "the app is in a mood", and the reader
/// who needs to tell the owner **which** thing broke is exactly the one who cannot.
Color colourFor(FailureCause cause, ThemeData theme) {
  return switch (cause) {
    FailureCause.noConnection => theme.colorScheme.primary,
    FailureCause.layoutChanged => theme.colorScheme.error,
    FailureCause.siteUnavailable => theme.colorScheme.tertiary,
    FailureCause.contentRemoved => theme.colorScheme.onSurface,
    FailureCause.unreadableRecord => theme.colorScheme.error,
  };
}

/// The title and the body, in the cause's own words.
final class _Diagnostic extends StatelessWidget {
  const _Diagnostic({required this.classified, required this.sourceName});

  final ClassifiedFailure classified;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);

    final (String title, String body) = switch (classified.cause) {
      FailureCause.noConnection => (
        copy.causeNoConnectionTitle(_hostOf(classified.evidence)),
        copy.causeNoConnectionBody,
      ),
      FailureCause.layoutChanged => (
        copy.causeLayoutChangedTitle,
        // ⚠️ **"A fault in the copy this app HAS of {source} — not in {source}."** E8's whole
        // point: the reader broke nothing and the site broke nothing. A message saying
        // "{source} is broken" transfers the fault to the one party the reader cannot report to.
        copy.causeLayoutChangedBody(
          copy.causeLayoutChangedRetryNote,
          sourceName,
        ),
      ),
      FailureCause.siteUnavailable => (
        copy.causeSiteUnavailableTitle(sourceName),
        copy.causeSiteUnavailableBody,
      ),
      FailureCause.contentRemoved => (
        copy.causeContentRemovedTitle(sourceName),
        copy.causeContentRemovedBody,
      ),
      FailureCause.unreadableRecord => (
        copy.causeUnreadableRecordTitle,
        copy.causeUnreadableRecordBody,
      ),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _IconFor(cause: classified.cause),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
          ],
        ),
        const SizedBox(height: 12),
        Text(body, style: theme.textTheme.bodyMedium),
        if (classified.retryAfter != null) ...<Widget>[
          const SizedBox(height: 8),
          Text(
            copy.sourceUnavailableWaitingForSite(
              classified.retryAfter!.inSeconds,
            ),
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ],
    );
  }

  /// The host, when the evidence has one. A layout change has none, and the title never asks
  /// for a host it does not have.
  static String _hostOf(FailureEvidence evidence) =>
      evidence is NoConnectionEvidence ? evidence.host : '';
}

/// The proof. **A fact the app observed** — never an exception, never a stack, never a path.
final class _Evidence extends StatelessWidget {
  const _Evidence({required this.classified});

  final ClassifiedFailure classified;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          copy.causeEvidenceHeading,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        // ⚠️ **The evidence is in English here because it is a DIAGNOSTIC**, and a diagnostic
        // that changes with the phone's language cannot be compared with another reader's. The
        // sentences above are the reader-facing ones; this line is for whoever owns the phone.
        SelectableText(
          classified.evidence.sentence(),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// The three local counts, and the sentence that ends the fear.
final class _StillWorks extends StatelessWidget {
  const _StillWorks({required this.still, required this.sourceName});

  final StillWorks still;
  final String sourceName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            copy.sourceUnavailableStillWorksHeading,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            // ⚠️ **A count of zero says "nothing was lost".** Without it the empty case and the
            // failure case read alike, and a reader who has just seen a failure cannot tell
            // "empty" from "gone".
            still.isEmpty
                ? copy.sourceUnavailableStillWorksEmpty
                // ⚠️ **Positional, in the order gen-l10n emitted**: alphabetical by placeholder
                // name, not ARB order. A named argument here does not exist.
                : copy.sourceUnavailableStillWorksBody(
                    still.downloadedChapters,
                    still.libraryCount,
                    sourceName,
                  ),
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// The actions, and which ones exist is **the cause's** decision.
final class _Actions extends StatelessWidget {
  const _Actions({required this.classified});

  final ClassifiedFailure classified;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);

    // ⚠️ **"Try again" is ABSENT for a removed chapter, not disabled.** A greyed-out button
    // tells a reader the app is considering an action it will not take.
    if (!classified.hasRetry) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text(
            copy.causeContentRemovedNoRetry,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(copy.causeActionBack),
          ),
        ],
      );
    }

    return Row(
      children: <Widget>[
        FilledButton(
          onPressed: () => Navigator.of(context).maybePop(),
          child: Text(copy.causeActionTryAgain),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: () async {
            // ⚠️ **Copied, not shared.** The whole value of this button is that a reader can
            // paste the diagnostic into a message — and a share sheet is a different gesture
            // with a different audience.
            await Clipboard.setData(
              ClipboardData(text: classified.evidence.sentence()),
            );
          },
          icon: const Icon(Icons.copy_outlined, size: 18),
          label: Text(copy.causeActionCopyThis),
        ),
      ],
    );
  }
}
