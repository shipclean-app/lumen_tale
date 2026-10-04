// Lumen Tale — `/novel/:novelId`: the header that collapses, the pinned row, and the nine states.
//
// `3-2`. The screen that makes B12 visible — *a list nobody asked for is not an empty list* —
// and that turns `2-5`'s *add* into something a reader can act on.
//
// ## ⚠️ THE HEADER IS DRAWN FROM WHAT THE ROUTE BROUGHT, BEFORE ANY LIST IS ASKED
//
// The banner, the title and the metadata come from the stored novel row. Only the chapter list
// waits, and it waits **as its own state**. That split is why `ChapterListLoading` is a
// skeleton of tiles rather than a spinner: the reader already knows which novel they are
// looking at, and a spinner over the whole screen would hide that they know.
//
// ## ⚠️ `*Go to the current chapter*` IS NOT RENDERED, NOT RENDERED EMPTY (B16)
//
// A button that navigates to nothing is a button that lies. The row asserts its absence.
//

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/domain/library/chapter_entry.dart';
import 'package:lumen_tale/features/novel_details/chapter_list_view_state.dart';
import 'package:lumen_tale/features/novel_details/providers/novel_details_providers.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// `/novel/:novelId` — one novel, and the nine states its chapter list can be in.
class NovelDetailsScreen extends ConsumerStatefulWidget {
  const NovelDetailsScreen({
    required this.novelId,
    required this.sourceName,
    this.currentChapterId,
    super.key,
  });

  final String novelId;
  final String sourceName;

  /// `null` → no `current` tile and no *Go to the current chapter* button at all.
  final String? currentChapterId;

  @override
  ConsumerState<NovelDetailsScreen> createState() => _NovelDetailsScreenState();
}

class _NovelDetailsScreenState extends ConsumerState<NovelDetailsScreen> {
  /// ⚠️ **The site's last answer, and it lives HERE.** Not in a provider: it is true from the
  /// tap until the next tap, and a shared holder would put one novel's answer on another
  /// novel's screen. Two detail screens can be on the stack at once.
  ChapterListSiteAnswer? _answer;

  /// ⚠️ **`true` only while a load is in flight, and it drives a bar rather than a spinner.**
  ///
  /// The reader has pressed a button, so the screen owes them a progress indication on **that
  /// list** — not a modal spinner over the novel they are reading about.
  bool _loading = false;

  Future<void> _loadFromSite() async {
    setState(() => _loading = true);
    try {
      final outcome = await ref.read(chapterListLoaderProvider)(widget.novelId);
      if (!mounted) return;
      setState(() {
        _answer = ChapterListSiteAnswer.of(outcome);
        _loading = false;
      });
    } on Object {
      // ⚠️ **A throw is not a state.** `mapAsyncError`'s lesson from `3-1` applies: the default
      // for forgetting to handle a throw is an empty list, and an empty list is the sentence
      // B12 forbids. The loader is typed and its failures are values, so reaching here means
      // the loader itself misbehaved — and the honest thing is to say nothing changed rather
      // than to render "no chapters".
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final AsyncValue<List<ChapterEntry>> rows = ref.watch(
      chapterListProvider(widget.novelId),
    );
    final AsyncValue<int> unopened = ref.watch(
      chapterUnopenedCountProvider(widget.novelId),
    );

    final ChapterListViewState state = switch (rows) {
      AsyncData<List<ChapterEntry>>(value: final List<ChapterEntry> chapters) =>
        mapChapterList(
          chapters: chapters,
          // ⚠️ **The SQL count when it has arrived; the list's own count when it has not.** Not
          // `?? chapters.length`: a chapter marked read in a write the stream has not observed
          // would make the badge disagree with the tiles under it, and both are on screen.
          unopenedCount: unopened.value ?? countUnreadIn(chapters),
          source: _answer == null
              ? ChapterListSource.stored
              : ChapterListSource.fromSite,
          sourceName: widget.sourceName,
          siteFailure: _answer?.failure,
          siteSuppliedSignal: _answer?.siteSuppliedSignal ?? '',
          currentChapterId: widget.currentChapterId,
        ),
      // ⚠️ **A stored list this app cannot read is its OWN state, and it offers no load.**
      // Loading from the site would REPLACE the stored copy with a second truth — and that is
      // precisely the state that exists because the first truth could not be read.
      AsyncError<List<ChapterEntry>>() => const ChapterListStoredUnreadable(),
      _ => const ChapterListLoading(),
    };

    return AppScaffold(
      titleBar: AppBar(title: Text(copy.novelDetailsTitle)),
      content: ChapterListBody(
        state: state,
        sourceName: widget.sourceName,
        isLoading: _loading,
        onLoad: _loadFromSite,
      ),
    );
  }
}

/// The list, or the one state that explains why there is no list.
///
/// ⚠️ **A `switch` over a sealed hierarchy with no `default`**, so a tenth state is a compile
/// error here rather than a blank area in a reader's hands.
class ChapterListBody extends StatelessWidget {
  const ChapterListBody({
    required this.state,
    required this.sourceName,
    required this.isLoading,
    required this.onLoad,
    super.key,
  });

