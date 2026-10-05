// Lumen Tale — the library's unopened-count pill, and the row that carries it.
//
// `design-system.md` § 2.1 (`NovelRow`, variant `library`) and § 2.5.
// `features/library/widgets/` — the row is this screen's own layout of shared pieces.
//
// ## ⚠️ `count == 0` PRODUCES **NO BADGE AT ALL**, AND THE CALL SITE OMITS THE WIDGET
//
// A pill reading `0` is a permanent alarm that means nothing, and B14 asks for an exact
// count — an exact zero is the absence of new chapters, not a badge. So [LibraryRow
// .showsUnopenedBadge] decides *whether the widget is built at all*, rather than the widget
// hiding itself. A pill that exists in the tree at zero is a pill a screen reader announces
// and a `find.byType` test can see, so "no badge" has to be true of the tree and not only
// of the pixels.
//
// ## ⚠️ THE STATUS LINE IS A `Wrap` OF FACTS, NEVER A CONCATENATED STRING
//
// `library.md` § 7: *no row assumes LTR — the status line is a `Wrap` of facts, not a
// single concatenated string, so an RTL locale reorders it without truncation.* A joined
// string would reorder its own words instead, which is how a sentence about a site becomes
// a sentence about a download.
//
// ## ⚠️ THE WHOLE ROW IS **ONE** SEMANTICS NODE
//
// `library.md` § 7: *"The Ascension of the Ninth Son, by Ilan W., 12 not opened, checked 3
// days ago, downloaded, 148 of 480 chapters."* A screen-reader user cannot infer a pill
// from a list, so the count, the timestamp and the pair are **inside the label** — which is
// why the label is built here and not left to four child widgets.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/ui/status_chip.dart';
import 'package:lumen_tale/domain/library/library_row.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The exact unopened count, in a pill. **B14.**
///
/// ⚠️ **The number, never "a few".** "Some chapters" is unfalsifiable, and a reader who
/// cannot check the figure has been told something they cannot verify — which is the shape
/// of every stale-count bug B14 forbids.
class UnopenedBadge extends StatelessWidget {
  const UnopenedBadge({required this.count, super.key});

