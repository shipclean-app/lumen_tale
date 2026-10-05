// Lumen Tale — the download queue in the provider graph, and the providers it owns.
//
// `5-1` § 4.2 / § 5. `features/downloads/providers/`, because these are **UI-facing**
// handles; the orchestration they hold lives in `data/` (`02-architecture.md`:
// orchestration is not a presentation).
//
// ## ⚠️ **`keepAlive` IS THE STATED EXCEPTION, AND E15 IS THE REASON
//
// `05-state-management.md` rule 10: *"Never `keepAlive` a parameterized provider without
// a stated reason."* Two reasons, and the second is the one that costs:
//
//  1. **the queue is one queue for the whole app** — the library row, the novel's
//     `Slot 2` and `persistentStatus` all read it, and `design-system.md` § 3.2 requires
//     the progress to be shown **once**, not three times;
//  2. **`autoDispose` would RESURRECT the exact restart E15 forbids.** An
//     autoDispose-and-recreate provider builds its loop again when a screen re-listens,
//     and a reader who left the app and came back would see a fifty-chapter download
//     begin again with no resume (`5-2`'s job).
//
// So the runner is built once and held for the session, `isRunning` starts `false`, and
// **nothing starts the loop by itself** — which is § 5's *"isRunning is session state,
// never the database"*, and the reason E7's no-automatic-resume holds even by accident.
//
// ## ⚠️ **THREE OF THESE ARE OVERRIDDEN AT THE BOOTSTRAP, AND THEY THROW UNTIL THEY ARE**
//
// `appDatabaseProvider`, the registry and the chapter writer all need something only
// `main.dart` can decide (which database file, which registry, which support directory).
// `app_database_provider.dart` states the same policy and the same reason: a provider that
// opened the file itself would move the platform-channel call away from the one file
// whose job is deciding what the process opens.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/core/database/app_database_provider.dart';
import 'package:lumen_tale/data/downloads/drift_download_queue_repository.dart';
import 'package:lumen_tale/data/downloads/drift_novel_download_scope.dart';
import 'package:lumen_tale/data/downloads/pipeline_chapter_converter.dart';
import 'package:lumen_tale/data/downloads/serial_download_queue_runner.dart';
import 'package:lumen_tale/data/downloads/source_registry_chapter_content.dart';
import 'package:lumen_tale/data/sources/source_manager.dart';
import 'package:lumen_tale/domain/downloads/bulk_choice.dart';
import 'package:lumen_tale/domain/downloads/bulk_download_enqueue.dart';
import 'package:lumen_tale/domain/downloads/chapter_writer.dart';
import 'package:lumen_tale/domain/downloads/download_queue_repository.dart';
import 'package:lumen_tale/domain/downloads/download_queue_runner.dart';
import 'package:lumen_tale/domain/downloads/novel_download_scope.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_progress_counts.dart';
import 'package:lumen_tale/features/downloads/providers/download_progress_provider.dart';
import 'package:lumen_tale/features/downloads/providers/download_queue_control_provider.dart';

/// Overridden at the bootstrap, like every repository over the database.
final downloadQueueRepositoryProvider = Provider<DownloadQueueRepository>(
  (Ref ref) => DriftDownloadQueueRepository(ref.watch(appDatabaseProvider)),
);

/// B9 — the chapter list a bulk choice resolves against, unbounded and `ordinal`-ordered.
final novelDownloadScopeProvider = Provider<NovelDownloadScope>(
  (Ref ref) => DriftNovelDownloadScope(ref.watch(appDatabaseProvider)),
);

/// `2-3`'s store behind the queue's port. **Overridden at the bootstrap**, because the
/// store needs the `ChapterMarker` wiring and the support directory.
final chapterWriterProvider = Provider<ChapterWriter>(
  (Ref ref) => throw UnimplementedError(
    'chapterWriterProvider is overridden at the bootstrap: the FileChapterStore needs '
    'its ChapterMarker wiring and the support directory, and main.dart is the one file '
    'whose job is deciding what the process opens',
  ),
);

/// The loop. Built **once** and held — see the file header.
final downloadQueueRunnerProvider = Provider<DownloadQueueRunner>((Ref ref) {
  final SourceManager registry = ref.watch(sourceManagerProvider);
  return SerialDownloadQueueRunner(
    queue: ref.watch(downloadQueueRepositoryProvider),
    // ⚠️ **THE GATE IS `watch`ED, AND IT IS THE SAME OBJECT THE CONTROL NOTIFIER HOLDS.**
    // `5-2`'s pause and cancel write flags the loop has to read; two `QueueStopGate`s would
    // be a queue the reader cannot stop, and the failure would be silent — the queue would
    // simply ignore the tap.
    gate: ref.watch(queueStopGateProvider),
    // ⚠️ **AND SO IS THE PROGRESS REPORTER**, which is how `5-3`'s cadence reaches a widget
    // the loop knows nothing about.
    progress: ref.watch(queueProgressReporterProvider),
    // ⚠️ **`byId` IS PASSED AS A CLOSURE, NOT THE MANAGER.** `SourceManager` is a
    // `final class`, and a runner holding one would make the loop untestable without a
    // registry — while the `maxConcurrent == 1` test must interpose a counter around the
    // fetch. The closure is read at attempt time, so a source the reader disables later
    // is resolved then rather than frozen at construction.
    content: SourceRegistryChapterContent(registry.byId),
    converter: const PipelineChapterConverter(),
    writer: ref.watch(chapterWriterProvider),
  );
});

