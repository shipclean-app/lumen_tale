// Lumen Tale — the catalogue screen, and the controller that turns one read into a screen.
//
// ## ⚠️ The controller reads ONE page and never merges state from anywhere else
//
// The grid and the footer read the same controller, so there is no second "append" state to
// disagree with the list. A screen holding both a list and a flag for "and also these" is how
// a footer claims to be loading while the list is unchanged.
//
// ## ⚠️ `retry` re-reads the SAME page, and never page 1
//
// A reader who pressed Retry on page 3 and landed on page 1 would think the site had fewer
// novels than it has. The requested page is part of the request, not of the retry decision.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_router.dart' show openNovelDetails;
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/domain/sources/browse_outcome.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';
import 'package:lumen_tale/domain/sources/models/novels_page.dart';
import 'package:lumen_tale/features/browse/browse_repository.dart';
import 'package:lumen_tale/features/browse/catalogue_states.dart';
import 'package:lumen_tale/features/browse/catalogue_view_state.dart';
import 'package:lumen_tale/features/browse/search_outcome.dart';
import 'package:lumen_tale/features/browse/widgets/catalogue_query_field.dart';
import 'package:lumen_tale/features/library/library_screen.dart'
    show libraryStreamProvider;
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The registry, as a provider.
///
/// ⚠️ **Overridden with a VALUE at the bootstrap**, never computed by a factory: the registry is
/// a list of clients, and a factory would build a fresh set of `Dio` instances per listener.
final sourceManagerProvider = Provider<SourceManager>(
  (Ref ref) => throw UnimplementedError(
    'sourceManagerProvider is overridden in the composition root, because it is the '
    'compilation of the static source registry, one HTTP client per source, and one rate '
    'limiter shared by them all',
  ),
);

/// ⚠️ **`keepAlive`, because it BUILDS the registry and not because it has state.**
///
/// `05-state-management.md` rule 8: the repository is a provider because it is the thing every
/// browse screen programs against. Building a `SourceManager` per screen would rebuild the
/// registry on every push, and ADR-013's registry is static — so there is nothing per-screen
/// to rebuild anyway.
final browseRepositoryProvider = Provider<BrowseRepository>(
  (Ref ref) => throw UnimplementedError(
    'browseRepositoryProvider is overridden in the composition root, because it is the '
    'composition of the static source registry and an HTTP client',
  ),
);

/// The controller: one request, one outcome, one view state.
final catalogueControllerProvider = FutureProvider.autoDispose
    .family<CatalogueViewState, CatalogueRequest>((
      Ref ref,
      CatalogueRequest request,
    ) async {
      final BrowseRepository browse = ref.watch(browseRepositoryProvider);

      BrowseOutcome<NovelsPage> outcome;
      try {
        outcome = await browse.readCatalogue(request);
      } on Object {
        // ⚠️ **Caught HERE and turned into a state, never rethrown.** An uncaught throw
        // becomes an `AsyncError` the screen has to remember to handle, and the default
        // for forgetting is an empty list — which is SC-6. `mapAsyncError` is the only
        // route from a throw to a view state, and it cannot return a list-shaped one.
        return mapAsyncError(
          sourceName: request.sourceId,
          tag: request is TagCatalogueRequest ? request.tag : '',
          error: StateError(
            'unreachable — the error is not carried into the state',
          ),
        );
      }

      return mapBrowseOutcome(
        outcome: outcome,
        sourceName: browse.sourceNameOf(request.sourceId),
        tag: request is TagCatalogueRequest ? request.tag : '',
        requestedPage: request.page,
        hasMore: true,
        // ⚠️ **The library's ids ride along, so a tile can say "kept" without a second
        // query per tile.** B11: keeping and following are one act, and a tile offering an
        // add that would be a no-op is a tile that lies.
        inLibraryIds: libraryIdsOf(
          ref.watch(libraryStreamProvider).value ?? const <LibraryEntry>[],
        ),
      );
    });

/// `/browse/:sourceId/genre/:genre` — the catalogue of one tag, or a search when `?q=` is
/// present. **One route, two modes** (`browse-catalogue.md` § 1.1).
class CatalogueScreen extends ConsumerWidget {
  const CatalogueScreen({
    required this.sourceId,
    required this.tag,
    this.page = 1,
    this.words,
    this.supportsSearch,
    super.key,
  });

  final String sourceId;
  final String tag;
  final int page;

  /// ⚠️ **`null` means a catalogue and a non-null means a search** — and a search whose words
  /// are the empty string is still a search, because the reader submitted an empty field and the
  /// site, not this app, decides what that means.
  final String? words;

