// Lumen Tale — the standing notice: downloads continue only while the app is open.
//
// `5-2` § 4.1/§ 4.3, from `downloads.md` § 2.1.
//
// ## ⚠️ **IT IS IN EVERY STATE, INCLUDING `idle`, AND IT IS NOT IN THE SETTINGS**
//
// `downloads.md` § 2.1, verbatim in substance: *"it is the first line under the title, it
// is always there, and it is repeated inside the stopped state"*. § 3's anatomy puts it
// directly under the title bar and above every section.
//
// `flows.md` § 4.4 calls this *"the single most likely over-promise in the product"*: every
// competing reader ships a background download service, so the expectation the app is
// fighting is that closing the app just moves the bar somewhere invisible. A limitation in
// a settings page, or a modal seen once, does not survive that expectation.
//
// ## ⚠️ **IT LIVES IN `features/downloads/` AND NOT IN `core/ui/`**
//
// No other screen carries it — `design-system.md` § 2.7 puts a single-feature component in
// the feature, and `updates.md`'s `ScheduleNotice` is the precedent. A shared folder for a
// one-owner widget is a folder that later grows a second, unrelated resident.

import 'package:flutter/material.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

class InProcessNotice extends StatelessWidget {
  const InProcessNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final LumenColors colors = LumenColors.of(context);
    return Semantics(
      // ⚠️ **A LIVE REGION, BECAUSE IT IS THE FIRST THING THAT CAN CHANGE UNDER THE READER.**
      // Nothing on this screen does; the notice's job is to be read once and remembered.
      container: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Text(
          AppLocalizations.of(context).downloadsInProcessNotice,
          // ⚠️ **`--text-caption` IN `--color-text-secondary`, AND THE SECOND IS DELIBERATE.**
          // `downloads.md` § 2's contrast table gives that pair 6.22:1 / 6.01:1, and C11 is
          // a night, one-handed, glanced-at context. A fainter grey would have been a
          // footnote.
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: colors.textSecondary),
        ),
      ),
    );
  }
}
