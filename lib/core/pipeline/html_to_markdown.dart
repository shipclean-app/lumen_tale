// Lumen Tale — chapter HTML in, Markdown out. The product's central transformation.
//
// `04-html-to-markdown.md`. `package:html` only — **no `html2md`, no FFI bridge**
// (ADR-003: every published `html2md` declares `sdk: >=2.12.0 <3.0.0`, so Dart 2 alone,
// and adding a Rust toolchain for this step is a bad trade in a mobile reader). So there
// is no base converter to *wrap*: the walk over the document is written here.
//
// ## THE rule this file exists for: `<br><br>` is a paragraph
//
// FanMTL emits **zero** `<p>`. A converter that asks "is this node a `<p>`" sees no `<p>`
// on a real chapter and emits the whole chapter as one paragraph — which **looks**
// correct at a glance and fails structurally. So a paragraph is *either* a `<p>` *or* a
// run of text between two `<br>`s, tracked by `_pendingBreak`:
//
// | state | meaning |
// |---|---|
// | `0` | nothing pending — text joins the current block |
// | `1` | one `<br>` seen; the hard break `  \n` is emitted and nothing more is owed |
// | `2` | two `<br>`s seen; the next text starts a **new paragraph** |
//
// ## The walk is ITERATIVE, over a stack of steps that includes CLOSERS
//
// Recursion over `Element.children` is the shorter spelling and it recurses once per
// **nesting level**. E1 asks that a 10 000-entry list stay readable, and a pathological
// document would overflow. A stack that also carries "close this container" costs one
// list slot rather than one call frame, so depth costs memory instead of stack.
//
// ## Determinism is a promise: same HTML in, byte-identical Markdown out
//
// No `DateTime`, no randomness, no `Set` whose iteration order can reach the output, no
// map hashing. **Lists, always.**

import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'package:lumen_tale/core/pipeline/converted_chapter.dart';
import 'package:lumen_tale/core/pipeline/removal_rule.dart';

/// Converts [request] to Markdown.
///
/// **Never throws for malformed input.** An unreadable chapter comes back
/// [ConvertedChapter.belowThreshold], which the pipeline reports as a failure rather than
/// as an empty chapter — a converter that threw would turn a site's layout change into a
/// crash.
ConvertedChapter convertChapter(ConversionRequest request) {
  final dom.Document document = html_parser.parse(request.rawHtml);
  _applyRemovals(document, request);

  // ⚠️ **`Uri` resolves `href` and `src`, never string concatenation.** A
  // protocol-relative `//evil.example/x` is the case that matters and only `Uri` gets it
  // right (`17-security.md` rule 1).
  final Uri? base = Uri.tryParse(request.baseUrl);

  final dom.Element root = _articleRootOf(document);
  return _Emitter(
    keepImages: request.keepImages,
  ).convert(<dom.Node>[root], base);
}

/// ⚠️ **The union, never a replacement.** `kDefaultRemovals` first, then the source's own,
/// so a source cannot re-introduce a `<script>` by omitting it — omitting is not an
/// operation the type offers.
void _applyRemovals(dom.Document document, ConversionRequest request) {
  for (final RemovalRule rule in <RemovalRule>[
    ...kDefaultRemovals,
    ...kConventionRemovals,
    ...request.additionalRemovals,
  ]) {
    for (final dom.Element node in document.querySelectorAll(rule.selector)) {
      if (rule.matchesSubtree) {
        node.remove();
      } else {
        _unwrap(node);
      }
    }
  }
}

/// Tags only; the text stays.
///
/// ⚠️ **`parent is! dom.Element` is load-bearing.** `querySelectorAll` is a live view, so
/// an earlier rule in this same pass may have removed an **ancestor** of this node — and
/// `parent` would then be the Document, so inserting into it would re-parent the node
/// *outside* the article and silently move prose out of the chapter. `package:html` has no
/// `parentElement`; this narrowing does the same job.
void _unwrap(dom.Element element) {
  final dom.Node? parent = element.parent;
  if (parent is! dom.Element) {
    return;
  }
  for (final dom.Node child in element.nodes.toList(growable: false)) {
    child.remove();
    parent.insertBefore(child, element);
  }
  element.remove();
}

