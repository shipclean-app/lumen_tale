// forge:slice 6-7
// Lumen Tale — `6-7` § 3.1 and § 11.2: what happens when the phone's language changes.
//
// ## What is here, and why each row is here
//
// | row | criterion |
// |---|---|
// | a `de-DE` phone resolves to French, and every error message comes back French | § 10.4 |
// | `fr-CA` → `fr`, `en-US` → `en` | § 10.14 |
// | a language change re-renders the labels and keeps the query **and the selection** | § 10.12, E12 |
// | at 200 % type, a failure sentence occupies more than one line and nothing truncates it | § 10.16, C11 |
//
// ## ⚠️ The query field is the CATALOGUE's, and that substitution is deliberate
//
// § 10.12 says *"while the library is open"*, and `library.md` § 5 promises the branch keeps
// *"its scroll offset and its query"*. `lib/features/library/library_screen.dart` is a
// `ConsumerWidget` with **no query field and no selection** — it was written before this
// criterion and has nothing of the sort to keep.
//
// The one query field the product has is `CatalogueQueryField` (`6-2`), which is a
// `StatefulWidget` holding the reader's words and their selection in a controller. The
// criterion's substance is *"a language change is a widget rebuild, not a state reset"*, and
// that is a property of the rebuild rather than of the screen, so the assertion is made where
// the state actually lives. Recorded here because a criterion that silently tests something
// else is a criterion that has stopped meaning what it says.
//
// ## ⚠️ `resolveLocaleForTesting` is `main.dart`'s own function, not a copy
//
// `localized_strings_test.dart` (`0-1`) declares its own `resolveLocaleFor` — a
// re-implementation, which asserts a copy and a copy is free to drift. This file imports the
// exported original instead, so the fallback chain `16-i18n.md` rule 5 names is the one
// under test.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/theme/app_theme.dart';
import 'package:lumen_tale/core/ui/app_error_copy.dart';
import 'package:lumen_tale/features/browse/widgets/catalogue_query_field.dart';
import 'package:lumen_tale/l10n/generated/app_localizations.dart';
import 'package:lumen_tale/main.dart' show resolveLocaleForTesting;

Future<AppLocalizations> l10nOf(Locale locale) =>
    AppLocalizations.delegate.load(locale);

/// What the reader typed, byte for byte.
///
/// B41: `mother  of` has two spaces because the reader pressed the space bar twice, and a
/// query that got trimmed would be a query the site never received. A test that typed
/// `'mother of'` could not tell a byte-preserving field from a normalising one.
const String typedQuery = '  mother  of ';

