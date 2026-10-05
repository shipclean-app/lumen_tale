// forge:slice 5-2
// Lumen Tale — `deriveQueueRunState`: the nine branches, and the order they run in.
//
// `5-2` § 11.1. Pure Dart, no database and no widget tree — which is the whole reason the
// function was written pure.
//
// | rule | the row |
// |---|---|
// | B19 | every row `done` → `idle`, `activeItem == null` |
// | B18 | `isRunning == true` and one `downloading` → `running` + `activeItem` |
// | E15, E7 | a `downloading` row with `isRunning == false` → `interrupted` |
// | E7 | `isRunning == false` + a `failed` row with `no_connection` → `stopped`/`noConnection` |
// | E20 | `error_code = 'storage_full'` → `stopped`/`outOfStorage` |
// | B19 | `isRunning == false`, nothing failed, rows queued → `paused` |
// | E15 | **order**: `downloading` + `!isRunning` is `interrupted`, NOT `paused` |
// | C8 | `doneCount` / `totalCount` are `count(done)` and `entries.length`, exactly |
// | B24 | `error_code = ''` → `unknown`, and **no exception** |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/database/app_database.dart';
import 'package:lumen_tale/domain/downloads/queue_entry.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state.dart';
import 'package:lumen_tale/domain/downloads/queue_run_state_deriver.dart';

/// A row the deriver can read, with no database behind it.
///
/// ⚠️ **A HAND-BUILT `QueueEntry`, NOT AN INSERTED ROW.** The function is pure over
/// `List<QueueEntry>`; making each case cost an in-memory drift database would test the
/// repository again rather than the derivation, and `5-1` already covers the repository.
QueueEntry entry(
  String id, {
  DownloadState state = DownloadState.queued,
  String errorCode = '',
  int attempts = 0,
  String novelId = 'n1',
}) => QueueEntry(
  id: 'q-$id',
  chapterId: 'c-$id',
  novelId: novelId,
  novelTitle: 'The Rune Smith',
  chapterName: 'Chapter $id',
  sourceId: 'rr',
  chapterUrl: '/fiction/1/n1/c-$id',
  ordinal: 1,
  chapterNumber: 1,
  state: state,
  queuePosition: 1,
  addedAt: DateTime.utc(2026),
  attempts: attempts,
  errorCode: errorCode,
);

