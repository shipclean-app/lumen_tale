// Lumen Tale — the two type sizes on `/onboarding` that no Material 3 slot carries.
//
// ## ⚠️ WHY THESE ARE SLICE-LOCAL AND NOT IN `app/theme/`
//
// `14-design-tokens.md` says typography lives in `app/theme/`, and normally that is the
// right answer. It is not the right answer **here**, for a reason that is a property of
// the token rather than of this screen:
//
//     `--text-h1` is used by EXACTLY ONE screen in the whole product.
//
// `onboarding.md` § 2 says the promise is *"the only screen in the app that uses
// `--text-h1`"*, and `3-4` § 10 makes it an acceptance criterion with a command attached:
// `grep -rn 'textH1' lib/` must match **only** this feature. A `--text-h1` in
// `app/theme/` would match there too, and it would be a global token with one consumer —
// which is a token the next screen that needs "a big heading" will quietly re-derive
// differently, and then there are two truths about the size of a page title.
//
// So: two local `TextStyle` constants, named after the design tokens they carry, and
// **every other size on this screen comes from the theme's Material 3 slots** — the
// design's `--text-body` is `bodyLarge`, `--text-body-sm` is `bodyMedium`, and the
// `--text-caption` footnote is `labelSmall`, the same slot `settings_rows.dart` renders
// it in, so the disclosure reads identically on both of its surfaces.
//
// ## ⚠️ NO COLOUR IS IN HERE
//
// `LumenColors` is read at build time and applied by the widget. A `TextStyle` carrying a
// colour would have to be rebuilt per theme, and a const token that holds one is a token
// that cannot be dark.

import 'package:flutter/material.dart';

/// The type this screen needs that the theme does not already carry.
abstract final class OnboardingType {
  const OnboardingType._();

  /// `--text-h1` — **31 / 38 at 700**. The promise, and **the only `--text-h1` in the
  /// app**.
  ///
  /// ⚠️ **`height` IS A MULTIPLE, NOT A LINE HEIGHT.** `TextStyle.height` multiplies the
  /// `fontSize`, so 38 / 31 is written as the division rather than as `38`: writing `38`
  /// would give a 31 × 38 line box, which is 1178dp on a 360dp phone, and the page would
  /// scroll for one sentence. Verified in the installed SDK —
  /// `packages/flutter/lib/src/painting/text_style.dart` documents `height` as
  /// *"the height of the text as a multiple of fontSize"*.
  static const TextStyle textH1 = TextStyle(
    fontSize: 31,
    height: 38 / 31,
    fontWeight: FontWeight.w700,
  );

  /// `--text-h2` — **25 / 32 at 700**. The consequence headline on step 2.
  ///
  /// ⚠️ **ONE POINT ABOVE `headlineSmall`, ON PURPOSE.** The theme's `headlineSmall` is
  /// 24 / 32; the design says 25 / 32. Writing the design's value here rather than
  /// accepting the slot's keeps `onboarding.md` § 12's table true — and § 12 is a table a
  /// design gate re-derives, so a screen that quietly rendered 24 where the table says 25
  /// is a screen the gate cannot defend.
  static const TextStyle textH2 = TextStyle(
    fontSize: 25,
    height: 32 / 25,
    fontWeight: FontWeight.w700,
  );

  /// `--text-overline` — 11 / 16 at **600**, with `letter-spacing 0.08em`.
  ///
  /// ⚠️ **`0.8`, NOT `0.08`.** `letterSpacing` is in logical pixels, so `0.08em` at this
  /// size is `0.08 × 11 ≈ 0.88`. `3-6`'s kicker already writes `0.8`, and matching it
  /// means the three kickers in the app track a finger rather than a ruler. `weight` and
  /// the tracking are the two things the theme's `labelSmall` does not carry, so those two
  /// are the whole of this style.
  static const double overlineTracking = 0.8;

  /// The overline weight, **600** — the slot's default is 500 and the design says 600.
  static const FontWeight overlineWeight = FontWeight.w600;
}

/// The height of both controls, in logical pixels.
///
/// ⚠️ **`48`, AND THE DESIGN'S `44` IS THE DRAWN HEIGHT.** `onboarding.md` § 6 asks for a
/// 44dp `primary` and a 48dp touch target; `14-design-tokens.md` §Accessibility — the
/// project's single owner of that rule — asks for 48 × 48 on every tappable affordance,
/// and it is the owner. So the target is 48 and the 44 is what a reader perceives. The
/// same constant as `3-2`'s `kActionRowControlHeight`, restated here rather than imported
/// from another feature — `02-architecture.md` forbids the import, and a 48dp target is
/// not a thing two screens can disagree about.
const double kOnboardingControlHeight = 48;

/// The two step dots' diameter, and the gap between them.
const double kStepDotSize = 8;
const double kStepDotGap = 8;