void main() {
  group('an unrecognised language falls back to French, not to the template', () {
    test('`de-DE` resolves to French', () {
      // § 3.1 branch 3 and § 10.4. ⚠️ NOT to English: `gen-l10n`'s own default fallback
      // is the TEMPLATE file, and `app_en.arb` is the template — so an unprotected reader
      // in Germany would see English with nothing anywhere signalling a mistake.
      // `16-i18n.md` rule 5 makes French the project's primary locale.
      expect(
        resolveLocaleForTesting(const <Locale>[
          Locale('de', 'DE'),
        ], AppLocalizations.supportedLocales),
        const Locale('fr'),
      );
    });

    test('a language this build does not speak resolves to French too', () {
      for (final Locale unsupported in <Locale>[
        const Locale('de'),
        const Locale('ja'),
        const Locale('pt', 'BR'),
        const Locale('ar'),
      ]) {
        expect(
          resolveLocaleForTesting(<Locale>[
            unsupported,
          ], AppLocalizations.supportedLocales),
          const Locale('fr'),
          reason:
              '$unsupported is not supported, and B28 says an unrecognised language '
              'falls back to French — never to the ARB template, which is English',
        );
      }
    });

    test('every failure sentence a `de-DE` reader sees is the French one', () {
      // § 10.4 says "**entirely** in French, **including all error messages**". Resolving
      // the locale is half of it; the other half is that the bundle that resolution
      // produces carries French for the WHOLE failure vocabulary — which is the sentence a
      // reader on a borrowed German phone would read aloud.
      final Locale resolved = resolveLocaleForTesting(const <Locale>[
        Locale('de', 'DE'),
      ], AppLocalizations.supportedLocales);
      final AppLocalizations resolvedL10n = _l10nOrThrow(resolved);
      final AppLocalizations french = _l10nOrThrow(const Locale('fr'));
      final AppLocalizations english = _l10nOrThrow(const Locale('en'));

      expect(resolvedL10n.localeName, 'fr');
      for (final AppErrorString arm in AppErrorString.values) {
        expect(
          resolvedL10n.message(arm),
          french.message(arm),
          reason:
              '${arm.name} must come back in French for a de-DE phone — it is the '
              'sentence the reader would describe to the owner of the phone',
        );
        expect(
          resolvedL10n.message(arm),
          isNot(english.message(arm)),
          reason: '${arm.name} came back in English for a de-DE phone',
        );
      }
    });

    test('no preferred locale at all resolves to French', () {
      // § 3.1 branch 4. `null` and `[]` are different inputs to Flutter and both occur.
      expect(
        resolveLocaleForTesting(null, AppLocalizations.supportedLocales),
        const Locale('fr'),
      );
      expect(
        resolveLocaleForTesting(
          const <Locale>[],
          AppLocalizations.supportedLocales,
        ),
        const Locale('fr'),
      );
    });

    test('`fr-CA` resolves to `fr` and `en-US` to `en`, by language code', () {
      // § 10.14, and § 3.1's note that the match is on the LANGUAGE CODE, not the whole
      // tag: `"fr_CA" != "fr"`, and comparing strings is exactly the mistake that would
      // send a Canadian phone to the English template.
      expect(
        resolveLocaleForTesting(const <Locale>[
          Locale('fr', 'CA'),
        ], AppLocalizations.supportedLocales),
        const Locale('fr'),
      );
      expect(
        resolveLocaleForTesting(const <Locale>[
          Locale('en', 'US'),
        ], AppLocalizations.supportedLocales),
        const Locale('en'),
      );
    });
  });

  group('changing the phone s language re-renders the text and nothing else', () {
    testWidgets('the labels change and the query and its selection survive', (
      WidgetTester tester,
    ) async {
      // E12 / § 10.12: *"the app's text, including every error message, follows the new
      // language, with no loss of library, downloads or progress"* — and `library.md` § 5
      // on the branch that keeps *"its scroll offset and its query"*.
      await tester.pumpWidget(_app(const Locale('fr')));
      expect(find.text('Bibliothèque'), findsOneWidget);

      await tester.enterText(find.byType(TextField), typedQuery);
      await tester.pump();
      final TextEditingController before = _queryController(tester);
      expect(
        before.text,
        typedQuery,
        reason: 'B41 — the words leave byte for byte',
      );

      // A selection the reader made and had not used yet. Losing THIS is the part of E12
      // nothing else covers: the text could survive while the selection did not, and a
      // reader about to replace three words would silently replace nine.
      before.selection = const TextSelection(baseOffset: 2, extentOffset: 9);
      await tester.pump();

      await tester.pumpWidget(_app(const Locale('en')));
      await tester.pump();

      expect(find.text('Library'), findsOneWidget);
      expect(find.text('Bibliothèque'), findsNothing);

      final TextEditingController after = _queryController(tester);
      expect(
        after.text,
        typedQuery,
        reason:
            'E12 — the reader\'s own words are DATA, not copy. A locale change '
            'rebuilds widgets; it does not reset a controller.',
      );
      expect(
        after.selection,
        const TextSelection(baseOffset: 2, extentOffset: 9),
        reason:
            'E12 — the selection is part of what the reader was doing, and '
            '`library.md` § 5 promises the branch keeps its query',
      );
    });

    testWidgets('an error sentence follows the new language on the same rebuild', (
      WidgetTester tester,
    ) async {
      // E12's *"including every error message"*. The error block is a sibling of the
      // labels, so if it lagged one rebuild behind the labels, E12 would be broken in the
      // place the criterion names and a label-only row would not see it.
      await tester.pumpWidget(_appWithFailure(const Locale('fr')));
      expect(find.text(_frSettingsLoad), findsOneWidget);

      await tester.pumpWidget(_appWithFailure(const Locale('en')));
      await tester.pump();

      expect(find.text(_enSettingsLoad), findsOneWidget);
      expect(find.text(_frSettingsLoad), findsNothing);
    });
  });

  group('a failure sentence is a block that grows — C11', () {
    testWidgets('at 200 % it occupies more than one line and truncates nothing', (
      WidgetTester tester,
    ) async {
      // § 10.16 / C11: at 200 % the message "s'étend sur plusieurs lignes dans son bloc
      // et n'est **pas** tronqué". Two halves, and the second is the one that fails in
      // practice: a message that wraps is fine, a message in a one-line banner is not.
      const double scale = 2;
      const double phoneWidth = 320;

      // ⚠️ **Measured from the RENDERED paragraph, and the NUMBERS are kept rather
      // than the render object.** `pumpWidget` with a structurally identical tree reuses
      // the elements, so the `RenderParagraph` returned at 100 % is the *same object* the
      // one at 200 % returns, mutated in place. Held in a variable and read after the second
      // pump, it reports the 200 % height twice and the row below compares a number with
      // itself — which is how "grows in height" can pass while never having been checked.
      await tester.pumpWidget(_failureOnly(const Locale('fr'), 1));
      await tester.pump();
      final double restHeight = _paragraph(tester).size.height;
      final double restLineHeight = _paragraph(tester).preferredLineHeight;

      await tester.pumpWidget(_failureOnly(const Locale('fr'), scale));
      await tester.pump();
      final RenderParagraph enlarged = _paragraph(tester);

      expect(
        _lineCount(enlarged),
        greaterThan(1),
        reason:
            'C11 — at 200 % the message must occupy SEVERAL lines inside its block. '
            'One line at 200 % is a banner, and a banner is what C11 forbids.',
      );
      expect(
        enlarged.size.height,
        greaterThan(restHeight),
        reason:
            'C11 — the block GROWS in height when the type grows. At 100 % this '
            'sentence was $restHeight px tall; at 200 % it is '
            '${enlarged.size.height} px.',
      );
      expect(
        enlarged.preferredLineHeight,
        greaterThan(restLineHeight),
        reason:
            'C11 — and the growth comes from the TYPE, not from more text: one line is '
            '$restLineHeight px at 100 % and ${enlarged.preferredLineHeight} px at 200 %',
      );
      expect(
        enlarged.size.height,
        greaterThan(enlarged.preferredLineHeight),
        reason:
            'C11 — and it is more than one line tall, which is the same claim measured '
            'through the layout rather than through the painter',
      );

      // The truncation half: laid out as a ONE-LINE banner the text WOULD be cut, which is
      // what makes "nothing truncates it" a real requirement rather than a formality.
      final TextPainter asBanner = TextPainter(
        text: TextSpan(
          text: (enlarged.text as TextSpan).text,
          style: enlarged.text.style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: const TextScaler.linear(scale),
        maxLines: 1,
      )..layout(maxWidth: phoneWidth);
      expect(
        asBanner.didExceedMaxLines,
        isTrue,
        reason:
            'witness — if the sentence fitted a one-line banner at 200 %, C11 would '
            'have nothing to protect and the rows above would be theatre',
      );

      final Text text = tester.widget<Text>(find.byType(Text));
      expect(
        text.maxLines,
        isNull,
        reason:
            'C11 — a failure message is a block that grows. `maxLines` on one is a '
            'truncated banner.',
      );
      expect(
        text.overflow,
        isNot(TextOverflow.ellipsis),
        reason:
            'C11 — an ellipsis on a failure message hides the part that says what '
            'survived, which is the half that stops it reading as data loss',
      );
    });
  });
}

/// The `MaterialApp` the language-change rows pump.
///
/// ⚠️ `localeListResolutionCallback` is wired even though these rows pass an explicit
/// `locale`, because that is the production wiring and a harness that leaves it out stops
/// being evidence about the real app.
Widget _app(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: resolveLocaleForTesting,
  theme: AppTheme.day(),
  home: Builder(
    builder: (BuildContext context) => Scaffold(
      body: Column(
        children: <Widget>[
          Text(AppLocalizations.of(context).navLibrary),
          Expanded(
            child: CatalogueQueryField(
              initialWords: typedQuery,
              onSubmitted: (String _) {},
            ),
          ),
        ],
      ),
    ),
  ),
);

/// The same tree plus a failure sentence, for E12's *"including every error message"*.
Widget _appWithFailure(Locale locale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: resolveLocaleForTesting,
  theme: AppTheme.day(),
  home: Builder(
    builder: (BuildContext context) => Scaffold(
      body: Column(
        children: <Widget>[
          Text(AppLocalizations.of(context).navLibrary),
          Text(AppLocalizations.of(context).errorSettingsLoad),
        ],
      ),
    ),
  ),
);

/// The failure sentence alone, at [scale], for the C11 rows.
Widget _failureOnly(Locale locale, double scale) => MaterialApp(
  locale: locale,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  localeListResolutionCallback: resolveLocaleForTesting,
  theme: AppTheme.day(),
  home: Builder(
    builder: (BuildContext context) => Scaffold(
      body: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(scale)),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 320,
            child: Text(AppLocalizations.of(context).errorSettingsLoad),
          ),
        ),
      ),
    ),
  ),
);

