// Lumen Tale — the E11 disclosure, and the two dots that say how many steps there are.
//
// `design-system.md` § 2.7's idiom, mounted on **two** surfaces: step 2 of `/onboarding`
// and the foot of `/more/settings`.
//
// ## ⚠️ IT LIVES HERE AND NOT IN `core/ui/`, AND THE REASON IS A RULE, NOT A PREFERENCE
//
// `3-4` § 4.2: the block has two consumers, and `02-architecture.md` forbids
// `features/*` from importing each other. Promoting it to `core/ui/` today would put a
// widget in the shared layer with **one** consumer — Settings, which already owns a
// slice-local copy of the same idiom — and `core/ui/` is `09-widgets-ui.md`'s place for
// components a *second* screen needs. The promotion trigger is stated in
// `history.md` § 3 and `updates.md` § 3 for their own block-local widgets: **a third
// screen anchors it**.
//
// The consequence, stated rather than hidden: this file and `features/settings/
// settings_rows.dart` each render the same idiom, and **both read the same ARB keys**.
// Two renderings are a risk; two *texts* would be a lie about the same loss.
//
// ## ⚠️ NO ICON, AND `--color-error` IS FORBIDDEN HERE
//
// `onboarding.md` § 2.1: *"a recessed block of words with no icon at all, because an icon
// would make a permanent fact look like an incident"*. § 12 lists `--color-error` in this
// screen's token table **for the record, marked "Not rendered"** — the absence is a
// decision, not an oversight. A red block says something is broken now; nothing here is
// broken, ever, and will not be until the phone is uninstalled by someone outside the app.

import 'package:flutter/material.dart';

import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/app/theme/lumen_radius.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/features/onboarding/widgets/onboarding_type.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The recessed block carrying E11: a body, a footnote saying **why it is said now**, and
/// — on the surface that has somewhere to send the reader — a ghost link.
class DisclosureBlock extends StatelessWidget {
  const DisclosureBlock({super.key, required this.showFootnote, this.onLink});

  /// Whether the "why now" footnote is rendered.
  ///
  /// ⚠️ **A PARAMETER, AND `3-4` § 4.2 NAMES IT.** Both surfaces that exist today pass
  /// `true` — step 2 and the Settings footer both state the impossibility, because that
  /// clause is what makes the disclosure a disclosure rather than an apology. The flag
  /// exists so a future surface with no room for a second line **omits the line** instead
  /// of truncating it, and so that decision is visible in review rather than taken by
  /// whoever next lays this block out.
  final bool showFootnote;