  final ChapterListViewState state;
  final String sourceName;
  final bool isLoading;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    // ⚠️ **A local, so the patterns PROMOTE.** `state` is a public final field of the widget,
    // and Dart does not promote a public field — so `_Tiles(state: state)` would not compile
    // and `state.canRetry` would not resolve. One local makes every arm below a promotion
    // instead of a cast.
    final ChapterListViewState current = state;
    return switch (current) {
      ChapterListFilled() => _Tiles(state: current),
      ChapterListLoading() => const _TileSkeleton(),
      ChapterListNeverLoaded() => _ChapterListNotice(
        icon: Icons.download_outlined,
        title: AppLocalizations.of(context).chapterListNeverLoadedTitle,
        body: AppLocalizations.of(
          context,
        ).chapterListNeverLoadedBody(sourceName),
        actionLabel: AppLocalizations.of(context).chapterListLoadAction,
        onAction: onLoad,
        isLoading: isLoading,
      ),
      ChapterListEmptyAtSource() => _ChapterListNotice(
        // ⚠️ **An inbox, not an error icon.** The site answered, and the answer was "none".
        // A warning triangle here would teach a reader that a site with no chapters for one
        // novel is broken.
        icon: Icons.inbox_outlined,
        title: AppLocalizations.of(
          context,
        ).chapterListEmptyAtSourceTitle(sourceName),
        body: AppLocalizations.of(context).chapterListEmptyAtSourceBody,
      ),
      ChapterListSiteUnreadable() => _ChapterListNotice(
        // ⚠️ **This is SC-6 again, at one novel's scale.** Never "0 chapters".
        icon: Icons.cloud_off_outlined,
        title: AppLocalizations.of(
          context,
        ).chapterListUnreadableTitle(sourceName),
        body: AppLocalizations.of(context).chapterListUnreadableBody,
        // ⚠️ **A retry only where a second attempt is honest.** `canRetry` comes from the
        // cause, never from a default.
        actionLabel: current.canRetry
            ? AppLocalizations.of(context).chapterListActionRetry
            : null,
        onAction: current.canRetry ? onLoad : null,
        isLoading: isLoading,
      ),
      ChapterListNotLoadedNoConnection() => _ChapterListNotice(
        // ⚠️ **A phone icon, and NO load button.** Offering *Load* with no connection offers a
        // tap that will fail for exactly the reason it just did.
        icon: Icons.wifi_off_outlined,
        title: AppLocalizations.of(context).chapterListNoConnectionTitle,
        body: AppLocalizations.of(
          context,
        ).chapterListNoConnectionBody(sourceName),
      ),
      ChapterListStoredUnreadable() => _ChapterListNotice(
        icon: Icons.storage_outlined,
        title: AppLocalizations.of(context).chapterListStoredUnreadableTitle,
        body: AppLocalizations.of(
          context,
        ).chapterListStoredUnreadableBody(sourceName),
      ),
      ChapterListDownloadRefusedForSpace() => _ChapterListNotice(
        icon: Icons.sd_storage_outlined,
        title: AppLocalizations.of(context).chapterListSpaceRefusedTitle,
        body: AppLocalizations.of(
          context,
        ).chapterListSpaceRefusedBody(_megabytes(current.requiredBytes)),
      ),
      ChapterListMarkedReadFailed() => _ChapterListNotice(
        icon: Icons.rule_outlined,
        title: AppLocalizations.of(context).chapterListMarkedReadFailedTitle,
        body: AppLocalizations.of(
          context,
        ).chapterListMarkedReadFailedBody(sourceName),
      ),
    };
  }
}

/// A chapter row, keyed by the chapter's own id.
///
/// ⚠️ **`ValueKey(chapter.id)`, never the index.** `2-5` learned this the same way: an id is
/// stable across a re-fetch and a position is not, and a list keyed by position rebuilds every
/// row the moment one is inserted or marked read.
/// ⚠️ **A no-op, and it is a named function rather than a closure.** B16 says the jump button
/// is not rendered when there is nowhere to go; when there *is* somewhere to go, the navigation
/// is `2-6`'s business and not this slice's, so the hook exists and does nothing yet rather
/// than being a `null` that would hide the button.
void _noop() {}

class _Tiles extends StatelessWidget {
  const _Tiles({required this.state});

