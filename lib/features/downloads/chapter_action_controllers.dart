// Lumen Tale — `3-3`'s enqueue and delete controllers.
//
// ## ⚠️ TWO NOTIFIERS, NOT ONE
//
// The plan says this in one line and it is worth repeating: *a delete and a download have
// neither the same failure state nor the same consequence.* One notifier with two methods
// would mean a failed delete turning a tile's download row into an error, and the two would
// clear each other's state. `AsyncValue<void>` each, `autoDispose` each.
//
// ## ⚠️ `autoDispose`, BECAUSE THE OPERATION IS THE CALL AND NOT THE SCREEN
//
// `05-state-management.md`: nothing here is `keepAlive`. The enqueue is one method call and
// its result is a snackbar; keeping a notifier alive to remember that would retain a
// repository reference for as long as the reader is in the app. `5-1`'s queue runner **is**
// `keepAlive` — it survives every screen — and that is a different object with a different
// lifetime, deliberately not this one.
//
// ## ⚠️ THE OUTCOME IS RETURNED TO THE CALLER, NOT RENDERED HERE
//
// Every `EnqueueOutcome` arm has one exact rendering (§ 4.3.2) and two of the six differ
// only in the sentence. Deciding which sentence inside the notifier would put a widget's
// words in a data layer and make the mapping untestable without a widget tree. The caller —
// the tile — maps the value to text; this layer only produces it.

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/downloads/chapter_action_repository.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';
import 'package:lumen_tale/features/downloads/providers.dart';

/// Runs one enqueue or one delete, and holds the result's failure if it had one.
///
/// ⚠️ **`AsyncNotifier<void>`: the success carries NOTHING.** `EnqueueOutcome` says what
/// happened — already stored, partly stored, refused — and a `void` state cannot express
/// that. The outcome is returned from the method for the caller to render, while `state`
/// exists only to surface a *failure*; putting the outcome in the state would make the tile
/// re-render from a value it already has, and would make "queued" indistinguishable from
/// "already stored" to anything watching the provider.
final class ChapterDownloadController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  ChapterActionRepository get _repository =>
      ref.read(chapterActionRepositoryProvider);

  /// Enqueues [request] and hands the outcome back to the caller.
  ///
  /// ⚠️ **`ref.read`, NOT `ref.watch`.** A mutation's dependencies are not the widget's
  /// dependencies: watching the repository here would rebuild the notifier when the
  /// repository changes, which is not a thing a download can react to.
  Future<EnqueueOutcome> downloadOne(DownloadRequest request) async {
    final ChapterActionRepository repository = _repository;
    state = const AsyncValue<void>.loading();
    try {
      final EnqueueOutcome outcome = await repository.enqueue(request);
      state = const AsyncValue<void>.data(null);
      return outcome;
    } on SourceFailure catch (failure, stack) {
      // B24 — a TYPED cause, kept in the state so the caller can say WHY rather than
      // showing a generic error. Nothing is written and nothing was half-written: `enqueue`
      // is a single batch.
      state = AsyncValue<void>.error(failure, stack);
      rethrow;
    }
  }
}

/// ⚠️ **ONE PROVIDER FOR BOTH ACTIONS' SHARED SHAPE, NOT A FAMILY.**
///
/// `05-state-management.md` rule 2 says an argument can *be* the identity — but only when the
/// value differs per argument. The enqueue takes a whole `DownloadRequest` and the delete one
/// chapter id, so the argument would be a `Object` and the type would carry nothing.
final AsyncNotifierProvider<ChapterDownloadController, void>
chapterDownloadControllerProvider =
    AsyncNotifierProvider<ChapterDownloadController, void>(
      ChapterDownloadController.new,
    );

/// Runs one delete of a stored chapter.
final class DeleteChapterController extends AsyncNotifier<void> {
  @override
  FutureOr<void> build() {}

  ChapterActionRepository get _repository =>
      ref.read(chapterActionRepositoryProvider);

  /// Deletes the stored copy of [chapterId] and hands back what happened.
  ///
  /// ⚠️ **`freedBytes` IS MEASURED BY THE REPOSITORY, BEFORE THE UNLINK.** This layer does
  /// not compute it and must not: after the unlink the size is zero, and a snackbar reading
  /// "0 KB freed" teaches a reader that deletions do nothing.
  Future<DeleteOneOutcome> delete(String chapterId) async {
    final ChapterActionRepository repository = _repository;
    state = const AsyncValue<void>.loading();
    try {
      final DeleteOneOutcome outcome = await repository.deleteStoredCopy(
        chapterId,
      );
      state = const AsyncValue<void>.data(null);
      return outcome;
    } on SourceFailure catch (failure, stack) {
      state = AsyncValue<void>.error(failure, stack);
      rethrow;
    }
  }
}

final AsyncNotifierProvider<DeleteChapterController, void>
deleteChapterControllerProvider =
    AsyncNotifierProvider<DeleteChapterController, void>(
      DeleteChapterController.new,
    );

/// Cancels a queued item — and only while it is still `queued`.
///
/// ⚠️ **A METHOD HERE RATHER THAN A THIRD NOTIFIER.** A cancel has no state to hold: it
/// either removes a row or refuses, and the refusal is a value the caller shows. A notifier
/// for it would be a `loading` flag that flips back immediately.
Future<CancelOutcome> cancelIfNotStarted(Ref ref, String queueItemId) =>
    ref.read(chapterActionRepositoryProvider).cancelIfNotStarted(queueItemId);