  /// The ghost link's action, or `null` for **no link at all**.
  ///
  /// ⚠️ **A CALLBACK, NOT A `context.push`.** Step 2 has no destination: the reader is on
  /// their way out, and a link on the disclosure that leaves the flow would be a second
  /// exit from a disclosure that is supposed to have one. Settings passes
  /// `openAbout`, and `09-widgets-ui.md` keeps navigation in the router's call sites.
  final VoidCallback? onLink;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    // ⚠️ **`Semantics(container: true)`, AND IT IS THE POINT OF THE WRAPPER.** The screen
    // file requires the disclosure to be announced as a **distinct region**, not as
    // trailing text: a screen-reader user must not be able to reach step 2, hear
    // "There is no backup.", and be able to swipe past the sentence that explains it.
    // `container: true` introduces a node of its own, so the body and the footnote are
    // reached as a block instead of being merged into the headline above them.
    return Semantics(
      container: true,
      child: Container(
        // ⚠️ **`surfaceSunken` AND NO SHADOW.** `design-system.md` § 2.1 refuses "a
        // shadowed card" on both steps; this is a thing to look *into*, not a card to
        // look *at*. The absence of a `BoxShadow` is deliberate and is asserted by the
        // tests, not merely left out.
        decoration: BoxDecoration(
          color: colors.surfaceSunken,
          borderRadius: BorderRadius.circular(LumenRadius.of(context).md),
        ),
        padding: EdgeInsets.all(spacing.xl2),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              disclosureBody(l10n),
              // ⚠️ **`bodyMedium`, WHICH IS `--text-body-sm` 14 / 20 — AND DELIBERATELY
              // NOT CAPTION SIZE.** This is the most consequential text in the product and
              // the only place a reader is told their downloads are unrecoverable; the
              // caption is reserved for *why the disclosure is here now*.
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: colors.textSecondary),
            ),
            if (showFootnote) ...<Widget>[
              SizedBox(height: spacing.sm),
              // ⚠️ **THE FOOTNOTE IS ITS OWN LINE, NEVER A CONTINUATION OF THE BODY.** It
              // answers a different question — *why now, and why not then* — and a reader
              // who read the body alone has still not been told that the app cannot detect
              // the uninstall it is warning about.
              Text(
                disclosureFootnote(l10n),
                style: Theme.of(
                  context,
                ).textTheme.labelSmall?.copyWith(color: colors.textSecondary),
              ),
            ],
            if (onLink != null) ...<Widget>[
              SizedBox(height: spacing.sm),
              // ⚠️ **A GHOST LINK — `TextButton`, NO CHEVRON, NO ARROW GLYPH.** The design
              // writes "What survives an update →", and the arrow is a character in the
              // label rather than an icon widget, so the block still contains no `Icon` and
              // `onboarding.md` § 2.1's claim stays checkable.
              TextButton(
                onPressed: onLink,
                child: Text(
                  l10n.settingsDisclosureAboutLink,
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.accent),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The disclosure body — **one ARB key, two surfaces**.
///
/// ⚠️ **THIS IS `settingsDisclosureE11`, NOT A NEW KEY, AND THAT IS THE POINT.** `3-4`
/// § 7: *"a single ARB key used by step 2, by the Settings `DisclosureBlock` and by the
/// About screen. Three copies are three versions, and one of the three will be shorter."*
/// The Settings screen reads the same getter — the precedent is
/// `aboutDataCountUnavailable`, which the settings screen already reads for the same
/// reason, because `02-architecture.md` forbids one feature importing another's *code*
/// while saying nothing about the generated l10n class they both already hold.
///
/// The key keeps Settings' name because **renaming it would touch a validated slice's
/// tests for no gain in what the reader sees**; the alternative — a fresh
/// `onboardingStep2Disclosure` holding the same sentence — is the copy § 7 forbids, and
/// it would be free to drift from the day it was written.
String disclosureBody(AppLocalizations l10n) => l10n.settingsDisclosureE11;

/// The footnote — **the same key, for the same reason.** See [disclosureBody].
String disclosureFootnote(AppLocalizations l10n) =>
    l10n.settingsDisclosureE11Footer;

/// **Two** dots, one active. Position only — it carries no action and is not focusable.
class StepDots extends StatelessWidget {
  const StepDots({super.key, required this.active, this.count = 2});

  /// Which step is showing, **zero-based**.
  final int active;

  /// How many steps exist. **Two**, and the default says so.
  ///
  /// ⚠️ **COUNTED, NOT DRAWN TWICE BY HAND.** A hand-written pair of dots has no way to
  /// disagree with the state machine; a counted one does, immediately, the first time a
  /// third step is written.
  final int count;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenColors colors = LumenColors.of(context);

    return Semantics(
      // ⚠️ **`excludeSemantics: true` WITH THE LABEL**, so a screen-reader user hears
      // *"Step 1 of 2"* as one fact rather than as two identical empty circles between the
      // promise and the body. Position is therefore never carried by colour alone, which is
      // the second half of the same rule the dot colours serve.
      container: true,
      excludeSemantics: true,
      label: l10n.onboardingStepPosition(active + 1, count),
      child: Row(
        children: <Widget>[
          for (int index = 0; index < count; index++)
            Padding(
              padding: EdgeInsets.only(
                right: index == count - 1 ? 0 : kStepDotGap,
              ),
              child: SizedBox.square(
                dimension: kStepDotSize,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    // ⚠️ **`borderField`, NOT `border`.** `design-system.md` § 0.0 exempts
                    // `--color-border` because it is a *decorative rule between rows*; a
                    // dot is a UI component indicating position, so claiming the exemption
                    // would be a false claim of the kind the design system explicitly warns
                    // about. `--color-border-field` is the token declared for a component
                    // boundary and it clears 3:1.
                    color: index == active ? colors.accent : colors.borderField,
                    borderRadius: BorderRadius.circular(
                      LumenRadius.of(context).full,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