/// The article node, when the page marks one.
///
/// ⚠️ **`main`, then `article`, then the body.** The source has already extracted its own
/// container (`2-1`'s `div.chapter-inner.chapter-content`), so this is a *second* narrowing
/// for a page handed over whole — and a page with neither falls back to the body rather
/// than converting the `<head>`.
dom.Element _articleRootOf(dom.Document document) {
  for (final String selector in const <String>['main', 'article']) {
    final dom.Element? found = document.querySelector(selector);
    if (found != null) {
      return found;
    }
  }
  return document.body ?? document.documentElement!;
}

/// Builds the Markdown and owns every count.
///
/// One class because the counts are not derivable afterwards: `_pendingBreak` decides
/// whether text opens a paragraph, and the paragraph count is incremented at the same
/// moment. Splitting them would mean re-deriving one from the other, and the two would be
/// free to disagree.
final class _Emitter {
  _Emitter({required this.keepImages});

  final bool keepImages;

  final StringBuffer _out = StringBuffer();

  /// 0, 1 or 2 — § 3.2's table, and the whole of this converter's central rule.
  int _pendingBreak = 0;

  /// The open lists, so a `</ul>` dedents exactly one level.
  final List<_ListFrame> _lists = <_ListFrame>[];

  int _emphasisDepth = 0;
  int _strongDepth = 0;
  bool _atLineStart = true;

  /// Whether any prose has been emitted yet.
  bool _documentStarted = false;

  /// Whether the last block was CLOSED — a `</p>` the site wrote.
  ///
  /// ⚠️ **This is what makes `paragraphCount` the number of paragraphs a reader SEES.**
  ///
  /// `<p>One</p>Two` is two paragraphs and one paragraph respectively: the site closed a
  /// block, so the text after it starts another. Without this, "Two" joined the `<p>`'s
  /// block and the output showed three paragraphs while the count said two — and the
  /// count is what E22's threshold reads.
  bool _blockClosed = false;

  int paragraphCount = 0;
  int lineBreakCount = 0;
  int imagesKept = 0;
  int plainTextLength = 0;

  ConvertedChapter convert(List<dom.Node> roots, Uri? base) {
    _walk(roots, base);
    return ConvertedChapter(
      markdown: _normalise(_out.toString()),
      paragraphCount: paragraphCount,
      lineBreakCount: lineBreakCount,
      plainTextLength: plainTextLength,
      imagesKept: imagesKept,
    );
  }

  // ── the walk ────────────────────────────────────────────────────────────────

  /// ⚠️ **First child first**, which a reversed push produces: the stack pops from the
  /// end. The first version appended and popped, and the whole document came out
  /// reversed — a bug five rows caught at once.
  void _walk(List<dom.Node> nodes, Uri? base) {
    final List<_Step> stack = <_Step>[];
    for (int i = nodes.length - 1; i >= 0; i--) {
      stack.add(_Step.forNode(nodes[i]));
    }

    while (stack.isNotEmpty) {
      final _Step step = stack.removeLast();
      final _Closer? closer = step.closer;
      if (closer != null) {
        _closeWith(closer);
        continue;
      }
      // ⚠️ **Text nodes are steps too.** An earlier version emitted them while *pushing*,
      // which put every sentence of a chapter out before the element that contained it —
      // five rows caught it at once and the whole document came out empty of prose.
      final dom.Node node = step.node!;
      // ignore: avoid_print
      if (node is dom.Text) {
        _emitText(node.data);
        continue;
      }
      if (node is! dom.Element) {
        // A comment, a doctype, a processing instruction. Dropping it silently is right: a
        // comment inside a sentence is not prose.
        continue;
      }
      _open(node, base, stack);
    }
  }

  void _pushChildren(dom.Element element, _Closer? closer, List<_Step> stack) {
    // The closer goes on **first** so it is popped **last**.
    if (closer != null) {
      stack.add(_Step.forCloser(closer));
    }
    final List<dom.Node> children = element.nodes.toList(growable: false);
    for (int i = children.length - 1; i >= 0; i--) {
      stack.add(_Step.forNode(children[i]));
    }
  }

