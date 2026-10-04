// forge:slice 3-4
// Lumen Tale — `3-4` § 10, the acceptance criteria that are **commands**.
//
// ## ⚠️ WHY THESE ARE GREPS AND WHY COMMENTS ARE STRIPPED
//
// Four of `§ 10`'s criteria are written as shell commands over `lib/`:
// `grep -rn 'textH1' lib/`, `grep -rn 'download\|Download' lib/features/onboarding/`,
// `grep -rn 'dio\|Dio\|http' …`, `grep -rn 'requestPermission\|POST_NOTIFICATIONS' …`.
//
// Each of them is a claim about **code that must be absent**, and every one of them is
// satisfied by writing nothing — which is the easiest kind of criterion to make permanent by
// accident. Two things make these rows honest:
//
//   * **comments are stripped.** A prohibition discussed in a doc comment must not trip its
//     own grep, and a grep that counted its own prohibition would report a permanent red for
//     correct code — the exact trap `app_shell_test.dart`'s `_isComment` documents. The
//     exclusion is line-based and narrow: a line whose first non-space characters open a
//     comment. A prohibition therefore cannot hide a **use**, because a use sits on code.
//   * **each pattern carries a WITNESS** — a string that must match it — so a broken regex
//     fails loudly instead of reporting a permanent green.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every `.dart` file under [relativeDir], sorted so a failure is reproducible.
List<File> dartFilesIn(String relativeDir) {
  final Directory dir = Directory(relativeDir);
  expect(
    dir.existsSync(),
    isTrue,
    reason:
        '$relativeDir must exist — a grep over a missing directory is a grep over nothing, '
        'which is a permanent green',
  );
  final List<File> files =
      dir
          .listSync(recursive: true)
          .whereType<File>()
          .where((File f) => f.path.endsWith('.dart'))
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  expect(files, isNotEmpty, reason: 'and there must be files to read in it');
  return files;
}

/// Whether the line at [lineNumber] of [file] is **wholly** a comment.
///
/// ⚠️ **WHOLE LINES ONLY, AND A TRAILING COMMENT IS NOT ONE.** `foo(); // mentions download`
/// is still a hit, which is deliberate: a symbol name in a trailing comment is how a grep
/// finds a real use. The exclusion exists for a different problem — a prohibition discussed
/// in a doc comment must not trip its own grep, because a grep that counted its own
/// prohibition would report a permanent red for correct code.
bool _isComment(File file, int lineNumber) {
  final List<String> lines = file.readAsStringSync().split('\n');
  if (lineNumber > lines.length) {
    return false;
  }
  final String line = lines[lineNumber - 1].trimLeft();
  return line.startsWith('//') || line.startsWith('*') || line.startsWith('/*');
}

/// Every **executable** line in [files] matching [pattern], as `path:line`.
List<String> grepCode(List<File> files, RegExp pattern) {
  final List<String> hits = <String>[];
  for (final File file in files) {
    final List<String> lines = file.readAsStringSync().split('\n');
    for (var i = 0; i < lines.length; i++) {
      if (pattern.hasMatch(lines[i]) && !_isComment(file, i + 1)) {
        hits.add('${file.path}:${i + 1}: ${lines[i].trim()}');
      }
    }
  }
  return hits;
}

