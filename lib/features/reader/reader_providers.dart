// Lumen Tale — the reader's providers.
//
// ## The chrome is a `State`, not a provider, and that is the point
//
// `2-4` § 5 puts "chrome revealed / hidden" in the **widget's** `State`: it is ephemeral,
// it dies with the screen, and putting it in a provider would make it outlive the chapter
// it belongs to — so returning to a chapter would find the reader's own controls still
// open. Everything that must **survive** the screen is a provider; everything that must not
// is a `State`.
//
// ## `readerDocumentProvider` is `autoDispose`, and the Markdown is NEVER cached
//
// `2-4` § 5: a chapter's text is re-read from disk on every opening and never held between
// two openings of the same chapter. A 40 KB cache × a 4 812-chapter novel read whole is
// 190 MB if nothing ever invalidates it. `autoDispose` also means leaving the reader frees
// the prose, which is the point of not caching it.
//
// ## `markOpened` fires ONCE, on first display, and not from the widget's tap
//
// B13. The reader can open a chapter from the reading-zone tap, from the reader's chapter
// sheet, from history, or from "Continue" — four paths. Marking inside one tile's `onTap`
// catches one of them. § 3.4 pins the moment to **display**, the only one all four share.

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/domain/library/reading_position_store.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/domain/reader/chapter_reader_repository.dart';

/// The repository. Overridable, so a widget test supplies a fake and the row it returns —
/// `2-4` § 11.3 opens all seven states and the counter that proves the network is untouched
/// is only meaningful if the fake is the thing being counted on.
final chapterReaderRepositoryProvider = Provider<ChapterReaderRepository>(
  (Ref ref) => throw UnimplementedError(
    'chapterReaderRepositoryProvider is overridden in the composition root, because it '
    'is the composition of a database, a filesystem and a position store',
  ),
);

/// Everything one reading session needs, in one object.
///
/// ⚠️ **A record, not three providers**, because a reader that read three providers could
/// be shown a chapter's text from one loading and its position from another — and a
/// restored offset measured against a different chapter is a silent, plausible wrong place.
/// ⚠️ **`chapterId` alone.** `2-3` names a stored file after the row's ordinal, and the
/// repository reads that ordinal from the row it fetches — so carrying it here would be a
/// second copy of a fact with a second chance to be wrong, and `readerDocumentProvider`
/// would cache one entry per wrong copy.
@immutable
final class ReaderRequest {
  const ReaderRequest({required this.chapterId});

  final String chapterId;

  @override
  bool operator ==(Object other) =>
      other is ReaderRequest && other.chapterId == chapterId;

  @override
  int get hashCode => chapterId.hashCode;

  @override
  String toString() => 'ReaderRequest($chapterId)';
}

final readerDocumentProvider = FutureProvider.autoDispose
    .family<ChapterDocument, ReaderRequest>((Ref ref, ReaderRequest request) {
      // ⚠️ **Connectivity is READ here and passed IN, never acquired by the repository.**
      // Two reasons. The repository is `local only` and a connectivity call would be the
      // first network-shaped thing in its type; and the reader screen knows the truth from
      // the platform, so asking again would risk a second answer.
      return ref
          .watch(chapterReaderRepositoryProvider)
          .readChapter(
            chapterId: request.chapterId,
            hasConnection: ref.watch(hasConnectionProvider),
          );
    });

/// Whether the device currently has a connection.
///
/// ⚠️ **Overridden, and the default is `true`.** A default of `false` would make every
/// un-overridden test show [ChapterOfflineAndAbsent] — a state whose whole point is naming
/// *two* missing facts, and it would be the wrong one in every test but one.
final hasConnectionProvider = Provider<bool>((Ref ref) => true);

/// Writes a position, at a scroll settle.
///
/// ⚠️ **A closure-shaped provider, not a notifier.** The value is a fact about the scroll,
/// not UI state that a rebuild should react to; giving it a notifier would mean a scroll
/// settle invalidates every reader watching it.
final writeReaderPositionProvider =
    Provider<
      Future<void> Function({
        required String chapterId,
        required double offset,
        required double contentHeight,
      })
    >((Ref ref) {
      // ⚠️ **The store comes from the REPOSITORY, not from a second provider.** Two
      // providers building two stores over the same rows is how a position gets written
      // where `2-6` does not read it — and the reader's only correct dependency is the one
      // a test can substitute as a unit.
      final ReadingPositionStore store = ref
          .watch(chapterReaderRepositoryProvider)
          .positions;
      return ({
        required String chapterId,
        required double offset,
        required double contentHeight,
      }) => store.write(chapterId, offset, contentHeight: contentHeight);
    });

/// Marks the chapter opened, once. B13.
final markReaderOpenedProvider =
    Provider<Future<void> Function(String chapterId)>((Ref ref) {
      final ChapterReaderRepository repository = ref.watch(
        chapterReaderRepositoryProvider,
      );
      return repository.markOpened;
    });
