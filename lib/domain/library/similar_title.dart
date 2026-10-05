// Lumen Tale — "is this the same novel?", and the key the question is asked by.
//
// B40. `domain/library/` — beside the repository, because the question belongs to the add and
// only the add asks it.
//
// ## ⚠️ `6-6` ADDS A **SECOND** TIER ABOVE `normalizeForSimilarity`, and both block
//
// The rule says *a novel that **resembles** an existing entry* without ever saying at how
// many characters, at what distance, or on which normalisation. `6-6` § 7 records that as an
// open question and picks the cheapest reversible answer: **two exact tiers, no fuzzy one.**
//
// ```text
// exact       trim + collapse whitespace + lowercase      → "the ascension " == "the ascension"
// normalised  + drop punctuation, spaces, accents         → "ilan w" == "ilan w"
// (no tier)   ✗ Levenshtein  ✗ trigrams  ✗ a numeric threshold
// ```
//
// ⚠️ **"The Em" against "The Ember" is `SimilarityTier.none`, and that row FAILS if
// somebody adds a distance.** A fuzzy tier would raise a blocking dialog over a title the
// reader chose, which is worse than the absence of a warning: a control that stops legitimate
// additions trains a reader to dismiss the ones that matter.

/// What the reader chose about a similar title (B40).
enum SimilarTitleVerdict {
  /// Close the dialog without choosing. **The default**, and identical to
  /// [declinedForSimilarTitle] — nothing is added.
  dismissed,

  /// Do not add this second entry.
  declined,

  /// Add it anyway. B40: nothing is merged, so this is a second row.
  addAnyway,

  /// Open the entry that already exists, adding nothing.
  openExisting,
}

/// How close an existing title is to the incoming one. B40.
///
/// ⚠️ **Two tiers and a verdict, and [SimilarityTier.none] is a VERDICT rather than a
/// tier.** It is what [tierFor] answers when nothing resembles anything, and no
/// candidate ever carries it — a list holding a `none` would be a dialog opened to
/// say nothing.
enum SimilarityTier {
  /// The same title after case-insensitive trim and whitespace collapse. **Blocking.**
  exact,

  /// The same title once punctuation and accents are folded away. **Blocking.**
  normalised,

  /// No candidate at all. **Not a dialog** — this is the normal path.
  none,
}

/// An existing library entry whose title resembles the incoming one.
///
/// ⚠️ **The SITE's title, never the normalised key.** A reader choosing between two novels
/// is shown what the sites published; the normalisation exists only to find the collision
/// and is never displayed, or the row would show a title no site ever used.
final class SimilarTitleCandidate {
  const SimilarTitleCandidate({
    required this.tier,
    required this.novelId,
    required this.title,
    required this.sourceName,
    this.author,
  });

  /// `exact` or `normalised` — never [SimilarityTier.none], see the enum.
  final SimilarityTier tier;

  /// The **existing** entry. `novelId` is what *Open the existing one* opens, and B40
  /// says that navigation writes nothing.
  final String novelId;

  /// B10 — verbatim, so the reader can compare what the two sites published.
  final String title;

  /// ADR-024 — shown beside the title, and never part of the comparison.
  final String? author;

  /// ⚠️ **Always shown.** E17: two sites publish the same title, they are two books, and
  /// a dialog naming only one of them would make them look like duplicates.
  final String sourceName;

  @override
  bool operator ==(Object other) =>
      other is SimilarTitleCandidate && other.novelId == novelId;

  @override
  int get hashCode => novelId.hashCode;

  @override
  String toString() =>
      'SimilarTitleCandidate($title, $sourceName, ${tier.name})';
}

