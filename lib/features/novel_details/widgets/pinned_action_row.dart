// Lumen Tale — `3-2`'s pinned action row: **three** slots, and never a fourth.
//
// ## What this file is for
//
// `3-2`'s plan § 3.5 fixes the row at three places, and **B11 makes the count a rule
// rather than a description**: no share (B30), no star (keeping IS following, and a
// second marker is a second list wearing a different icon), no "mark as finished" (no
// rule defines a finished state — B39's note records that the check lost its finished
// flag for exactly that reason).
//
// ## ⚠️ IT IS PRESENTATION, AND IT TAKES NO `Novel`
//
// The row receives what it renders and emits what was tapped. It resolves nothing, opens
// nothing, and writes nothing — which is why it can be pumped in a test with no provider,
// no database and no network, and why B11's "count the descendants" row needs none.
//
// ⚠️ **Slot 1's CALLBACK is a `Novel?` and that null is load-bearing.** B12's button
// appears precisely when the novel is NOT in the library — and a novel that is not in the
// library has no stored row to read the `Novel` back from. So the caller may genuinely not
// have one, and `onAdd` receives that fact rather than a fiction. See `Q-028` in
// `DECISIONS.md`; the row renders correctly with a null and the screen decides what that
// means.

import 'package:flutter/material.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// The minimum height of every control in the row.
///
/// ⚠️ **A DISABLED CONTROL KEEPS 48dp, and the row never reflows.** A "mark all as read"
/// that disappears — or shrinks — when the last unopened chapter is opened moves the
/// controls under the reader's thumb at the exact moment they are reaching for one. The
/// button stays, greyed, saying there is nothing left to do.
const double kActionRowControlHeight = 48;

/// What slot 2 is offering — the download surface of B18.
///
/// ⚠️ **A SEALED HIERARCHY, so a fourth case is a compile error here** rather than a blank
/// space in the middle of a row that is supposed to have exactly three things in it.
sealed class DownloadSlot {
  const DownloadSlot();

  /// ⚠️ **Only the idle state renders a BUTTON.** This is what keeps B11's count true while
  /// a download runs: the bar and the chips are controls, but not action controls, so the
  /// row does not grow a fourth tap target that would compete with the other two.
  bool get isAction => false;
}

/// Nothing queued and nothing downloaded: the tap opens the bulk sheet.
final class DownloadIdle extends DownloadSlot {
  const DownloadIdle();

  @override
  bool get isAction => true;
}

/// A queue is running, and its progress is a fact rather than a promise.
final class DownloadRunning extends DownloadSlot {
  const DownloadRunning({required this.done, required this.total});

  final int done;
  final int total;

  @override
  bool get isAction => false;
}

/// Every chosen chapter is on disk.
final class DownloadDone extends DownloadSlot {
  const DownloadDone();

  @override
  bool get isAction => false;
}

/// The queue stopped, and it says why — a chip with no reason is a shrug.
final class DownloadStopped extends DownloadSlot {
  const DownloadStopped({required this.reason});

  final String reason;

  @override
  bool get isAction => false;
}

/// Where slot 1 points, which is membership first and reading second.
///
/// ⚠️ **A switch on a sealed type, not a nullable string.** "Not in the library", "in the
/// library with no position" and "in the library with a position" are three different
/// offers, and a `String? label` would let a caller pass the label of one with the
/// behaviour of another.
sealed class MembershipSlot {
  const MembershipSlot();
}

/// B12 — the novel is not in the library, and this is the only way in from here.
final class OfferToAdd extends MembershipSlot {
  const OfferToAdd();
}

/// In the library, nothing read yet: the chapter at `ordinal == 0`.
final class OfferReadFromStart extends MembershipSlot {
  const OfferReadFromStart();
}

/// In the library with a position: B12 says the label carries the chapter's own title and
/// the semantics says how far into it the reader is.
final class OfferContinue extends MembershipSlot {
  const OfferContinue({required this.chapterName, required this.percent});

  final String chapterName;
  final int percent;
}

/// The row. Three slots, always three, in this order.
class PinnedActionRow extends StatelessWidget {
  const PinnedActionRow({
    required this.membership,
    required this.download,
    required this.unopenedCount,
    required this.onAdd,
    required this.onReadFromStart,
    required this.onContinue,
    required this.onDownload,
    required this.onMarkAllRead,
    super.key,
  });

  final MembershipSlot membership;
  final DownloadSlot download;

  /// B13 — how many chapters the reader has NOT opened. Zero disables slot 3.
  final int unopenedCount;

