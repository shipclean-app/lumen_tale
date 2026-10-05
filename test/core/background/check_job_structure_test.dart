// forge:slice 6-10
// Lumen Tale — the rows that are greps, because they are claims about *where* code lives.
//
// ## ⚠️ WHY SO MANY GREPS RATHER THAN BEHAVIOUR
//
// `6-10` § 10 has rows that are not observable at runtime on a host: no
// `registerPeriodicTask` anywhere, the composition root's ordering, the manifest's contents,
// `gradle.properties`, and "the three Check buttons use the same controller". Each is a fact
// about the repository's *text*, and each would pass vacuously if written as a line match —
// `dart format` breaks a call across three lines, so a grep for two tokens on one line finds
// nothing and reports success. Comments are stripped first.
//
// ## ⚠️ AND EVERY LIST BELOW IS ASSERTED NON-EMPTY
//
// A guard over "files that happen to mention X" matches nothing today for half of these and
// passes for the wrong reason — the shape a structural row has already taken in this project.
// Each row therefore names the files it expects to find, so an empty input fails.
//
// | rule | the row |
// |---|---|
// | **ADR-023** | no `registerPeriodicTask` anywhere in `lib/` |
// | **B36** | `main()` initialises the engine **before** `runApp` and registers nothing |
// | **B36** | `start()` on the in-process check has exactly one call site |
// | **B37** | exactly one `CheckJobController` is declared, in `data/` |
// | **C3** | the plugin is imported by two files, both outside `domain/` and `features/` |
// | **B28** | no English notification literal in `core/background/` |
// | **B37** | the merged manifest's inputs: `POST_NOTIFICATIONS` present, `DATA_SYNC` absent |

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'code_grep.dart';

/// The lines of [path] carrying [needle], as `path:line`.
///
/// ⚠️ **LINE NUMBERS ARE REPORTED SO A FAILURE POINTS AT SOMETHING.** A guard whose output
/// is wrong is a guard nobody trusts when it fires.
List<String> linesWith(String path, String needle) => <(int, String)>[
  for (final (int line, String text) in codeLinesWithNumbers(path))
    if (text.contains(needle)) (line, text),
].map(((int, String) record) => '$path:${record.$1}').toList(growable: false);

/// The body of a file in an installed package, resolved through `package_config.json`.
///
/// ⚠️ **RESOLVED, NOT GUESSED.** A pub cache lives in `$PUB_CACHE`, in `~/.pub-cache`, or
/// wherever CI puts it, so the path comes from the file the Dart tool wrote. The trailing
/// slash matters: `Uri.resolve` treats a base without one as a file, which eats the version
/// segment and makes a missing package read as a moved file.
String packageFile(String package, String relative) {
  final File config = File('.dart_tool/package_config.json');
  final Map<String, Object?> packages =
      json.decode(config.readAsStringSync()) as Map<String, Object?>;
  final Map<String, Object?> entry = (packages['packages']! as List<Object?>)
      .cast<Map<String, Object?>>()
      .firstWhere((Map<String, Object?> p) => p['name'] == package);
  final String root = entry['rootUri']! as String;
  final Uri base = Uri.parse(root).hasScheme
      ? Uri.parse(root.endsWith('/') ? root : '$root/')
      : config.absolute.uri.resolve(root);
  return File.fromUri(base.resolve(relative)).readAsStringSync();
}

/// An XML document with its `<!-- … -->` comments removed.
///
/// ⚠️ **EXISTS BECAUSE THIS SLICE EXPLAINS ITSELF IN THE MANIFEST.** The comment above
/// `POST_NOTIFICATIONS` names `FOREGROUND_SERVICE_DATA_SYNC` to say it is *not* declared —
/// and a grep that read comments would fail on that explanation, at which point the
/// tempting fix is to weaken the pattern until it proves nothing.
String _withoutXmlComments(String xml) =>
    xml.replaceAll(RegExp(r'<!--[\s\S]*?-->'), '');