/// Finds the library entries whose title resembles an incoming one.
///
/// ⚠️ **No parameter can express collapsing two entries.** [find] takes a title and
/// optionally a source id, and returns *suggestions* — the caller decides. `6-6` § 10
/// asserts on this directory that none of the three identifiers a caller would have to
/// name in order to fold two entries into one occurs anywhere in it, comments included —
/// so this comment describes the shape of the guarantee without spelling those names out.
/// Spelling them here is exactly what happened the first time: the assertion caught its
/// own author's prose, which is how the row proved it could fail.
abstract interface class SimilarTitleFinder {
  /// The candidates for [candidateTitle], strongest tier first.
  ///
  /// ⚠️ **Summarised BY SOURCE, in both tiers.** Two entries sharing a title from two
  /// different sites are **two candidates**, each naming its site — E17's whole content.
  /// Collapsing them by title would be the merge B40 forbids, wearing a ranking's clothes.
  ///
  /// ⚠️ **Never a network call.** The question is asked of the local library *before*
  /// anything is written; proving a match by fetching the site would cost a request to
  /// answer something the phone already holds.
  Future<List<SimilarTitleCandidate>> find({
    required String candidateTitle,
    String? candidateSourceId,
  });
}

/// The `exact` tier's key: trim, collapse whitespace, lowercase.
///
/// ⚠️ **Nothing else is removed.** No punctuation, no accents — that is
/// [normalizeForSimilarity], and the two tiers exist precisely because they answer
/// different questions: "did the site type the same words?" and "are these the same words
/// wearing different punctuation?".
String exactSimilarityKey(String title) =>
    title.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();

/// The tier of the relationship between two titles.
///
/// ⚠️ **`exact` is checked FIRST**, so a collision reports the *narrower* of the two
/// reasons and a reader of a test log can tell which rule fired. The reverse order would
/// report `normalised` for two titles that are in fact identical after trimming, which
/// teaches whoever reads it that `normalised` fires far more often than it does.
SimilarityTier tierFor(String incomingTitle, String existingTitle) {
  final String incoming = exactSimilarityKey(incomingTitle);
  // ⚠️ An empty incoming title is `none`, NOT `exact`: "every title equals the empty
  // string" would open a dialog listing the entire library against a novel B10 says
  // cannot be displayed at all.
  if (incoming.isEmpty) {
    return SimilarityTier.none;
  }
  if (incoming == exactSimilarityKey(existingTitle)) {
    return SimilarityTier.exact;
  }
  final String folded = normalizeForSimilarity(incomingTitle);
  if (folded.isNotEmpty && folded == normalizeForSimilarity(existingTitle)) {
    return SimilarityTier.normalised;
  }
  return SimilarityTier.none;
}

/// An existing library entry whose title resembles the incoming one.
final class SimilarTitle {
  const SimilarTitle({
    required this.existingNovelId,
    required this.existingTitle,
    required this.existingSourceName,
    required this.incomingTitle,
    required this.incomingSourceName,
  });

  final String existingNovelId;

  /// ⚠️ **The SITE's title, never the normalised key.** A reader deciding between two novels
  /// is shown what the sites published; the normalisation exists only to find the collision.
  final String existingTitle;

  final String existingSourceName;
  final String incomingTitle;
  final String incomingSourceName;

  /// ⚠️ **B40: the dialog must name BOTH sites**, or the question is pointless — "is this the
  /// same novel?" is unanswerable without knowing which site published which.
  bool get isSameSource => existingSourceName == incomingSourceName;

  @override
  bool operator ==(Object other) =>
      other is SimilarTitle && other.existingNovelId == existingNovelId;

  @override
  int get hashCode => existingNovelId.hashCode;

  @override
  String toString() => 'SimilarTitle($existingTitle <- $incomingTitle)';
}

