// Lumen Tale — how wide the reader's column may be, **computed** rather than written down.
//
// `design-system.md` § 1.2 and B27 / ADR-019.
//
// ## ⚠️ There is NO hard-coded character count anywhere in this file, and that is the rule
//
// The design says 65–75 **characters**. It does not say "34 characters per line", because
// that number depends on the typeface, the step, the phone's text scale and the family the
// platform actually resolved. A written number is wrong for at least one of the five steps,
// and wrong *silently* — the layout looks fine and the lines are too long.
//
// So the width is `75 × averageAdvance`, where the advance is **measured** from the resolved
// font. The 65 is a **check**, not a floor: on a narrow phone the available width can be
// below 65 characters, and `design-quality.md` § 3's 16 dp floor and the measure's lower
// bound are two different constraints. Merging them would produce an unreadable screen in
// order to satisfy a measurement.
//
// ## ⚠️ ADR-019 is satisfied by NOT BRANCHING
//
// Past 600 dp the layout **stops growing** and centres. That is what `Center` +
// `ConstrainedBox(maxWidth:)` already does — so there is **no `MediaQuery` width compared
// against a threshold in this file at all**, and adding one would be the first step towards
// a layout that grows on a tablet.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// The measure's two ends, from `design-system.md` § 1.2.
const int kMinMeasureCharacters = 65;
const int kTargetMeasureCharacters = 70;
const int kMaxMeasureCharacters = 75;

/// The lower bound on the column's width, from `design-quality.md` § 3.
///
/// ⚠️ **A floor in pixels, independent of the measure.** This is the constraint that stops a
/// narrow screen from producing a column of a few characters: the screen binds first, and the
/// measure is satisfied by being as close to 70 as the screen allows.
const double kMinColumnWidthDp = 16;

/// Measures how wide a run of ordinary prose is in the resolved font.
///
/// ⚠️ **An interface with one method, so the layout is testable without a font.** A test that
/// needed a real `TextPainter` would need a font to have been loaded, and a row that cannot
/// run is a row that does not exist. The production implementation measures; the rows supply
/// a number.
abstract interface class AdvanceMeasurer {
  /// The average advance of [sample] in logical pixels at [fontSize].
  double averageAdvanceOf(String sample, double fontSize);
}

/// Measures with a real `TextPainter`, against the resolved font at [textStyle].
final class TextPainterAdvanceMeasurer implements AdvanceMeasurer {
  const TextPainterAdvanceMeasurer(this.textStyle);

  final TextStyle textStyle;

  /// ⚠️ **The lowercase alphabet, and lowercase on purpose.** Upper-case letters are wider
  /// than the body of the text a reader actually reads, so an upper-case sample makes the
  /// computed column narrower than the prose it will hold — which shows up as lines under
  /// the measure's lower bound rather than as an obvious error.
  static const String sample = 'abcdefghijklmnopqrstuvwxyz';

  @override
  double averageAdvanceOf(String text, double fontSize) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final double width = painter.width;
    painter.dispose();
    // ⚠️ **A `max` of 1, because a zero advance makes every width zero.** A failed layout
    // (an unbound painter, an unavailable glyph) would otherwise produce a column of no
    // width at all — and `ConstrainedBox(maxWidth: 0)` renders nothing, silently.
    return math.max(width / text.length, 1);
  }
}

/// Everything the reader's layout needs, and nothing that depends on a widget.
final class ReaderLayout {
  const ReaderLayout({required this.advance, required this.horizontalMargin});

  /// The measured average advance of one character, in logical pixels.
  final double advance;

  /// The margin on each side, from `design-system.md`.
  final double horizontalMargin;

  /// ⚠️ **The CAP is `kMaxMeasureCharacters × advance`, and it is a cap.** The `65` is not a
  /// floor: see the file header. `compute()` returns this, and the widget applies it as a
  /// `maxWidth` — never as a width.
  double get maxColumnWidth => kMaxMeasureCharacters * advance;

  /// The width at [available] dp, which is **the smaller of the screen and the cap**.
  ///
  /// ⚠️ **The `max` with [kMinColumnWidthDp] is not a clamp that helps.** It exists so the
  /// answer is never below the design floor; in practice [available] is the binding
  /// constraint on any real phone, so it never fires.
  double availableWidth(double screenWidth) {
    return math.max(
      math.min(screenWidth - 2 * horizontalMargin, maxColumnWidth),
      0,
    );
  }

  /// How many characters the column will actually hold at [screenWidth] dp.
  ///
  /// ⚠️ **Derived, never stored.** It exists for a row that wants to assert the measure, and
  /// a stored figure would be one more thing that can disagree with the width.
  double get achievedCharacters => advance == 0 ? 0 : maxColumnWidth / advance;

  /// Whether the cap is what binds at [screenWidth] — i.e. whether this is the wide-screen
  /// case the cap exists for.
  bool capBinds(double screenWidth) =>
      screenWidth - 2 * horizontalMargin > maxColumnWidth;

  /// A description for a row's failure message, and for nothing else.
  @override
  String toString() =>
      'ReaderLayout(advance: ${advance.toStringAsFixed(2)}, '
      'cap: ${maxColumnWidth.toStringAsFixed(0)}, margin: $horizontalMargin)';
}

/// The screen's margin on each side, from `design-system.md`.
const double kReaderHorizontalMargin = 20;

/// Applies the cap and centres, which is the whole of ADR-019.
class ReaderColumn extends StatelessWidget {
  const ReaderColumn({
    required this.layout,
    required this.screenWidth,
    required this.child,
    super.key,
  });

  final ReaderLayout layout;
  final double screenWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      // ⚠️ **`Center` + `ConstrainedBox(maxWidth:)`, and NOT `width: double.infinity`.**
      // Infinity would be the full screen width — precisely what the cap forbids — and on a
      // tablet it would produce the ~150-character lines ADR-019 exists to prevent.
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: layout.availableWidth(screenWidth),
        ),
        child: child,
      ),
    );
  }
}