void main() {
  group('ADR-023 — there is no schedule in any version', () {
    test('no file in lib/ mentions registerPeriodicTask', () {
      final List<File> files = dartFilesIn('lib').toList();
      expect(
        files.length,
        greaterThan(20),
        reason:
            'the loop must have something to read; an empty or tiny list would make this '
            'row pass for the wrong reason',
      );
      for (final File file in files) {
        expect(
          linesWith(file.path, 'registerPeriodicTask'),
          isEmpty,
          reason:
              'ADR-023 withdrew B35: there is no interval picker and therefore no schedule. '
              'A periodic task here would check the library on a timer the reader never '
              'chose — B36, with B38 traffic cost and no dialog',
        );
      }
    });

    test('the request type has no frequency, no delay and no expedited', () {
      final String engine = codeOf('lib/core/background/check_job_engine.dart');
      for (final String forbidden in <String>[
        'initialDelay',
        'frequency',
        'expedited',
        'cancelAll',
      ]) {
        expect(
          engine,
          isNot(contains(forbidden)),
          reason:
              'a field on the seam would make a schedule or a global cancel expressible, and '
              '§ 7 forbids both. Their absence is the rule; a comment saying so is not',
        );
      }
    });
  });

  group('B36 — the composition root starts nothing', () {
    test('main() initialises the background engine BEFORE runApp', () {
      final List<String> main = codeOf('lib/main.dart').split('\n');
      final int init = main.indexWhere(
        (String l) => l.contains('initializeBackgroundCheckEngine'),
      );
      final int cleanup = main.indexWhere(
        (String l) => l.contains('releaseStaleCheckJobFlag'),
      );
      final int runApp = main.indexWhere((String l) => l.contains('runApp('));

      expect(
        init,
        greaterThan(-1),
        reason: 'the engine must be initialised at all',
      );
      expect(
        cleanup,
        greaterThan(-1),
        reason: '§ 3.3 branches 7 and 8: the stale flag is cleared at start-up',
      );
      expect(runApp, greaterThan(-1), reason: 'precondition: the app starts');
      expect(
        init,
        lessThan(runApp),
        reason:
            '§ 3.5: executeTask registers its handlers on the isolate messenger and the '
            'platform calls the dispatcher afterwards, so in the other order the first '
            'task runs before the handlers exist',
      );
      expect(
        cleanup,
        lessThan(runApp),
        reason:
            'a flag left by a killed isolate must be released before the first frame, so '
            'the reader first tap is not refused with no explanation (B36, C8)',
      );
    });

    test('main() registers no work at all', () {
      for (final String forbidden in <String>[
        'registerOneOffTask',
        'registerPeriodicTask',
      ]) {
        expect(
          linesWith('lib/main.dart', forbidden),
          isEmpty,
          reason:
              '§ 3.5: the only caller of registerOneOffTask in the whole code base is '
              'start(). A registration in the composition root would make opening the app '
              'a trigger, which is B36',
        );
      }
    });

    test('start() on the in-process check has exactly ONE call site', () {
      // ⚠️ **THE FILE IS THE UNIT, NOT THE LINE.** `dart format` breaks
      // `ref.read(libraryCheckProvider.notifier).start()` across three lines, so a
      // line-based match finds nothing and passes vacuously — the strongest form this
      // defect takes.
      final List<String> sites = <String>[
        for (final File file in dartFilesIn('lib'))
          if (codeOf(file.path).contains('libraryCheckProvider'))
            ...linesWith(file.path, '.start()'),
      ];
      expect(
        sites,
        <String>['lib/data/background/check_job_providers.dart:89'],
        reason:
            'B36: the in-process pass starts from ONE place — § 3.4 fallback, which is a '
            'reader tap whose foreground job could not be registered. A screen, a lifecycle '
            'hook or a build clause appearing here would be a pass nobody asked for. The '
            'line number is asserted too, so an index into a stripped list cannot report a '
            'line that means nothing',
      );
    });

    // ⚠️ **THIS ROW WAS "NO FEATURE MAY MENTION IT", AND THAT WAS STRICTER THAN ITS OWN
    // RULE — the same mistake its sibling row was corrected for, in the file next door.**
    //
    // § 4.3's mapping is the opposite of an entry point: `updates.md`, `library.md` and
    // `settings.md` **read** the provider, because a button must be *disabled while a pass
    // runs* and that is the only place the state is. Forbidding the mention forbade the
    // documented mapping in order to prevent a call — and it did not prevent the call: the
    // library's first wiring called `libraryCheckProvider.notifier.start()` directly and was
    // caught by a **different** row, one file over.
    //
    // ⚠️ **THE RULE IS THE CALL, NOT THE MENTION.** No feature may START the in-process pass;
    // reading its state is required. Two implementations of a rule SC-3 depends on diverge
    // invisibly, and `start()` is the implementation.
    test('no feature STARTS the in-process pass', () {
      for (final File file in dartFilesIn('lib/features')) {
        expect(
          linesWith(file.path, 'libraryCheckProvider.notifier'),
          isEmpty,
          reason:
              '§ 3.4: the in-process pass is reached only through the fallback seam in '
              'data/, which registers a foreground job first. A screen that calls '
              '`start()` is a second entry point. READING the provider is required — a '
              'button must be disabled while a pass runs — so the mention itself is not '
              'the violation',
        );
      }
    });
  });

  group('B37 — one controller, three buttons', () {
    test('exactly one CheckJobController provider is declared, and it is in data/', () {
      final List<String> declarations = <String>[
        for (final File file in dartFilesIn('lib'))
          ...linesWith(file.path, 'Provider<CheckJobController>'),
      ];
      expect(
        declarations,
        <String>['lib/data/background/check_job_providers.dart:95'],
        reason:
            '§ 10: the three Check buttons of library.md, updates.md and settings.md call '
            'the SAME controller. One declaration makes two passes impossible by '
            'construction rather than by discipline — and it lives in data/ because a '
            'shared provider in a feature is F-018 again: three screens read this one',
      );
    });

    test('no feature declares a second way to start a pass', () {
      final List<String> offenders = <String>[
        for (final File file in dartFilesIn('lib/features'))
          if (codeOf(file.path).contains('registerOneOffTask') ||
              codeOf(file.path).contains('DriftCheckLibrary'))
            file.path,
      ];
      expect(
        offenders,
        isEmpty,
        reason:
            'the check is reached through CheckJobController or not at all. A screen that '
            'built the interactor would be a second entry point into B37 — and § 4.2 puts '
            'the plugin behind core/ precisely so no widget can reach it',
      );
    });
  });

  group('C3 — the plugin is confined, and domain stays pure', () {
    test('exactly two files import package:workmanager', () {
      final List<String> importers = <String>[
        for (final File file in dartFilesIn('lib'))
          if (codeOf(
            file.path,
          ).contains('package:workmanager/workmanager.dart'))
            file.path,
      ]..sort();
      expect(
        importers,
        <String>[
          'lib/core/background/workmanager_check_job_engine.dart',
          'lib/data/background/check_job_entry_point.dart',
        ],
        reason:
            '§ 2.2: the only place in the repository that imports workmanager. It is two '
            'files rather than one, and the split is mechanical: core may not import data, '
            'and the dispatcher has to build AppDatabase, SourceManager and '
            'DriftCheckLibrary to run the pass. The translation of a request into a plugin '
            'call stays in core; the assembly of the isolate stays in data',
      );
    });

    test('domain/ imports no Flutter UI, no plugin and no drift', () {
      final List<File> domain = dartFilesIn('lib/domain').toList();
      expect(
        domain.length,
        greaterThan(10),
        reason: 'precondition: the loop below must have files to read',
      );
      for (final File file in domain) {
        final String code = codeOf(file.path);
        for (final String forbidden in <String>[
          // ⚠️ **`flutter/foundation` IS DELIBERATELY NOT IN THIS LIST.**
          // `02-architecture.md` allows it "only where strictly needed", and
          // `lib/domain/sources/http_fetching.dart` needs it for `@protected`. Forbidding it
          // would fail a row against a file this slice did not touch and cannot fix —
          // and a row that fails for an unrelated reason is a row nobody reads.
          'package:flutter/material',
          'package:flutter/widgets',
          // ⚠️ **`flutter/services` IS THE DOOR `workmanager` OPENS INTO `domain`.** Its
          // re-exported Pigeon surface imports it, which is the whole reason
          // `check_stop_reason.dart` declares its own enum.
          'package:flutter/services',
          'package:workmanager',
          'package:drift',
        ]) {
          expect(
            code,
            isNot(contains(forbidden)),
            reason:
                '`02-architecture.md`: domain is the pure layer, and § 1 is the reason it '
                'must stay pure — CheckLibrary runs in the main isolate AND in the '
                'background one. ${file.path} reaching $forbidden would make the foreground '
                'job impossible to build',
          );
        }
      }
    });

    test('features/ imports no plugin', () {
      for (final File file in dartFilesIn('lib/features')) {
        expect(
          codeOf(file.path),
          isNot(contains('package:workmanager')),
          reason:
              'C3 and `02-architecture.md`: workmanager is an external plugin and only '
              'core may depend on one. A widget reaching it would put a platform call in a '
              'build method',
        );
      }
    });
  });

  group('B28 — no English literal for a system surface', () {
    test('the notification strings exist only as ARB keys', () {
      for (final String literal in <String>[
        'Checking your library',
        'Library checks',
        'Check for new chapters',
      ]) {
        final List<String> hits = <String>[
          for (final File file in dartFilesIn('lib/core/background'))
            if (codeOf(file.path).contains(literal)) file.path,
        ];
        expect(
          hits,
          isEmpty,
          reason:
              'B28 / § 11.3: the notification text is resolved by AppLocalizations in both '
              'languages. A literal in core/background/ would be an English sentence in a '
              'French application — and this one is drawn on a locked screen',
        );
      }
    });

    test('the ARB does carry the notification strings, in both languages', () {
      for (final String arb in <String>[
        'lib/l10n/app_en.arb',
        'lib/l10n/app_fr.arb',
      ]) {
        final String body = File(arb).readAsStringSync();
        for (final String key in <String>[
          'checkNotificationTitle',
          'checkNotificationChannelName',
        ]) {
          expect(
            body,
            contains('"$key"'),
            reason:
                '`6-7` owns the notification strings and both locales must carry the key; a '
                'missing one is a crash in the locale that lacks it',
          );
        }
      }
    });
  });

  group('§ 4.5 — the platform declaration, and its merged inputs', () {
    test('POST_NOTIFICATIONS is in the main manifest', () {
      expect(
        File('android/app/src/main/AndroidManifest.xml').readAsStringSync(),
        contains('android.permission.POST_NOTIFICATIONS'),
        reason:
            '§ 4.5: added into the manifest element. Without it Android 13+ shows no '
            'notification at all and B37 visible is unreachable on a modern phone',
      );
    });

    test('FOREGROUND_SERVICE_DATA_SYNC is absent from OUR manifests', () {
      for (final String manifest in <String>[
        'android/app/src/main/AndroidManifest.xml',
        'android/app/src/debug/AndroidManifest.xml',
        'android/app/src/profile/AndroidManifest.xml',
      ]) {
        final File file = File(manifest);
        if (!file.existsSync()) {
          continue;
        }
        expect(
          _withoutXmlComments(file.readAsStringSync()),
          isNot(contains('FOREGROUND_SERVICE_DATA_SYNC')),
          reason:
              '§ 7: dataSync is opt-in and requires '
              'workmanager.enableDataSyncForegroundService=true; the app asks for '
              'shortService. Declaring the permission would declare a capability the '
              'manifest merger cannot justify. XML comments are stripped first, because '
              'this slice explains the absence in one and a grep that read it would fail '
              'on its own documentation',
        );
      }
    });

    test('gradle.properties does not enable the dataSync foreground service', () {
      expect(
        File('android/gradle.properties').readAsStringSync(),
        isNot(contains('workmanager.enableDataSyncForegroundService')),
        reason:
            '§ 4.5: NOTHING TO ADD, and in particular not this property. Setting it swaps '
            "in workmanager_android's opt-in manifest, which declares "
            'FOREGROUND_SERVICE_DATA_SYNC — a Play Console special type the app would have '
            'to declare and demonstrate for a service it never starts',
      );
    });

    test(
      "the plugin's own manifest declares the two permissions shortService needs",
      () {
        // ⚠️ **THE MERGED MANIFEST CANNOT BE READ HERE, SO ITS INPUTS ARE.**
        //
        // § 10 asks for two things about the merged manifest: that it contains
        // POST_NOTIFICATIONS, FOREGROUND_SERVICE and FOREGROUND_SERVICE_SHORT_SERVICE, and
        // that it does **not** contain FOREGROUND_SERVICE_DATA_SYNC. Proving the merge
        // needs `flutter build apk` and a device — Q-008. What CI can prove is every
        // *input* to the merge: our manifest (the rows above) and the plugin's, which is
        // where the two foreground-service permissions come from. Declaring them in our own
        // manifest as well would be a second list of permissions — a second source of truth
        // about what the plugin requires.
        final String plugin = packageFile(
          'workmanager_android',
          'android/src/main/AndroidManifest.xml',
        );
        for (final String permission in <String>[
          'FOREGROUND_SERVICE',
          'FOREGROUND_SERVICE_SHORT_SERVICE',
        ]) {
          expect(
            plugin,
            contains('android.permission.$permission'),
            reason:
                '§ 4.5: workmanager already declares FOREGROUND_SERVICE and '
                'FOREGROUND_SERVICE_SHORT_SERVICE in ITS own manifest and the merger folds '
                'them into ours. If the plugin stopped declaring $permission, this app '
                'shortService foreground job would throw IllegalStateException at runtime',
          );
        }
        expect(
          plugin,
          isNot(
            contains(
              'uses-permission android:name="android.permission.FOREGROUND_SERVICE_DATA_SYNC"',
            ),
          ),
          reason:
              'and it declares the dataSync permission only behind the opt-in property '
              'that § 7 forbids this project from setting',
        );
      },
    );
  });

  group('§ 3.5 — the dispatcher is named, and it fails loudly', () {
    test('the dispatcher is top-level and carries the vm:entry-point pragma', () {
      final String entry = codeOf(
        'lib/data/background/check_job_entry_point.dart',
      );
      expect(
        entry,
        contains("@pragma('vm:entry-point')"),
        reason:
            'workmanager invokes the dispatcher BY NAME from a fresh engine; a method or a '
            'closure would be tree-shaken and the name would not exist at runtime',
      );
      expect(
        entry,
        contains('void checkJobCallbackDispatcher()'),
        reason:
            'and it must be a top-level function, not a method — the platform holds a '
            'Function tear-off it invokes by name',
      );
    });

    test('the dispatch switch throws for an unknown task', () {
      final String entry = codeOf(
        'lib/data/background/check_job_entry_point.dart',
      );
      expect(
        entry,
        contains('throw UnimplementedError'),
        reason:
            '§ 2.2 and `13-error-handling.md` rule 4: a switch whose default ran the check '
            'would mean any future task through this plugin silently checks the reader '
            'library — B36 and C7, with a plausible-looking result',
      );
      expect(
        entry,
        contains('unknown workmanager task'),
        reason:
            'the message names the offending task, so a failure in the field says what '
            'arrived rather than only that something did',
      );
    });

    test('onTaskStopped filters by task name', () {
      final String entry = codeOf(
        'lib/data/background/check_job_entry_point.dart',
      );
      expect(
        entry,
        contains('taskName != checkJobTaskName'),
        reason:
            'the plugin delivers the stopped callback for every task it runs. Reacting to '
            'another task stop by releasing OUR flag would clear the interlock while a check '
            'was still running',
      );
    });
  });
}
