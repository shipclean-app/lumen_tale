// Lumen Tale — the reader's seven non-prose states, and why each has its own words.
//
// ## Six of these are not errors, and that is the design
//
// `2-4` § 3.5's table: only [ChapterReadFailed] reports *this app* as broken. Everything
// else is a state of the world with its own sentence, and three of them have to name TWO
// facts at once or they tell the reader nothing they can act on:
//
//   | state | what the reader must learn |
//   |---|---|
//   | not stored, online | "download it, and here is the button" |
//   | not stored, offline | "you need the chapter **and** a connection" |
//   | marked, file gone | "the download worked; the FILE is what is missing" |
//
// ## ⚠️ The `ChapterFileCorrupt` word comes from the TYPED reason, not from a switch here
//
// The sentence lives with the enum it describes, so it cannot drift from the branch that
// produced it — and the *action* differs too: `unreadableIo` retries, the other two
// re-download. A screen that offered one button for all three would tell a reader with a
// permissions problem to re-download a file that was fine.

import 'package:flutter/material.dart';

import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The intents the reader emits. `2-4` **does not execute** any of them: `3-3` owns
/// enqueueing, `3-1` owns the catalogue.
///
/// ⚠️ **Void callbacks, not a service.** The reader's job is to *say* what it wants; a
/// callback is the smallest thing that can say it, and it keeps `features/reader` free of
/// any dependency the reader itself would later want to unit-test.
final class ReaderActions {
  const ReaderActions({
    required this.downloadChapter,
    required this.openDownloads,
    required this.goBack,
    required this.retry,
  });

  /// B5 — the reader has asked, by opening, so retrieving would be permitted. This screen
  /// still does not retrieve: it emits the intent. That is what keeps the "zero network
  /// calls" guarantee checkable by a counter.
  final VoidCallback downloadChapter;

  final VoidCallback openDownloads;
  final VoidCallback goBack;
  final VoidCallback retry;
}

/// Every non-prose state, dispatched on the document's type.
///
/// Exhaustive by construction: a new `ChapterDocument` case makes this a compile error, which
/// is the property that matters — a new state must never silently fall through to "blank".
sealed class ReaderStateView extends StatelessWidget {
  const ReaderStateView({super.key});

