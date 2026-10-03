// Lumen Tale — corner radii and stroke widths.
//
// `design-system.md` § 1.5.

import 'package:flutter/material.dart';

/// § 1.5 — four radii plus the two stroke widths.
///
/// `--radius-none` is `BorderRadius.zero` and is **not** a stored token: it is the
/// absence of a radius, and giving it a constant would invite it to be applied.
@immutable
class LumenRadius extends ThemeExtension<LumenRadius> {
  const LumenRadius({
    required this.sm, // 4dp   — chips, small badges
    required this.md, // 8dp   — text fields, buttons
    required this.lg, // 16dp  — sheets, cards, dialogs
    required this.full, // 999dp — pills, the unread count dot
  });

  factory LumenRadius.standard() =>
      const LumenRadius(sm: 4, md: 8, lg: 16, full: 999);

  final double sm;
  final double md;
  final double lg;
  final double full;

  /// § 1.5 — one stroke, 1dp, plus a strengthened 2dp for a selected row and a
  /// focused field.
  static const double borderWidth = 1;
  static const double borderWidthStrong = 2;

  /// The reader's prose column. § 1.5 declares it explicitly, so it has a value —
  /// but not an extension: nobody should be able to change it by theme.
  static const BorderRadius none = BorderRadius.zero;

  static LumenRadius of(BuildContext context) =>
      Theme.of(context).extension<LumenRadius>()!;

  BorderRadius get smAll => BorderRadius.circular(sm);
  BorderRadius get mdAll => BorderRadius.circular(md);
  BorderRadius get lgAll => BorderRadius.circular(lg);
  BorderRadius get fullAll => BorderRadius.circular(full);

  @override
  LumenRadius copyWith({double? sm, double? md, double? lg, double? full}) =>
      LumenRadius(
        sm: sm ?? this.sm,
        md: md ?? this.md,
        lg: lg ?? this.lg,
        full: full ?? this.full,
      );

  @override
  LumenRadius lerp(covariant LumenRadius? other, double t) =>
      other == null ? this : copyWith();
}
