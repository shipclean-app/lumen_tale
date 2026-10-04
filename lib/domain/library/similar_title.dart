// Lumen Tale — "is this the same novel?", and the key the question is asked by.
//
// B40. `domain/library/` — beside the repository, because the question belongs to the add and
// only the add asks it.

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
