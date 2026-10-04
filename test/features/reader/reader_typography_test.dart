// forge:slice 2-8
// Lumen Tale — `2-8` § 11.1: the prose, the measure, and the two arithmetic traps in E14.
//
// ## The most valuable rows here are the ones that FAIL if a number is moved
//
// | trap | what it produces | the row |
// |---|---|---|
// | multiplying the platform scaler a second time | reader prose twice the size of the app | `the phone scale ADDS, applied ONCE` |
// | computing the measure cap on the NOMINAL step | a ~95-character column at 200% | `75 characters at 100% and the SAME 75 at 200%` |
//
// Both are invisible in a screenshot and both are named by the design system, which is why
// they are asserted as arithmetic rather than as "looks right".

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/features/reader/domain/reader_typography.dart';
import 'package:lumen_tale/features/reader/reader_layout.dart';

/// Builds a prose the way the screen does, with the platform's scale supplied directly.
///
/// **A `BuildContext` is not needed**, because [ReaderProse] takes the resolved style as a
/// parameter. That is deliberate: it is what lets the arithmetic below be checked by hand.
ReaderProse prose(ReaderTextScale step, double systemScale) => ReaderProse(
  step: step,
  style: resolveProse(step, TextScaler.linear(systemScale)),
);

/// A modelled face: the average advance is a fixed fraction of the size.
///
/// **A modelled advance, and the reason it is modelled.** `flutter_test` resolves every
/// glyph to a full em square, so a real `TextPainter` reports an advance equal to the font
/// size and no assertion about *characters per line* is possible against it. Half an em is
/// what a real text face gives, and it makes the arithmetic checkable by hand — which is the
/// whole point of the rows that use it.
final class HalfEmAdvance implements AdvanceMeasurer {
  const HalfEmAdvance();

  @override
  double averageAdvanceOf(String sample, double fontSize) => fontSize / 2;
}

/// A measurer that records the size it was asked about, and answers a fixed advance.
final class Recording implements AdvanceMeasurer {
  const Recording(this.asked);

  final List<double> asked;

  @override
  double averageAdvanceOf(String sample, double fontSize) {
    asked.add(fontSize);
    return 9;
  }
}

