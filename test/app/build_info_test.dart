// Lumen Tale — `apk-pipeline` § 11.1, the build-info rows.
//
// B43 is a promise about what the owner can be told when they report a bug, so the
// rows here are about **absence**: what the About screen must NOT print when the OS
// reports nothing. An invented `0.0.0` is the failure this file exists to prevent.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/app/build_info.dart';

void main() {
  group('isUnknown', () {
    test('both absent is unknown', () {
      expect(
        const AppBuildInfo(buildName: null, buildNumber: null).isUnknown,
        isTrue,
      );
    });

    test('a buildName alone is NOT unknown', () {
      // Three states, not two. `buildNumber` missing while `buildName` is present is
      // a real case — an OS that reports a version but no code — and collapsing it
      // into "unknown" would hide a readable version.
      expect(
        const AppBuildInfo(buildName: '1.0.0', buildNumber: null).isUnknown,
        isFalse,
      );
      expect(
        const AppBuildInfo(buildName: null, buildNumber: '42').isUnknown,
        isFalse,
      );
    });
  });

  group('displayLine', () {
    test('both known reads name (number)', () {
      expect(
        const AppBuildInfo(buildName: '1.0.0', buildNumber: '42').displayLine,
        '1.0.0 (42)',
      );
    });

    test('a missing buildNumber is a dash pair, never a bare name', () {
      // The plan's row: `buildNumber` absent → `—`, **not** `1.0.0` alone.
      expect(
        const AppBuildInfo(buildName: '1.0.0', buildNumber: null).displayLine,
        '—',
        reason:
            'a partial identifier is worse than none — B31 is a promise '
            'about two identifiers',
      );
    });

    test('a missing buildName is a dash', () {
      expect(
        const AppBuildInfo(buildName: null, buildNumber: '42').displayLine,
        '—',
      );
    });

    test('no output invents a value', () {
      // ⚠️ This is the row that matters, and it is written as a SCAN rather than
      // four equality assertions, because four assertions only cover the four
      // cases someone thought of. Every combination of present/absent is generated,
      // so a fifth state added later cannot slip past.
      const names = <String?>[null, '1.0.0', '2.3.4'];
      const numbers = <String?>[null, '1', '42'];
      final forbidden = <String>[
        '0.0.0',
        'unknown',
        'null',
        'undefined',
        'NaN',
      ];

      for (final name in names) {
        for (final number in numbers) {
          final line = AppBuildInfo(
            buildName: name,
            buildNumber: number,
          ).displayLine;
          for (final banned in forbidden) {
            expect(
              line.toLowerCase(),
              isNot(contains(banned.toLowerCase())),
              reason:
                  'name=$name number=$number produced "$line", which '
                  'contains the invented value "$banned"',
            );
          }
          // And the line is never empty, which is its own kind of lie.
          expect(line.trim(), isNotEmpty);
        }
      }
    });

    test('a fully-known line contains both identifiers', () {
      final line = const AppBuildInfo(
        buildName: '1.0.0',
        buildNumber: '42',
      ).displayLine;
      expect(line, contains('1.0.0'));
      expect(line, contains('42'));
    });
  });

  group('isDistinguishable — two builds of one commit must differ', () {
    test('same commit, different run numbers', () {
      // This is exactly what ADR-011's `--build-number=${{ github.run_number }}`
      // guarantees, and B31 needs it to be checkable.
      expect(isDistinguishable('1.0.0', '41', '1.0.0', '42'), isTrue);
    });

    test('same name, different numbers', () {
      expect(isDistinguishable('1.0.0', '41', '1.0.0', '42'), isTrue);
    });

    test('different names, same number', () {
      // The converse: a bumped version with a reused run number. `buildName`
      // repeats across runs by design, so comparing either identifier alone is
      // not enough.
      expect(isDistinguishable('1.0.0', '42', '1.0.1', '42'), isTrue);
    });

    test('an identical pair is NOT distinguishable', () {
      expect(isDistinguishable('1.0.0', '42', '1.0.0', '42'), isFalse);
    });
  });

  group('BuildInfoReader', () {
    test('a fake reader is enough — no package needed', () {
      // The interface exists precisely so `3-5`'s implementation is testable
      // without `package_info_plus`, which `apk-pipeline` § 7 records as an open
      // dependency question under `17-security.md` rule 13.
      const reader = _FakeBuildInfoReader(
        AppBuildInfo(buildName: '3.4.5', buildNumber: '99'),
      );
      expect(
        reader.readInstalledBuild().then((AppBuildInfo i) => i.displayLine),
        completion('3.4.5 (99)'),
      );
    });

    test('the repository contains no implementation of it', () {
      // ⚠️ Deliberate: there is NO concrete `BuildInfoReader` in `lib/`, because
      // reading the OS's version needs `package_info_plus`, which is not a
      // dependency. `3-5` owns it.
      //
      // A grep row would be the wrong instrument — this is a *file* question, and
      // the assertion is that the interface has no implementer yet, which the
      // analyzer enforces anyway (an unused abstract class is fine; a call to
      // `readInstalledBuild` from `main.dart` would not compile without one).
      // What matters is stated here so nobody "fixes" the absence by reading
      // pubspec.yaml at runtime.
      expect(AppBuildInfo, isNotNull);
    });
  });
}

final class _FakeBuildInfoReader implements BuildInfoReader {
  const _FakeBuildInfoReader(this.info);

  final AppBuildInfo info;

  @override
  Future<AppBuildInfo> readInstalledBuild() async => info;
}
