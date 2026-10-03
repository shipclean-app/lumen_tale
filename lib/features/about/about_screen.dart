// Lumen Tale — `/more/settings/about`: the version, the three counts, and what leaves
// the device.
//
// `settings-about.md`. `settings.md`'s sub-route, so it is a `push` from Settings and
// **outside** the shell's branch roots but **inside** its branch — `openNovelDetails`
// in `app_router.dart` says why `push` and not `go`.
//
// ## The three counts are the screen
//
// § 2.1: *"A guarantee that an upgrade preserves the library is worth nothing without
// a way to see that it did."* B31 is a promise and these are the evidence, which is why
// they are on this page and not on a stats screen: a reader takes them **before** an
// update and compares **after**.
//
// ## A count that could not be computed is a DASH, not a zero
//
// And that distinction is the whole reason the block exists. A zero says *"you have
// none"*; a dash says *"we could not look"*. A reader who took the first for the second
// would re-download a library they still have.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/app_version.dart';
import 'package:lumen_tale/app/theme/lumen_spacing.dart';
import 'package:lumen_tale/core/ui/app_scaffold.dart';
import 'package:lumen_tale/features/about/about_providers.dart';
import 'package:lumen_tale/features/about/about_widgets.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

/// ⚠️ **No `UpdateBlock`, no "Check for a new version", and no network call at all.**
///
/// `settings-about.md` § 4bis removed the whole version-check feature from v1: no
/// success criterion requires it, `apk-pipeline` already delivers builds, and it is
/// the one control on this screen that would reach a server by itself — which makes
/// every future addition to it a place to be careless about B29.
///
/// What § 4bis keeps is the **version line** (B43) and **B31's guarantee sentence**,
/// and both are here. Eighteen ARB keys the design still listed are deliberately
/// absent; dead copy is a defect.
class AboutScreen extends ConsumerWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final AboutCounts counts = ref.watch(aboutCountsProvider);

    return AppScaffold(
      titleBar: AppBar(title: Text(l10n.appTitle)),
      content: AboutBody(version: readBuildVersion(), counts: counts),
    );
  }
}

/// The page, and every block in it.
class AboutBody extends StatelessWidget {
  const AboutBody({super.key, required this.version, required this.counts});

  final BuildVersion version;

  /// Three independent figures. **Never blocks the rest of the page** — a privacy
  /// statement must not be waiting on a query about counts, so this is a `Provider` and
  /// not a `FutureProvider`: the page is built while the three are still loading.
  final AboutCounts counts;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = AppLocalizations.of(context);
    final LumenSpacing spacing = LumenSpacing.of(context);

    return ListView(
      // ⚠️ `--space-3xl` top margin, once, on the page and not on each block: the
      // design's § 2 says the page is a single column with the identity block first,
      // and per-block margins would make the rhythm unreadable.
      padding: EdgeInsets.fromLTRB(
        spacing.lg,
        spacing.xl3,
        spacing.lg,
        spacing.xl3,
      ),
      children: <Widget>[
        AboutIdentity(
          version: version,
          onCopied: () => ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.aboutSnackCopied))),
        ),
        SizedBox(height: spacing.xl),
        DataBlock(counts: counts),
        SizedBox(height: spacing.xl),
        const PrivacyBlock(),
        SizedBox(height: spacing.xl),
        Text(
          l10n.aboutDeliveryBody,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    );
  }
}

/// The three figures, as a group of `AsyncValue`s rather than one.
///
/// ⚠️ **One query per figure, and the three are independent.** A single `SELECT` with
/// three sub-selects would be cheaper and would make them one answer: one slow query
/// would put all three in `loading` and one failure would blank all three. The design
/// says *"one local query per figure"*, and the real reason is the failure shape — a
/// reader who cannot see their position count must still see their library count.
class AboutCounts {
  const AboutCounts({
    required this.library,
    required this.downloaded,
    required this.positions,
  });

  final AsyncValue<int> library;
  final AsyncValue<int> downloaded;
  final AsyncValue<int> positions;
}
