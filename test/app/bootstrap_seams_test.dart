// forge:slice 0-5
// Lumen Tale — the seam audit: **does the real app actually run?**
//
// ## Why this file exists, and why it is a TEST and not a script
//
// `flutter analyze` was clean, `DoD` was **PASS 7 of 7**, and **1 927 tests were green** —
// and the app **threw `UnimplementedError` the first time a reader opened a chapter**.
//
// `chapterReaderRepositoryProvider` is declared
// `throw UnimplementedError('overridden in the composition root')`, and the composition root
// never overrode it. **Every reader test supplies a fake**, so the suite was measuring the
// fake. This is the project's **fifth** instance of one shape:
//
// | # | the shape | what it cost |
// |---|---|---|
// 1 | `3-6`'s absent retry control | a button that did nothing |
// 2 | `3-1`'s `() {}` Add | a button labelled *add this novel* that added nothing |
// 3 | duplicated `registerScreens()` | two copies of a composition root |
// 4 | the catalogue footer's `() {}` Retry | a button that retried nothing |
// 5 | **this one** | **the core screen could not open a chapter** |
//
// ⚠️ **NOTHING ELSE IN THE GATE CAN SEE THIS SHAPE.** The code says exactly what it means, it
// analyzes clean, and the tests pass *because they supply the seam*. A seam every test
// overrides and production does not is a seam that is **tested and absent**.
//
// ⚠️ **SO THE RULE IS MECHANICAL AND TOTAL: every provider whose BODY throws `UnimplementedError`
// is overridden in `lib/main.dart`.** Enumerated by parsing `lib/`, not by remembering —
// because the defect was never "someone forgot", it was "nobody checked".

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every provider in `lib/` whose declaration's body is exactly
/// `(…) => throw UnimplementedError(…)`.
///
/// ⚠️ **THE BODY, NOT THE FILE.** An earlier version of this check grepped each file for the
/// string and reported seventeen names — most of them providers that merely sat near the
/// throw, or whose *dependencies* throw. Ten declarations actually throw, and a check that
/// reports seventeen wrong names is a check people learn to ignore.
Set<String> throwingProviders() {
  final Set<String> names = <String>{};
  for (final File file in Directory(
    'lib',
  ).listSync(recursive: true).whereType<File>()) {
    if (!file.path.endsWith('.dart') || file.path.contains('generated')) {
      continue;
    }
    final String source = file.readAsStringSync();
    final RegExp declaration = RegExp(
      r'final\s+(\w+)\s*=\s*\w*Provider(?:<[^;]*?>)?\s*\(\s*\n?\s*'
      r'\([^)]*\)\s*=>\s*throw\s+UnimplementedError',
    );
    for (final RegExpMatch match in declaration.allMatches(source)) {
      names.add(match.group(1)!);
    }
  }
  return names;
}

String _codeOf(String path) => File(path)
    .readAsStringSync()
    .split('\n')
    .where((String line) => !line.trimLeft().startsWith('//'))
    .join('\n');

/// Every `.dart` under `lib/features/`, comments stripped — the second place a seam may
/// legitimately be overridden, alongside `lib/main.dart`.
String _featureCode() => Directory('lib/features')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File f) => f.path.endsWith('.dart'))
    .map<String>((File f) => _codeOf(f.path))
    .join('\n');