  void _open(dom.Element element, Uri? base, List<_Step> stack) {
    final String tag = element.localName?.toLowerCase() ?? '';

    switch (tag) {
      // ── § 3.2, the central rule ──────────────────────────────────────
      case 'br':
        _onBreak();
        return;
      case 'p':
        _openParagraph();
        _pushChildren(element, const _ParagraphCloser(), stack);
        return;

      // ── blocks ──────────────────────────────────────────────────────
      case 'h1':
      case 'h2':
      case 'h3':
      case 'h4':
      case 'h5':
      case 'h6':
        _blankLine();
        _text('#' * int.parse(tag.substring(1)), raw: true);
        // ⚠️ **`_atLineStart = false` BEFORE the space, or it is trimmed.** `_emitText`
        // trims a leading space at a line start — right for source indentation, wrong
        // here. The first version produced `###Sub`.
        _atLineStart = false;
        _text(' ', raw: true);
        // ⚠️ **`_documentStarted = true` here, and it is what makes `### Title` a heading
        // rather than `### ` followed by a new paragraph.** The first run of text in a
        // document opens a paragraph — that is how a chapter with no `<p>` and no `<br>`
        // still gets one — but a heading's own text is part of the *heading*, not the
        // first paragraph of the body. Without this the marker and the title are split by
        // a blank line and the heading renders as an empty one.
        _documentStarted = true;
        _pushChildren(element, const _HeadingCloser(), stack);
        return;
      case 'hr':
        _blankLine();
        _text('---', raw: true);
        _blankLine();
        return;
      case 'blockquote':
        _blankLine();
        _quoteStarts.add(_out.length);
        _pushChildren(element, const _BlockquoteCloser(), stack);
        return;
      case 'ul':
      case 'ol':
        _lists.add(_ListFrame(ordered: tag == 'ol'));
        _pushChildren(element, const _ListCloser(), stack);
        return;
      case 'li':
        _visitListItem(element, base, stack);
        return;
      case 'table':
        _visitTable(element, base);
        return;
      case 'img':
        _visitImage(element, base);
        return;

      // ── inline ──────────────────────────────────────────────────────
      case 'em':
      case 'i':
        _emphasisDepth += 1;
        _text('*', raw: true);
        // ⚠️ **`_documentStarted = true` after an inline marker too.** The first run of
        // text in a document opens a paragraph — which is how a chapter with no `<p>` and
        // no `<br>` still gets one — and `*a*`'s text is part of the *emphasis*, not the
        // first paragraph. Without it the output was `*~a*`: the marker, a blank line,
        // then the text it belongs to.
        _documentStarted = true;
        _pushChildren(
          element,
          _InlineCloser('*', () => _emphasisDepth -= 1),
          stack,
        );
        return;
      case 'strong':
      case 'b':
        _strongDepth += 1;
        _text('**', raw: true);
        _documentStarted = true;
        _pushChildren(
          element,
          _InlineCloser('**', () => _strongDepth -= 1),
          stack,
        );
        return;
      case 'del':
      case 's':
        _emphasisDepth += 1;
        _text('~~', raw: true);
        _documentStarted = true;
        _pushChildren(
          element,
          _InlineCloser('~~', () => _emphasisDepth -= 1),
          stack,
        );
        return;
      case 'code':
        // ⚠️ **Never escaped**, and that is the whole point of `<code>`: a chapter about
        // shell quoting must survive intact.
        _text('`${element.text}`', raw: true);
        _atLineStart = false;
        return;
      case 'pre':
        // ⚠️ **Never escaped, triple backtick, raw content.** Same reason.
        _blankLine();
        _text('```', raw: true);
        _out.write('\n${element.text}\n');
        _text('```', raw: true);
        _blankLine();
        return;
      case 'a':
        _visitLink(element, base);
        return;

      default:
        // A tag with no rule of its own: its children are walked. **That is what keeps
        // prose** — dropping unlisted subtrees would lose it, and rule 8 ("no data loss")
        // outranks tidiness.
        _pushChildren(element, null, stack);
    }
  }