/// The key two titles are compared by (B40).
///
/// ⚠️ **Equality on the normalised key — not edit distance, not a substring test, not common
/// tokens.** Each of those answers "are these the same novel?" differently, and the rule is
/// equality. A substring test in particular would call "The Rune Smith" and "The Rune Smith
/// Returns" the same novel and warn about a collision that does not exist — which trains a
/// reader to dismiss the warning, and a warning they dismiss is a warning that protects
/// nobody.
///
/// ⚠️ **Accents are FOLDED, not stripped from the alphabet.** `é` becomes `e`, so "The
/// Rêverie" and "The Reverie" collide — which is right, since a reader comparing two titles
/// in a catalogue does not see an accent as a distinction. Non-Latin scripts keep their own
/// characters, because folding them to nothing would collide every title on the site.
String normalizeForSimilarity(String title) {
  final String folded = title
      .toLowerCase()
      // ⚠️ **The table FIRST, the combining marks SECOND.** Dart has no NFD normaliser and
      // `unorm_dart` would be a new dependency for one function, so precomposed letters are
      // folded through an explicit table and anything already decomposed is caught by the
      // combining-marks strip. Reversing the two orders leaves `e` + U+0301 as `e` and misses
      // the precomposed `ê` — one of the two spellings of the same letter.
      // ⚠️ **`replaceAllMapped`, not `replaceAll`.** `replaceAll(Pattern, String)` takes ONE
      // replacement for every match, so joining the keys with `|` and the values with `|`
      // folds every accented letter in a title into the FIRST value in the table — and the
      // row asserting "The Rêverie" collides with "The Reverie" caught exactly that, by
      // failing.
      .replaceAllMapped(
        _latinAccentPattern,
        (Match match) => _latinAccents[match[0]!]!,
      )
      .replaceAll(_combiningMarks, '');
  return folded.replaceAll(_notLettersOrDigits, '');
}

/// Precomposed Latin letters that fold to their base letter.
///
/// ⚠️ **Bounded on purpose.** This covers Latin-1 Supplement and the part of Latin Extended-A
/// a web-novel title actually uses. It is not a full Unicode decomposition, and pretending to
/// be would be worse than the gap: a Greek or Cyrillic title keeps its own letters (the
/// character class below allows them), so two Greek titles collide only if they are genuinely
/// equal — which is the correct answer, not a missed fold.
const Map<String, String> _latinAccents = <String, String>{
  'à': 'a',
  'á': 'a',
  'â': 'a',
  'ã': 'a',
  'ä': 'a',
  'å': 'a',
  'ā': 'a',
  'ă': 'a',
  'ą': 'a',
  'è': 'e',
  'é': 'e',
  'ê': 'e',
  'ë': 'e',
  'ē': 'e',
  'ĕ': 'e',
  'ė': 'e',
  'ę': 'e',
  'ě': 'e',
  'ì': 'i',
  'í': 'i',
  'î': 'i',
  'ï': 'i',
  'ī': 'i',
  'į': 'i',
  'ı': 'i',
  'ò': 'o',
  'ó': 'o',
  'ô': 'o',
  'õ': 'o',
  'ö': 'o',
  'ø': 'o',
  'ō': 'o',
  'ŏ': 'o',
  'ő': 'o',
  'ù': 'u',
  'ú': 'u',
  'û': 'u',
  'ü': 'u',
  'ū': 'u',
  'ŭ': 'u',
  'ů': 'u',
  'ű': 'u',
  'ų': 'u',
  'ç': 'c',
  'ć': 'c',
  'ĉ': 'c',
  'ċ': 'c',
  'č': 'c',
  'ñ': 'n',
  'ń': 'n',
  'ņ': 'n',
  'ň': 'n',
  'ý': 'y',
  'ÿ': 'y',
  'ŷ': 'y',
  'š': 's',
  'ś': 's',
  'ş': 's',
  'ž': 'z',
  'ź': 'z',
  'ż': 'z',
  'ð': 'd',
  'đ': 'd',
  'ť': 't',
  'ţ': 't',
  'ł': 'l',
  'ľ': 'l',
  'ĺ': 'l',
  'ř': 'r',
  'ŕ': 'r',
  'æ': 'ae',
  'œ': 'oe',
  'ß': 'ss',
  'þ': 'th',
};

/// Every key of [_latinAccents], as one alternation.
final RegExp _latinAccentPattern = RegExp(
  _latinAccents.keys.toList().join('|'),
);

/// Unicode combining diacritical marks, which are removed after the table has run.
final RegExp _combiningMarks = RegExp('[\u0300-\u036f]');

/// Everything that is not a letter or a digit in the Latin ranges.
final RegExp _notLettersOrDigits = RegExp(
  '[^a-z0-9\u00c0-\u024f\u0370-\u1fff]+',
);
