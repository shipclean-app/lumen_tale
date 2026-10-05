// Lumen Tale — named durations and curves, and the reduce-motion policy.
//
// `design-system.md` § 1.6.

import 'package:flutter/material.dart';

/// § 1.6 — named, not "a nice transition".
@immutable
class LumenMotion extends ThemeExtension<LumenMotion> {
  const LumenMotion({
    required this.fast,
    required this.normal,
    required this.slow,
    required this.standard,
    required this.decelerate,
    required this.accelerate,
    required this.reduced,
  });

  factory LumenMotion.standard() => const LumenMotion(
    fast: Duration(milliseconds: 120),
    normal: Duration(milliseconds: 200),
    slow: Duration(milliseconds: 320),
    standard: Cubic(0.2, 0, 0, 1),
    decelerate: Cubic(0, 0, 0, 1),
    accelerate: Cubic(0.3, 0, 1, 1),
    reduced: Duration.zero,
  );

  /// 120ms — press feedback, token selection.
  final Duration fast;

  /// 200ms — screen push, sheet entry.
  final Duration normal;

  /// 320ms — reader chrome reveal, scroll restoration.
  final Duration slow;

  /// `cubic-bezier(0.2, 0, 0, 1)`
  final Curve standard;

  /// `cubic-bezier(0, 0, 0, 1)` — entry.
  final Curve decelerate;

  /// `cubic-bezier(0.3, 0, 1, 1)` — exit.
  final Curve accelerate;

  /// **Zero, never a shorter duration.** § 1.6: under the system's "reduce
  /// animations" setting every duration becomes `0ms` and the chrome reveal
  /// becomes instant. A reading app that animates a restoration the reader did
  /// not ask for is worse than one that does not animate it at all.
  final Duration reduced;

  /// The single point where the system setting is read. Any screen that animates
  /// calls `LumenMotion.of(context).duration(context, base)` and never compares it
  /// to `Duration.zero` itself.
  Duration duration(BuildContext context, Duration base) =>
      MediaQuery.disableAnimationsOf(context) ? reduced : base;

  Curve curve(BuildContext context, Curve base) =>
      MediaQuery.disableAnimationsOf(context) ? Curves.linear : base;

  static LumenMotion of(BuildContext context) =>
      Theme.of(context).extension<LumenMotion>()!;

  @override
  LumenMotion copyWith({
    Duration? fast,
    Duration? normal,
    Duration? slow,
    Curve? standard,
    Curve? decelerate,
    Curve? accelerate,
    Duration? reduced,
  }) => LumenMotion(
    fast: fast ?? this.fast,
    normal: normal ?? this.normal,
    slow: slow ?? this.slow,
    standard: standard ?? this.standard,
    decelerate: decelerate ?? this.decelerate,
    accelerate: accelerate ?? this.accelerate,
    reduced: reduced ?? this.reduced,
  );

  @override
  LumenMotion lerp(covariant LumenMotion? other, double t) =>
      other == null ? this : copyWith();
}