  /// The offsets at which each open blockquote began.
  final List<int> _quoteStarts = <int>[];

  /// ⚠️ **Every line of the emitted slice gets a `> `, not just the first.**
  ///
  /// Writing `> ` once at the start is the common shortcut and it produces a Markdown
  /// blockquote whose later lines fall out of it — which is what a hard break inside the
  /// quote does. Buffering the slice and prefixing per line is the only way to get the
  /// continuation lines right.
  void _closeBlockquote() {
    if (_quoteStarts.isEmpty) {
      return;
    }
    final int from = _quoteStarts.removeLast();
    final String all = _out.toString();
    final String body = all.substring(from);
    final String marked = body
        .split('\n')
        .map((String line) => line.trim().isEmpty ? '' : '> $line')
        .join('\n');
    _out
      ..clear()
      ..write(all.substring(0, from))
      ..write(marked);
    _blankLine();
  }

  void _closeWith(_Closer closer) {
    switch (closer) {
      case _ParagraphCloser():
        _closeParagraph();
      case _HeadingCloser():
        _blankLine();
      case _BlockquoteCloser():
        _closeBlockquote();
      case _ListCloser():
        _lists.removeLast();
        _blankLine();
      case _InlineCloser(:final String marker, :final void Function() leave):
        // ⚠️ **No closer for an unopened emphasis.** `<b>text` with no closing tag is
        // malformed; emitting `**` anyway leaves a stray pair of asterisks in the prose.
        if (_emphasisDepth > 0 || _strongDepth > 0) {
          leave();
          _text(marker, raw: true);
        }
    }
  }

  // ── the central rule ──────────────────────────────────────────────────────

  /// ⚠️ **Nothing is emitted here — the break is DEFERRED to the next text.**
  ///
  /// § 3.2's table says a `<br>` followed by a `<br>` emits *nothing*, and a `<br>` followed
  /// by text emits `  \n`. Emitting the hard break on the first `<br>` and then upgrading
  /// it to a paragraph on the second is **not** "nothing": it produced `Two  \n\nThree` —
  /// a hard break *and* a paragraph, two visual separations where the site asked for one.
  ///
  /// So `_pendingBreak` is a promise, and [`_emitText`] keeps it.
  void _onBreak() {
    if (_pendingBreak < 2) {
      _pendingBreak += 1;
    }
    // A third `<br>` changes nothing: still a boundary.
  }

  /// The hard break a single `<br>` owes: **two trailing spaces and a newline.**
  ///
  /// ⚠️ **Exactly two spaces.** Without them most renderers join the lines back into one,
  /// and with four — which is what calling a space-writer first produced — the second pair
  /// is read as content.
  void _emitHardBreak() {
    final String current = _out.toString();
    if (current.endsWith(' ')) {
      _out
        ..clear()
        ..write(current.trimRight());
    }
    _out.write('  \n');
    lineBreakCount += 1;
    _atLineStart = true;
  }

  void _emitText(String raw) {
    // ⚠️ **Rule "Whitespace": every run of `[\s\n]` in a text node is ONE space.** Not
    // stripped — a chapter's indentation is not prose.
    final String collapsed = raw.replaceAll(RegExp(r'[\s\n]+'), ' ');

    // ⚠️ **The deferred break is paid HERE**, between the `<br>` and the text that
    // follows it — which is the only place both are known.
    //
    // `_pendingBreak == 2` is the site's `<br><br>` and opens a paragraph; `== 1` is a
    // single `<br>` and owes a hard break. And `_pendingBreak == 0` with an empty
    // document opens the first paragraph, because a chapter that begins straight into
    // prose with no `<p>` and no `<br>` still has paragraphs — and `paragraphCount` is what
    // E22's threshold reads.
    if (_pendingBreak == 2 || !_documentStarted || _blockClosed) {
      _openParagraph();
    } else if (_pendingBreak == 1) {
      _emitHardBreak();
      _pendingBreak = 0;
    }
    if (collapsed.isEmpty) {
      return;
    }
    _documentStarted = true;

    final String body = _atLineStart ? collapsed.trimLeft() : collapsed;
    if (body.isEmpty) {
      return;
    }

    plainTextLength += _unescapedLength(body);
    _text(body);
    _atLineStart = false;
  }

