// Lumen Tale — `3-6`: SC-6's only surface, and the seven differences from an empty list.
//
// ## A reader who mistakes this for a list concludes the site has no novels
//
// Each difference below is asserted, because "it looks different" is not a property a code
// review can check — only a row can.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/core/error/source_failure.dart';
import 'package:lumen_tale/domain/library/library_entry.dart';
import 'package:lumen_tale/features/library/library_screen.dart'
    show libraryStreamProvider;
import 'package:lumen_tale/features/source_unavailable/failure_cause.dart';
import 'package:lumen_tale/features/source_unavailable/source_unavailable_screen.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

LibraryEntry entry({String id = 'n1', int downloaded = 148}) => LibraryEntry(
  id: id,
  sourceId: 'royalroad',
  sourceName: 'Royal Road',
  title: 'The Rune Smith',
  inLibrary: true,
  unopenedCount: 0,
  chapterCount: 480,
  downloadedCount: downloaded,
  addedAt: DateTime(2026, 10, 1, 9),
);

/// A library stream the test drives, so the "still works" counts are real.
final class FakeLibraryStream {
  FakeLibraryStream(this.entries);

  List<LibraryEntry> entries;

  /// ⚠️ **A broadcast controller**, because a screen that watches the stream twice would throw
  /// on a single-subscription one — and that would be a harness failure reported as a product
  /// defect.
  // ignore: close_sinks
  final StreamController<List<LibraryEntry>> controller =
      StreamController<List<LibraryEntry>>.broadcast();
}

Future<void> pumpScreen(
  WidgetTester tester,
  SourceFailure failure, {
  List<LibraryEntry> library = const <LibraryEntry>[],
}) async {
  final FakeLibraryStream stream = FakeLibraryStream(library);
  addTearDown(stream.controller.close);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        libraryStreamProvider.overrideWith(
          (Ref ref) => stream.controller.stream,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: SourceUnavailableScreen(
          sourceId: 'royalroad',
          sourceName: 'Royal Road',
          failure: failure,
        ),
      ),
    ),
  );
  stream.controller.add(stream.entries);
  await tester.pumpAndSettle();
}

