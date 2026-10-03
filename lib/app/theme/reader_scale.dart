// Lumen Tale — the reader's text scale, and the prose style it produces.
//
// `design-system.md` § 1.2 and § 1.8.
//
// B27 has **two** sources — the step the reader chose and the phone's own font
// scale — and § 3.2 composes them rather than choosing one against the other.

import 'package:flutter/material.dart';

/// The reader scale of `design-system.md` § 1.2 — **five steps, a 16px floor, a
/// constant 1.72 line height**.
///
/// B27 exposes these five steps to the reader. They are never applied one at a
/// time: see [resolveProse] for the composition with the phone's scale.
enum ReaderTextScale {
  /// 16 / 27 — the smallest legible step. `design-quality.md` § 3 forbids going
  /// below 16px on mobile, so this step **is** the floor: E14 ("no clipped text at
  /// the largest size") and "never below 16px" cannot both be violated, because
  /// the smallest step already *is* 16px.
  ///
  /// ⚠️ 27/16 is **1.6875**, not the 1.72 `design-system.md` § 1.2 states. Both
  /// numbers are authoritative and they disagree: the table's five pairs are the
  /// specification, and the prose's single ratio is an idealisation of them. The
  /// pairs are used, because rounding five line-heights to hit 1.72 would make the
  /// table false. [designRatio] is the per-step ratio, and the test asserts the
  /// spread across steps is under 0.04 — the rhythm is near-constant rather than
  /// exactly constant, and claiming otherwise would be a number the table refutes.
  sm(16, 27),

  /// 18 / 31 — **the default**.
  md(18, 31),

  /// 20 / 34
  lg(20, 34),

  /// 23 / 39
  xl(23, 39),

  /// 26 / 44 — the largest step.
  xxl(26, 44);

  const ReaderTextScale(this.fontSize, this.lineHeight);

  /// Font size in logical pixels.
  final double fontSize;

  /// Line height in logical pixels. **1.72 at every step, deliberately constant**:
  /// scaling the leading with the size would break the reading rhythm between
  /// steps, and a rhythm that changes when the reader changes the size is a rhythm
  /// they cannot get used to.
  final double lineHeight;

  /// This step's own line-height ratio.
  ///
  /// ⚠️ **Not exactly 1.72, and the design system is why.** § 1.2 states 1.72 as
  /// a single figure and then gives five size/line pairs whose ratios are 1.6875,
  /// 1.7222, 1.7000, 1.6957 and 1.6923. The pairs are the specification — they
  /// are what a reader sees — and the prose figure is a rounded description of
  /// them. Reporting one number here would mean one of the two sources in § 1.2 is
  /// a lie, and this project has been bitten by exactly that shape seven times.
  ///
  /// The spread is 0.035, so the rhythm *is* effectively constant; [test] asserts
  /// the spread rather than asserting a figure the table contradicts.
  double get designRatio => lineHeight / fontSize;

  /// The order is the list's order, so this is the slider's order in
  /// `SettingsChoiceSheet` and must not be used for anything else.
  ///
  /// ⚠️ Named `stepIndex` and not `index`: every Dart `enum` already declares
  /// `index`, so declaring it here is a compile error. The plan writes `index`,
  /// which cannot be implemented as written.
  int get stepIndex => ReaderTextScale.values.indexOf(this);

  static ReaderTextScale fromIndex(int i) =>
      ReaderTextScale.values[i.clamp(0, ReaderTextScale.values.length - 1)];

  /// Reading the persisted value.
  ///
  /// **Any unknown value falls back to `md`, silently and without throwing.** The
  /// string comes from `shared_preferences` and may have been written by an
  /// earlier version: a removed version must not make the app unable to start.
  /// This is a display setting, not data.
  static ReaderTextScale fromStorage(String? raw) {
    for (final step in ReaderTextScale.values) {
      if (step.name == raw) return step;
    }
    return ReaderTextScale.md;
  }
}

/// § 3.2 — composes the reader's step with the phone's font scale.
///
/// [platformScaler] is `MediaQuery.textScalerOf(context)`. The two sources are
/// multiplied and then clamped, and the **line height ratio is recomputed from the
/// clamped size** rather than copied in pixels — copying `step.lineHeight` (44)
/// onto a recomputed 40 gives a ratio of 1.10 and **overlapping lines**, which is
/// precisely what E14 forbids.
TextStyle resolveProse(ReaderTextScale step, TextScaler platformScaler) {
  final product = step.fontSize * platformScaler.scale(1);
  final size = product.clamp(
    ReaderProseBounds.minSize,
    ReaderProseBounds.maxSize,
  );

  return TextStyle(
    fontSize: size,
    // This step's own RATIO, recomputed — so the line follows `size` instead of
    // being frozen at the step's pixel value.
    height: step.designRatio,
    fontFamilyFallback: LumenReaderProse.standard().familyFallbackOrDefault,
  );
}

/// The clamps § 2.2 fixes, in one place so "what is the ceiling" has one answer.
final class ReaderProseBounds {
  const ReaderProseBounds._();

  /// `design-quality.md` § 3: never below 16px on mobile. Non-negotiable, and
  /// applied to the **product**, so it can never bite below the smallest step.
  static const double minSize = 16;

  /// § 3.2 and E14. Without it, `xxl` at 200% gives 52px in a 328dp column —
  /// about **twelve characters per line**, and a reader who has to follow the
  /// cursor to follow the line. The ceiling turns the degraded case into the
  /// scroll's job.
  static const double maxSize = 40;
}

/// The reader's prose style — the **only** typographic style the chrome does not
/// use, and the only one built by hand rather than carried by a Material 3 slot
/// (`design-system.md` § 1.8: "plus one `readerProse` style").
///
/// **Serif preference chain, nothing embedded (ADR-017).** `Noto Serif` then
/// `Roboto Slab` then the platform serif, with the platform sans as a guaranteed
/// fallback: a missing family degrades to readable text, never to squares.
@immutable
class LumenReaderProse extends ThemeExtension<LumenReaderProse> {
  const LumenReaderProse({required this.familyFallback});

  factory LumenReaderProse.standard() =>
      const LumenReaderProse(familyFallback: null);

  /// `null` = use [familyFallbackOrDefault] alone. Reserved for a future case
  /// where a single family must be pinned; nothing uses it yet.
  final String? familyFallback;

  /// ADR-017 — the preference chain, platform sans last so nothing renders as
  /// tofu.
  static const List<String> _defaultChain = <String>[
    'Noto Serif',
    'Roboto Slab',
    'serif',
    'sans-serif',
  ];

  List<String> get familyFallbackOrDefault =>
      familyFallback == null ? _defaultChain : <String>[familyFallback!];

  static LumenReaderProse of(BuildContext context) =>
      Theme.of(context).extension<LumenReaderProse>()!;

  @override
  LumenReaderProse copyWith({String? familyFallback}) =>
      LumenReaderProse(familyFallback: familyFallback ?? this.familyFallback);

  @override
  LumenReaderProse lerp(covariant LumenReaderProse? other, double t) =>
      other == null ? this : copyWith();
}
