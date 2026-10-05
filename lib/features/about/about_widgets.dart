// Lumen Tale — the About screen's four blocks. Slice-local.
//
// `settings-about.md` § 3. `AboutIdentity`, `DataBlock` and `PrivacyBlock` are declared
// **"slice-local composition"** in that table, so they live here and not in
// `core/ui/` — promoting one would be a claim that a second screen wants it, and no
// second screen does.
//
// ## Three of the blocks sit on `--color-surface-sunken`
//
// § 2: the update notice, the data counts and the E11 statement are **recessed facts to
// look into**, not cards to look at. `--color-surface-raised` appears nowhere on this
// screen except the snackbar. That is why these blocks are not built out of a generic
// "card" helper: the design distinguishes raised from sunken, and a helper with one
// shape would flatten the distinction the screen is making.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/features/about/about_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// Title, version, provenance, and the clipboard button.
class AboutIdentity extends StatelessWidget {
  const AboutIdentity({
    super.key,
    required this.version,
    required this.onCopied,
  });

  final BuildVersion version;
  final VoidCallback onCopied;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          l10n.appTitle,
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.xs),
        // ⚠️ **Either the version line or the error, never `Version —`.**
        //
        // An em dash looks like a version. C9 requires the owner to be able to
        // determine which build is installed, so the honest rendering of "I could not
        // read it" is a **sentence in `--color-error`** and nothing else — and
        // everything BELOW this line renders unchanged, because the version is one
        // string and a missing string must not blank the page that states what the app
        // does with the reader's data.
        if (version.isReadable)
          Text(
            l10n.aboutVersion(version.buildName, version.buildNumber),
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(color: colors.textPrimary),
          )
        else
          Text(
            l10n.aboutVersionUnreadable,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: colors.error),
          ),
        SizedBox(height: spacing.xs2),
        Text(
          l10n.aboutProvenance,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
        ),
        SizedBox(height: spacing.sm),
        TextButton(
          onPressed: version.isReadable
              ? () {
                  // ⚠️ **The version that was copied is the version that is displayed.**
                  // Copying the *build-time* pair while showing a rendered one would let
                  // the two disagree, and C9's whole point is that a pasted version
                  // identifies the build.
                  Clipboard.setData(
                    ClipboardData(
                      text:
                          '${version.buildName} · build ${version.buildNumber}',
                    ),
                  );
                  onCopied();
                }
              : null,
          child: Text(l10n.aboutCopyVersion),
        ),
      ],
    );
  }
}

/// B31's evidence: three figures, a guarantee, and E11 in full.
class DataBlock extends StatelessWidget {
  const DataBlock({super.key, required this.counts});

  final AboutCounts counts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return _RecessedBlock(
      label: l10n.aboutDataLabel,
      children: <Widget>[
        // ⚠️ **Three independent rows, three independent states.** Not one `loading`
        // around the block: a reader who cannot see their position count must still
        // see their library count.
        CountRow(
          label: l10n.aboutDataLibrary,
          value: _figure(l10n, counts.library),
        ),
        CountRow(
          label: l10n.aboutDataDownloaded,
          value: _figure(l10n, counts.downloaded),
        ),
        CountRow(
          label: l10n.aboutDataPositions,
          value: _figure(l10n, counts.positions),
        ),
        SizedBox(height: spacing.md),
        Text(
          l10n.aboutGuarantee,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
        SizedBox(height: spacing.sm),
        Text(
          l10n.aboutDataE11,
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ],
    );
  }

  /// A figure, and **a dash is not a zero**.
  ///
  /// ⚠️ While loading it is `null` too, and that is the one place the two states are
  /// rendered the same way — deliberately: a dash that flickers to a number reads as an
  /// error that was not one, and the design's own Loading rendering is *"a bar the width
  /// of the figure it will become"*, which [CountRow] draws.
  ///
  /// `error` reaches here as a **dash**, never a zero and never a skeleton: a skeleton
  /// on a query that has given up would spin forever.
  String? _figure(AppLocalizations l10n, AsyncValue<int>? value) {
    if (value == null || value.isLoading) {
      return null;
    }
    return value.value?.toString() ?? l10n.aboutDataCountUnavailable;
  }
}

/// One figure: a label and a value, and **neither is interactive**.
class CountRow extends StatelessWidget {
  const CountRow({super.key, required this.label, required this.value});

  final String label;