  /// B12 — delegated to `2-5`, which owns the similar-title question (B40).
  final VoidCallback onAdd;
  final VoidCallback onReadFromStart;
  final VoidCallback onContinue;

  /// B18 — opens the bulk sheet. `5-1` implements the queue behind it.
  final VoidCallback onDownload;

  /// B13 — writes the same field opening a chapter writes, so every count in the app moves
  /// identically.
  final VoidCallback onMarkAllRead;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations copy = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      child: Row(
        children: <Widget>[
          Expanded(child: _slot1(context, copy)),
          const SizedBox(width: 8),
          Expanded(child: _slot2(context, copy)),
          const SizedBox(width: 8),
          Expanded(child: _slot3(context, copy)),
        ],
      ),
    );
  }

  /// ⚠️ **The membership offer, or the way back into the book.**
  ///
  /// B12 puts "add" first and `primary` — it is the reason a reader opened this screen
  /// from a catalogue, and a screen that makes them hunt for it has answered a different
  /// question than the one they asked.
  Widget _slot1(BuildContext context, AppLocalizations copy) {
    final MembershipSlot current = membership;
    return switch (current) {
      OfferToAdd() => FilledButton(
        onPressed: onAdd,
        child: Text(copy.chapterListAddToLibrary),
      ),
      OfferReadFromStart() => FilledButton(
        onPressed: onReadFromStart,
        child: Text(copy.chapterListReadFromStart),
      ),
      // ⚠️ **The visible label is the word alone; the SEMANTICS carries the chapter and the
      // percentage.** "Continue" tells a sighted reader where the tap goes and tells a
      // screen-reader user nothing at all — not which chapter, not how far in, which are
      // the two facts that make resuming a decision rather than a leap.
      OfferContinue() => FilledButton(
        onPressed: onContinue,
        child: Text(
          copy.chapterListContinue,
          semanticsLabel: copy.chapterListContinueSemantics(
            current.chapterName,
            current.percent,
          ),
        ),
      ),
    };
  }

  Widget _slot2(BuildContext context, AppLocalizations copy) {
    final DownloadSlot current = download;
    return switch (current) {
      DownloadIdle() => OutlinedButton(
        onPressed: onDownload,
        child: Text(copy.chapterListDownloadAction),
      ),
      // ⚠️ **A BAR, not a button.** It reports; it does not offer. Rendering it as a
      // disabled button would add a fourth control that cannot be pressed, which is the
      // thing B11 exists to prevent.
      DownloadRunning() => _Progress(
        value: current.total == 0 ? 0 : current.done / current.total,
        label: '${current.done} / ${current.total}',
      ),
      DownloadDone() => _StatusChip(
        icon: Icons.download_done_outlined,
        label: copy.chapterTileDownloaded,
      ),
      // ⚠️ **The REASON is the chip's label, not an afterthought.** A chip that says "stopped"
      // without saying why leaves the reader to guess between "the site refused", "no space"
      // and "I cancelled it" — and those three want three different actions.
      DownloadStopped() => _StatusChip(
        icon: Icons.error_outline,
        label: current.reason,
      ),
    };
  }

  /// ⚠️ **B13: DISABLED AT ZERO, NEVER ABSENT.**
  ///
  /// The button stays, greyed, at [kActionRowControlHeight]. Two reasons, and the second is
  /// the one that costs: a control that disappears moves its neighbours, so marking the
  /// last chapter read slides *Download* sideways under a thumb that was already moving.
  Widget _slot3(BuildContext context, AppLocalizations copy) {
    final bool nothing = unopenedCount == 0;
    return SizedBox(
      height: kActionRowControlHeight,
      child: OutlinedButton(
        onPressed: nothing ? null : onMarkAllRead,
        child: Text(
          nothing
              ? copy.chapterListNothingUnopened
              : copy.chapterListMarkAllRead,
        ),
      ),
    );
  }
}

/// The running bar. It reports a count and never invites a tap.
class _Progress extends StatelessWidget {
  const _Progress({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 4,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}

/// A finished or stopped queue, as a chip that always SAYS something.
///
/// ⚠️ **The label is required, and that is the point.** The first version took a
/// `String? labelKey` beside an optional `semanticLabel`, and `DownloadDone` passed `null`
/// for both — which is an icon a screen reader announces as "icon". A chip whose state
/// cannot be named is a state the reader cannot act on, so the type makes the caller supply
/// the words.
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return SizedBox(
      height: kActionRowControlHeight,
      child: Row(
        children: <Widget>[
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.labelSmall,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
