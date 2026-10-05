// forge:slice 5-3
// Lumen Tale — `shouldStopQueue`: what stops the queue, decided **by cause**.
//
// `5-3` § 11.1. Pure Dart, no network, no database and no file — which is the only reason
// twelve cases are reachable from a literal.
//
// | rule | the row |
// |---|---|
// | E7, E20, B22, B19 | the five stopping causes → `true` |
// | E8, E18 | `source_empty`, `no_real_text`, `parse_failed` → `false` |
// | B24 | `'zzz'` → `false`, **not** an exception |
// | B24 | exhaustiveness — adding a code breaks this file's compilation |

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/downloads/queue_failure_code.dart';
import 'package:lumen_tale/domain/downloads/queue_stop_policy.dart';

void main() {
  group('E7 / E20 / B22 / B19 — the causes that STOP the queue', () {
    // ⚠️ **ONE ROW PER CAUSE, AND EACH ROW NAMES ITS RULE.** A loop over a list would be
    // shorter and would carry no reasons, and the reasons are the part a future session needs
    // when somebody asks "why does this one stop it?".
    test('⚠️ `no_connection` stops it — E7', () {
      expect(
        shouldStopQueue(QueueFailureCode.noConnection.stored),
        isTrue,
        reason:
            'E7: "It does not resume on its own … The reader resumes it." The next chapter '
            'would fail identically and the reader would watch a queue produce nothing but '
            'failures — which is the over-promise `downloads.md` § 2.1 exists to prevent',
      );
    });

    test('⚠️ `rate_limited` stops it — `17-security.md` rule 6', () {
      expect(
        shouldStopQueue(QueueFailureCode.rateLimited.stored),
        isTrue,
        reason:
            'rule 6: `429` carries `Retry-After` and the answer is to WAIT. A queue that keeps '
            'fetching is a queue hammering a site that has just asked it to stop, and the '
            'harm lands on the future access this reader already has',
      );
    });

    test('⚠️ `source_layout_changed` stops it — B22', () {
      expect(
        shouldStopQueue(QueueFailureCode.sourceLayoutChanged.stored),
        isTrue,
        reason:
            'B22: forty-eight chapters failing because a selector no longer matches is ONE '
            'broken site. Continuing would produce forty-eight identical rows that say the '
            'same thing forty-eight times, and a reader can act on none of them',
      );
    });

    test('⚠️ `source_unavailable` stops it — B3 is the same situation', () {
      expect(
        shouldStopQueue(QueueFailureCode.sourceUnavailable.stored),
        isTrue,
        reason:
            'B3: a novel naming a source this build no longer contains fails identically on '
            '**every** chapter of that novel, so this is B22 wearing a different code. A '
            'policy that stopped for a layout change and not for this would be stopping for '
            'the spelling rather than the cause',
      );
    });

    test('⚠️ `storage_full` stops it — E20', () {
      expect(
        shouldStopQueue(QueueFailureCode.storageFull.stored),
        isTrue,
        reason:
            'E20: continuing would empty the phone. The queue stops, says why, keeps every '
            'completed chapter, and records nothing partial as complete (B6)',
      );
    });

    test('⚠️ `cancelled` stops it — and no row survives to carry it', () {
      expect(
        shouldStopQueue(QueueFailureCode.cancelled.stored),
        isTrue,
        reason:
            'B19: the cancellation of `5-2` DELETES the non-`done` rows rather than marking them, '
            'so this code is never written. It is answered anyway because a policy with no '
            'answer for a code the vocabulary can express is a policy waiting to be wrong',
      );
    });
  });

  group('E8 / E18 / B24 — the causes that DO NOT stop it', () {
    test('⚠️ `source_empty` does NOT stop it — E8', () {
      expect(
        shouldStopQueue(QueueFailureCode.sourceEmpty.stored),
        isFalse,
        reason:
            'E8/B22: the site was READ and published nothing for that chapter. The next '
            'chapter is a different URL on a page that answered, and a 400-chapter novel '
            'with one blank page is a normal Tuesday',
      );
    });

    test('⚠️ `no_real_text` does NOT stop it — E18 with the E22 bargain', () {
      expect(
        shouldStopQueue(QueueFailureCode.noRealText.stored),
        isFalse,
        reason:
            'E18 says the chapter is reported as a failure **with a retry**; E22 says a short '
            'chapter must never be mistaken for a broken one. A threshold applied to the '
            'queue would turn every *Extra* into the end of a novel',
      );
    });

    test('⚠️ `parse_failed` does NOT stop it', () {
      expect(
        shouldStopQueue(QueueFailureCode.parseFailed.stored),
        isFalse,
        reason:
            'B22: one file did not survive parsing. That is one chapter, and the other 399 '
            'are on the same site being read fine',
      );
    });

    test('⚠️ `item_removed_at_source` does NOT stop it — E9', () {
      expect(
        shouldStopQueue(QueueFailureCode.itemRemovedAtSource.stored),
        isFalse,
        reason:
            'E9: the site says THIS item is gone and "the rest is unaffected". The site '
            'answered; it is not broken',
      );
    });

    test('⚠️ `cause_unknown` does NOT stop it, and that is a CLAIM', () {
      expect(
        shouldStopQueue(QueueFailureCode.causeUnknown.stored),
        isFalse,
        reason:
            '`source_failure.dart` says the same about retriability: "an app that does not '
            'know what happened cannot know whether trying again would help". Refusing to '
            'guess is the one consistent answer',
      );
    });
  });

  group('B24 — the failure mode of this function must not be a crash', () {
    test('⚠️ a code from an UNKNOWN build → `false`, and no exception', () {
      expect(
        shouldStopQueue('zzz'),
        isFalse,
        reason:
            'B24: an `error_code` this build cannot read is not "unknown", it is *unreadable*, '
            'and `QueueFailureCode.parse` answers `null` for it. Guessing that it was fatal '
            'would stop a queue over a value nothing here can interpret',
      );
    });

    test('⚠️ the EMPTY string → `false`', () {
      expect(
        shouldStopQueue(''),
        isFalse,
        reason:
            '`architecture.md` § 4.5 declares `\'\'` as the column default, so an unfinished '
            'row carries it. Treating the default as fatal would stop every queue that had '
            'ever enqueued something',
      );
    });

    test('⚠️ `shouldStopQueue` IS **TOTAL** OVER THE CLOSED ENUM', () {
      // ⚠️ **THE WITNESS ROW, AND IT IS THE ONE THAT MAKES THE OTHER ROWS BELIEVABLE.**
      // § 11.1 asks that "the `switch` covers the eight codes; adding a code breaks the
      // compilation". That cannot be asserted directly — a `switch` over a closed enum is
      // checked by the compiler, not at runtime — so what this row checks is the half a test
      // *can* check: every value the enum can produce has an answer, and none of them throws.
      for (final QueueFailureCode code in QueueFailureCode.values) {
        expect(
          shouldStopQueue(code.stored),
          isA<bool>(),
          reason:
              'every `QueueFailureCode` must have a verdict, and ${code.stored} does',
        );
      }
      expect(
        QueueFailureCode.values.length,
        11,
        reason:
            '⚠️ **AND THE ENUM HAS NOT GROWN A FOURTH STATE.** `5-2` § 7 forbids a `paused` or '
            '`cancelled` **row**; `5-3` added `storage_full` and `cancelled` as *codes* '
            'without touching `DownloadState`, which still has exactly four values. This row '
            'fails if a code is added without a decision being recorded here',
      );
    });
  });
}
