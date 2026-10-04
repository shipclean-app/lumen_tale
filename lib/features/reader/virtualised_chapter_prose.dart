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
class ChapterProseColumn extends StatelessWidget {
  const ChapterProseColumn({
    required this.document,
    required this.layout,
    super.key,
  });

  final ChapterText document;
  final ReaderLayout layout;

  bool get _virtualise => document.byteLength > kVirtualiseAboveByteLength;

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    return ReaderColumn(
      layout: layout,
      screenWidth: screenWidth,
      child: _virtualise
          ? _BlockList(document: document)
          : _SingleBody(document: document),
    );
  }
}

/// The short path: **one** `MarkdownBody` for the whole chapter.
///
/// ⚠️ **No `shrinkWrap` and no height.** The body measures itself; a height set here is what
/// E14 forbids and what `2-4` deliberately left out.
class _SingleBody extends StatelessWidget {
  const _SingleBody({required this.document});

  final ChapterText document;

  @override
  Widget build(BuildContext context) {
    return MarkdownBody(
      data: document.markdown,
      selectable: true,
      styleSheet: readerStyleSheet(Theme.of(context)),
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
  const _BlockList({required this.document});

  final ChapterText document;

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
          styleSheet: readerStyleSheet(Theme.of(context)),
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
/// ⚠️ **A function, not a `const`.** `MarkdownStyleSheet.fromTheme` needs a `ThemeData`, so
/// two call sites that each built their own sheet would be free to disagree — and one of them
/// would be the long path and the other the short path, which is exactly the pair a reader
/// notices as "the chapter looks different once it gets big".
MarkdownStyleSheet readerStyleSheet(ThemeData theme) {
  return MarkdownStyleSheet.fromTheme(theme).copyWith(
    p: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
    h1: theme.textTheme.headlineSmall,
    h2: theme.textTheme.titleLarge,
    h3: theme.textTheme.titleMedium,
    code: theme.textTheme.bodyMedium?.copyWith(
      fontFamily: 'monospace',
      fontFamilyFallback: const <String>['Roboto Mono', 'Menlo', 'Courier'],
    ),
    blockquote: theme.textTheme.bodyLarge?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
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
