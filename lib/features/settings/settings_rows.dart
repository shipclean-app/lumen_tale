// Lumen Tale — where this screen's row primitives live.
//
// `settings.md` § 3: the design system declares the **"Settings" layout**
// (`design-system.md` § 4.2 — *"grouped rows with section labels, no icons"*) but **no
// row primitive for it**. So `SettingsRow`, `DangerRow`, `GroupLabel` and
// `DisclosureBlock` are **slice-local**, and § 3 records the consequence:
//
//     *"the row wrapper needs to be lifted into `design-system.md` § 2 before a second
//     settings screen is written — otherwise the same rows will acquire two renderings.
//     This is recorded rather than silently duplicated."*
//
// ## The one rule a read-only row exists to enforce
//
// § 4 (Read-only): *"read-only content carries no chevron, no ripple, no toggle, and no
// pressed state. A row the reader cannot act on is visually inert **by absence, not by
// greying**."* A greyed row reads as a control the app has not finished, and on this
// screen that is exactly the affordance that makes a broken source look empty.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';

/// `--text-overline` section label, and a **semantic header**.
class GroupLabel extends StatelessWidget {
  const GroupLabel({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: spacing.sm, top: spacing.md),
      child: Semantics(
        // ⚠️ `header: true` **and** an explicit `label` — the flag alone leaves
        // `properties.label` null, so the label arrives as a separate child node and
        // anything reading the tree sees a heading with no name.
        header: true,
        label: label,
        child: ExcludeSemantics(
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colors.textSecondary,
              letterSpacing: 0.08,
            ),
          ),
        ),
      ),
    );
  }
}

/// Label, an optional right-aligned value, an optional hint, and a chevron.
class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.label,
    this.value,
    this.hint,
    this.onTap,
    this.readOnly = false,
  });

  final String label;

  /// Right-aligned, and **truncates before the label does** — § 4.1: a French value line
  /// runs longer than the English one and "the truncation is a design consequence, not
  /// a bug".
  final String? value;

  /// A second line under the row, in `--text-caption`.
  final String? hint;

  /// `null` on a read-only row, and **that null is the whole mechanism**: it removes the
  /// ripple, the hover and the chevron in one decision rather than three.
  final VoidCallback? onTap;

  /// § 4 (Read-only). See the file header for why inertness is **by absence**.
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: readOnly ? colors.textSecondary : colors.textPrimary,
                ),
              ),
            ),
            if (value != null) ...<Widget>[
              SizedBox(width: spacing.md),
              Flexible(
                child: Text(
                  value!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
                ),
              ),
            ],
            // ⚠️ **The chevron exists only where there is somewhere to go.** A chevron on
            // the read-only `Language` row would promise a destination the row does not
            // have, and B28 forbids the destination from existing.
            if (onTap != null) ...<Widget>[
              SizedBox(width: spacing.sm),
              Icon(Icons.chevron_right, size: 20, color: colors.textSecondary),
            ],
          ],
        ),
        if (hint != null) ...<Widget>[
          SizedBox(height: spacing.xs2),
          Text(
            hint!,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
        ],
      ],
    );

    // ⚠️ **`ConstrainedBox` outside the `Padding`.** The first version put
    // `constraints:` on the `Padding` — which takes a `padding`, so the analyzer caught
    // it — and before that on the inner `Column`, which sizes to its text and let a
    // one-line row collapse to 28dp. This screen is one long list of targets.
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: spacing.sm),
          // ⚠️ **`ExcludeSemantics` on a read-only row**: the row is not focusable and
          // carries no action, so announcing it as text is right — but its *value* is
          // announced with it, which is what makes "Language — English" read as one
          // fact rather than two unrelated strings.
          child: readOnly ? ExcludeSemantics(child: content) : content,
        ),
      ),
    );
  }
}

/// The one destructive row on the screen.
///
/// ⚠️ **Disabled is `--color-text-disabled` at the SAME height**, per § 4 (Empty — no
/// data): *"still 48dp tall so the row does not jump"*. A row that collapses when it
/// disables makes the page reflow under the finger that just tapped it.
class DangerRow extends StatelessWidget {
  const DangerRow({
    super.key,
    required this.label,
    required this.enabled,
    required this.countUnavailable,
    required this.onTap,
  });

  final String label;

  /// Whether a count exists **and** is non-zero.
  final bool enabled;

  /// Whether the count could not be obtained — which disables the row too, for the
  /// reason in § 4: a dialog cannot state a count it does not have, and that is the one
  /// thing it exists to state.
  final bool countUnavailable;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Semantics(
      enabled: enabled,
      button: true,
      label: label,
      child: InkWell(
        // ⚠️ **`onTap: null` when disabled**, so there is no ripple and no tap — not a
        // tap handler that does nothing. § 4: a dialog asking the reader to confirm
        // destroying zero entries is theatre, and a button that accepts the tap and then
        // declines is worse.
        onTap: enabled ? onTap : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: spacing.sm),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    label,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      // ⚠️ `--color-error` when enabled, `--color-text-disabled` when
                      // not. Never a red disabled row: a disabled control that still
                      // looks destructive invites the tap that does nothing.
                      color: enabled ? colors.error : colors.textDisabled,
                    ),
                  ),
                ),
                // ⚠️ **An icon, and it is `--color-warning`** — § 4 (Offline /
                // permissions) says a warning "is reported in words with an icon, because
                // colour alone is forbidden from carrying it". `--color-warning` means
                // "something is not doing what you asked and it is not broken", which is
                // exactly a count that could not be read.
                if (!enabled && countUnavailable)
                  Padding(
                    padding: EdgeInsets.only(left: spacing.sm),
                    child: ExcludeSemantics(
                      child: Icon(
                        Icons.help_outline,
                        size: 16,
                        color: colors.warning,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The recessed block carrying E11. `--color-surface-sunken`, and **no icon** — § 2.7.
class DisclosureBlock extends StatelessWidget {
  const DisclosureBlock({
    super.key,
    required this.body,
    required this.footer,
    required this.linkLabel,
    required this.onLink,
  });

  final String body;
  final String footer;
  final String linkLabel;
  final VoidCallback onLink;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Container(
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(LumenRadius.of(context).md),
      ),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            body,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
          ),
          SizedBox(height: spacing.sm),
          // ⚠️ **The footer is the sentence that admits the app cannot warn you.** It is
          // `--text-caption` on its own line, not a continuation of the body, because
          // it answers a different question: *why now, and why not then*.
          Text(
            footer,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
          ),
          SizedBox(height: spacing.sm),
          TextButton(onPressed: onLink, child: Text(linkLabel)),
        ],
      ),
    );
  }
}
