// Lumen Tale — the only two shadows in the app.
//
// `design-system.md` § 1.4.

import 'package:flutter/material.dart';

/// § 1.4 — **two** shadows, for the two things that genuinely float: a bottom sheet
/// and a modal dialog. Everything else is no shadow at all, and separation on a
/// flat surface is `--color-border`, a background step, or space.
@immutable
class LumenShadows extends ThemeExtension<LumenShadows> {
  const LumenShadows({required this.sheet, required this.dialog});

  /// In the night theme the shadows are **unchanged**: on a `#121315` field a dark
  /// shadow is nearly invisible, which is exactly why night has a raised surface.
  /// That is the deliberate exception § 1.4 records.
  factory LumenShadows.standard() => const LumenShadows(
    sheet: <BoxShadow>[
      BoxShadow(color: Color(0x2E000000), blurRadius: 24, offset: Offset(0, 8)),
    ],
    dialog: <BoxShadow>[
      BoxShadow(
        color: Color(0x3D000000),
        blurRadius: 48,
        offset: Offset(0, 16),
      ),
    ],
  );

  /// `0 8 24 rgba(0,0,0,0.18)` — bottom sheet, the reader's control bar.
  final List<BoxShadow> sheet;

  /// `0 16 48 rgba(0,0,0,0.24)` — modal dialog only.
  final List<BoxShadow> dialog;

  static LumenShadows of(BuildContext context) =>
      Theme.of(context).extension<LumenShadows>()!;

  @override
  LumenShadows copyWith({List<BoxShadow>? sheet, List<BoxShadow>? dialog}) =>
      LumenShadows(sheet: sheet ?? this.sheet, dialog: dialog ?? this.dialog);

  @override
  LumenShadows lerp(covariant LumenShadows? other, double t) =>
      other == null ? this : copyWith();
}
