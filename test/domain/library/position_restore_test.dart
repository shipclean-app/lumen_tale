// forge:slice 2-6
// Lumen Tale — `2-6` § 3.2: the restore function, branch by branch.
//
// Pure Dart, no widget binding, no database. The interesting cases here are all
// arithmetic, and every branch is a decision the reader can observe — so every row
// below asserts **what the reader would see**, not just which class came back.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/domain/library/position_restore.dart';
import 'package:lumen_tale/domain/library/reading_position.dart';

final DateTime at = DateTime.utc(2026, 10, 3, 12);

/// Every value explicit, with no defaults.
///
/// ⚠️ The first version defaulted `offset: 500, contentHeight: 1000`, and the linter
/// was right every time it complained: half the calls read `stored(offset: 500,
/// contentHeight: 1000)`, which is the default written out. In a file whose entire
/// subject is *which number was stored*, a call site that does not name its numbers is
/// a call site that cannot be read.
ReadingPosition stored({
  required double offset,
  required int? contentHeight,
  String chapterId = 'c1',
}) => ReadingPosition(
  chapterId: chapterId,
  offset: offset,
  updatedAt: at,
  contentHeight: contentHeight,
);

void main() {
  group('Branch 1 — no row', () {
    test('no row is NoPosition, not an offset of zero', () {
      final ResumePoint point = restorePosition(
        stored: null,
        currentScrollExtent: 4000,
      );
      expect(point, isA<NoPosition>());
      // The distinction the sealed type exists for: a reader who never opened the
      // chapter and a reader who opened it and did not scroll are different facts.
      expect(point, isNot(isA<ResumeAt>()));
    });

    test(
      'NoPosition carries nothing, so it cannot be mistaken for a place',
      () {
        expect(const NoPosition().toString(), isNot(contains('offset')));
      },
    );
  });

  group('Branch 2 — a null or negative offset', () {
    test('offset 0 is a REAL position and survives untouched', () {
      // ⚠️ The row a reader creates by opening a chapter and closing it without
      // scrolling. Discarding it would make "I opened it" indistinguishable from
      // "I never opened it" — and would make the current-chapter tile flicker away.
      final ResumePoint point = restorePosition(
        stored: stored(offset: 0, contentHeight: null),
        currentScrollExtent: 4000,
      );

      final ResumeAt resume = point as ResumeAt;
      expect(resume.offset, 0);
      expect(resume.wasClamped, isFalse);
      expect(resume.anchoredByRatio, isFalse);
    });

    test('a negative offset becomes 0 rather than scrolling upward', () {
      // Cannot come from a ScrollController; defended because the restore must not
      // return a number that no viewport accepts.
      final ResumePoint point = restorePosition(
        stored: stored(offset: -40, contentHeight: 1000),
        currentScrollExtent: 4000,
      );
      expect((point as ResumeAt).offset, 0);
      expect(point.wasClamped, isFalse);
    });
  });

  group('Branch 3 — the height was recorded, so the fraction survives', () {
    test('the same extent restores the exact pixel', () {
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 500, contentHeight: 1000),
                currentScrollExtent: 1000,
              )
              as ResumeAt;

      expect(resume.offset, 500);
      expect(resume.anchoredByRatio, isTrue);
      expect(resume.wasClamped, isFalse);
    });

    test('a SHRUNK chapter re-anchors by ratio, not by pixel', () {
      // Read at 1000 px of extent, halfway down. Now the extent is 400 — the text got
      // much bigger. Halfway is still halfway.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 500, contentHeight: 1000),
                currentScrollExtent: 400,
              )
              as ResumeAt;

      expect(resume.offset, closeTo(200, 1e-9));
      expect(resume.anchoredByRatio, isTrue);
    });

    test('a GREWN chapter re-anchors by ratio too', () {
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 500, contentHeight: 1000),
                currentScrollExtent: 4000,
              )
              as ResumeAt;

      expect(resume.offset, closeTo(2000, 1e-9), reason: '50 % of 4000');
      expect(resume.anchoredByRatio, isTrue);
      expect(
        resume.offset,
        isNot(500),
        reason: 'using the raw pixel here is the bug E14 is about',
      );
    });

    test('a SHRINK alone never clamps, because a fraction cannot exceed one', () {
      // ⚠️ The plan's clamp branch in § 3.2 assumes a shrink can push the re-anchored
      // offset past the new extent. **It cannot.** `raw <= storedHeight` makes the
      // fraction `<= 1`, and a fraction `<= 1` times any extent is `<= ` that extent.
      // My first version of this test asserted a clamp on `900/1000 x 300` and measured
      // **270** — the arithmetic was right and the assertion was wrong.
      //
      // Which is worth stating plainly, because the OTHER branch's clamp is reachable
      // and easy to confuse with this one. A shrink is safe by construction; only an
      // **inconsistent row** can clamp here.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 900, contentHeight: 1000),
                currentScrollExtent: 300,
              )
              as ResumeAt;

      expect(resume.offset, closeTo(270, 1e-9), reason: '90 % of 300');
      expect(resume.wasClamped, isFalse);
      expect(resume.anchoredByRatio, isTrue);
    });

    test('an INCONSISTENT row clamps — offset larger than its own height', () {
      // Reachable, and the reason the clamp exists. `maxScrollExtent` can change
      // between the frame that measured it and the frame that writes the position
      // (content reflowing, an image resolving), so a row can carry an offset larger
      // than the height it was measured against. `900/800 = 1.125`, which exceeds any
      // extent once projected.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 900, contentHeight: 800),
                currentScrollExtent: 400,
              )
              as ResumeAt;

      expect(resume.offset, 400, reason: 'the end is the least-wrong place');
      expect(
        resume.wasClamped,
        isTrue,
        reason: 'B24: a disclosed wrong position',
      );
      expect(resume.anchoredByRatio, isTrue);
    });

    test('exactly at the end is not clamped', () {
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 1000, contentHeight: 1000),
                currentScrollExtent: 1000,
              )
              as ResumeAt;

      expect(resume.offset, 1000);
      expect(resume.wasClamped, isFalse, reason: 'the end IS the end');
    });

    test(
      'a height of 0 in the row is NOT a measurement and is not divided by',
      () {
        // ⚠️ 0 is the degenerate denominator. The restore refuses it, so the row falls
        // through to the pixel branch rather than producing Infinity or NaN.
        final ResumeAt resume =
            restorePosition(
                  stored: stored(offset: 500, contentHeight: 0),
                  currentScrollExtent: 1000,
                )
                as ResumeAt;

        expect(resume.offset, 500);
        expect(resume.anchoredByRatio, isFalse);
        expect(resume.offset.isFinite, isTrue);
      },
    );
  });

  group('Branch 4 — no height recorded, so the pixel is all there is', () {
    test('the pixel is used as-is', () {
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 500, contentHeight: null),
                currentScrollExtent: 4000,
              )
              as ResumeAt;

      expect(resume.offset, 500);
      expect(resume.anchoredByRatio, isFalse);
      expect(resume.wasClamped, isFalse);
    });

    test('a pixel past the extent clamps AND says so', () {
      // Every row written before `contentHeight` existed lands here, and a reader who
      // read at 26 px and returns at 18 px has exactly this problem.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 3000, contentHeight: null),
                currentScrollExtent: 1200,
              )
              as ResumeAt;

      expect(resume.offset, 1200);
      expect(resume.wasClamped, isTrue);
      expect(resume.anchoredByRatio, isFalse);
    });

    test('a NULL height never silently becomes a ratio', () {
      // The tempting shortcut is to assume the current extent and restore "halfway".
      // That manufactures a measurement that was never taken, and it looks correct.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 500, contentHeight: null),
                currentScrollExtent: 1000,
              )
              as ResumeAt;

      expect(resume.offset, 500, reason: 'not 500 either, but not 500 by luck');
      expect(resume.anchoredByRatio, isFalse);
    });
  });

  group('The chapter has not been laid out yet', () {
    test('a zero extent does not throw the position away', () {
      // ⚠️ A first frame has no extent. Clamping a real position to 0 would lose the
      // reader's place to a timing detail — the caller re-runs this once measured.
      final ResumeAt resume =
          restorePosition(
                stored: stored(offset: 800, contentHeight: 2000),
                currentScrollExtent: 0,
              )
              as ResumeAt;

      expect(resume.offset, 800);
      expect(resume.wasClamped, isFalse);
      expect(resume.anchoredByRatio, isFalse);
    });

    test('a negative extent is treated the same way', () {
      expect(
        (restorePosition(
                  stored: stored(offset: 800, contentHeight: 2000),
                  currentScrollExtent: -1,
                )
                as ResumeAt)
            .offset,
        800,
      );
    });

    test('a position of 0 with no extent is still 0', () {
      expect(
        (restorePosition(
                  stored: stored(offset: 0, contentHeight: null),
                  currentScrollExtent: 0,
                )
                as ResumeAt)
            .offset,
        0,
      );
    });
  });

  group('Properties that must hold across the whole input space', () {
    test('the restored offset is never outside [0, extent]', () {
      for (final double offset in <double>[0, 1, 250, 999, 1000, 5000]) {
        for (final int? height in <int?>[null, 0, 1, 500, 1000, 2000]) {
          for (final double extent in <double>[1, 100, 1000, 4000]) {
            final ResumePoint point = restorePosition(
              stored: stored(offset: offset, contentHeight: height),
              currentScrollExtent: extent,
            );
            if (point is! ResumeAt) continue;
            expect(
              point.offset,
              inInclusiveRange(0, extent),
              reason: 'offset=$offset height=$height extent=$extent',
            );
            expect(point.offset.isFinite, isTrue);
          }
        }
      }
    });

    test('a restore is deterministic', () {
      final ReadingPosition row = stored(offset: 733, contentHeight: 1500);
      final ResumeAt a =
          restorePosition(stored: row, currentScrollExtent: 900) as ResumeAt;
      final ResumeAt b =
          restorePosition(stored: row, currentScrollExtent: 900) as ResumeAt;
      expect(a, equals(b));
    });

    test('a wider viewport never moves the reader UP', () {
      // Monotonicity: more room can only push the position further down, never
      // back up. A restore that moved a reader backwards would read as losing pages.
      double at1(double extent) =>
          (restorePosition(
                    stored: stored(offset: 400, contentHeight: 800),
                    currentScrollExtent: extent,
                  )
                  as ResumeAt)
              .offset;

      expect(at1(1000), greaterThan(at1(800)));
      expect(at1(800), greaterThan(at1(400)));
    });

    test('the timestamp is carried through untouched on every branch', () {
      for (final int? height in <int?>[null, 1000]) {
        for (final double extent in <double>[0, 100, 5000]) {
          final ResumePoint point = restorePosition(
            stored: stored(offset: 100, contentHeight: height),
            currentScrollExtent: extent,
          );
          if (point is ResumeAt) {
            expect(
              point.updatedAt,
              at,
              reason: 'height=$height extent=$extent',
            );
          }
        }
      }
    });

    test('exhaustive switch needs no default', () {
      String describe(ResumePoint p) => switch (p) {
        NoPosition() => 'none',
        ResumeAt() => 'at',
      };
      expect(describe(const NoPosition()), 'none');
      expect(
        describe(
          restorePosition(
            stored: stored(offset: 500, contentHeight: 1000),
            currentScrollExtent: 10,
          ),
        ),
        'at',
      );
    });
  });
}
