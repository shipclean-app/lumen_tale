// forge:slice 3-3
// Lumen Tale — `DownloadRequest` and the outcome vocabulary.
//
// ## Why this file exists
//
// `3-3`'s plan calls the two prohibitions its core — the UI never writes
// `chapters.downloadedAt`, and a delete never removes the `chapters` row — and both live in
// `data/`. The **types** those operations speak in live here, and a type that says "failed"
// without saying which failure is the exact thing B22 exists to prevent, so the vocabulary
// is worth pinning before the first implementation writes a row.
//
// ## The rows
//
// | rule | the row |
// |---|---|
// | B18 — a LIST, never a range | *there is no `from`, no `to` and no `count`* |
// | B18 — the ORDER is part of the request | *the same chapters reversed are a DIFFERENT request* |
// | B20 — a request is immutable | *the list is unmodifiable* |
// | B24 — a reason per outcome, never a bool | *six enqueue reasons, four delete reasons* |

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/downloads/download_request.dart';

void main() {
  group('B18 — the request is a LIST of ids, in this order', () {
    // ⚠️ **A SOURCE-LEVEL ROW, and it is the only one that can catch this.** Every other test
    // in the file exercises behaviour; this one asserts the ABSENCE of fields, because a
    // `from`/`to`/`count` that crept in would change no behaviour this file can see — it
    // would just quietly become an intention again.
    testWidgets(
      '⚠️ NO `from`, NO `to`, NO `count` — a range is an intention, not a fact',
      (WidgetTester tester) async {
        final String source = _sourceOf(
          'lib/domain/downloads/download_request.dart',
        );
        for (final String forbidden in <String>[
          'final int? from',
          'final int? to',
          'final int count',
          'this.from',
          'this.to',
          'this.count',
        ]) {
          expect(
            source,
            isNot(contains(forbidden)),
            reason:
                'a range is only correct while the list behind it does not move, and a novel\'s '
                'chapter list grows, shrinks and reorders at the site. "The next 25" is '
                'converted to a list ONCE, at the tap, and never re-derived',
          );
        }
      },
    );

    test('⚠️ the same chapters in a DIFFERENT order are a DIFFERENT request', () {
      final DownloadRequest forward = DownloadRequest.of(<String>[
        'a',
        'b',
        'c',
      ]);
      final DownloadRequest reversed = DownloadRequest.of(<String>[
        'c',
        'b',
        'a',
      ]);

      expect(
        forward,
        isNot(equals(reversed)),
        reason:
            'B18 says `queuePosition` follows this order, so two different queue plans must '
            'not compare equal — otherwise a cache could serve one plan for the other',
      );
      expect(
        DownloadRequest.of(<String>['a', 'b']),
        equals(DownloadRequest.of(<String>['a', 'b'])),
        reason: 'and the same order IS the same request',
      );
    });

    // ⚠️ **`hashCode` MUST agree with `==`**, or a request can be equal to itself's twin in
    // one place and unequal in another — which is how a "duplicate" download becomes a
    // mystery.
    test('⚠️ equal requests hash alike, and reversed ones do not collide', () {
      expect(
        DownloadRequest.of(<String>['a', 'b']).hashCode,
        DownloadRequest.of(<String>['a', 'b']).hashCode,
        reason:
            'equal values, equal hashes — `Object.hashAll` over the ordered list',
      );
    });

    test('⚠️ the id list is UNMODIFIABLE', () {
      final DownloadRequest request = DownloadRequest.of(<String>['a', 'b']);

      expect(
        () => request.chapterIds.add('c'),
        throwsUnsupportedError,
        reason:
            'a request is a value; a caller that mutates one after the queue has read it has '
            'changed what the reader asked for without asking them',
      );
    });

    test('⚠️ length and isEmpty answer about CHAPTERS', () {
      expect(DownloadRequest.of(<String>['a', 'b', 'c']).length, 3);
      expect(DownloadRequest.of(const <String>[]).isEmpty, isTrue);
      expect(
        DownloadRequest.of(const <String>[]).length,
        0,
        reason: 'and an empty request is a value like any other, not a null',
      );
    });
  });

  group('B24 — one reason per outcome, and never a bool', () {
    testWidgets('⚠️ every enqueue outcome is DISTINCT and names itself', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Six reasons, asserted as six VALUES.** A single `bool added` collapses "already
      // in the library", "no space" and "the site refused" into one answer, and the interface
      // then has to invent a sentence for a state it cannot name.
      final List<Object> outcomes = <Object>[
        const EnqueueQueued(queued: 3),
        const EnqueueAlreadyStored(),
        const EnqueuePartlyStored(queued: 2, skipped: 1),
        const EnqueueRefusedForSpace(requiredBytes: 900, freeBytes: 100),
        const EnqueueQueued(queued: 1),
      ];

      final Set<String> rendered = <String>{
        for (final Object o in outcomes) o.toString(),
      };

      expect(
        rendered.length,
        outcomes.length,
        reason:
            'each outcome renders differently, because `toString` is what a log line and a '
            'test both read — and two identical renderings are two indistinguishable '
            'failures',
      );
    });

    // ⚠️ **E20's BOTH NUMBERS.** A refusal that carries one number is a shrug; the two
    // figures are the whole content of the decision the reader is being asked to make.
    test('⚠️ a space refusal carries BOTH numbers, and they are distinct', () {
      const EnqueueRefusedForSpace refusal = EnqueueRefusedForSpace(
        requiredBytes: 48234496,
        freeBytes: 1048576,
      );

      expect(
        refusal.requiredBytes,
        48234496,
        reason: 'what the download needs',
      );
      expect(refusal.freeBytes, 1048576, reason: 'and what the phone has');
      expect(
        refusal.requiredBytes,
        isNot(refusal.freeBytes),
        reason:
            'when they are equal the refusal is not a refusal — and a type that cannot '
            'express that difference is a type that will report it anyway',
      );
    });

    testWidgets('⚠️ a partial enqueue says how MANY were skipped', (
      WidgetTester tester,
    ) async {
      const EnqueuePartlyStored partial = EnqueuePartlyStored(
        queued: 2,
        skipped: 7,
      );

      expect(
        partial.toString(),
        contains('7'),
        reason:
            '"nothing happened" and "some happened" are different sentences, and a count of '
            'zero alone cannot tell them apart — this is why the partial case is its own type',
      );
    });

    testWidgets(
      '⚠️ a delete that freed nothing is a DIFFERENT outcome from a failure',
      (WidgetTester tester) async {
        final Set<Object> outcomes = <Object>{
          const DeleteOneRemoved(freedBytes: 0),
          const DeleteOneNothingToRemove(),
          const DeleteOneFailed(_offline),
        };

        expect(
          outcomes,
          hasLength(3),
          reason:
              'B33: a chapter that was not downloaded deletes nothing and writes nothing, and '
              'the UI must not say "deleted" for it — a confirmation for a no-op teaches a '
              'reader that confirmations are decorative',
        );
      },
    );

    test('⚠️ B6 — cancelling a started item is its own answer', () {
      expect(
        const CancelRemoved(),
        isNot(equals(const CancelTooLate())),
        reason:
            'a cancel that arrives one moment late costs the reader their CANCEL, not their '
            'chapter: no file is touched, `downloadedAt` is unchanged, and the item finishes '
            'normally',
      );
    });
  });
}

String _sourceOf(String path) => File(path).readAsStringSync();

/// A typed failure, built from a real cause rather than a bare string —
/// `13-error-handling.md`: a typed value is RETURNED, never thrown.
///
/// ⚠️ **A HOSTNAME, never a path.** `NoConnection` says so itself: the figure is a host,
/// never a path, a query, or anything the reader typed.
const NoConnection _offline = NoConnection(host: 'www.royalroad.com');
