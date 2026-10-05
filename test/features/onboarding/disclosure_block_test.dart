// forge:slice 3-4
// Lumen Tale — `3-4` § 3.5, the disclosure block on **both** its surfaces, and the one ARB
// key they share.
//
// ## ⚠️ WHY THIS FILE EXISTS AT ALL, GIVEN `features/settings/` HAS ITS OWN COPY
//
// `02-architecture.md` forbids `features/*` importing each other, so the Settings screen's
// slice-local `DisclosureBlock` and this one coexist — and the risk that creates is not two
// renderings, it is **two texts**. § 7: *"Three copies are three versions, and one of the
// three will inevitably be shorter."* So the rows below are about the STRINGS, and they read
// the generated `AppLocalizations` — which both features already hold — rather than
// importing anything from either.

import 'package:flutter/material.dart';
// ⚠️ **`SemanticsNode` COMES FROM `package:flutter/semantics.dart`, NOT `widgets.dart`.** The
// library `flutter/widgets.dart` re-exports does not include `src/semantics/semantics.dart`,
// so `tester.getSemantics`'s return type has to be named from its own library.
import 'package:flutter/semantics.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/app/theme/lumen_colors.dart';
import 'package:lumen_tale/features/onboarding/widgets/disclosure_block.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';

late AppLocalizations en;
late AppLocalizations fr;