void main() {
  group('the composition root supplies every seam that throws', () {
    test('⚠️ the SCAN FINDS THE SEAMS — a vacuous check would pass everything', () {
      final Set<String> found = throwingProviders();

      expect(
        found,
        isNotEmpty,
        reason:
            'if this is empty the scan is broken, and an empty scan makes every other row '
            'in this file pass for the wrong reason. This project has four guards that '
            'reported success while testing nothing',
      );
      expect(
        found,
        contains('chapterReaderRepositoryProvider'),
        reason:
            'the seam that was missing. Its absence from this set would mean the RegExp no '
            'longer matches the shape it was written for',
      );
    });

    // ⚠️ **THE ROW THAT WOULD HAVE CAUGHT THE CORE SCREEN.** Not a sample, not an
    // enumeration someone chose: every one, by name.
    //
    // ⚠️ **`main.dart` PLUS THE FEATURE THAT OWNS IT — because SCOPING IS LEGITIMATE.**
    // `onboardingRouterProvider` needs a `BuildContext` only an element under the router
    // has, so `OnboardingScreen` overrides it and `main.dart` cannot. The first version of
    // this row demanded `main.dart` specifically and reported that provider as missing —
    // ⚠️ **a rule that demands the wrong place sends you to move a correct override.**
    test('⚠️ EVERY throwing provider is overridden SOMEWHERE REAL', () {
      final String main = _codeOf('lib/main.dart');
      final String features = _featureCode();
      final List<String> missing =
          throwingProviders()
              .where(
                (String name) =>
                    !main.contains('$name.overrideWith') &&
                    !features.contains('$name.overrideWith'),
              )
              .toList()
            ..sort();
      final String listed = missing.map((String n) => '  $n').join('\n');

      expect(
        missing,
        isEmpty,
        reason:
            'these providers THROW unless the composition root overrides them, and every '
            'test supplies its own fake — so the suite measures the fake and production '
            'measures the throw:\n$listed',
      );
    });

    // ⚠️ **AND THE OVERRIDE MUST BE REAL.** A name appearing in a comment is not an
    // override, and a row that counted substrings would have accepted the comment.
    // ⚠️ **`.overrideWith` AS A PREFIX, NOT `overrideWith(`.** `main.dart` overrides the
    // theme preferences with `overrideWithValue(`, which is a real override — and a row
    // demanding the bare `overrideWith(` reported a correctly overridden provider as
    // missing. ⚠️ **A row that fails on correct code trains people to ignore it.**
    test('⚠️ an override is a CALL, not a mention in a comment', () {
      final String code = _codeOf('lib/main.dart') + _featureCode();

      for (final String name in throwingProviders()) {
        expect(
          code,
          contains('$name.overrideWith'),
          reason:
              '$name is mentioned but never overridden with a value. `_codeOf` strips '
              'comment lines precisely so a prose mention cannot satisfy this row',
        );
      }
    });
  });

  group('no control is wired to nothing', () {
    // ⚠️ **THE FIFTH OCCURRENCE, and the row is generic on purpose.** It is not written
    // against `catalogue_screen.dart`; a row that names one screen is a row that is fixed
    // the moment the next dead control appears in another file.
    test('⚠️ NO screen has an EMPTY callback on a control', () {
      final List<String> offenders = <String>[];
      for (final File file in Directory(
        'lib/features',
      ).listSync(recursive: true).whereType<File>()) {
        if (!file.path.endsWith('.dart')) continue;
        final String code = _codeOf(file.path);
        // ⚠️ **`onPressed: null` IS **NOT** IN THIS LIST, and removing it was a correction.**
        // A `null` callback is how Flutter spells *disabled*, and a disabled control with a
        // tooltip saying who owns it is honest — `library_screen.dart` carried one for six
        // slices and the defect was that nobody came back for it, not that it was `null`.
        // ⚠️ **A grep that cannot tell DISABLED from DEAD will eventually demand that a
        // disabled button be made live.** The check for that is `isLoading`, not `null`.
        for (final String pattern in <String>[
          'onPressed: () {}',
          'onTap: () {}',
        ]) {
          if (code.contains(pattern)) offenders.add('${file.path}: $pattern');
        }
      }

      // ⚠️ **THE LIST IS BUILT FIRST, NOT INSIDE THE REASON.** An interpolation that opens
      // a nested string literal cannot be closed, and the fix — hoisting the join out — is
      // also what makes the message readable in a terminal.
      final String listed = offenders.map((String o) => '  $o').join('\n');
      expect(
        offenders,
        isEmpty,
        reason:
            'a control that does nothing. This project has shipped five, and each one '
            'looked finished because the control was present and the label was right:\n'
            '$listed',
      );
    });
  });

  group("the bootstrap's overrides are the ones that matter", () {
    test('⚠️ the reader gets a REAL repository, not a placeholder', () {
      final String main = _codeOf('lib/main.dart');

      expect(
        main,
        contains('LocalChapterReaderRepository('),
        reason:
            'the reader must be built over the real database, the real chapter store and the '
            'real position store. A repository assembled from anything else would pass every '
            'reader test and open the wrong text',
      );
      expect(
        main,
        contains('driftChapterRowLookup('),
        reason:
            'and the row lookup must be the drift one — `getSingleOrNull`, never '
            '`getSingle()`, or a stale deep link becomes an exception instead of a '
            '`ChapterRowGone`',
      );
    });

    // ⚠️ **THE TWO OF A THING ARE NOT ONE OF A THING.** `6-10` hit this with the rate
    // limiter; a reader resolving positions from a different store than the queue writes to
    // would restore an offset against a chapter it has not read.
    test('⚠️ the reader and the queue share ONE chapter store', () {
      final String main = _codeOf('lib/main.dart');

      expect(
        main,
        contains('store: ref.watch(chapterStoreProvider)'),
        reason:
            'the reader reads the file the queue wrote. Two stores would mean two sets of '
            '`downloadedAt` writers and an offset restored against a chapter it has not read',
      );
    });

    // ⚠️ **A SOURCE NAME IS A READER'S WORD, AND `unknown` IS NOT ONE.**
    test(
      '⚠️ the library resolves a source NAME, never the id and never `unknown`',
      () {
        final String main = _codeOf('lib/main.dart');

        expect(
          main,
          contains('sources.byId(sourceId)?.name'),
          reason:
              '`DriftLibraryRepository` defaults `sourceNameOf` to a function returning the '
              'literal `unknown`, and every library row printed it. A default is not an error, '
              'so no linter and no state assertion could see it',
        );
      },
    );
  });
}