  void _openParagraph() {
    _pendingBreak = 0;
    _blockClosed = false;
    _blankLine();
    paragraphCount += 1;
    _atLineStart = true;
    // ⚠️ **Opening a paragraph is the document starting.**
    //
    // Without this, `<p>One</p>` opened a paragraph and then its own text saw
    // `!_documentStarted` and opened a *second* one — so `<p>One</p><p>Two</p>` counted
    // three paragraphs, and the count E22's threshold reads was one too high.
    _documentStarted = true;
  }

  void _closeParagraph() {
    _pendingBreak = 0;
    _blockClosed = true;
    _blankLine();
    _atLineStart = true;
  }

  // ── lists ──────────────────────────────────────────────────────────────────

  void _visitListItem(dom.Element element, Uri? base, List<_Step> stack) {
    final _ListFrame? frame = _lists.isEmpty ? null : _lists.last;
    final String indent = '  ' * (_lists.length - 1);
    // ⚠️ **`frame.ordered`, not "is there a frame".** The first version chose `- ` only
    // when there was NO list, so every `<ul>` item rendered as `1.` — a bullet list that
    // claimed to be numbered, in Markdown a renderer will show as numbers.
    final String marker = frame == null
        ? '- '
        : (frame.ordered ? '${frame.counter(_lists.length)}. ' : '- ');

    _trailingSpaces();
    _text('$indent$marker', raw: true);
    _atLineStart = false;
    // ⚠️ **The same rule as a heading.** A list item's first line belongs to the item, not
    // to a paragraph that happens to start with it.
    _documentStarted = true;

    final int before = _out.length;
    // ⚠️ **The item's children are walked HERE, not through the shared stack.**
    //
    // The continuation indent has to be applied to the text this item produced, and that
    // text is only complete once the item's own subtree is done — so the item's subtree is
    // walked to completion here. The first version ALSO pushed the children, and every
    // item rendered twice: `1. One    1. Deep`.
    //
    // The recursion is bounded by the item's own nesting depth, not by its sibling count,
    // so E1's 10 000-entry list is still iterative where it matters.
    _walk(element.nodes.toList(growable: false), base);
    final String all = _out.toString();
    final String body = all.substring(before);
    if (body.contains('\n')) {
      // ⚠️ **Every newline inside the item is re-indented.** A bare `\n` at that point drops
      // the continuation line out of the list, and the second line of a wrapped item
      // stops being part of it.
      final String continuation = ' ' * marker.length;
      _out
        ..clear()
        ..write(all.substring(0, before))
        ..write(body.replaceAll('\n', '\n$indent$continuation'));
    }
    _out.write('\n');
    _atLineStart = true;
  }

  // ── links and images ───────────────────────────────────────────────────────

  void _visitLink(dom.Element element, Uri? base) {
    final String? resolved = _resolveHref(element.attributes['href'], base);
    final String label = element.text.trim();

    // ⚠️ **`javascript:` is NEVER rendered.** A link is navigation; a `javascript:` href is
    // code pretending to be a place. The label survives as plain text, because the words
    // are the author's.
    if (resolved == null) {
      if (label.isNotEmpty) {
        _emitText(label);
      }
      return;
    }
    if (label.isEmpty) {
      _text(resolved, raw: true);
      _atLineStart = false;
      return;
    }
    _text('[$label]($resolved)', raw: true);
    _atLineStart = false;
  }

  void _visitImage(dom.Element element, Uri? base) {
    // ⚠️ **Rule 3: drop by default.** See [ConversionRequest.keepImages].
    if (!keepImages) {
      return;
    }
    final String? resolved = _resolveHref(element.attributes['src'], base);
    if (resolved == null) {
      // ⚠️ **An unresolvable `src` is dropped and NOT counted.** An `![](…)` the reader
      // will also see broken is worse than no image.
      return;
    }
    imagesKept += 1;
    _text('![${element.attributes['alt'] ?? ''}]($resolved)', raw: true);
    _atLineStart = false;
  }