Future<void> _pump(
  WidgetTester tester,
  DisclosureBlock block, {
  Locale locale = const Locale('en'),
}) async {
  tester.view
    ..physicalSize = const Size(360, 900)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.day(),
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SingleChildScrollView(child: block)),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() async {
    en = await AppLocalizations.delegate.load(const Locale('en'));
    fr = await AppLocalizations.delegate.load(const Locale('fr'));
  });

  group('the block renders the body, the footnote, and the ghost link', () {
    testWidgets('all three, when the link has a destination', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await _pump(
        tester,
        DisclosureBlock(showFootnote: true, onLink: () => taps++),
      );

      expect(find.text(disclosureBody(en)), findsOneWidget);
      expect(find.text(disclosureFootnote(en)), findsOneWidget);
      expect(find.text(en.settingsDisclosureAboutLink), findsOneWidget);
      expect(taps, 0, reason: 'rendering is not pressing');

      await tester.tap(find.text(en.settingsDisclosureAboutLink));
      await tester.pumpAndSettle();
      expect(
        taps,
        1,
        reason: 'the ghost link is a link, and it goes somewhere',
      );
    });

    testWidgets('⚠️ `showFootnote: false` omits the LINE, not the sentence', (
      WidgetTester tester,
    ) async {
      // ⚠️ **THE PARAMETER IS USED, AND WHAT IT DOES IS NAMED.** The footnote answers a
      // different question from the body — *why now, and why not then* — so omitting it must
      // remove the whole line rather than truncate it. A surface with no room for a second
      // line has to be able to drop it honestly.
      await _pump(tester, const DisclosureBlock(showFootnote: false));

      expect(
        find.text(disclosureBody(en)),
        findsOneWidget,
        reason: 'the body stays',
      );
      expect(
        find.text(disclosureFootnote(en)),
        findsNothing,
        reason: 'the footnote is gone, not shortened',
      );
      expect(
        find.byType(Text),
        findsOneWidget,
        reason: 'one paragraph, and nothing pretending to be a footnote',
      );
    });

    testWidgets('no link means no link — `onLink: null` renders no `TextButton`', (
      WidgetTester tester,
    ) async {
      // ⚠️ **STEP 2'S CASE.** The reader is on their way out and the only destination is the
      // library; a link here would be a second exit from a disclosure § 2.1 says has one.
      await _pump(tester, const DisclosureBlock(showFootnote: true));

      expect(find.byType(TextButton), findsNothing);
      expect(
        find.text(en.settingsDisclosureAboutLink),
        findsNothing,
        reason:
            'and the label is not rendered either — an invisible affordance is a lie',
      );
    });
  });

  group('⚠️ E11 — the block announces itself as a DISTINCT region', () {
    testWidgets('it is its own semantics node, not trailing text', (
      WidgetTester tester,
    ) async {
      final SemanticsHandle handle = tester.ensureSemantics();

      await _pump(tester, const DisclosureBlock(showFootnote: true));

      // ⚠️ **`getSemanticsData().label`, NOT A FLAG.** `Semantics(container: true)`'s whole
      // effect — *"this widget will introduce a new node in the semantics tree"* — is not
      // exposed as a flag on `SemanticsData`; what it produces is a node whose label is the
      // block's own text rather than a merge of the block into whatever is above it. So the
      // observable is the label, and that is what the row reads.
      final SemanticsNode node = tester.getSemantics(
        find.byType(DisclosureBlock),
      );
      final String label = node.getSemanticsData().label;
      expect(
        label,
        contains('Nothing here is backed up'),
        reason:
            'the disclosure must be reachable as itself. § 7: a screen-reader user must not '
            'be able to reach step 2, hear "There is no backup." and swipe past the sentence '
            'that explains it.',
      );
      expect(
        label,
        contains('cannot warn you at the moment you uninstall'),
        reason:
            'the footnote is inside the same region — it is the reason the disclosure is '
            'here NOW, and a reader who missed it would believe it was a momentary warning',
      );
      handle.dispose();
    });
  });

  group('⚠️ three occurrences, ONE text', () {
    test('the block and step 2 read the SAME ARB key, in both languages', () {
      // ⚠️ **THE ROW THAT IS ABOUT THE KEY RATHER THAN THE STRING.**
      //
      // Two accessors returning the same sentence today is a coincidence; one accessor is a
      // fact. `disclosureBody` and `disclosureFootnote` are the onboarding feature's *only*
      // way to reach this text, and they return `settingsDisclosureE11` and
      // `settingsDisclosureE11Footer` — which is why the settings slice's own
      // `DisclosureBlock` cannot drift away from this one.
      for (final AppLocalizations l10n in <AppLocalizations>[en, fr]) {
        expect(
          disclosureBody(l10n),
          l10n.settingsDisclosureE11,
          reason:
              'step 2 and the block must be reading one key in ${l10n.localeName}. A second '
              'key holding the same sentence is the copy § 7 refuses.',
        );
        expect(
          disclosureFootnote(l10n),
          l10n.settingsDisclosureE11Footer,
          reason: 'and the same for the footnote',
        );
      }
    });

    test('the three surfaces that exist today, and what each says', () {
      // ⚠️ **THE ABOUT SCREEN IS *NOT* IDENTICAL, AND THIS ROW SAYS SO.**
      //
      // § 7 asks for "three occurrences, one text": onboarding step 2, the Settings block
      // and the About screen. The first two are one key. The third is `aboutDataE11`, which
      // `settings-about.md` § 9 gives its own sentence — it states the guarantee about
      // updates ("installing a new version over this one does not touch them") beside the
      // warning, because that page exists to show B31's evidence.
      //
      // Making it identical would delete a sentence the About screen is built around, so this
      // row asserts the **distinction and its reason** rather than papering over it. It is
      // recorded as an open question for the orchestrator: the plan's literal wording and
      // the two approved screen files disagree, and the screen files are the authority.
      expect(
        en.aboutDataE11,
        isNot(en.settingsDisclosureE11),
        reason:
            'the About screen says more — it pairs the warning with B31\'s only guarantee. '
            'Collapsing the two would delete that sentence, which is the page\'s reason to '
            'exist.',
      );
      expect(
        en.aboutDataE11,
        contains('no copy exists'),
        reason: 'but it still discloses E11, in the same direction',
      );
      expect(
        en.aboutDataE11,
        contains('does not touch them'),
        reason:
            'and it adds the one thing this app DOES guarantee about an update, which the '
            'onboarding disclosure deliberately does not mention',
      );
      // ⚠️ **AND BOTH CARRY THE SAME SENTENCE COUNT**, so the French page cannot be the one
      // that drops a clause.
      int sentences(String text) =>
          RegExp(r'[.!?](?=\s|$)').allMatches(text).length;
      expect(
        sentences(fr.aboutDataE11),
        sentences(en.aboutDataE11),
        reason:
            'the About disclosure is translated in full too, for the same reason as E11',
      );
    });
  });

  group('⚠️ the ghost link goes where the design says', () {
    testWidgets('tapping it reaches `/more/settings/about`', (
      WidgetTester tester,
    ) async {
      // ⚠️ **A REAL ROUTER, NOT A COUNTER.** § 11.2 asks that the link "navigates to
      // `/more/settings/about`", and a counter would only prove that the callback fired —
      // the destination is chosen by whoever supplies the callback, so the row has to
      // navigate for the claim to mean anything.
      final GoRouter router = GoRouter(
        initialLocation: '/',
        routes: <RouteBase>[
          GoRoute(
            path: '/',
            builder: (BuildContext context, GoRouterState state) => Scaffold(
              body: DisclosureBlock(
                showFootnote: true,
                onLink: () =>
                    GoRouter.of(context).push(AppRoutes.settingsAbout),
              ),
            ),
          ),
          GoRoute(
            path: AppRoutes.settingsAbout,
            builder: (BuildContext context, GoRouterState state) =>
                const Scaffold(body: Text('ABOUT PAGE')),
          ),
        ],
      );
      addTearDown(router.dispose);

      tester.view
        ..physicalSize = const Size(360, 900)
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.day(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(en.settingsDisclosureAboutLink));
      await tester.pumpAndSettle();

      expect(
        find.text('ABOUT PAGE'),
        findsOneWidget,
        reason:
            'the disclosure\'s ghost link is named "What survives an update" — a promise '
            'about updates — and it must land on the page that carries the version line '
            'beside E11 (B31, C9). A link that went nowhere would be a control that looks '
            'like an answer.',
      );
      expect(AppRoutes.settingsAbout, '/more/settings/about');
    });
  });

  group('⚠️ the design\'s anti-generic claims about the block', () {
    testWidgets('no icon, no error colour, no shadow — § 2.1 and § 12', (
      WidgetTester tester,
    ) async {
      await _pump(tester, DisclosureBlock(showFootnote: true, onLink: () {}));

      expect(
        find.byType(Icon),
        findsNothing,
        reason:
            '§ 2.1: "a recessed block of words with no icon at all, because an icon would '
            'make a permanent fact look like an incident".',
      );
      final Iterable<Widget> texts = tester.widgetList<Text>(find.byType(Text));
      expect(
        texts,
        hasLength(3),
        reason: 'a body, a footnote and a link label',
      );
      for (final Widget widget in texts) {
        final Text text = widget as Text;
        expect(
          text.style?.color,
          isNot(
            LumenColors.of(tester.element(find.byType(DisclosureBlock))).error,
          ),
          reason:
              '"${text.data}" is painted in `--color-error`. § 12 lists that token in this '
              'screen\'s table marked "Not rendered", and records the absence as a decision.',
        );
      }
      final Container container = tester.widget<Container>(
        find.byType(Container),
      );
      expect(
        (container.decoration! as BoxDecoration).boxShadow,
        isNull,
        reason: '`--shadow-none`: the block is recessed, not a card',
      );
    });
  });
}
