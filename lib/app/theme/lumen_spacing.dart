// Lumen Tale — spacing, base 4dp.
//
// `design-system.md` § 1.3.

import 'package:flutter/material.dart';

// Lumen Tale — spacing, radius, shadows, motion.
//
// `design-system.md` § 1.3 (base 4dp, eight tokens), § 1.5 (four radii plus two
// stroke widths), § 1.4 (two shadows), § 1.6 (named durations and curves).

/// § 1.3 — base 4dp, eight tokens.
@immutable
class LumenSpacing extends ThemeExtension<LumenSpacing> {
  const LumenSpacing({
    required this.xs2, // 2dp  — badge inset
    required this.xs, // 4dp  — inside a chip
    required this.sm, // 8dp  — gap inside a group
    required this.md, // 12dp — standard gap, list row padding
    required this.lg, // 16dp — between groups
    required this.xl, // 24dp — section break
    required this.xl2, // 32dp — major section break
    required this.xl3, // 48dp — page top margin, empty-state block
  });

  factory LumenSpacing.standard() => const LumenSpacing(
    xs2: 2,
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    xl2: 32,
    xl3: 48,
  );

  final double xs2;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xl2;
  final double xl3;

  static LumenSpacing of(BuildContext context) =>
      Theme.of(context).extension<LumenSpacing>()!;

  @override
  LumenSpacing copyWith({
    double? xs2,
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xl2,
    double? xl3,
  }) => LumenSpacing(
    xs2: xs2 ?? this.xs2,
    xs: xs ?? this.xs,
    sm: sm ?? this.sm,
    md: md ?? this.md,
    lg: lg ?? this.lg,
    xl: xl ?? this.xl,
    xl2: xl2 ?? this.xl2,
    xl3: xl3 ?? this.xl3,
  );

  @override
  LumenSpacing lerp(covariant LumenSpacing? other, double t) =>
      other == null ? this : copyWith();
}