  String? _resolveHref(String? href, Uri? base) {
    if (href == null || href.trim().isEmpty) {
      return null;
    }
    final String trimmed = href.trim();
    final String lowered = trimmed.toLowerCase();

    // ⚠️ **A scheme check BEFORE any resolution.** These are not places a reader can go,
    // and a converter that passes one through is emitting code into a document.
    for (final String scheme in const <String>[
      'javascript:',
      'data:',
      'vbscript:',
      'file:',
    ]) {
      if (lowered.startsWith(scheme)) {
        return null;
      }
    }
    if (lowered.startsWith('#')) {
      // An in-page anchor, kept verbatim: it is the author's own reference.
      return trimmed;
    }
    if (base == null) {
      return trimmed;
    }
    try {
      return base.resolve(trimmed).toString();
    } on Object {
      return null;
    }
  }

  // ── tables: three branches, and the fallback is a rule ────────────────────

  void _visitTable(dom.Element table, Uri? base) {
    final List<List<String>> rows = <List<String>>[
      for (final dom.Element row in table.querySelectorAll('tr'))
        <String>[
          for (final dom.Element cell in row.querySelectorAll('th, td'))
            cell.text.trim(),
        ],
    ];

    // ⚠️ **Over `kMaxTableRows` the fallback is unconditional.** At that size "too
    // irregular to represent" is the only honest description, and a 200-row Markdown table
    // is not readable on a 360 dp phone.
    if (!_isRegularTable(rows) || rows.length > kMaxTableRows) {
      for (final List<String> row in rows) {
        if (row.every((String c) => c.isEmpty)) {
          continue;
        }
        _openParagraph();
        for (int c = 0; c < row.length; c++) {
          if (row[c].isEmpty) {
            continue;
          }
          _emitText(row[c]);
          // ⚠️ **The em dash, not a pipe.** A pipe inside prose reads as a table row to
          // every renderer, and this fallback is prose.
          if (c != row.length - 1 && row[c + 1].isNotEmpty) {
            _emitText(' — ');
          }
        }
        _closeParagraph();
      }
      return;
    }

    _blankLine();
    for (int r = 0; r < rows.length; r++) {
      _text('| ${rows[r].join(' | ')} |', raw: true);
      _out.write('\n');
      if (r == 0) {
        _text(
          '|${List<String>.filled(rows[r].length, '---').join('|')}|',
          raw: true,
        );
        _out.write('\n');
      }
    }
    _blankLine();
  }

  bool _isRegularTable(List<List<String>> rows) {
    if (rows.isEmpty) {
      return false;
    }
    final int width = rows.first.length;
    if (width < 1) {
      return false;
    }
    for (final List<String> row in rows) {
      if (row.length != width) {
        return false;
      }
      if (row.every((String c) => c.isEmpty)) {
        return false;
      }
    }
    return true;
  }

  // ── emitting ───────────────────────────────────────────────────────────────

  /// Writes escaped prose.
  ///
  /// ⚠️ **`raw: true` is for punctuation this class itself produces** — a heading's `#`, a
  /// list's `-`, a link's `[`. Prose goes through the escaping path, and only prose.
  void _text(String value, {bool raw = false}) {
    if (value.isEmpty) {
      return;
    }
    _out.write(raw ? value : escapeMarkdown(value));
    if (value.endsWith('\n')) {
      _atLineStart = true;
    }
  }

  void _blankLine() {
    final String current = _out.toString();
    if (current.endsWith('\n\n')) {
      // ⚠️ **Never two blank lines in a row** (rule "Whitespace"), and an empty buffer is
      // not a blank line — it is the start of the document.
      return;
    }
    if (current.endsWith('\n')) {
      _out.write('\n');
    } else if (current.isNotEmpty) {
      _out.write('\n\n');
    }
    _atLineStart = true;
  }

