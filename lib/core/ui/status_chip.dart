// Lumen Tale — the one chip, shared by the library row and the updates feed.
//
// `design-system.md` § 2.5 (`StatusChip`). `core/ui/` because **two surfaces render the
// same six states** (`library.md` § 8 and `updates.md` § 4) and a chip whose tone drifted
// between them would make "could not check" look like a download state on one screen and a
// check state on the other.
//
// ## ⚠️ NO STATE IS CARRIED BY COLOUR ALONE
//
// `14-design-tokens.md` § Accessibility: every tone takes an **icon** or a **word**, and
// the caller supplies which. A chip that is only a colour is unreadable at night, to a
// screen reader, and to a reader who is looking at the phone from the side of a bus — C11
// is a one-handed, often-glanced context and the whole reason the count is a number on the
// library row rather than a dot.
//
// ## ⚠️ FIVE TONES AND NO SIXTH
//
// The enum is `final`, so a tone nobody designed cannot be added by accident. `neutral` is
// the information tone's neutral sibling and is what B49's *Never checked* uses when a
// caller has no icon to give — wording only, because "we have not looked" is a fact and
// not an alarm.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';

/// What a [StatusChip] is saying. Semantic, never a raw palette colour.
enum StatusChipTone {
  /// A fact about the local store. B49's *Never checked* — wording only, no alarm.
  info,

  /// Present and whole. B6's *downloaded*.
  success,

  /// Partial, or paused by something the reader did not ask for. E6's *stopped*.
  warning,

  /// Could not read, could not write. B22/B24.
  error,

  /// Neither good nor bad: a plain fact such as *local*.
  neutral,
}

/// One status word, with an optional leading glyph.
@immutable
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.tone,
    this.icon,
    super.key,
  });

  /// Already localized by the caller — a chip never builds its own sentence.
  final String label;

  final StatusChipTone tone;

  /// ⚠️ **Required for [StatusChipTone.error] and [StatusChipTone.warning] in practice, and
  /// the a11y rule is why.** § 2.5 lists `failed` as the one chip carrying an icon *and*
  /// the words; a red word alone is a colour a colour-blind reader cannot use as a channel.
  /// Nothing enforces that here — the caller decides — which is why the test asserts it.
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenRadius radius = LumenRadius.of(context);

    final Color foreground = switch (tone) {
      StatusChipTone.info => colors.info,
      StatusChipTone.success => colors.success,
      StatusChipTone.warning => colors.warning,
      StatusChipTone.error => colors.error,
      StatusChipTone.neutral => colors.textSecondary,
    };

    final Widget content = Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: 14, color: foreground),
          SizedBox(width: spacing.xs),
        ],
        // ⚠️ **The WORD is the chip.** A chip that were only an icon would be a second
        // colour-only state indicator, and the failure B22 exists for is exactly the one a
        // reader must be able to describe out loud (C12).
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: foreground),
          ),
        ),
      ],
    );

    return Semantics(
      label: label,
      container: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.xs,
          vertical: spacing.xs2,
        ),
        decoration: BoxDecoration(
          color: foreground.withValues(alpha: 0.12),
          borderRadius: radius.fullAll,
          border: Border.all(color: foreground.withValues(alpha: 0.35)),
        ),
        child: content,
      ),
    );
  }
}
