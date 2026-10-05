// Lumen Tale — a chapter, and the one place a chapter number is parsed.
//
// `03-source-system.md` § Models + rule 9. B10 is the reason this file holds
// both: the number is *derived from the site's own text*, so the parsing and the
// field it feeds have to be read together or the `-1` / `0` distinction is lost.
//
// Pure Dart.

import 'package:lumen_tale/domain/sources/source_id.dart';

/// Rule 9 — parse a number out of the site's own chapter title.
///
/// The regex is the transposed one: `[0-9]+(\.[0-9]+)?(\.?[a-z]+)?`, so
/// `Chapter 1` → `1.0`, `Ch. 12.5` → `12.5`, `Vol 3` → `3.0`, `12a` → `12.0`.
///
/// ## The three special values, and why each is a different number
///
/// | Title | Number | Reason |
/// |---|---|---|
/// | `Extra` | `0.99` | the site published no number; `0.99` sorts after every real chapter without claiming one |
/// | `Omake` | `0.98` | same, one step earlier |
/// | anything else unreadable | `-1` | **not** `0` |
///
/// ⚠️ **`-1` is not `0`, and `0` is reachable.** B10: an *Extra*, an *Omake* and
/// an author's note are genuinely chapter `0` on several sites, and an
/// unparseable title is neither. Collapsing them makes a chapter that has no
/// number look like one that is numbered zero, and the reader is told "Chapter 0"
/// about something the site never called that. `chapters.number` defaults to `-1`
/// for the same reason.
abstract final class ChapterRecognition {
  const ChapterRecognition._();

  /// Extra / omake / special, per rule 9. Named so that no caller retypes the
  /// literal and no reader has to guess which is which.
  static const double extra = 0.99;
  static const double omake = 0.98;
  static const double special = 0.97;

  /// The value for a title from which no number can be read.
  static const double unparseable = -1;

  static final RegExp _number = RegExp(
    r'([0-9]+)(\.[0-9]+)?(\.?[a-z]+)?',
    caseSensitive: false,
  );

  static final RegExp _extra = RegExp(r'\bextra\b', caseSensitive: false);
  static final RegExp _omake = RegExp(r'\bomake\b', caseSensitive: false);
  static final RegExp _special = RegExp(
    r'\b(special|bonus|author.s note)\b',
    caseSensitive: false,
  );

  /// The number for [title], or [unparseable] when there is none.
  ///
  /// ⚠️ **The title is never modified.** B10 is "titles are displayed exactly as
  /// the site presents them"; this method reads a number out of it and returns
  /// only the number. Normalising here would put the site's own text at risk
  /// from the one function that touches it most.
  ///
  /// ⚠️ **The special words are checked first.** `Chapter 7 (Extra)` contains
  /// both a number and the word *Extra*; taking the number would file a bonus
  /// chapter in the middle of the run. The rule's order is the transposed one.
  static double parse(String? title) {
    if (title == null || title.trim().isEmpty) {
      return unparseable;
    }
    if (_extra.hasMatch(title)) return extra;
    if (_omake.hasMatch(title)) return omake;
    if (_special.hasMatch(title)) return special;

    final RegExpMatch? match = _number.firstMatch(title);
    if (match == null) {
      return unparseable;
    }
    final String whole = match.group(1)!;
    final String? fraction = match.group(2);
    if (fraction == null || fraction == '.') {
      return double.parse(whole);
    }
    return double.parse('$whole$fraction');
  }
}

/// A chapter, as read from a source.
///
/// ⚠️ **There is no `ordinal` field.** `03-source-system.md` § Models does not
/// have one and this type does not invent it. The site's order is the **position
/// in the returned list**, and `2-5` (first add) and `6-4` (later) are what
/// write `chapters.ordinal = index`. Re-deriving the order from [number] is
/// forbidden by B9: `number` restarts at every volume, is `-1` when unreadable,
/// and sorts an extra between two real chapters.
final class Chapter {
  Chapter({
    required this.id,
    required this.novelId,
    required this.url,
    required this.name,
    required this.number,
    this.scanlator,
    this.dateUpload,
    this.memo = const <String, Object?>{},
  });

  /// B3 — derived by [SourceId.forChapter]. Never hand-written.
  final String id;

  /// The novel this chapter belongs to. Part of the identity, so two sources'
  /// chapters cannot collide.
  final String novelId;

  /// Rule 3 — relative (`path + query`), never a full URL.
  final String url;

  /// B10 — the site's own text, **verbatim**. Never normalised, never corrected.
  ///
  /// **Nullable, and `null` means the site published no title**: it renders as
  /// *Untitled*, never as an index or a generated number. A fabricated title is
  /// a sentence the app invented and the reader would believe.
  final String? name;

  /// [ChapterRecognition.parse] of [name], or the caller's explicit value.
  ///
  /// `-1` when unparseable. **Never `0` by default** — see `ChapterRecognition`.
  final double number;

  /// The scanlation group, when the site publishes one. `null` when it does not.
  final String? scanlator;

  /// When the site says the chapter was published. **`null` when it does not
  /// say** — and the app never substitutes "now", because a fabricated date makes
  /// the library order lie.
  final DateTime? dateUpload;

  /// Rule 7 — small, source-internal, never shown to a reader.
  final Map<String, Object?> memo;

  Chapter copyWith({
    String? name,
    double? number,
    String? scanlator,
    DateTime? dateUpload,
    Map<String, Object?>? memo,
  }) {
    return Chapter(
      id: id,
      novelId: novelId,
      url: url,
      name: name ?? this.name,
      number: number ?? this.number,
      scanlator: scanlator ?? this.scanlator,
      dateUpload: dateUpload ?? this.dateUpload,
      memo: memo ?? this.memo,
    );
  }

  /// The id and nothing else — see `Novel.toString` for why the title is absent.
  @override
  String toString() => 'Chapter($id)';
}

/// `03-source-system.md` § Models — a chapter split over several pages.
///
/// ⚠️ **The list order is authoritative.** [index] is kept because the caller may
/// want to say which page failed, and rule 11 tells the source to ignore it: a
/// site that emits pages out of order with 1-based indices is a site whose
/// numbering is wrong, and sorting by it would produce a chapter that is not the
/// chapter.
final class Page {
  const Page({
    required this.index,
    required this.url,
    this.html,
    this.imageUrl,
  });

  /// The page's ordinal **as the site published it**. Recorded, not obeyed.
  final int index;

  /// Relative (`path + query`), per rule 3.
  final String url;

  /// The raw HTML of this page, once it has been read. `null` before that.
  final String? html;

  /// Only ever set by a manga-style source. Lumen Tale has none, and rule 11 is
  /// why this field can be empty without that being a hole in the model.
  final String? imageUrl;

  @override
  String toString() => 'Page($index)';
}