  /// Two trailing spaces, which is what makes a `\n` a **hard** break.
  void _trailingSpaces() {
    if (_atLineStart) {
      return;
    }
    final String current = _out.toString();
    if (current.isEmpty || current.endsWith('  ')) {
      return;
    }
    _out.write('  ');
  }
}

/// One step on the walk: a node to open, or a container to close.
final class _Step {
  _Step.forNode(this.node) : closer = null;

  _Step.forCloser(this.closer) : node = null;

  /// A `Node` and not an `Element`, because a text node is also a step — it is emitted
  /// on push rather than on open, so `_pushNode` handles it before a `_Step` is made.
  final dom.Node? node;
  final _Closer? closer;
}

/// What to emit when a container closes.
sealed class _Closer {
  const _Closer();
}

final class _ParagraphCloser extends _Closer {
  const _ParagraphCloser();
}

final class _HeadingCloser extends _Closer {
  const _HeadingCloser();
}

final class _BlockquoteCloser extends _Closer {
  const _BlockquoteCloser();
}

final class _ListCloser extends _Closer {
  const _ListCloser();
}

final class _InlineCloser extends _Closer {
  const _InlineCloser(this.marker, this.leave);

  final String marker;
  final void Function() leave;
}

/// One open list, and the counters that make an `<ol>` read as one.
final class _ListFrame {
  _ListFrame({required this.ordered});

  final bool ordered;
  final List<int> _counters = <int>[];

  /// The number for the item at [depth] (0-based), starting at 1.
  ///
  /// ⚠️ **Reset per depth**, so a nested list restarts at 1 rather than continuing its
  /// parent's count — which is what every renderer does and what a reader expects.
  int counter(int depth) {
    while (_counters.length <= depth) {
      _counters.add(1);
    }
    final int value = _counters[depth];
    _counters[depth] = value + 1;
    return value;
  }
}

/// A table above this many rows is prose, not a table.
const int kMaxTableRows = 200;

/// ⚠️ **The Markdown reserved set, and "only where it would change the sense".**
///
/// A chapter *about* Markdown must stay readable: escaping `*` when it is surrounded by
/// spaces turns a sentence into noise. So a character is escaped only when it is adjacent
/// to a non-space character — the compromise the plan's row *un mot qui contient des
/// astérisques reste lisible* locks down.
String escapeMarkdown(String input) {
  const String reserved = r'\`*_{}[]()#+-.!|~>';
  final StringBuffer out = StringBuffer();

  for (int i = 0; i < input.length; i++) {
    final String character = input[i];
    if (!reserved.contains(character)) {
      out.write(character);
      continue;
    }

    final bool hasLeft = i > 0 && !_isSpace(input[i - 1]);
    final bool hasRight = i + 1 < input.length && !_isSpace(input[i + 1]);
    out.write(hasLeft || hasRight ? '\\$character' : character);
  }
  return out.toString();
}

bool _isSpace(String character) =>
    character == ' ' ||
    character == '\t' ||
    character == '\n' ||
    character == '\r';

/// Trailing whitespace trimmed per line, and the document's own blank edges gone.
///
/// ⚠️ **Per line, and the two-space hard break is preserved**: trimming blindly would
/// delete the very thing `_onBreak` wrote, and every soft-wrapped line would join its
/// neighbour.
String _normalise(String markdown) {
  final List<String> lines = markdown.split('\n');
  final List<String> out = <String>[
    for (final String line in lines)
      if (line.endsWith('  ')) line else line.trimRight(),
  ];
  while (out.isNotEmpty && out.first.trim().isEmpty) {
    out.removeAt(0);
  }
  while (out.isNotEmpty && out.last.trim().isEmpty) {
    out.removeLast();
  }
  return out.join('\n');
}

/// The visible length of a fragment, escape characters excluded.
int _unescapedLength(String text) {
  final StringBuffer out = StringBuffer();
  for (int i = 0; i < text.length; i++) {
    if (text[i] == r'\' && i + 1 < text.length) {
      i += 1;
      out.write(text[i]);
      continue;
    }
    out.write(text[i]);
  }
  return out.toString().trim().length;
}