void main() {
  group('§ 10 — the greps that are acceptance criteria', () {
    test('⚠️ B7: `textH1` appears ONLY under features/onboarding', () {
      // ⚠️ **THE ROW THAT MAKES "THE ONLY `--text-h1` IN THE APP" CHECKABLE.**
      //
      // `onboarding.md` § 2: the promise is *"the only screen in the app that uses
      // `--text-h1`"*. A grep that returned a hit in `app/theme/` would mean the token is a
      // global one with a single consumer — which is a token the next screen that needs "a
      // big heading" re-derives differently, and then there are two truths about the size of
      // a page title.
      final List<File> files = dartFilesIn('lib');
      final List<String> hits = grepCode(files, RegExp('textH1'));

      expect(
        hits.every((String hit) => hit.startsWith('lib/features/onboarding/')),
        isTrue,
        reason:
            '`--text-h1` is this screen\'s alone. A hit outside '
            '`lib/features/onboarding/` means a second place sizes a headline: $hits',
      );
      expect(
        hits,
        isNotEmpty,
        reason:
            'the promise MUST be set at it — a row that finds nothing is a dead grep',
      );

      // And the witness, because a regex that cannot match would report a permanent green.
      expect(
        RegExp(
          'textH1',
        ).hasMatch('static const TextStyle textH1 = TextStyle();'),
        isTrue,
        reason: 'the pattern must match a real declaration of the token',
      );
    });

    test('⚠️ B32: `download` in the feature is COPY only, never a queue or a store', () {
      // ⚠️ **THIS SLICE *TALKS* ABOUT STORAGE AND MANAGES NONE.** The disclosure names the
      // downloads because B32 creates a loss nothing can repair — and a `DownloadQueue` or a
      // `DownloadRepository` reaching this feature would make a screen with the least data in
      // the product read the most.
      final List<String> hits = grepCode(
        dartFilesIn('lib/features/onboarding'),
        RegExp('download', caseSensitive: false),
      );
      expect(
        hits,
        isEmpty,
        reason:
            'the word may appear in a comment and in ARB keys; on an executable line it '
            'would be a call. Found: $hits',
      );
      expect(
        RegExp(
          'download',
          caseSensitive: false,
        ).hasMatch('await downloadQueue.enqueue(chapter);'),
        isTrue,
        reason: 'the witness: a real queue call must be caught by this pattern',
      );
    });

    test(
      '⚠️ C14: no `dio`, no `Dio`, no `http` anywhere in the feature or the store',
      () {
        // ⚠️ **`dio` IS MATCHED AS A WORD, NOT A SUBSTRING.** The plan's command is
        // `grep -rn 'dio\|Dio\|http'` and a bare substring would match "radio", "studio" and
        // "http" inside a URL in a comment. Matched case-insensitively as a whole word, this
        // catches the imports and the client and nothing else.
        final List<File> files = <File>[
          ...dartFilesIn('lib/features/onboarding'),
          ...<File>[File('lib/core/storage/onboarding_seen.dart')],
        ];
        expect(
          files.where((File f) => !f.existsSync()),
          isEmpty,
          reason: 'the flag store must exist at the path the criterion names',
        );

        final List<String> hits = grepCode(
          files,
          RegExp('\\b(?:dio|https?)\\b', caseSensitive: false),
        );
        expect(
          hits,
          isEmpty,
          reason:
              '§ 8 C14: the first thing this app says about itself is that it works with the '
              'connection off, and an onboarding screen that needed a connection would be an '
              'embarrassment as well as a defect. Found: $hits',
        );
        expect(
          RegExp(
            '\\b(?:dio|https?)\\b',
            caseSensitive: false,
          ).hasMatch("import 'package:dio/dio.dart';"),
          isTrue,
          reason:
              'the witness: the pattern must catch the import it exists to forbid',
        );
      },
    );

    test('⚠️ ADR-023: no permission request, at any point, on this screen', () {
      // § 7: *"A screen of permissions here would be a lie about what the application needs
      // to read a novel."* B35 was withdrawn, so there is no schedule whose first firing
      // would need a grant — and on Android 13+ a request shown before its context is a
      // request the reader is primed to refuse.
      final List<String> hits = grepCode(
        dartFilesIn('lib/features/onboarding'),
        RegExp(
          'requestPermission|POST_NOTIFICATIONS|permission_handler|Permission\\.',
          caseSensitive: false,
        ),
      );
      expect(hits, isEmpty, reason: 'found: $hits');
      expect(
        RegExp(
          'requestPermission',
          caseSensitive: false,
        ).hasMatch('await requestPermission(Permission.notification);'),
        isTrue,
        reason: 'the witness: the pattern must catch a real permission request',
      );
    });

    test('⚠️ 02-architecture: no import of `features/settings/` from here', () {
      // ⚠️ **ALSO A GATE, AND IT IS ASSERTED TWICE ON PURPOSE.** `tool/check_boundaries.py`
      // catches *every* cross-feature import; this row names the one `3-4` was most likely
      // to commit — importing the Settings screen's `DisclosureBlock` or its navigation to
      // render the same idiom, which `DisclosureBlock`'s own header explains is why it does
      // not.
      final List<String> hits = grepCode(
        dartFilesIn('lib/features/onboarding'),
        RegExp('package:lumen_tale/features/(?!onboarding/)'),
      );
      expect(
        hits,
        isEmpty,
        reason:
            '`features/*` communicates through `app/` and shared providers, never by '
            'importing each other. Found: $hits',
      );
    });

    test('⚠️ § 2.1: no `PageView` and no horizontal pager machinery', () {
      final List<String> hits = grepCode(
        dartFilesIn('lib/features/onboarding'),
        RegExp('\\bPageView\\b|\\bPageRoute\\b|\\bPageController\\b'),
      );
      expect(
        hits,
        isEmpty,
        reason:
            '§ 2.1 decision 1: the steps advance by buttons. A pager fights Android\'s back '
            'gesture, and a reader swiping back from step 2 expects to leave the app. '
            'Found: $hits',
      );
    });

    test('the feature imports no package the app does not already depend on', () {
      // ⚠️ **`17-security.md` rule 12, CHECKED WHERE A NEW DEPENDENCY WOULD APPEAR.** A new
      // third-party import in a feature is how `AGENTS.md`'s banned list gets re-opened
      // without anybody editing `pubspec.yaml` — and the boundary is the natural place to
      // notice, because a feature's imports are its whole dependency surface.
      const Set<String> allowed = <String>{
        'package:flutter/material.dart',
        'package:flutter/semantics.dart',
        'package:flutter_riverpod/flutter_riverpod.dart',
        'package:go_router/go_router.dart',
        'package:shared_preferences/shared_preferences.dart',
      };
      final List<String> foreign = <String>[];
      for (final File file in dartFilesIn('lib/features/onboarding')) {
        for (final Match match in RegExp(
          r"^import\s+'([^']+)'",
        ).allMatches(file.readAsStringSync())) {
          final String uri = match.group(1)!;
          if (uri.startsWith('package:lumen_tale/') ||
              uri.startsWith('dart:') ||
              allowed.contains(uri)) {
            continue;
          }
          foreign.add('${file.path}: $uri');
        }
      }
      expect(
        foreign,
        isEmpty,
        reason:
            'this slice adds no dependency, so it must import no package the project does '
            'not already have. Found: $foreign',
      );
    });
  });
}