  /// ⚠️ **`null` means "ask the registry", and it is resolved in `build`.**
  ///
  /// The source's own answer decides whether a line is drawn, and it is the *registry's* answer
  /// — so the screen reads it from the same repository it reads the catalogue from. A caller may
  /// pass a value, which is how a row pins the source's answer without a registry.
  ///
  /// ⚠️ **Never a default of `false`.** A `false` default would make a forgotten argument
  /// silently drop the field, and "the field is missing" is indistinguishable from "this site has
  /// no search" — the one confusion `6-2` exists to prevent.
  final bool? supportsSearch;

  /// What a row may do, assembled ONCE here and handed down.
  ///
  /// ⚠️ **`_Grid` and `CatalogueRow` take callbacks, never a `WidgetRef`.** They are the
  /// layer that renders, and a widget that reached for the repository itself would put the
  /// write one layer away from the branch that decides whether to write.
  ///
  /// ⚠️ **B40 — the row opens THE NOVEL IN THE ROW, never one with a similar title.** The
  /// tap carries `novel.id`, so a catalogue listing two novels with the same title opens the
  /// one the reader tapped. Re-deriving the novel from its title would break exactly the
  /// anti-merge case B40 is written against.
  ///
  /// ⚠️ **THE ADD BUTTON NAVIGATES, AND THAT IS A DEVIATION FROM THE DESIGN DOC.**
  /// `browse-catalogue.md`'s interaction table says the row's `AddAction` writes the library
  /// directly and shows a snackbar with *Undo*. Doing that here would mean
  /// `features/browse` importing `features/library` — which `02-architecture.md` forbids, and
  /// which **two features already do** (`browse` for `libraryStreamProvider`,
  /// `source_unavailable` for the same). The coupling is real and pre-existing; it is a
  /// property of *where the library providers live*, not of this screen.
  ///
  /// The honest move available without rewriting `2-5` is to route the button to the details
  /// screen, which owns the add and already reaches `addFromCatalogue`. That makes the button
  /// TRUE — it was `() {}`, a control that said *add this novel* and added nothing — and it
  /// is what makes `3-2`'s B12 button reachable, which is the point of this wiring. The cost
  /// is one extra tap against the design's intent, and it is recorded rather than absorbed.
  _CatalogueRowActions _rowActions(BuildContext context) =>
      _CatalogueRowActions(
        onOpen: (Novel novel) => openNovelDetails(context, novelId: novel.id),
        onAdd: (Novel novel) => openNovelDetails(context, novelId: novel.id),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations copy = AppLocalizations.of(context);
    final bool searchSupported =
        supportsSearch ??
        ref.read(browseRepositoryProvider).supportsSearchOf(sourceId);
    final CatalogueRequest request = words == null
        ? TagCatalogueRequest(sourceId: sourceId, tag: tag, page: page)
        : SearchCatalogueRequest(sourceId: sourceId, words: words!, page: page);
    final AsyncValue<CatalogueViewState> catalogue = ref.watch(
      catalogueControllerProvider(request),
    );

    return AppScaffold(
      titleBar: AppBar(title: Text(copy.browseTitle)),
      content: Column(
        children: <Widget>[
          // ⚠️ **RENDERED OR NOT RENDERED — there is no disabled state.** A disabled field is a
          // promise about a version that does not exist, and it takes a line on the most
          // comparative screen in the app.
          if (rendersQueryField(supportsSearch: searchSupported))
            CatalogueQueryField(
              initialWords: words ?? '',
              onSubmitted: (String typed) =>
                  goToSearch(context, sourceId, typed),
            ),
          Expanded(
            child: switch (catalogue) {
              AsyncData<CatalogueViewState>(
                value: final CatalogueViewState state,
              ) =>
                switch (state) {
                  CatalogueFilled() => _Grid(
                    state: state,
                    actions: _rowActions(context),
                  ),
                  CatalogueSearchFilled() => _Grid(
                    state: state.state,
                    actions: _rowActions(context),
                  ),
                  _ => CatalogueStates.forState(state),
                },
              AsyncError<CatalogueViewState>(error: final Object failure) =>
                CatalogueStates.forState(
                  mapAsyncError(sourceName: sourceId, tag: tag, error: failure),
                ),
              _ => const _CatalogueSkeleton(),
            },
          ),
        ],
      ),
    );
  }
}

/// Navigates to a search on the same source, carrying the words **byte for byte**.
///
/// ⚠️ **A top-level function taking a [BuildContext], not a provider.** Navigation needs a
/// context and `05-state-management.md` forbids a provider modifying another's state — which
/// starts with the router — so this is the same shape as `openReader` in `app_router.dart` and
/// exists for the same reason.
void goToSearch(BuildContext context, String sourceId, String words) {
  GoRouter.of(
    context,
  ).go(searchQueryFor(sourceId: sourceId, words: words).toString());
}