  final int count;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);

    // ⚠️ **A guard, not the mechanism.** The row omits this widget at zero; if a caller
    // builds it anyway it renders nothing rather than a `0`. Which of the two is load
    // bearing is answered by the row's own test, not by this line.
    if (count <= 0) {
      return const SizedBox.shrink();
    }

    return Semantics(
      // ⚠️ **The count is IN the label**, because § 2.5's rule is that a badge is never a
      // colour and a screen reader is never told "new" without the figure.
      label: copy.libraryUnopenedBadgeSemantics(count),
      excludeSemantics: true,
      child: Container(
        key: const Key('library.unopened-badge'),
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        padding: EdgeInsets.symmetric(horizontal: spacing.xs),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.accent,
          borderRadius: radius.fullAll,
        ),
        child: Text(
          '$count',
          textAlign: TextAlign.center,
          // ⚠️ `--color-text-inverse` on `--color-accent`, which is the pair § 1.1
          // measures at 5.50:1 / 7.25:1. A primary-coloured digit on an accent pill would
          // be the one unreadable number on the row.
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colors.textInverse,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

/// `NovelRow` variant `library` — 72dp, a 48dp cover, a title, an author and the facts.
class LibraryNovelRow extends StatelessWidget {
  const LibraryNovelRow({
    required this.row,
    required this.onTap,
    required this.onRemove,
    super.key,
  });

  final LibraryRow row;

  final VoidCallback onTap;

  /// B32's removal, from the row.
  ///
  /// ⚠️ **`library.md` § 3 says a row carries NO action of its own** — Remove belongs to
  /// the `SelectionActionBar` reached by a long-press, and that bar is `5-1`'s. It is kept
  /// here because `2-5` shipped it as the only reachable way to remove a novel, and a
  /// library with no reachable removal is worse than a row with one button. When the bar
  /// lands it replaces this slot rather than sitting beside it.
  final VoidCallback onRemove;

  /// 72dp, `design-system.md` § 1.3.
  static const double height = 72;

  /// 48dp — the one image on the row.
  static const double coverSize = 48;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);

    final List<Widget> facts = _facts(context, copy);

    return Semantics(
      button: true,
      // ⚠️ **ONE LABEL FOR THE WHOLE ROW.** `library.md` § 7 spells out the sentence: a
      // screen-reader user cannot infer a pill from a list, so the count, the verification
      // and the pair are all inside it.
      label: _semanticLabel(copy),
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        // ⚠️ **A MINIMUM HEIGHT, NOT A FIXED ONE.** `library.md` § 6 says rows are 72dp
        // *and* that nothing overflows at large text scales; those two hold at once only if
        // 72 is a FLOOR. A `SizedBox(height: 72)` is a ceiling, and at 200% the status
        // `Wrap` needs three lines instead of two — which overflowed by 302px on a 360dp
        // phone. `14-design-tokens.md` § Accessibility asks for `Expanded` / scrollable
        // patterns rather than fixed-size boxes; this is that rule applied to a row.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: height),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: LumenSpacing.of(context).lg,
              vertical: LumenSpacing.of(context).sm,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _cover(context, colors),
                SizedBox(width: LumenSpacing.of(context).md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      // ⚠️ **TWO LINES WITH AN ELLIPSIS, never more.** A 360dp phone with a
                      // 200% text scale cannot show an unbounded title, and truncating the
                      // *title* is the loss the design accepts — the full string is on the
                      // novel's chapter list.
                      Text(
                        row.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium,
                      ),
                      // ⚠️ **THE SUBTITLE COLLAPSES AND THE ROW KEEPS ITS 72dp.**
                      // `library.md` § 8: `author` absent → *the `subtitle` slot renders
                      // empty and the row keeps its 72dp*. A dash would be a fact the site
                      // never stated; "Author unknown" is a sentence the library owns, and
                      // it is carried by the *subtitle*, never by the search (ADR-024).
                      if (row.author != null)
                        Text(
                          '${row.sourceName} · ${row.author}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      SizedBox(height: LumenSpacing.of(context).xs2),
                      // ⚠️ **A `Wrap`, so an RTL locale reorders the facts and truncates
                      // none of them.** See the file header.
                      Wrap(
                        spacing: LumenSpacing.of(context).xs,
                        runSpacing: LumenSpacing.of(context).xs2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: facts,
                      ),
                    ],
                  ),
                ),
                // ⚠️ **A 48dp HIT AREAROUND A 24dp GLYPH.** § 6: *the chevron's hit area is
                // padded to 48dp even though the glyph is 24dp, so the row is not the only
                // target* — and `14-design-tokens.md` § Accessibility requires ≥ 48×48 for
                // every tappable affordance.
                IconButton(
                  key: const Key('library.remove'),
                  onPressed: onRemove,
                  icon: const Icon(Icons.remove_circle_outline),
                  tooltip: copy.libraryRemoveAction,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ⚠️ **A SUNKEN BLOCK WITH THE TITLE'S INITIALS, never a broken-image glyph.**
  /// `library.md` § 2: a missing cover is *not* a failure state — E5 is about browsing,
  /// which this screen does not do — and a grey square with a slash in it would be a cover
  /// the reader did not ask about.
  Widget _cover(BuildContext context, LumenColors colors) {
    return ExcludeSemantics(
      child: Container(
        width: coverSize,
        height: coverSize,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: LumenRadius.of(context).smAll,
        ),
        child: row.coverUrl == null
            ? Text(
                row.title.isEmpty ? '?' : row.title.characters.first,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: colors.textDisabled),
              )
            : const SizedBox.shrink(),
      ),
    );
  }

  /// The facts, in the order a reader scans them: the count, the verification, the pair.
  ///
  /// ⚠️ **THE BADGE IS OMITTED HERE AT ZERO.** See the file header — this is the line that
  /// makes "no badge" true of the widget tree.
  List<Widget> _facts(BuildContext context, AppLocalizations copy) {
    final ThemeData theme = Theme.of(context);
    final LumenColors colors = LumenColors.of(context);
    // ⚠️ **READ ONCE AND SHOWN AS ITS OWN CHIP.** § 3.3's three stop wordings are
    // three different sentences a reader acts on differently, and welding them onto the pair
    // would make *12 of 480 downloaded* un-findable — which is the number E6 is about.
    final String? stopped = stoppedLabelOf(row.download, copy);
    return <Widget>[
      if (row.showsUnopenedBadge) UnopenedBadge(count: row.unopenedCount),
      // ⚠️ **B22 — the failed chip carries an ICON AND THE WORDS**, and the exact count
      // beside it is untouched: losing contact with a site changes the verification, never
      // a local fact (B48).
      if (row.couldNotBeChecked)
        StatusChip(
          label: copy.libraryRowCouldNotCheck,
          tone: StatusChipTone.error,
          icon: Icons.cloud_off_outlined,
        ),
      // ⚠️ **B49 — `null` renders *Never checked* in words.** Never "just now", never
      // omitted, and never folded into "0 new": the app never implies nothing is new for a
      // novel it has not looked at.
      if (row.lastCheckedAt == null && !row.couldNotBeChecked)
        StatusChip(
          label: copy.libraryRowNeverChecked,
          tone: StatusChipTone.info,
        ),
      // ⚠️ **THE DOWNLOAD FACT IS A CHIP OR A PAIR, NEVER A PROGRESS BAR.** E6's row says
      // *12 of 480 downloaded*; a determinate bar that is not moving reads as a bar that
      // has finished, which is the exact presentation C8 forbids. There is therefore **no
      // `LinearProgressIndicator` on a stopped row at all** — the test asserts its absence.
      if (row.download == DownloadPresentation.complete)
        StatusChip(
          label: copy.libraryRowDownloadComplete,
          tone: StatusChipTone.success,
          icon: Icons.check_circle_outline,
        ),
      if (stopped != null)
        StatusChip(label: stopped, tone: StatusChipTone.warning),
      if (row.download != DownloadPresentation.complete)
        Text(
          // ⚠️ **`0 / 0` FOR A NOVEL WITH NO CHAPTERS, verbatim.** That is what the
          // site published, and rendering it as *Not downloaded yet* would claim an
          // expectation the library has no evidence for (§ 3.2's last row).
          row.hasNoChapters
              ? row.downloadedPair
              : copy.libraryTileProgress(row.downloadedCount, row.chapterCount),
          key: const Key('library.download-pair'),
          style: theme.textTheme.labelSmall?.copyWith(
            // ⚠️ **THE STATUS LINE IS `--color-text-secondary`, MEASURED AT 6.22:1 / 6.01:1.**
            // It carries the count, which is the most important string on the row, so it is
            // measured as body text and never drawn in the disabled token.
            color: colors.textSecondary,
          ),
        ),
      // ⚠️ **THE SOURCE IS ALWAYS NAMED, and it is a word rather than an icon.** B40/E17:
      // two novels with the same title are only distinguishable by their site, so this is
      // not decoration — it is what makes the row a *row* rather than a duplicate.
      Text(
        row.sourceName,
        key: const Key('library.source-name'),
        style: theme.textTheme.labelSmall?.copyWith(
          color: colors.textSecondary,
        ),
      ),
    ];
  }

  /// ⚠️ **BUILT FROM THE SAME HELPERS THE CHIPS USE**, so the label and the pixels cannot
  /// say different things. `library.md` § 7 spells out the sentence: a screen-reader user
  /// cannot infer a pill from a list, so the count, the verification and the pair are all
  /// inside it.
  String _semanticLabel(AppLocalizations copy) {
    return <String?>[
      row.title,
      if (row.author != null) row.author,
      row.sourceName,
      if (row.showsUnopenedBadge) copy.libraryTileUnopened(row.unopenedCount),
      if (row.couldNotBeChecked)
        copy.libraryRowCouldNotCheck
      else if (row.lastCheckedAt == null)
        copy.libraryRowNeverChecked,
      downloadFactOf(row, copy),
    ].whereType<String>().join(', ');
  }
}

