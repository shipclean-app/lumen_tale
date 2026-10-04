// Lumen Tale — the prose column: the Markdown from disk, and nothing else around it.
//
// ## What `2-4` renders and what `2-7` adds
//
// `2-4` renders the **content** and the **states**. `2-7` owns the measurement column, the
// gesture and the no-clipping guarantee. So this column does the two things that must be
// right on their own:
//
//   1. **prose at the reader's scale**, rebuilt from `MediaQuery.textScalerOf` each frame, so
//      E14 — the platform font size changing mid-read — needs no notification at all;
//   2. **no fixed height and no fixed width**, so a larger type cannot be clipped. A column
//      that set its own height would be the thing E14 rules out.
//
// ## ⚠️ `selectable: true`, and why it is not a preference
//
// A chapter is text the reader may want to copy — a passage to look up in the glossary. The
// default `Markdown` widget is not selectable, and that is a decision someone would have to
// reverse later by changing this one argument.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The site's number, as the reader should see it.
///
/// ⚠️ **`double` in, text out — and a whole value loses its fraction.** `chapters.number` is
/// a `RealColumn`, so `12` arrives as `12.0`, and an ICU `{number}` bound to a `double`
/// renders "Chapter 12.0" — a decimal place the site never printed. B10 is about displaying
/// what the site wrote, so the formatting belongs here, where the type can be inspected,
/// and not in an ARB placeholder that only sees a `double`.
///
/// A genuinely fractional number (`12.5`, a site's own convention) keeps its fraction: the
/// column is `real` precisely because some sources publish halves.
String formatChapterNumber(double number) {
  if (number == number.roundToDouble()) {
    return number.toInt().toString();
  }
  return number.toString();
}

/// The reader's title line and its prose.
///
/// ⚠️ **`number` and the em dash are decided here, once.** B10: `-1` is unparseable and `0`
/// is a real chapter number, so the two cannot share a format string. Formatting `-1` as a
/// number is how an omake becomes "Chapter 0" forever.
class ChapterProse extends StatelessWidget {
  const ChapterProse({required this.document, super.key});

  final ChapterText document;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    // ⚠️ **`textScalerOf(context)` read here, in `build`.** E14 asks the prose to resize on
    // the next frame, and the read *is* the mechanism — no listener, no state, nothing to
    // forget to update.
    final TextScaler scaler = MediaQuery.textScalerOf(context);

    return ListView.builder(
      // ⚠️ **The key is the reading zone, and it is public on purpose.** `2-4` § 3.5: a tap
      // anywhere in the prose reveals the chrome, and a row needs a stable handle on "the
      // prose area" that does not name the widget class — a rename would otherwise break
      // every tap row for no reason.
      key: const ValueKey<String>('reader-prose-area'),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: 2,
      itemBuilder: (BuildContext context, int index) {
        if (index == 0) {
          return _ChapterTitle(
            document: document,
            scaler: scaler,
            semanticsLabel: _semanticsTitle(context, document, copy),
          );
        }
        return MarkdownBody(
          data: document.markdown,
          selectable: true,
          // ⚠️ **No fixed `shrinkWrap` and no fixed height anywhere.** The column measures
          // itself; a height set here would be the clip E14 forbids.
          styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
            p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            h1: theme.textTheme.headlineSmall,
            h2: theme.textTheme.titleLarge,
            h3: theme.textTheme.titleMedium,
            code: theme.textTheme.bodyMedium?.copyWith(
              fontFamily: 'monospace',
              fontFamilyFallback: const <String>[
                'Roboto Mono',
                'Menlo',
                'Courier',
              ],
            ),
            blockquote: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            blockquoteDecoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              border: Border(
                left: BorderSide(
                  color: theme.colorScheme.outlineVariant,
                  width: 3,
                ),
              ),
            ),
            blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
          ),
        );
      },
    );
  }

  /// The title as a single label, so a screen reader does not read "Chapter" and "twelve"
  /// as two unrelated things — and so `-1` never reaches a screen reader as a number.
  static String _semanticsTitle(
    BuildContext context,
    ChapterText document,
    AppLocalizations copy,
  ) {
    final double? number = document.number;
    return number == null
        ? document.chapterName
        : '${copy.readerChapterNumber(formatChapterNumber(number))} — '
              '${document.chapterName}';
  }
}

/// The title line: the number as a word, then the site's name, **verbatim**.
///
/// ⚠️ **B10 — the name is never truncated here.** A 120-character title is shown whole; the
/// library row and the chapter sheet are where truncation happens, and they mark it. An
/// ellipsis in the reader would be the one place a reader cannot see which chapter they are
/// in.
class _ChapterTitle extends StatelessWidget {
  const _ChapterTitle({
    required this.document,
    required this.scaler,
    required this.semanticsLabel,
  });

  final ChapterText document;
  final TextScaler scaler;
  final String semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    final double? number = document.number;

    return Semantics(
      header: true,
      label: semanticsLabel,
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // ⚠️ **The number line renders for an UNPARSEABLE number too, as an em dash.**
            // `03-source-system.md` rule 9 requires it, and omitting the line instead would
            // leave an omake looking like a chapter with no number at all — a different claim
            // from "the site could not tell me this chapter's number".
            Text(
              number == null
                  ? '${copy.readerChapterNumberUnreadable} —'
                  : copy.readerChapterNumber(formatChapterNumber(number)),
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(document.chapterName, style: theme.textTheme.headlineSmall),
          ],
        ),
      ),
    );
  }
}

/// The ephemeral line that appears **once** per session, on the first offline display.
///
/// ⚠️ **Once, tracked by the session, and never a banner.** § 3.5 forbids a band, a gradient
/// and any "OFFLINE MODE": three of them would be a badge, a strip and a mode, competing
/// with the prose for a reader's attention in a screen whose entire promise is that the
/// prose is the point. It is a sentence that appears once and leaves.
class ReaderOfflineNote extends StatefulWidget {
  const ReaderOfflineNote({required this.visible, super.key});

  final bool visible;

  @override
  State<ReaderOfflineNote> createState() => _ReaderOfflineNoteState();
}

class _ReaderOfflineNoteState extends State<ReaderOfflineNote> {
  bool _shownThisSession = false;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool show = widget.visible && !_shownThisSession;
    if (show) {
      // ⚠️ **Recorded in `build`, deliberately.** The alternative — a post-frame callback or
      // a provider — would put the session flag somewhere the reader's scroll does not reach,
      // and the note would come back on every reconstruction.
      _shownThisSession = true;
    }
    if (!show) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
      child: Text(
        AppLocalizations.of(context).readerOfflineBanner,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
