// Lumen Tale — the library's query, as state.
//
// `6-6` § 4.2. `features/library/` — screen-scoped, so nothing else may read it
// (`05-state-management.md` rule 10: a provider in a feature is only for that feature).
//
// ## ⚠️ `autoDispose`, AND THE TAB SWITCH STILL KEEPS THE QUERY
//
// `library.md` § 5 says the shell branch *keeps its scroll offset and its query*, and § 4.2
// asks for `autoDispose`. Both hold, and the reason is that `autoDispose` disposes when
// **nothing is listening** — and `go_router`'s `StatefulShellRoute` keeps each branch's
// `Navigator` alive, so a tab change does not tear down `LibraryScreen` and this provider
// stays listened to. An `autoDispose` provider only forgets a query when the branch itself
// is destroyed, which is what leaving `/library` entirely should do.
//
// ## ⚠️ THE STATE IS A `TitleSearch`, NOT A `String`
//
// The raw text is what the field shows; whether the query *restricts anything* is what the
// list branches on, and that is [TitleSearch.isEmpty]. A `String` provider would make every
// caller re-derive emptiness, and two callers would derive it differently — § 3.1 branch 1
// (whole library) and branch 5 (nothing matched) would end up rendering the same thing.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/domain/library/library_search.dart';

/// The library's title query.
final libraryQueryProvider =
    NotifierProvider.autoDispose<LibraryQueryNotifier, TitleSearch>(
      LibraryQueryNotifier.new,
    );

class LibraryQueryNotifier extends Notifier<TitleSearch> {
  @override
  TitleSearch build() => TitleSearch.empty;

  /// Called on **every keystroke** — `library.md` § 5: rows recompute per keystroke, and
  /// the field's helper text carries the count. There is deliberately no *Apply*.
  void setQuery(String raw) => state = TitleSearch.of(raw);

  /// The field's `X` and the *Clear search* button in the empty state.
  ///
  /// ⚠️ **Back to [TitleSearch.empty], not `TitleSearch.of('')`.** They compare equal, so
  /// the list behaves the same either way — but the empty state has to tell "no query"
  /// from "a query that matched nothing", and going through `of('')` would leave a raw
  /// string of `''` in the state that a later reader could mistake for a real query.
  void clear() => state = TitleSearch.empty;
}