/// The stopped wording for a row, in the reader's words. E6, E7, E20.
///
/// ⚠️ **FOUR CASES AND A FALLBACK, and the fallback is `stopped`, not `running`.** The
/// remaining case is a stopped queue whose cause the row cannot name — and the honest word
/// for it is *stopped*. Renders `null` for every state that is not stopped, so a caller
/// cannot paint a stopped row as anything else.
///
/// ⚠️ **`stoppedByConnectionLost` says *stopped*, NEVER *paused*.** E7: a queue stopped by a
/// lost connection does not resume on its own when the connection returns, and "paused"
/// promises exactly that resume.
String? stoppedLabelOf(
  DownloadPresentation presentation,
  AppLocalizations copy,
) {
  return switch (presentation) {
    DownloadPresentation.stoppedByConnectionLost =>
      copy.libraryRowStoppedConnection,
    DownloadPresentation.stoppedOutOfStorage => copy.libraryRowStoppedStorage,
    DownloadPresentation.stopped => copy.libraryRowStopped,
    DownloadPresentation.none ||
    DownloadPresentation.running ||
    DownloadPresentation.complete => null,
  };
}

/// The whole status line's wording for a row, and the ONE place it is built.
///
/// ⚠️ **A single function, so the chip and the semantics label cannot drift.** `library.md`
/// § 4 *Offline — actions that need a network*: the stopped states must say *stopped* and
/// name the cause; [LibraryNovelRow._semanticLabel] reads the same facts through the same
/// helpers.
String downloadFactOf(LibraryRow row, AppLocalizations copy) {
  final String? stopped = stoppedLabelOf(row.download, copy);
  if (stopped != null) {
    return '$stopped · ${copy.libraryTileProgress(row.downloadedCount, row.chapterCount)}';
  }
  return copy.libraryTileProgress(row.downloadedCount, row.chapterCount);
}