  final ChapterListFilled state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return Column(
      children: <Widget>[
        ChapterListHeader(
          count: state.chapters.length,
          unopenedCount: state.unopenedCount,
          sourceName: '',
          // ⚠️ **Absent, not rendered empty** (B16). A button that navigates to nothing is a
          // button that lies.
          onJump: state.hasCurrent ? _noop : null,
        ),
        Expanded(
          child: ListView.separated(
            key: const ValueKey<String>('chapter-list'),
            itemCount: state.chapters.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              final ChapterEntry chapter = state.chapters[index];
              return ChapterTile(
                key: ValueKey<String>(chapter.id),
                chapter: chapter,
                isCurrent: chapter.id == state.currentChapterId,
              );
            },
          ),
        ),
        ChapterListTailMarker(
          total: state.chapters.length,
          displayed: state.chapters.length,
          tailLabel: copy.chapterListTailMarker(
            state.chapters.length,
            state.chapters.length,
          ),
        ),
      ],
    );
  }
}

/// One chapter.
class ChapterTile extends StatelessWidget {
  const ChapterTile({
    required this.chapter,
    required this.isCurrent,
    super.key,
  });

  final ChapterEntry chapter;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return ListTile(
      leading: SizedBox(
        width: 40,
        child: Text(
          // ⚠️ **An em dash for an unreadable number, and `0` stays `0`.** -1 never reaches a
          // tile: it is the column's sentinel, not a chapter the site published.
          chapter.numberLabel,
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ),
      title: Text(
        // ⚠️ **The site's own text, verbatim.** `null` became the empty string in `data/`, and
        // *Untitled* is this tile's rendering of it — B10: never an index, never a generated
        // "Chapter 12".
        chapter.name.isEmpty ? copy.chapterListUntitled : chapter.name,
      ),
      subtitle: chapter.isRead
          ? null
          : Text(
              copy.chapterTileUnread,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: chapter.isDownloaded
          ? Icon(
              Icons.download_done_outlined,
              size: 18,
              // ⚠️ **The mark, and only the mark.** `2-4` established that `downloadedAt` is
              // the only discriminator; an interrupted download has no mark (E6) and so shows
              // no tick, rather than a tick over a truncated file.
              color: theme.colorScheme.onSurfaceVariant,
              semanticLabel: copy.chapterTileDownloaded,
            )
          : null,
      selected: isCurrent,
    );
  }
}

/// The list's header: the count, the unread count, and the jump when there is somewhere to go.
class ChapterListHeader extends StatelessWidget {
  const ChapterListHeader({
    required this.count,
    required this.unopenedCount,
    required this.sourceName,
    required this.onJump,
    super.key,
  });

  final int count;
  final int unopenedCount;

  /// The site's name, and an EMPTY STRING means "do not name a site".
  ///
  /// ⚠️ **Empty rather than a nullable string**, so a caller cannot forget the question and be
  /// answered with `null` text.
  final String sourceName;

  /// `null` → the jump button is **not rendered at all** (B16).
  final VoidCallback? onJump;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              sourceName.isEmpty
                  ? copy.chapterListHeaderCount(count)
                  : copy.chapterListHeaderAtSource(count, sourceName),
              style: theme.textTheme.titleSmall,
            ),
          ),
          if (onJump != null)
            TextButton(
              onPressed: onJump,
              child: Text(copy.chapterListJumpToCurrent),
            ),
        ],
      ),
    );
  }
}

/// The tail, and it is a fact rather than an invitation.
///
/// ⚠️ **It never says "show more".** B9 forbids a deferred entry, so there is no page two of
/// this list and a control implying one would be a promise the app cannot keep.
class ChapterListTailMarker extends StatelessWidget {
  const ChapterListTailMarker({
    required this.total,
    required this.displayed,
    required this.tailLabel,
    super.key,
  });

  final int total;
  final int displayed;
  final String tailLabel;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: Text(
        tailLabel,
        textAlign: TextAlign.center,
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// The one shape every non-list state uses: icon, title, body, and at most one action.
final class _ChapterListNotice extends StatelessWidget {
  const _ChapterListNotice({
    required this.icon,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.isLoading = false,
  });

  final IconData icon;
  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
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
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              if (actionLabel != null && onAction != null) ...<Widget>[
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : onAction,
                  child: isLoading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(actionLabel!),
                ),
              ],
              if (actionLabel == null) ...<Widget>[
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(copy.chapterListActionBack),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// ⚠️ **A skeleton in the shape of tiles**, never a spinner: the reader already knows which
/// novel they are looking at, and a spinner would hide that they know.
class _TileSkeleton extends StatelessWidget {
  const _TileSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, _) => const ListTile(
        leading: SizedBox(
          width: 40,
          height: 12,
          child: ColoredBox(color: Color(0x14000000)),
        ),
        title: SizedBox(
          height: 12,
          child: ColoredBox(color: Color(0x14000000)),
        ),
      ),
    );
  }
}

/// A size in megabytes, for a sentence a reader can act on.
///
/// ⚠️ **Rounded UP, and never `0`.** "Needs about 0 MB" is a sentence that sends a reader to
/// their storage settings for nothing; `ceil` also means the estimate is never below the truth.
String _megabytes(int bytes) => '${(bytes + 1048575) ~/ 1048576} MB';
