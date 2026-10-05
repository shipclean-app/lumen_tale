// forge:slice 2-8
// Lumen Tale — the reader's prose: a step, the phone's scale, and a measured measure.
//
// ## ⚠️ This file COMPUTES nothing about the style — `theme-type` owns it
//
// `reader_scale.dart` already declares `resolveProse(step, platformScaler)`, which
// multiplies, clamps to 16..40, **recomputes the ratio from the clamped size** and carries
// ADR-017's serif preference chain. A second function here would be a second definition of
// "what size is the prose at", and the two would disagree the first time one of them was
// edited — which is exactly the defect the plan's § 8 names when it withdraws a second
// `SharedPreferencesReaderPreferences`.
//
// So [ReaderProse] is the reader's **holder** for what `resolveProse` produced, plus the
// one thing `theme-type` deliberately does not know: how wide the column may be.
//
// ## ⚠️ The measure is computed on the RESOLVED size — E14, and the defect it prevents
//
// `resolveProse` returns the size after the phone's scale and after the clamp. The column
// cap is `75 × the advance measured at THAT size`, so the cap grows with the text and the
// line keeps 65–75 characters at any system scale. Computing the cap at the step's
// *nominal* size would make the same column hold ~95 characters at 200% — a line so long
// that the reader loses the start of the next one coming back to the left, which is the
// whole reason the cap exists.
//
// ## ⚠️ Nothing here reads a `TextScaler` and multiplies it
//
// `MediaQuery.textScalerOf` is read once, in [ReaderProse.fromContext], and handed to
// `resolveProse`. Multiplying it a second time — here, or in the Markdown style sheet —
// would make the reader's text twice the size of every other text in the app.
// `settings-reader.md` § 8 forbids it by name: *"not multiplied twice"*.

import 'package:flutter/widgets.dart';

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/features/reader/reader_layout.dart';

/// The prose the reader is being shown: one step, resolved, with its measure.
@immutable
final class ReaderProse {
  const ReaderProse({required this.step, required this.style});

  /// Builds the prose for [step] as the platform currently reports it.
  ///
  /// ⚠️ **`MediaQuery.textScalerOf(context)` is the ONLY platform read, and it is passed
  /// straight through.** Reading it here is also the mechanism E14 asks for: a change to
  /// the phone's font size invalidates this dependency, so the prose resizes on the next
  /// frame with no listener and no state to forget.
  factory ReaderProse.fromContext(BuildContext context, ReaderTextScale step) =>
      ReaderProse(
        step: step,
        style: resolveProse(step, MediaQuery.textScalerOf(context)),
      );

  /// The step the reader chose. **Carried, not re-derived**: the sheet's check, the
  /// semantics label and the measure all have to agree about which of the five this is.
  final ReaderTextScale step;

  /// The resolved style — `resolveProse`'s output, including the platform's own scaling
  /// and ADR-017's family chain. Never a second composition of the same two numbers.
  final TextStyle style;

  /// The size actually laid out, in logical pixels.
  ///
  /// ⚠️ **`style.fontSize`, never `step.fontSize`.** The first has the phone's scale and
  /// the 16..40 clamp in it; the second is the bare step. Every cap that exists to keep
  /// the measure readable has to be computed on the first — that is E14.
  double get resolvedFontSize => style.fontSize ?? ReaderProseBounds.minSize;

  /// The relative leading actually applied — near-constant across the five steps, and
  /// *recomputed* rather than copied from [ReaderTextScale.lineHeight].
  double get lineRatio => style.height ?? step.designRatio;

  /// The measure, computed from the advance in **this** prose.
  ///
  /// ⚠️ **Measured, never a character count.** `reader_layout.dart`'s header states the
  /// rule: 65–75 characters is a width that depends on the typeface, the step, the phone's
  /// text scale and the family the platform actually resolved, so a written number is
  /// wrong for at least one of the five steps — and wrong *silently*. The plan's
  /// `measureEm = 34` is exactly that number, and it is not written here.
  ///
  /// [measurer] exists so a row can supply a known advance; production measures with a
  /// `TextPainter` against [style].
  ReaderLayout measureLayout({AdvanceMeasurer? measurer}) => ReaderLayout(
    advance: (measurer ?? TextPainterAdvanceMeasurer(style)).averageAdvanceOf(
      TextPainterAdvanceMeasurer.sample,
      resolvedFontSize,
    ),
    horizontalMargin: kReaderHorizontalMargin,
  );

  /// The column's width at [availableWidth] dp, and how many characters that is.
  ///
  /// ⚠️ **One measurement, two readings.** An earlier version kept a lazily-cached
  /// *ratio* beside [measureLayout], so the diagnostic and the layout measured the advance
  /// twice, by two routes, and could disagree — a second source of truth for one number,
  /// which is the defect this whole slice is about.
  ({double width, double characters}) measureAt(
    double availableWidth, {
    AdvanceMeasurer? measurer,
  }) {
    final ReaderLayout layout = measureLayout(measurer: measurer);
    final double width = layout.availableWidth(availableWidth);
    return (
      width: width,
      characters: layout.capBinds(availableWidth)
          ? layout.achievedCharacters
          : width / layout.advance,
    );
  }
}