  /// Builds the view for [document].
  ///
  /// ⚠️ **`BuildContext` is a parameter, not a captured value.** The copy comes from it and
  /// the widget that renders the copy must be built under the same locale — so the function
  /// that reads the strings and the `Element` that will show them travel together. Reading
  /// a localisation from a `BuildContext` obtained anywhere else is how a screen ends up
  /// rendering French inside an English build.
  ///
  /// The `switch` is over the sealed hierarchy and has **no default**: adding a
  /// `ChapterDocument` case is a compile error here rather than a blank screen in a
  /// reader's hands.
  static Widget forDocument(
    BuildContext context,
    ChapterDocument document,
    ReaderActions actions, {
    Key? key,
  }) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return switch (document) {
      ChapterNotStored() => _DownloadPrompt(
        key: key,
        title: copy.readerNotStoredTitle,
        body: copy.readerNotStoredBody,
        onPrimary: actions.downloadChapter,
        primaryLabel: copy.readerActionDownloadChapter,
        secondaryLabel: copy.readerActionOpenDownloads,
        onSecondary: actions.openDownloads,
      ),
      ChapterOfflineAndAbsent() => _DownloadPrompt(
        key: key,
        title: copy.readerOfflineAbsentTitle,
        body: copy.readerOfflineAbsentBody,
        // ⚠️ **Disabled, and the reason is on screen beneath it.** A disabled primary with
        // no explanation reads as a broken button, and § 3.5 asks for the reason.
        onPrimary: null,
        primaryLabel: copy.readerActionDownloadChapter,
        primaryDisabledReason: AppLocalizations.of(
          context,
        ).readerDownloadNeedsConnection,
        secondaryLabel: copy.readerActionOpenDownloads,
        onSecondary: actions.openDownloads,
      ),
      ChapterFileMissing() => _DownloadPrompt(
        key: key,
        title: copy.readerFileMissingTitle,
        body: copy.readerFileMissingBody,
        onPrimary: actions.downloadChapter,
        primaryLabel: copy.readerActionDownloadAgain,
      ),
      ChapterFileEmpty() => _DownloadPrompt(
        key: key,
        title: copy.readerFileEmptyTitle,
        body: copy.readerFileEmptyBody,
        onPrimary: actions.downloadChapter,
        primaryLabel: copy.readerActionDownloadAgain,
      ),
      ChapterFileCorrupt(:final reason) => _corruptPrompt(
        key,
        copy,
        actions,
        reason,
      ),
      ChapterReadFailed() => _DownloadPrompt(
        key: key,
        title: copy.readerLoadFailedTitle,
        body: copy.readerLoadFailedBody,
        onPrimary: actions.retry,
        primaryLabel: copy.readerActionRetry,
      ),
      ChapterRowGone() => _BackPrompt(
        key: key,
        title: copy.readerRowGoneTitle,
        body: copy.readerRowGoneBody,
        actions: actions,
      ),
      ChapterText() || ChapterLoading() => throw StateError(
        'ReaderStateView.forDocument was given ${document.runtimeType}. The prose and the '
        'loading skeleton are rendered by the screen, not by this dispatcher — a call here '
        'means a state was routed to the wrong place, and it is better to say so than to '
        'draw nothing.',
      ),
    };
  }

  /// ⚠️ **Title AND action come from ONE `switch`, and that is the whole point.**
  ///
  /// The first version wrote the label as `reason == unreadableIo ? Retry : Download again`
  /// and the callback as a second, separate `reason == unreadableIo ? retry : download` —
  /// two expressions of one rule. A sabotage that changed only the callback left a button
  /// reading **Retry** that performed a re-download, and the row asserting the label passed.
  ///
  /// One switch returning one pair makes that state unreachable: there is no second place
  /// where the word and the action can disagree.
  static Widget _corruptPrompt(
    Key? key,
    AppLocalizations copy,
    ReaderActions actions,
    ReaderFileFailure reason,
  ) {
    final (
      String title,
      String label,
      VoidCallback onPressed,
    ) = switch (reason) {
      // ⚠️ **An I/O refusal RETRIES.** The bytes may be perfectly good and the filesystem
      // merely said no; offering a re-download would tell the reader their copy is at fault.
      ReaderFileFailure.unreadableIo => (
        copy.readerFileCorruptUnreadableIo,
        copy.readerActionRetry,
        actions.retry,
      ),
      ReaderFileFailure.notMarkdown => (
        copy.readerFileCorruptNotMarkdown,
        copy.readerActionDownloadAgain,
        actions.downloadChapter,
      ),
      ReaderFileFailure.truncatedUtf8 => (
        copy.readerFileCorruptTruncated,
        copy.readerActionDownloadAgain,
        actions.downloadChapter,
      ),
    };
    return _DownloadPrompt(
      key: key,
      title: title,
      primaryLabel: label,
      onPrimary: onPressed,
    );
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// "Not stored", "offline and absent", "the file went", "empty", "corrupt", "read failed" —
/// all of them one title, at most a body, and one or two actions.
final class _DownloadPrompt extends ReaderStateView {
  const _DownloadPrompt({
    required this.title,
    required this.primaryLabel,
    required this.onPrimary,
    this.body,
    this.secondaryLabel,
    this.onSecondary,
    this.primaryDisabledReason,
    super.key,
  });

  final String title;
  final String? body;
  final String primaryLabel;

  /// `null` disables the primary — used only by the offline state, and only because the
  /// reason is shown underneath it.
  final VoidCallback? onPrimary;

  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final String? primaryDisabledReason;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return _PromptLayout(
      title: title,
      body: body,
      children: <Widget>[
        FilledButton(onPressed: onPrimary, child: Text(primaryLabel)),
        if (primaryDisabledReason != null)
          // ⚠️ **Beneath the button, not instead of it.** The reader asked for this chapter;
          // removing the action and showing a sentence would answer a question they did not
          // ask.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              primaryDisabledReason!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        if (secondaryLabel != null && onSecondary != null)
          TextButton(onPressed: onSecondary, child: Text(secondaryLabel!)),
      ],
    );
  }
}

/// The one state with no download action: the chapter is gone, and re-downloading a chapter
/// that is not in the library would fail.
final class _BackPrompt extends ReaderStateView {
  const _BackPrompt({
    required this.title,
    required this.body,
    required this.actions,
    super.key,
  });

  final String title;
  final String body;
  final ReaderActions actions;

  @override
  Widget build(BuildContext context) {
    return _PromptLayout(
      title: title,
      body: body,
      children: <Widget>[
        FilledButton(
          onPressed: actions.goBack,
          child: Text(AppLocalizations.of(context).readerActionBack),
        ),
      ],
    );
  }
}

/// The shared shape: prose-scale text, centred, and nothing else.
///
/// ⚠️ **No `AppBar`, no `Scaffold` title, no icon.** § 3.5 gives every non-prose state a
/// plain surface; a screen title would push the sentence down a bar's height for no reader
/// who needed it, and the sentences here are the whole of what these states have to say.
final class _PromptLayout extends StatelessWidget {
  const _PromptLayout({required this.title, required this.children, this.body});

  final String title;
  final String? body;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                title,
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              if (body != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  body!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              ...children,
            ],
          ),
        ),
      ),
    );
  }
}

/// The loading state, **in the shape of prose**.
///
/// ⚠️ **Never a spinner** (§ 3.5). A spinner over prose implies an unknown length; a
/// skeleton implies the shape of what is arriving, and this is the one place where knowing
/// the shape in advance is free — a chapter is paragraphs.
final class ReaderProseSkeleton extends StatelessWidget {
  const ReaderProseSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    // ⚠️ **The last line is shorter**, which is what makes a skeleton read as *text* rather
    // than as five identical bars.
    const List<double> widths = <double>[1, 1, 1, 1, 0.6];
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: widths.length,
      separatorBuilder: (_, _) => const SizedBox(height: 14),
      itemBuilder: (BuildContext context, int index) => FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: widths[index],
        child: Container(
          height: 12,
          decoration: BoxDecoration(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(6),
          ),
        ),
      ),
    );
  }
}
