// Lumen Tale — what changed on a site since the app last looked.
//
// `03-source-system.md` § Models: novel + chapters, and the one sentence that
// matters: *a source must not re-emit chapters the caller already holds*.
//
// Pure Dart.

import 'package:lumen_tale/domain/sources/models/chapter.dart';
import 'package:lumen_tale/domain/sources/models/novel.dart';

/// The result of `Source.getNovelUpdate`.
///
/// ⚠️ **[chapters] is a difference, not a list.** It is what the site published
/// that the caller did not already hold, keyed by url and in the site's order. A
/// source that re-sent the whole list would force `6-4` to diff again, and the
/// two diffs would be free to disagree — `SKILL.md` § Discipline de vérification,
/// rule 10: one fact, two representations.
///
/// ⚠️ **An empty [chapters] is not a conclusion.** It says the site published
/// nothing new *among what this call read*. B49: `6-4` writes
/// `novel.lastCheckedAt` and nothing about reading time, no file and no queue
/// (B38). A source has no clock and must never claim a novel is up to date.
final class NovelUpdate {
  NovelUpdate({required this.novel, required List<Chapter> chapters})
    : chapters = List<Chapter>.unmodifiable(chapters);

  /// The novel as it now reads, or the one the caller passed in when the call
  /// asked for no detail fetch. Never a re-read of what it already knew.
  final Novel novel;

  /// Only what the caller did not already hold.
  final List<Chapter> chapters;

  @override
  String toString() => 'NovelUpdate(${novel.id}, +${chapters.length})';
}