/// `0-5`'s `SourceManager` over `source_registry.dart`.
final sourceManagerProvider = Provider<SourceManager>(
  (Ref ref) => throw UnimplementedError(
    'sourceManagerProvider is overridden at the bootstrap by 0-5, which owns the '
    'registry over source_registry.dart',
  ),
);

/// The queue, as a stream — **`keepAlive`**, for the file header's second reason.
///
/// ⚠️ **`watchQueue()` AND NOT A `ref.invalidate` AFTER A MUTATION.** Rule 4 of
/// `05-state-management.md`: drift-backed reactive data is a `Stream`, and a manual
/// refresh after `markDone` is a state the reader can watch disagree with itself for one
/// frame — which on this screen is `11 of 50 downloaded` flickering to `12 of 50`.
final downloadQueueStreamProvider = StreamProvider<List<QueueEntry>>(
  (Ref ref) => ref.watch(downloadQueueRepositoryProvider).watchQueue(),
);

/// B18's queue, as a notifier with the two mutations a screen performs.
final downloadQueueProvider =
    NotifierProvider<DownloadQueueNotifier, QueueState>(
      DownloadQueueNotifier.new,
    );

/// What the queue looks like from a screen: the exact counts and whether it is moving.
///
/// ⚠️ **THE COUNTS ARE A VALUE, NOT A STORED TOTAL.** C8: `12 of 50 downloaded` is
/// `count(state = 'done')`, derived from the rows every time, so it cannot drift from
/// them. § 5 says the same about unread counts in B14/B48.
final class QueueState {
  QueueState({required Iterable<QueueEntry> entries, required this.isRunning})
    : entries = List<QueueEntry>.unmodifiable(entries);

  final List<QueueEntry> entries;

  /// ⚠️ **SESSION STATE, NEVER THE DATABASE.** § 5: a false `isRunning` at session start
  /// is what makes E15's *no automatic resume* hold even by forgetting to implement it.
  final bool isRunning;

  /// Both header numbers, exact: never 13 after a failure, never 11 after a cancel.
  QueueProgressCounts get counts => QueueProgressCounts.of(entries);

  /// B18 — at most one, because the queue is serial.
  QueueEntry? get active {
    for (final QueueEntry entry in entries) {
      if (entry.state == DownloadState.downloading) {
        return entry;
      }
    }
    return null;
  }

  @override
  String toString() =>
      'QueueState(${entries.length} rows, running: $isRunning, $counts)';
}

/// The two actions a screen performs on the queue, and nothing else.
///
/// ⚠️ **`enqueueChoice` RETURNS AN OUTCOME, NOT A COUNT.** "Nothing to download" and "a
/// novel with no chapter list yet" are different sentences (B22), and a count of zero
/// covers both.
class DownloadQueueNotifier extends Notifier<QueueState> {
  @override
  QueueState build() {
    final AsyncValue<List<QueueEntry>> entries = ref.watch(
      downloadQueueStreamProvider,
    );
    return QueueState(
      // ⚠️ **`value`, NOT `valueOrNull`, AND NOT `requireValue`.** Read from the installed
      // `riverpod` 3.4.3: `AsyncValue.value` is the nullable getter and
      // `requireValue` **throws** while loading. A queue screen that crashed on its first
      // frame because the stream had not emitted yet would be a bug in the queue's
      // lifetime, not in the reader's data.
      entries: entries.value ?? const <QueueEntry>[],
      // ⚠️ **READ, NEVER WATCHED, AND THAT IS THE POINT.** The loop's liveness is not in
      // the database, so watching it would rebuild every listener once per chapter —
      // fifty rebuilds of a screen whose numbers come from the stream anyway. It is
      // read when the state is asked for, and § 5 puts it in the session state.
      isRunning: ref.read(downloadQueueRunnerProvider).isRunning,
    );
  }

  /// § 3.2's six branches, then the loop.
  Future<QueueEnqueueOutcome> enqueueChoice({
    required String novelId,
    required BulkChoice choice,
  }) async {
    final QueueEnqueueOutcome outcome = await enqueueBulkChoice(
      queue: ref.read(downloadQueueRepositoryProvider),
      scope: ref.read(novelDownloadScopeProvider),
      novelId: novelId,
      choice: choice,
    );

    // ⚠️ **THE LOOP STARTS ONLY WHEN SOMETHING WAS QUEUED.** Branch 2 returns nothing,
    // and starting a loop over an empty queue would make `isRunning` briefly true for a
    // reader who was just told there is nothing to download.
    if (outcome is QueueEnqueued) {
      ref.read(downloadQueueRunnerProvider).start();
    }
    return outcome;
  }

  /// Wakes the loop. **Idempotent** — B18's "one at a time" is a property of the loop,
  /// not of how often a screen calls this.
  void start() => ref.read(downloadQueueRunnerProvider).start();

  /// B19 — drop every row that is not `done`.
  ///
  /// ⚠️ **NOTHING ELSE.** No file is touched and `downloadedAt` is not written: B32 says
  /// removing a novel keeps its downloaded chapters, and a queue row is state, not
  /// content.
  Future<int> clearUnfinished() =>
      ref.read(downloadQueueRepositoryProvider).clearUnfinished();
}