  /// `null` renders the skeleton; never an em dash for "loading".
  final String? value;

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs),
      child: Row(
        // ⚠️ **No `InkWell`, no `IconButton`, no leading icon.** `settings-about.md` § 5:
        // *"evidence that responds to a tap is not evidence"*. These are read as text and
        // they are read-only **by design rather than by limitation** — they are the
        // reference a reader takes before an update and compares after.
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
          if (value == null)
            // ⚠️ **A bar the width of the figure it will become** (`settings-about.md` § 4,
            // Loading) — not a centred spinner, which would put a spinner on a page whose
            // every other element is text.
            Container(
              width: 48,
              height: 12,
              decoration: BoxDecoration(
                color: colors.textSecondary.withValues(alpha: 0.24),
                borderRadius: BorderRadius.circular(2),
              ),
            )
          else
            Text(
              value!,
              // ⚠️ `--text-body`, set exactly like the non-zero case. `settings-about.md`
              // § 4 (Empty — no data): the three counts read `0 · 0 · 0` with no
              // `EmptyState`, no illustration and no "get started" — an About screen with
              // a celebratory empty state about having downloaded nothing is
              // gamification.
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
        ],
      ),
    );
  }
}

/// What leaves the device, what never does, and the falsifiable check.
class PrivacyBlock extends StatelessWidget {
  const PrivacyBlock({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    final List<String> sent = <String>[
      l10n.aboutPrivacySent1,
      l10n.aboutPrivacySent2,
    ];
    final List<String> never = <String>[
      l10n.aboutPrivacyNever1,
      l10n.aboutPrivacyNever2,
      l10n.aboutPrivacyNever3,
      l10n.aboutPrivacyNever4,
      l10n.aboutPrivacyNever5,
      l10n.aboutPrivacyNever6,
      l10n.aboutPrivacyNever7,
    ];

    return _RecessedBlock(
      label: l10n.aboutPrivacyLabel,
      children: <Widget>[
        for (final String line in sent)
          _ListLine(text: line, icon: Icons.info_outline, color: colors.info),
        for (final String line in never) ...<Widget>[
          SizedBox(height: spacing.xs2),
          _ListLine(
            text: line,
            // ⚠️ `--color-success` and not `--color-text-secondary`: the seven "never"
            // lines are a **claim about this build's network posture**, and colouring
            // them like ordinary body text makes a list of seven assertions look like a
            // list of seven facts of equal weight.
            icon: Icons.check,
            color: colors.success,
          ),
        ],
        SizedBox(height: spacing.md),
        Text(
          l10n.aboutPrivacyVerify,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
        ),
      ],
    );
  }
}

/// One line of the privacy list: a coloured icon and its sentence.
class _ListLine extends StatelessWidget {
  const _ListLine({
    required this.text,
    required this.icon,
    required this.color,
  });

  final String text;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenColors colors = LumenColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: spacing.xs2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: EdgeInsets.only(right: spacing.sm, top: spacing.xs2),
            child: ExcludeSemantics(
              // ⚠️ **The icon carries no meaning to a screen reader here.** A
              // "checkmark" before *Analytics* would be announced as a success; the
              // sentence is the content and the overline above already says which list
              // this is.
              child: Icon(icon, size: 16, color: color),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// A block on `--color-surface-sunken` with an overline, which is the *only* container
/// this screen has.
class _RecessedBlock extends StatelessWidget {
  const _RecessedBlock({required this.label, required this.children});

  final String label;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final LumenSpacing spacing = LumenSpacing.of(context);
    final LumenColors colors = LumenColors.of(context);

    return Container(
      // ⚠️ `--radius-md`, and read from `LumenRadius` rather than from
      // `cardTheme.shape`: the design system declares four radii as tokens and this
      // screen's blocks are `--radius-md`. Borrowing the card's shape would make the
      // About page's corner radius a property of whatever component last set it.
      decoration: BoxDecoration(
        color: colors.surfaceSunken,
        borderRadius: BorderRadius.circular(LumenRadius.of(context).md),
      ),
      padding: EdgeInsets.all(spacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Semantics(
            // ⚠️ `header: true` **and** an explicit `label`. The flag alone is not
            // enough: with only `header`, the label arrives as a separate child node
            // and `properties.label` is `null` — so anything reading the tree, this
            // screen's test included, sees a heading with no name. The same shape
            // `DayGroupHeader` uses, for the same reason.
            header: true,
            label: label,
            child: ExcludeSemantics(
              child: Text(
                label,
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ),
          ),
          SizedBox(height: spacing.md),
          ...children,
        ],
      ),
    );
  }
}
