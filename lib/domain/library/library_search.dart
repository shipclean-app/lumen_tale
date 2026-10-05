// Lumen Tale — the library search, as a value.
//
// `6-6` § 2.2 / § 3.1. Pure Dart: `domain` carries no Flutter import
// (`02-architecture.md`).
//
// ## ⚠️ B45 is a claim about a QUERY, and this class is the only place it is made
//
// Three things have to hold at once, and none of them is a promise in a comment:
//
// 1. **one column** — `novels.title` and nothing else (ADR-024: `author` and
//    `description` are displayed, never indexed, never searched);
// 2. **an interior match** — `ember` finds *The Vow of **Embers***, not only a
//    prefix; B45 says "by title", not "by the start of the title";
// 3. **a literal wildcard** — the needle reaches SQLite escaped, because
//    `100 %` finding *Chapter 1000* is a silent false answer, not a failure.
//
// The first is SQL (`lib/data/library/library_queries.dart`), the second is the
// `%…%` wrapper below, and the third is [TitleSearch.escapedNeedle]. Splitting
// them across three layers is why this file is small and named.
//
// ## ⚠️ THE ESCAPE ORDER IS THE CONTRACT, AND IT IS NOT A STYLE CHOICE
//
// `\` **first**, then `%`, then `_`. Reversing the first two makes
// `a\b` escape to `a\\b` and then to `a\\\\b` — the anticharres just added get
// escaped again, and a title containing a backslash becomes unmatchable.
// Written that way, `2-6`'s branch-9d case (`100\%` as a literal) has to be the
// test that catches it, which is why it exists.

/// A library search, already normalised.
///
/// ⚠️ **The normalisation lives here and not in the widget**, because it is what
/// decides whether the query *restricts* anything. An empty query is a different
/// state from a query that matched nothing (`6-6` § 3.1 branch 1 vs branch 5):
/// the first renders the whole library, the second renders a sentence that names
/// the query. A widget that trimmed its own text could not tell them apart.
final class TitleSearch {
  /// ⚠️ **PRIVATE, AND THAT IS HOW A `TitleSearch` CAN ONLY EVER BE A REAL QUERY.**
  /// Three named fields, so an escaping or normalising bug cannot be introduced by
  /// handing a raw string to something that expects a prepared one.
  const TitleSearch._({
    required this.raw,
    required this.normalised,
    required this.escapedNeedle,
  });

  /// Builds a search from raw field text.
  ///
  /// ⚠️ **THE FACTORY SITS ABOVE THE CONSTANT, AND THAT IS THE ORDERING RULE.**
  /// `sort_constructors_first` wants every constructor before every field, and
  /// [empty] is a static field — so the factory reads next to it rather than three
  /// fields away.
  factory TitleSearch.of(String raw) {
    final String normalised = raw
        .trim()
        .replaceAll(_whitespaceRuns, ' ')
        .toLowerCase();
    if (normalised.isEmpty) {
      return TitleSearch.empty;
    }
    // ⚠️ ORDER: the anticharre, then the two wildcards. See the file header.
    final String escaped = normalised
        .replaceAll(r'\', r'\\')
        .replaceAll('%', r'\%')
        .replaceAll('_', r'\_');
    return TitleSearch._(
      raw: raw,
      normalised: normalised,
      escapedNeedle: '%$escaped%',
    );
  }

  /// An empty search — the whole library, in stored order.
  static const TitleSearch empty = TitleSearch._(
    raw: '',
    normalised: '',
    escapedNeedle: '',
  );

  /// The query as the reader typed it, for the field's own value.
  final String raw;

  /// Trimmed, whitespace collapsed, lowercased.
  ///
  /// ⚠️ **Case folding happens HERE, in Dart, and `COLLATE NOCASE` still rides
  /// along in the SQL.** The lowercasing is what makes [isEmpty] decidable
  /// without a query, and the collation is what makes SQLite agree. Neither is
  /// redundant: removing the Dart half leaves `isEmpty` unable to answer, and
  /// removing the SQL half would leave the folding to `LIKE`, which `sqlite3`
  /// spells differently across builds.
  final String normalised;

  /// [normalised], escaped and wrapped in `%…%`: **exactly** what
  /// `title LIKE ? ESCAPE '\'` is bound to.
  final String escapedNeedle;

  /// ⚠️ **`true` means "this query restricts nothing"**, and the answer is the
  /// WHOLE library — never an empty list. `library.md` § 4: *Empty — never
  /// visited* is the only state that renders as no data, and it has its own copy
  /// and its own button.
  bool get isEmpty => normalised.isEmpty;

  /// ⚠️ **One escape door in the whole application**, and this is it. Every
  /// `LIKE` this app writes binds its needle through [bindValue]; nothing builds
  /// one by hand.
  String get bindValue => escapedNeedle;

  @override
  bool operator ==(Object other) =>
      other is TitleSearch &&
      other.normalised == normalised &&
      other.escapedNeedle == escapedNeedle;

  @override
  int get hashCode => Object.hash(normalised, escapedNeedle);

  @override
  String toString() => 'TitleSearch($raw)';
}

/// Any run of whitespace, including the tab and newline a paste can carry.
final RegExp _whitespaceRuns = RegExp(r'\s+');