void main() {
  group('B19 — `idle` when there is nothing left to do', () {
    test('⚠️ every row `done` → `idle`, and `activeItem` is null', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          entry('0', state: DownloadState.done),
          entry('1', state: DownloadState.done),
        ],
        isRunning: false,
      );

      expect(
        run.state,
        QueueRunState.idle,
        reason:
            '`downloads.md` § 4: an `idle` queue renders **nothing at all** — not a "Paused" '
            'row and not a disabled *Resume*. There is no act a reader could take, and a '
            'control for a state that does not exist is a promise about a version that does '
            'not exist (§ 11)',
      );
      expect(
        run.activeItem,
        isNull,
        reason: 'and nothing is in flight, which is what `idle` means',
      );
      expect(
        run.canPause,
        isFalse,
        reason: 'nor can it be paused — there is nothing to pause',
      );
      expect(
        run.canResume,
        isFalse,
        reason:
            '⚠️ **AND IT IS NOT `true`.** § 3.3 row 3 says *Resume* on an empty queue is a '
            'silent no-op, and the control is not rendered; a `true` here would make the '
            'button appear and do nothing, which B24 forbids',
      );
    });
  });

  group('B18 — `running` names the chapter it is on', () {
    test(
      '⚠️ `isRunning == true` with one `downloading` row → `running` + that row',
      () {
        final QueueEntry head = entry(
          '12',
          state: DownloadState.downloading,
          attempts: 1,
        );
        final QueueRun run = deriveQueueRunState(
          entries: <QueueEntry>[
            for (int i = 0; i < 12; i++) entry('$i', state: DownloadState.done),
            head,
            entry('13'),
          ],
          isRunning: true,
        );

        expect(
          run.state,
          QueueRunState.running,
          reason: 'B18: the loop is moving, and a moving loop is running',
        );
        expect(
          run.activeItem,
          same(head),
          reason:
              '§ 4.2: `activeItem` is what the downloads screen names on its running row. A '
              'progress bar with no chapter title is C8 with extra steps',
        );
        expect(
          run.doneCount,
          12,
          reason:
              'C8: `count(state = \'done\')` — 12, never 13 after a failure',
        );
        expect(
          run.canPause,
          isTrue,
          reason: 'and Pause is offered while it moves',
        );
      },
    );
  });

  group('E15 / E7 — `interrupted` is a derivation, not a column', () {
    test('⚠️ a `downloading` row with `isRunning == false` → `interrupted`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          for (int i = 0; i < 12; i++) entry('$i', state: DownloadState.done),
          entry('12', state: DownloadState.downloading, attempts: 1),
          for (int i = 13; i < 50; i++) entry('$i'),
        ],
        isRunning: false,
      );

      expect(
        run.state,
        QueueRunState.interrupted,
        reason:
            'E15: "a `downloading` row while the loop is not running" **is** the observation '
            'that the process died mid-chapter. § 3.1 resets it to `queued` on the first read '
            'of a session, and until then this is what the rows say',
      );
      expect(
        run.doneCount,
        12,
        reason:
            'C8: the counter is exact **while the queue is mid-death**, which is the moment a '
            'stored total is most likely to be wrong. § 11.5 checks this manually at 100 ms '
            'after a kill and it must read 12, never 13',
      );
      expect(
        run.totalCount,
        50,
        reason:
            'and the total is the fifty chapters the reader asked for, not the survivors',
      );
    });

    // ⚠️ **THE ORDER ROW, AND IT IS THE ONE THAT FAILS IF THE BRANCHES ARE SWAPPED.**
    test(
      '⚠️ ORDER: `downloading` + `!isRunning` is `interrupted`, **NOT** `paused`',
      () {
        final QueueRun run = deriveQueueRunState(
          entries: <QueueEntry>[entry('0', state: DownloadState.downloading)],
          isRunning: false,
        );

        expect(
          run.state,
          QueueRunState.interrupted,
          reason:
              '§ 2.2 step 2 observes `downloading` **before** it looks at `isRunning`. This is '
              'the only place in the function where the order of the tests matters, and a deriver '
              'that classified it as `paused` would make the E15 reset untestable — the domain '
              'state that distinguishes "the process died" from "the reader paused" would have '
              'no observable effect',
        );
        expect(
          run.canResume,
          isFalse,
          reason:
              '⚠️ **AND `interrupted` OFFERS NO CONTROL.** By the time anything renders this, '
              '§ 3.1 has already turned it into `paused`; a *Resume* for a state the reader is '
              'never shown would be a control for a version of the queue that does not exist',
        );
      },
    );
  });

  group('E7 / E20 — `stopped` names the cause, because C12 needs a sentence', () {
    test('⚠️ `no_connection` → `stopped` / `noConnection`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          for (int i = 0; i < 12; i++) entry('$i', state: DownloadState.done),
          entry('12', state: DownloadState.failed, errorCode: 'no_connection'),
          for (int i = 13; i < 50; i++) entry('$i'),
        ],
        isRunning: false,
      );

      expect(
        run.state,
        QueueRunState.stopped,
        reason:
            'E7: "the queue stops, says why, and keeps every chapter already completed". The '
            'list does **not** stop, the loop does',
      );
      expect(
        run.stopReason,
        QueueStopReason.noConnection,
        reason:
            'C12: a borrowed-device reader has to be able to say "the downloads stopped, the '
            'network went" out loud. A `failed` row with no reason is the state B22 exists to '
            'prevent',
      );
      expect(
        run.doneCount,
        12,
        reason:
            'and the completed chapters are still counted — E7 says they are KEPT',
      );
      expect(
        run.failedCount,
        1,
        reason:
            'the failure is counted in neither header figure, and is reported here',
      );
    });

    test('⚠️ `storage_full` → `stopped` / `outOfStorage`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          for (int i = 0; i < 10; i++) entry('$i', state: DownloadState.done),
          entry('10', state: DownloadState.downloading, attempts: 1),
          for (int i = 11; i < 50; i++) entry('$i'),
        ],
        isRunning: false,
        sessionStopReason: QueueStopReason.outOfStorage,
      );

      expect(
        run.stopReason,
        QueueStopReason.outOfStorage,
        reason:
            'E20: "the queue stops, says why, keeps every already-completed chapter". A full '
            'disk produces **no `failed` row** (§ 3.2 row 10), so the reason cannot be read '
            'off a row and comes from the session instead',
      );
      expect(
        run.doneCount,
        10,
        reason: 'E20: ten completed, and the counter says ten — not eleven',
      );
    });

    test('⚠️ a `source_layout_changed` row → `stopped` / `sourceUnreadable`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          entry(
            '0',
            state: DownloadState.failed,
            errorCode: 'source_layout_changed',
          ),
          entry('1'),
        ],
        isRunning: false,
      );

      expect(
        run.stopReason,
        QueueStopReason.sourceUnreadable,
        reason:
            'B22: forty-eight chapters failing for this reason is ONE broken site, and the '
            'screen collapses them into a single line naming it. `interrupted` is not the '
            'answer here — the loop stopped on purpose, so nothing is in flight',
      );
    });
  });

  group('B19 — `paused` is a deliberate act, not a fault', () {
    test('⚠️ nothing running, nothing failed, rows queued → `paused`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          for (int i = 0; i < 12; i++) entry('$i', state: DownloadState.done),
          for (int i = 12; i < 50; i++) entry('$i'),
        ],
        isRunning: false,
      );

      expect(
        run.state,
        QueueRunState.paused,
        reason:
            '§ 2.2 step 5. **E15**: the app was closed at chapter 13 of fifty, the reset '
            'brought the in-flight row back to `queued`, and nothing started the loop — so '
            'this is what a reopened session must show: `12 of 50`, paused, waiting for the '
            'reader',
      );
      expect(
        run.stopReason,
        QueueStopReason.unknown,
        reason:
            'C12: a reader who paused their own queue has **no reason to give**, and rendering '
            '`stopped` here would show a *fault* for a deliberate act',
      );
      expect(
        run.canResume,
        isTrue,
        reason:
            'and *Resume* is offered — § 3.3: it resumes **without an explanation**, which '
            'is what distinguishes `paused` from `stopped`',
      );
    });
  });

  group('C8 — the counts are derived, and they are exact', () {
    test('⚠️ `doneCount` and `totalCount` are exactly what the rows say', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          for (int i = 0; i < 12; i++) entry('$i', state: DownloadState.done),
          entry('12', state: DownloadState.failed, errorCode: 'no_real_text'),
          for (int i = 13; i < 50; i++) entry('$i'),
        ],
        isRunning: false,
      );

      expect(
        run.doneCount,
        12,
        reason:
            'C8: `12 of 50 downloaded` is `count(state = \'done\')` and is **12** — never 13 '
            'after a failure and never 11 after a cancellation. The figure is derived from the '
            'rows every time, so it cannot drift from them',
      );
      expect(
        run.totalCount,
        50,
        reason:
            'and the total is `entries.length`, never an estimate: `downloads.md` § 8 says an '
            'absent total drops the *of N* rather than substituting `0`',
      );
    });
  });

  group('B24 — an unreadable code produces a screen, not a crash', () {
    // ⚠️ **`errorCode` IS LEFT AT ITS DEFAULT `''` ON PURPOSE.** The default *is* the empty
    // string `architecture.md` § 4.5 declares, so passing it explicitly would be the same
    // assertion written louder — and `avoid_redundant_argument_values` is right to say so.
    test('⚠️ a failed row with NO code → `unknown`, and no exception is thrown', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          entry('0', state: DownloadState.failed),
          entry('1'),
        ],
        isRunning: false,
      );

      expect(
        run.stopReason,
        QueueStopReason.unknown,
        reason:
            '§ 11.1 last row. `QueueFailureCode.parse` returns `null` for a code this build '
            'does not have and a `StateError` here would take the downloads screen down because '
            'one row carried a value an older build wrote',
      );
      expect(
        run.state,
        QueueRunState.stopped,
        reason:
            'and the queue still reads as STOPPED — "nothing is downloading" is true whatever '
            'the cause, and the generic sentence then says nothing more',
      );
    });

    test('⚠️ a code from an UNKNOWN FUTURE build also yields `unknown`', () {
      final QueueRun run = deriveQueueRunState(
        entries: <QueueEntry>[
          entry(
            '0',
            state: DownloadState.failed,
            errorCode: 'a_code_from_2099',
          ),
          entry('1'),
        ],
        isRunning: false,
      );

      expect(
        run.stopReason,
        QueueStopReason.unknown,
        reason:
            'B24: an unrecognised code must still produce a screen, and the screen must not '
            'invent a cause. That is the difference between `unknown` as a **value** and a '
            'throw',
      );
    });
  });

  group('§ 2.2 — the conveniences follow from the state and from nothing else', () {
    test('⚠️ `canPause` is true in EXACTLY the running state', () {
      final List<(QueueRunState, bool)> cases = <(QueueRunState, bool)>[
        (QueueRunState.running, true),
        (QueueRunState.paused, false),
        (QueueRunState.stopped, false),
        (QueueRunState.interrupted, false),
        (QueueRunState.idle, false),
      ];

      for (final (QueueRunState state, bool expected) in cases) {
        final QueueRun run = QueueRun(
          state: state,
          stopReason: QueueStopReason.unknown,
          doneCount: 0,
          totalCount: 1,
          failedCount: 0,
          activeItem: null,
        );
        expect(
          run.canPause,
          expected,
          reason:
              '§ 4.3: *Pause* is rendered only while the queue moves, and `downloads.md` § 6 '
              'calls a disabled `Pause` the one class of disabled control it allows — a '
              'control that is **absent** elsewhere',
        );
      }
    });
  });
}