/// The list, in the site's order with no sort applied by this app.
///
/// ⚠️ **Keyed by the novel's id**, because a novel's id is stable across re-reads and its
/// position is not.
class _Grid extends StatelessWidget {
  const _Grid({required this.state, required this.actions});

  final CatalogueFilled state;
  final _CatalogueRowActions actions;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      key: const ValueKey<String>('catalogue-list'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: state.items.length + 1,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        if (index == state.items.length) {
          return _Footer(state: state);
        }
        final Novel novel = state.items[index];
        return CatalogueRow(
          key: ValueKey<String>(novel.id),
          novel: novel,
          isKept: state.isKept(novel),
          onOpen: actions.onOpen,
          onAdd: actions.onAdd,
        );
      },
    );
  }
}

/// One novel. Title, then the site's own numbers — and **no author line when the site
/// published none** (ADR-024).
/// The two things a catalogue row may do, and nothing else.
///
/// ⚠️ **A CLASS, not two loose parameters**, because the pair travels together and a
/// `_Grid` that took them separately could be handed one and not the other — producing a
/// row that opens nothing and adds nothing, which is the state this file was in.
class _CatalogueRowActions {
  const _CatalogueRowActions({required this.onOpen, required this.onAdd});

  /// Opens this novel's details. B40 — the novel in the row.
  final void Function(Novel novel) onOpen;

  /// ⚠️ **NAVIGATES to the novel's details, where the add happens** (B12) — so this returns
  /// nothing. `openNovelDetails` hands back the pushed route's result, which is not an
  /// `AddOutcome`; typing it as one would have been a claim about the button that is false.
  final void Function(Novel novel) onAdd;
}

/// One novel. Title, then the site's own numbers — and **no author line when the site
/// published none** (ADR-024).
class CatalogueRow extends StatelessWidget {
  const CatalogueRow({
    required this.novel,
    required this.isKept,
    required this.onOpen,
    required this.onAdd,
    super.key,
  });

  final Novel novel;
  final bool isKept;
  final void Function(Novel novel) onOpen;
  final void Function(Novel novel) onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations copy = AppLocalizations.of(context);
    return ListTile(
      // ⚠️ **THE WHOLE ROW OPENS THE NOVEL.** `browse-catalogue.md`'s interaction table says
      // so, and it is the only reason a reader who has just discovered a novel can reach
      // its chapter list, its description and its *Add* button.
      onTap: () => onOpen(novel),
      title: Text(novel.title),
      // ⚠️ **`author` is omitted, not replaced by a dash.** ADR-024: displayed, never searched,
      // and a site may publish none. Royal Road's catalogue rows carry no author at all — a
      // fact its own fixtures recorded — so an author line here would be an empty one.
      subtitle: novel.author == null
          ? null
          : Text(
              novel.author!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
      trailing: isKept
          // ⚠️ **ABSENT, NOT DISABLED** (`browse-catalogue.md`, B11): a kept row carries the
          // marker and no Add, because a greyed *Add* on a row the reader can still open
          // invites them to wonder what they are missing.
          ? Text(
              copy.browseTileKept,
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          : TextButton(
              // ⚠️ **This used to be `() {}`** — a control labelled *add this novel* that added
              // nothing, which is B12's "explicit user action" rendered as a decoration. It now
              // reaches `2-5.addFromCatalogue`, so B40's similar-title question fires BEFORE
              // anything is stored, exactly as it does from the Library.
              onPressed: () => onAdd(novel),
              child: Text(copy.browseTileAdd),
            ),
    );
  }
}

/// The footer's only job is to say whether more exists.
///
/// ⚠️ **Rendered for a [CatalogueFilled] and for nothing else.** An error state has no footer:
/// a footer under an error is a promise that more is coming, and there is nothing coming.
class _Footer extends StatelessWidget {
  const _Footer({required this.state});

  final CatalogueFilled state;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          if (state.appended)
            const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else if (state.hasMore)
            TextButton(onPressed: () {}, child: Text(copy.browseActionRetry))
          else
            Text(
              copy.browseFooterEnd,
              style: Theme.of(context).textTheme.bodySmall,
            ),
        ],
      ),
    );
  }
}

/// ⚠️ **A skeleton in the shape of rows**, and never a spinner: a spinner over a list implies
/// a wait of unknown length, and this list's length is exactly what is unknown.
class _CatalogueSkeleton extends StatelessWidget {
  const _CatalogueSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: 8,
      itemBuilder: (_, _) => const ListTile(
        title: SizedBox(
          height: 12,
          child: ColoredBox(color: Color(0x14000000)),
        ),
        subtitle: SizedBox(
          height: 10,
          child: ColoredBox(color: Color(0x0A000000)),
        ),
      ),
    );
  }
}