void main() {
  group('§ 3.2 — six failures in, five causes out, exhaustively', () {
    test('⚠️ every SourceFailure has a cause, and a NEW one breaks this file', () {
      // ⚠️ **The `switch` in `classify` has no `default`**, so adding a seventh `SourceFailure`
      // is a compile error in `failure_cause.dart` rather than a cause that renders as the
      // generic one — and the generic one says *the app could not read its own record*, which
      // is a much stronger and different claim.
      final Map<SourceFailure, FailureCause> expected =
          <SourceFailure, FailureCause>{
            const NoConnection(host: 'x'): FailureCause.noConnection,
            const RateLimited(retryAfter: Duration(seconds: 30)):
                FailureCause.siteUnavailable,
            const SourceLayoutChanged(failedSelector: 'tr', status: 200):
                FailureCause.layoutChanged,
            const SourceUnavailable(status: 503): FailureCause.siteUnavailable,
            const SourceUnavailable(status: 403, isChallenge: true):
                FailureCause.siteUnavailable,
            const ItemRemovedAtSource(itemId: 'c1', status: 404):
                FailureCause.contentRemoved,
            const ParseFailed(path: '/fictions'): FailureCause.layoutChanged,
          };
      for (final MapEntry<SourceFailure, FailureCause> entry
          in expected.entries) {
        expect(
          classify(entry.key).cause,
          entry.value,
          reason: entry.key.toString(),
        );
      }
    });

    test('⚠️ only layoutChanged is RED, and only it is the app\'s own fault', () {
      // ⚠️ **A page that is red whatever happened teaches a reader that red means "the app is in
      // a mood"** — and the reader who needs to tell the owner *which* thing broke is exactly
      // the one who can no longer.
      expect(
        classify(const NoConnection(host: 'x')).colour,
        isNot(CauseColour.error),
      );
      expect(
        classify(const SourceUnavailable(status: 503)).colour,
        isNot(CauseColour.error),
        reason: 'the site being down is not the app being wrong',
      );
      expect(
        classify(const ItemRemovedAtSource(itemId: 'c', status: 404)).colour,
        CauseColour.primaryText,
        reason: 'the author withdrew a chapter — that is the site working',
      );
      expect(
        classify(
          const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        ).colour,
        CauseColour.error,
      );
    });

    test('⚠️ a challenge is NAMED, never merged into a bare status', () {
      // ⚠️ **ADR-014 rejected climbing a challenge**, so it is a wall this app will not climb —
      // and a reader told "some sites need a browser" can act on it while one told "HTTP 403"
      // cannot.
      final ClassifiedFailure challenge = classify(
        const SourceUnavailable(status: 403, isChallenge: true),
      );
      expect(challenge.evidence, isA<AntiBotChallengeEvidence>());
      expect(challenge.evidence.sentence(), contains('anti-bot'));
    });

    test('⚠️ retryAfter rides ONLY on the rate-limited cause', () {
      // ⚠️ § 5.2: `RateLimited | duration | after Retry-After | wait`. A countdown anywhere else
      // is a number nobody can trust.
      expect(
        classify(
          const RateLimited(retryAfter: Duration(seconds: 30)),
        ).retryAfter,
        const Duration(seconds: 30),
      );
      for (final SourceFailure failure in <SourceFailure>[
        const NoConnection(host: 'x'),
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        const ItemRemovedAtSource(itemId: 'c', status: 404),
      ]) {
        expect(
          classify(failure).retryAfter,
          isNull,
          reason: failure.toString(),
        );
      }
    });

    test('⚠️ the evidence never contains a PATH', () {
      // ⚠️ `17-security.md` rule 4. A request path is not a fact a reader can act on and is a
      // site-internal URL on their screen.
      final ClassifiedFailure parsed = classify(
        const ParseFailed(path: '/fictions/active-popular?page=1'),
      );
      expect(parsed.evidence.sentence(), isNot(contains('/fictions')));
      expect(parsed.evidence.sentence(), isNot(contains('page=1')));
    });

    test('⚠️ the site\'s own "nothing here" marker is KEPT in the evidence', () {
      // ⚠️ **B22's discriminant made visible.** The string is the proof that the site said so,
      // and discarding it would leave a reader with "the page was empty" and no explanation.
      final ClassifiedFailure state = classify(
        const SourceLayoutChanged(
          failedSelector: 'tr',
          status: 200,
          siteSuppliedSignal: 'There is nothing here :(',
        ),
      );
      expect(state.evidence.sentence(), contains('There is nothing here :('));
    });
  });

  group('§ 3.1 — the COLOUR is the message', () {
    testWidgets('⚠️ the RENDERED colour is the cause\'s, and only one is an error', (
      WidgetTester tester,
    ) async {
      // ⚠️ **This row is about the RENDERED colour, not `classify`'s enum.** A sabotage that
      // repainted `colourFor` passed the enum row entirely — the enum still said `info` while
      // the screen drew red — which is exactly the failure this rule exists to prevent: red has
      // to mean *this app's selectors no longer match the site*, on screen, not in a data
      // structure nobody looks at.
      final ThemeData theme = ThemeData.light();

      expect(
        colourFor(FailureCause.noConnection, theme),
        theme.colorScheme.primary,
        reason: 'a phone in a tunnel is not a broken site',
      );
      expect(
        colourFor(FailureCause.siteUnavailable, theme),
        theme.colorScheme.tertiary,
        reason: 'the site being down is not the app being wrong',
      );
      expect(
        colourFor(FailureCause.contentRemoved, theme),
        theme.colorScheme.onSurface,
        reason: 'the author withdrew a chapter — that is the site working',
      );
      expect(
        colourFor(FailureCause.layoutChanged, theme),
        theme.colorScheme.error,
      );
    });

    testWidgets('⚠️ and the kicker ON SCREEN carries it', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const NoConnection(host: 'x'));

      // ⚠️ **Asserted as an ABSENCE of the error colour**, because comparing against
      // `colourFor(..., ThemeData.light())` would compare two different themes — the screen
      // pumps with `MaterialApp`'s default and a probe with an explicit `light()`. The
      // property that matters is the one a reader sees: this screen is not red.
      final Text kicker = tester.widget<Text>(find.text('NO CONNECTION'));
      final ColorScheme scheme = Theme.of(
        tester.element(find.text('NO CONNECTION')),
      ).colorScheme;
      expect(kicker.style?.color, isNotNull);
      expect(kicker.style?.color, isNot(scheme.error));
    });
  });

  group('§ 3.1 — the seven differences from an empty list', () {
    testWidgets('1. a kicker, before anything else', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
      );
      expect(find.text('THE PAGES OF THIS SITE HAVE CHANGED'), findsOneWidget);
    });

    testWidgets('2. an icon, coloured by cause', (WidgetTester tester) async {
      await pumpScreen(tester, const NoConnection(host: 'x'));
      expect(find.byIcon(Icons.wifi_off_outlined), findsOneWidget);
    });

    testWidgets('3. a title in the app\'s own words', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const NoConnection(host: 'www.royalroad.com'));
      expect(find.text('No connection to www.royalroad.com'), findsOneWidget);
    });

    testWidgets('4. an evidence line, with the observed facts', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr[data-url]', status: 200),
      );
      expect(find.text('What happened'), findsOneWidget);
      expect(find.textContaining('HTTP 200'), findsOneWidget);
      expect(find.textContaining('tr[data-url]'), findsOneWidget);
    });

    testWidgets('5. ⚠️ a "what still works" block with the LOCAL counts', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The block that ends the fear.** SC-6's damage is not the failure — it is a reader
      // concluding their library is gone. These counts need no network, so they cannot lie
      // about one.
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        library: <LibraryEntry>[
          entry(),
          entry(id: 'n2', downloaded: 12),
        ],
      );

      expect(find.text('What still works'), findsOneWidget);
      expect(find.textContaining('2 novels'), findsOneWidget);
      expect(find.textContaining('160 downloaded chapters'), findsOneWidget);
    });

    testWidgets('5b. ⚠️ a count of ZERO says nothing was lost', (
      WidgetTester tester,
    ) async {
      // ⚠️ Without this the empty case and the failure case read alike, and a reader who has
      // just seen a failure cannot tell "empty" from "gone".
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
      );

      // ⚠️ **The zero case, not the counted one.** The block must say something when there is
      // nothing to count, because "empty" and "gone" read alike otherwise.
      expect(find.textContaining('Nothing is stored yet'), findsOneWidget);
      expect(find.textContaining('nothing was lost'), findsOneWidget);
    });

    testWidgets('6. ⚠️ a REMOVED chapter has NO retry, and says why', (
      WidgetTester tester,
    ) async {
      // ⚠️ **Absent, not disabled.** A greyed-out *Try again* tells a reader the app is
      // considering an action it will not take.
      await pumpScreen(
        tester,
        const ItemRemovedAtSource(itemId: 'c1', status: 404),
      );

      expect(find.widgetWithText(FilledButton, 'Try again'), findsNothing);
      expect(find.text('There is nothing to try again here.'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Back'), findsOneWidget);
    });

    testWidgets('6b. a layout change DOES retry, and hedges first', (
      WidgetTester tester,
    ) async {
      // ⚠️ A site mid-deployment is a temporary state, so the button is honest — and the
      // sentence under it sets the expectation a retry needs to be fair.
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
      );

      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(
        find.textContaining('Sometimes it resolves on its own'),
        findsOneWidget,
      );
    });

    testWidgets('7. ⚠️ NEVER a list of novels and never a count of them', (
      WidgetTester tester,
    ) async {
      // ⚠️ **The difference SC-6 turns on.** A list-shaped failure page is indistinguishable
      // from a site with nothing in it.
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
        library: <LibraryEntry>[entry()],
      );

      expect(find.byType(ListView), findsNothing);
      expect(find.byType(GridView), findsNothing);
      expect(find.byType(ListTile), findsNothing);
      // ⚠️ **And it never says "0 novels"** — the phrase that would read as "this site is empty".
      expect(find.textContaining('0 novels'), findsNothing);
      expect(find.textContaining('No novels'), findsNothing);
    });
  });

  group('the body says what is NOT wrong, before what is', () {
    testWidgets('⚠️ no connection leads with "Nothing was lost"', (
      WidgetTester tester,
    ) async {
      await pumpScreen(tester, const NoConnection(host: 'x'));
      expect(find.textContaining('Nothing was lost'), findsOneWidget);
    });

    testWidgets('⚠️ a layout change blames the APP\'S COPY, not the site', (
      WidgetTester tester,
    ) async {
      // ⚠️ E8's whole point: the reader broke nothing and the site broke nothing. "{source} is
      // broken" transfers the fault to the one party the reader cannot report to.
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
      );

      expect(
        find.textContaining('a fault in the copy this app has of'),
        findsOneWidget,
      );
      expect(find.textContaining('not in Royal Road'), findsOneWidget);
      expect(
        find.textContaining('nothing is to do with how you use it'),
        findsOneWidget,
      );
    });

    testWidgets('⚠️ C12: there is a sentence the reader can read ALOUD', (
      WidgetTester tester,
    ) async {
      // ⚠️ The reader is often on a phone they cannot type on, and "the pages of X have
      // changed" is something a person can act on while "HTTP 200" is not.
      await pumpScreen(
        tester,
        const SourceLayoutChanged(failedSelector: 'tr', status: 200),
      );

      expect(find.textContaining('Say:'), findsOneWidget);
      expect(
        find.textContaining('the pages of Royal Road have changed'),
        findsOneWidget,
      );
    });
  });
}