/// The reader's controller, read off the rendered field.
///
/// The controller is private inside `_CatalogueQueryFieldState`, and it should be: a test
/// reaching past the widget for it would be asserting an implementation detail. The field's
/// own `TextField` is public API of the widget it builds, which is what a reader's typing
/// actually reaches.
TextEditingController _queryController(WidgetTester tester) =>
    tester.widget<TextField>(find.byType(TextField)).controller!;

/// `errorSettingsLoad` in each language, read from the bundle rather than written here.
///
/// ⚠️ **The string lives in ONE place — the ARB — and these two lines read it.** A test that
/// typed the sentence out would keep passing after the copy changed, and would then be
/// asserting a sentence the product no longer shows: a green row about a string that is gone
/// is worse than no row.
final String _frSettingsLoad = _l10nOrThrow(
  const Locale('fr'),
).errorSettingsLoad;
final String _enSettingsLoad = _l10nOrThrow(
  const Locale('en'),
).errorSettingsLoad;

/// The rendered paragraph behind the failure sentence, with its RESOLVED style.
RenderParagraph _paragraph(WidgetTester tester) =>
    tester.renderObject<RenderParagraph>(
      find.descendant(of: find.byType(Text), matching: find.byType(RichText)),
    );

/// How many visual lines [paragraph] occupies.
///
/// ⚠️ **Counted from the selection boxes, not from the height.** `RenderParagraph` has no
/// public `computeLineMetrics` — the painter's copy is private — and a line count derived
/// from `size.height / preferredLineHeight` is a division that rounds. One box per line, with
/// the tops compared, is the measurement the layout actually made.
int _lineCount(RenderParagraph paragraph) {
  final int length = (paragraph.text as TextSpan).text!.length;
  final List<TextBox> boxes = paragraph.getBoxesForSelection(
    TextSelection(baseOffset: 0, extentOffset: length),
  );
  final Set<double> tops = <double>{};
  for (final TextBox box in boxes) {
    // Rounded to a tenth: a box's top is derived from the line's baseline, and two boxes on
    // the SAME line differ by a sub-pixel rounding that is not a second line.
    tops.add((box.top * 10).roundToDouble() / 10);
  }
  return tops.length;
}

/// The delegate's bundle, loaded synchronously for a row that is not a widget test.
///
/// ⚠️ `test()`, not `testWidgets()`, for every row that goes through here: the delegate's
/// `load` is a `SynchronousFuture`, which is why it is safe under fake async, but a helper
/// that took a `WidgetTester` would invite a real-async caller into a fake-async zone later,
/// and that combination HANGS rather than fails.
AppLocalizations _l10nOrThrow(Locale locale) {
  const List<Locale> supported = AppLocalizations.supportedLocales;
  final bool known = supported.any(
    (Locale candidate) => candidate.languageCode == locale.languageCode,
  );
  if (!known) {
    throw ArgumentError.value(locale, 'locale', 'not one of $supported');
  }
  // `SynchronousFuture` completes synchronously, so `then` has already run by the time
  // this line returns — which is what lets a non-widget row read the bundle at all.
  AppLocalizations? loaded;
  AppLocalizations.delegate.load(locale).then((AppLocalizations value) {
    loaded = value;
  });
  return loaded!;
}
