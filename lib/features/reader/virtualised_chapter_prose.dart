// Lumen Tale — the prose, virtualised over blocks when the chapter is large.
//
// `2-7` promise 4 and `prd.md` § 7.1: "scrolling a downloaded chapter drops no frames".
//
// ## ⚠️ That is a property of TREE CONSTRUCTION, not of Flutter
//
// A `SingleChildScrollView` holding ten thousand `Text` widgets builds ten thousand widgets on
// the first frame — and the frames dropped while opening a chapter are the frames a reader
// notices. So the long path is a `ListView.builder` over **blocks**, and the short path is
// one `MarkdownBody`.
//
// ## ⚠️ The threshold is DERIVED from a budget, and the budget is written down
//
// The image budget is 16 ms at 60 Hz. A Markdown block renders in a fraction of a
// millisecond, so a few thousand blocks in one frame exceed the budget by themselves.
// [kVirtualiseAboveBlockCount] is that few-thousand, and the comment says where it comes from
// rather than presenting a number as a fact.
//
// ## ⚠️ `byteLength` decides, and it is free
//
// `2-4`'s `ChapterText` already carries the file's **measured** size. It is a local,
// deterministic signal that costs nothing — as opposed to timing the build, which is a
// property of the device, and `Q-003` says there is no device here to time.
//
// So: bytes over the threshold → virtualise; under it → one widget, because a
// `ListView.builder` over 30 blocks costs more than it saves.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/features/reader/domain/reader_typography.dart';
import 'package:lumen_tale/features/reader/reader_layout.dart';

/// ⚠️ **Above this many BYTES, the prose is built block by block.**
///
/// Derived, not chosen: the image budget is 16 ms at 60 Hz (`prd.md` § 7.1), a Markdown
/// block renders in a fraction of a millisecond, and 8 192 of them waiting in one frame
/// exceed the budget on their own. It is a *byte* threshold rather than a block count because
/// the byte count is already in hand and deterministic — a block count would have to be
/// derived by splitting, which is the work being decided.
const int kVirtualiseAboveByteLength = 8192;

/// The floor under the column, re-exported so a row can assert the floor without importing
/// the layout file.
const double readerMinColumnWidthDp = kMinColumnWidthDp;

/// The chapter's prose, in whichever of the two modes its size calls for.
///
/// ⚠️ **`prose` is REQUIRED, and it is what makes B27 visible here.** The column receives the
/// style and never computes it (`2-8` § 4.1: *"reçoit le style, ne le calcule pas"*): a
/// default would let this widget render a chapter at `md` while the reader is at `xxl`, and
/// the two would be free to disagree about the same text.
class ChapterProseColumn extends StatelessWidget {
  const ChapterProseColumn({
    required this.document,
    required this.prose,
    required this.layout,
    super.key,
  });

  final ChapterText document;

  /// The reader's chosen step, resolved. `2-8`'s value, handed in rather than read.
  final ReaderProse prose;

  final ReaderLayout layout;

  bool get _virtualise => document.byteLength > kVirtualiseAboveByteLength;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    return ReaderColumn(
      layout: layout,
      screenWidth: screenWidth,
      child: _virtualise
          ? _BlockList(document: document, prose: prose)
          : _SingleBody(document: document, prose: prose),
    );
  }
}

/// The short path: **one** `MarkdownBody` for the whole chapter.
///
/// ⚠️ **No `shrinkWrap` and no height.** The body measures itself; a height set here is what
/// E14 forbids and what `2-4` deliberately left out.
class _SingleBody extends StatelessWidget {
  const _SingleBody({required this.document, required this.prose});

  final ChapterText document;
  final ReaderProse prose;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: document.markdown,
      selectable: true,
      styleSheet: readerStyleSheet(Theme.of(context), prose),
    );
  }
}

/// The long path: a `ListView.builder` over the chapter's **blocks**.
///
/// ⚠️ **Split on blank lines, and the split is lossy in one direction only.** The blocks are
/// re-joined with `\n\n` for the measure and for the reader's eye, and a chapter whose blocks
/// were not separated by a blank line — a definition list, a run of headers — arrives as one
/// block, which is correct. Nothing is dropped: `blocks.join('\n\n') == markdown` is asserted.
class _BlockList extends StatelessWidget {
  const _BlockList({required this.document, required this.prose});