void main() {
  group('the step becomes the size, and only the step', () {
    test('the five steps render 16, 18, 20, 23, 26 at 100%', () {
      // § 1.2's table, reached through `2-8`'s holder rather than through the foundation's
      // own rows — this is the figure the reader sees.
      expect(
        ReaderTextScale.values.map(
          (ReaderTextScale s) => prose(s, 1).resolvedFontSize,
        ),
        <double>[16, 18, 20, 23, 26],
        reason: 'design-system.md § 1.2 tabulates these five pairs',
      );
    });

    test('the phone scale ADDS to the step, and is applied ONCE', () {
      // B27, and the acceptance criterion in words: at `md` and system scale 2.0 the text
      // is at double 18px, not quadruple.
      final ReaderProse at200 = prose(ReaderTextScale.md, 2);
      expect(
        at200.resolvedFontSize,
        closeTo(36, 0.001),
        reason:
            '18 doubled is 36 — the phone owns one multiplication and so do we',
      );
      expect(
        at200.resolvedFontSize,
        lessThan(72),
        reason:
            '72 would mean the platform scale was applied twice: resolveProse already '
            'multiplies it, and DefaultTextStyle applies it again on the way to the glyphs',
      );
    });

    test('the floor is never breached and the ceiling is never passed', () {
      for (final ReaderTextScale step in ReaderTextScale.values) {
        for (final double scale in <double>[0.5, 1, 2, 4]) {
          expect(
            prose(step, scale).resolvedFontSize,
            inInclusiveRange(16, 40),
            reason: '${step.name} at ${scale * 100}%',
          );
        }
      }
    });
  });

  group('ADR-017 — the rhythm, measured on the style the reader sees', () {
    test('the line-height ratio is near 1.72 at EVERY step, with no exception', () {
      // **The plan asks for 1.72 plus or minus 0.01 and § 1.2's own table cannot give it.**
      // The five pairs are 27/16 = 1.6875, 31/18 = 1.7222, 34/20 = 1.7000, 39/23 = 1.6957
      // and 44/26 = 1.6923, so the furthest sits 0.0325 from the stated figure.
      // `reader_scale.dart` documents this at length and `reader_scale_test.dart` asserts
      // the SPREAD instead; rewriting the table to hit a number a test wanted would be
      // editing the design system to fit the test, so the band here is the one the table
      // actually spans.
      for (final ReaderTextScale step in ReaderTextScale.values) {
        for (final double scale in <double>[1, 2]) {
          expect(
            prose(step, scale).lineRatio,
            closeTo(1.72, 0.04),
            reason:
                '${step.name} at ${scale * 100}% — § 1.2 states 1.72 in prose and tabulates '
                'five ratios spanning 1.6875 to 1.7222',
          );
        }
      }
    });

    test(
      'the ratio is RECOMPUTED from the clamped size, never copied in pixels',
      () {
        // The trap § 3.2 names: step.lineHeight (44) onto a recomputed 40 gives 1.10, and the
        // lines overlap.
        final ReaderProse capped = prose(ReaderTextScale.xxl, 2);
        expect(capped.resolvedFontSize, 40);
        expect(
          capped.lineRatio,
          closeTo(ReaderTextScale.xxl.designRatio, 0.0001),
        );
        expect(
          ReaderTextScale.xxl.lineHeight / capped.resolvedFontSize,
          closeTo(1.1, 0.01),
          reason:
              'this is the wrong answer, computed so that the right one above has something '
              'to differ from',
        );
      },
    );
  });

  group('E14 — the measure is computed on the RESOLVED size', () {
    test('the cap GROWS with the resolved size, so the character count holds', () {
      // **The row the whole cap exists for.** At 200% the text is twice as big, so the same
      // 65-75 characters need twice the width. A cap computed on the step's NOMINAL size
      // would hold about 37 characters at 200% — the defect E14 describes, printed as
      // arithmetic.
      for (final ReaderTextScale step in ReaderTextScale.values) {
        final double at100 = prose(step, 1).measureLayout().maxColumnWidth;
        final double at200 = prose(step, 2).measureLayout().maxColumnWidth;
        expect(
          at200,
          greaterThan(at100),
          reason:
              '${step.name}: the cap must scale with the text, or the measure collapses at '
              'a large system scale',
        );
      }
    });

    test('75 characters at 100% and the SAME 75 at 200% — never 37', () {
      for (final ReaderTextScale step in ReaderTextScale.values) {
        for (final double scale in <double>[1, 2]) {
          final ({double characters, double width}) wide = prose(
            step,
            scale,
          ).measureAt(4000, measurer: const HalfEmAdvance());
          expect(
            wide.characters,
            closeTo(kMaxMeasureCharacters, 0.5),
            reason:
                '${step.name} at ${scale * 100}% fits ${wide.characters} characters on a '
                'screen wide enough to break every other constraint — the cap did not hold',
          );
        }
      }
    });

    test('a wide screen is CAPPED, and the phone binds first', () {
      // **The two ends of ReaderLayout in one row.** 328dp is the phone after
      // kReaderHorizontalMargin; 4000dp is the case the cap exists for (ADR-019).
      final ReaderProse at100 = prose(ReaderTextScale.md, 1);
      final ({double characters, double width}) phone = at100.measureAt(
        328,
        measurer: const HalfEmAdvance(),
      );
      final ({double characters, double width}) wide = at100.measureAt(
        4000,
        measurer: const HalfEmAdvance(),
      );

      expect(
        phone.width,
        288,
        reason:
            "328dp less the reader's own margins: the SCREEN binds, so the cap is idle",
      );
      expect(
        phone.characters,
        closeTo(32, 0.5),
        reason:
            '18px at half an em is 9dp per character, so 288dp is 32 — and being under 65 '
            'on a phone is CORRECT. reader_layout.dart says so: the 16dp floor and the '
            'measure are two constraints, and merging them would overflow.',
      );
      expect(
        wide.width,
        kMaxMeasureCharacters * 9,
        reason: 'and past the measure the cap binds at 75 times the advance',
      );
      expect(wide.characters, closeTo(kMaxMeasureCharacters, 0.5));
    });

    test('the measurer is asked for the RESOLVED size, not the step figure', () {
      // **A seam, and the seam is the point.** AdvanceMeasurer receives a fontSize; a row
      // that watched the value it is handed observes the E14 rule directly, with no
      // arithmetic left to get wrong.
      final List<double> asked = <double>[];
      prose(ReaderTextScale.xl, 2).measureLayout(measurer: Recording(asked));
      expect(asked, <double>[
        40,
      ], reason: '23 doubled and clamped is the size measured at');
    });
  });

  group('ADR-017 — no font is embedded', () {
    test('the chain prefers a serif and ends on the platform sans', () {
      final List<String> chain =
          LumenReaderProse.standard().familyFallbackOrDefault;
      expect(chain.first, 'Noto Serif');
      expect(chain, contains('Roboto Slab'));
      expect(
        chain.last,
        contains('sans-serif'),
        reason:
            'the last entry must be a generic family: a missing face has to degrade to '
            'readable text and never to squares',
      );
    });

    test('the prose carries no fontFamily — only a fallback chain', () {
      // A named fontFamily with no asset behind it is how a build ships tofu.
      expect(prose(ReaderTextScale.md, 1).style.fontFamily, isNull);
      expect(
        prose(ReaderTextScale.md, 1).style.fontFamilyFallback,
        contains('Noto Serif'),
      );
    });

    test('pubspec.yaml declares no font family and no font asset', () {
      // **Comments stripped first.** The template `flutter create` leaves in `pubspec.yaml`
      // carries a commented-out `fonts:` block with Schyler and TrajanPro in it, so a naive
      // `contains('fonts:')` fails on a project that has embedded nothing at all.
      final List<String> live = File('pubspec.yaml')
          .readAsStringSync()
          .split('\n')
          .where((String line) => !line.trimLeft().startsWith('#'))
          .toList();
      final String pubspec = live.join('\n');

      expect(
        pubspec,
        isNot(contains('fonts:')),
        reason:
            'ADR-017 is a preference chain precisely so the APK carries no face and no '
            'licence; a fonts block would quietly make that false',
      );
      for (final String line in live) {
        final String trimmed = line.trim();
        if (!trimmed.startsWith('- assets/')) {
          continue;
        }
        expect(
          RegExp(
            r'\.(ttf|otf|woff2?)$',
            caseSensitive: false,
          ).hasMatch(trimmed),
          isFalse,
          reason: 'an embedded font asset: $trimmed',
        );
      }
    });
  });

  group('the acceptance criteria stated as source scans', () {
    test('nothing in lib/features/reader/ MULTIPLIES the platform scaler', () {
      // § 10: a grep for textScaler over lib/features/reader returns no manual
      // multiplication of the scaler. The WORD has to appear — it is how the platform's
      // value is read — so this row checks for the arithmetic, not for the word.
      final List<String> offenders = <String>[];
      for (final File file in Directory(
        'lib/features/reader',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }
        final List<String> lines = file
            .readAsStringSync()
            .split('\n')
            .where((String line) => !line.trimLeft().startsWith('//'))
            .toList();
        for (int i = 0; i < lines.length; i++) {
          final String line = lines[i];
          if (!RegExp('scaler', caseSensitive: false).hasMatch(line)) {
            continue;
          }
          if (RegExp(
            r'[A-Za-z0-9_)\]]\s*\*\s*[A-Za-z0-9_(\[]',
          ).hasMatch(line)) {
            offenders.add('${file.path}:${i + 1}  ${line.trim()}');
          }
        }
      }
      expect(
        offenders,
        isEmpty,
        reason:
            'the phone scale is multiplied once, inside resolveProse. A second '
            'multiplication here makes the reader twice the size of the rest of the app: '
            '$offenders',
      );
    });

    test('the reader owns no drift table, no migration and no schema version', () {
      // § 10: app_database.dart, schema.json and schemaVersion are intact. readingScale
      // and themeOverride live in shared_preferences, and a table for them would be a second
      // source of truth for a value theme-type already owns.
      expect(
        File('lib/core/database/app_database.dart').readAsStringSync(),
        contains('int get schemaVersion => 1;'),
        reason: 'the schema version is still 1: this slice changed no table',
      );
      for (final File file in Directory(
        'lib/features/reader',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) {
          continue;
        }
        final String source = file.readAsStringSync();
        expect(
          source,
          isNot(contains('package:drift')),
          reason:
              '${file.path} reaches for drift — the reader is local-only and has no table',
        );
        expect(
          source,
          isNot(matches(RegExp(r'\bextends Table\b'))),
          reason: '${file.path} declares a table',
        );
      }
    });
  });
}