  final ChapterText document;
  final ReaderProse prose;

  @override
  Widget build(BuildContext context) {
    final List<String> blocks = splitIntoBlocks(document.markdown);
    return ListView.builder(
      // ⚠️ **The measuring key is on the LIST, not on the body.** It is what a row taps to
      // reach the reading zone, and naming it here keeps it in one place.
      key: const ValueKey<String>('reader-prose-area'),
      padding: const EdgeInsets.symmetric(vertical: 16),
      // ⚠️ **`itemCount` is computed from the split, never estimated.** An estimate would
      // make the last block unreachable — which is the *clipping* `2-7` promises never
      // happens.
      itemCount: blocks.length,
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: MarkdownBody(
          data: blocks[index],
          selectable: true,
          // ⚠️ **The SAME sheet function as the short path, with the SAME prose.** Two call
          // sites building their own sheet would be free to disagree, and the pair a reader
          // notices is the short chapter and the long one — "it looks different once it gets
          // big".
          styleSheet: readerStyleSheet(Theme.of(context), prose),
        ),
      ),
    );
  }
}

/// Splits Markdown into blank-line-separated blocks, **losing nothing**.
List<String> splitIntoBlocks(String markdown) {
  final List<String> blocks = markdown
      .split(RegExp(r'\n[ \t]*\n+'))
      .where((String block) => block.trim().isNotEmpty)
      .toList();
  return blocks.isEmpty ? <String>[markdown] : blocks;
}

/// The reader's Markdown styling, in one place.
///
/// ## ⚠️ It takes the reader's PROSE, and that is the change `2-8` made
///
/// Before, it took a `ThemeData` and set `p: bodyLarge.copyWith(height: 1.5)` — a
/// hard-coded leading that contradicted ADR-017's held 1.72, and a size that came from the
/// theme rather than from the step the reader chose. B27 makes the step an input: the sheet
/// the reader taps must re-render the chapter **on the same frame**, and the only thing
/// that can do that is the Markdown sheet.
///
/// ⚠️ **The function stays a function.** `MarkdownStyleSheet.fromTheme` needs a
/// `ThemeData`, so two call sites each building their own sheet would be free to disagree —
/// and one of them is the long path and the other the short, which is exactly the pair a
/// reader notices as *"the chapter looks different once it gets big"*.
MarkdownStyleSheet readerStyleSheet(ThemeData theme, ReaderProse prose) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    // ⚠️ **`prose.style`, verbatim, and never `copyWith(height: …)`.** The leading it
    // carries is this step's own ratio, RECOMPUTED by `resolveProse` from the clamped size —
    // copying `step.lineHeight` (44px) onto a recomputed 40px gives 1.10 and overlapping
    // lines, which is precisely what E14 forbids. Nothing here multiplies the phone's
    // scaler: Flutter already applies it through `DefaultTextStyle`, and doing it twice
    // makes the reader twice the size of the rest of the app.
    p: prose.style,
    // ⚠️ **The headings are UNCHANGED from `2-7`.** The reader's step governs the body, and
    // a site that publishes six `#` headings in one chapter should not have them dwarf the
    // prose — but that is a decision `2-7` made about headings, and changing it here would be
    // a visual change this slice has no rule for.
    h1: theme.textTheme.headlineSmall,
    h2: theme.textTheme.titleLarge,
    h3: theme.textTheme.titleMedium,
    // ⚠️ **The prose's SIZE and leading, the theme's COLOUR.** A quotation is the reader's
    // own prose at their own step, set in the secondary colour so it reads as set apart from
    // the narration rather than as a second narration.
    blockquote: prose.style.copyWith(color: theme.colorScheme.onSurfaceVariant),
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Roboto Mono', 'Menlo', 'Courier'],
      color: prose.style.color,
    ),
    blockquoteDecoration: BoxDecoration(
      color: theme.colorScheme.surfaceContainerHighest,
      border: Border(
        left: BorderSide(color: theme.colorScheme.outlineVariant, width: 3),
      ),
    ),
    blockquotePadding: const EdgeInsets.fromLTRB(12, 4, 8, 4),
  );
}
