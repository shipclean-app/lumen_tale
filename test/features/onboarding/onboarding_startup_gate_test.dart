// forge:slice 3-4
// Lumen Tale — `3-4` § 3.1, the three branches of the cold-start decision, and the latch
// that makes it a **cold start** rather than a permanent rule.
//
// ## Why the latch has its own rows
//
// `onboarding.md` § 4 names the direction of every failure, and § 3.3 branch 5 names the
// one that breaks a naive implementation: *"a flag that can re-show a skipped screen is a
// bug, not a safety."* go_router evaluates `redirect` on **every** navigation, so a gate
// that merely answered "is the flag set?" would send a reader whose flag write failed back
// into onboarding every time they pressed a tab. That is invisible in the happy path and
// fatal in the one case E11 cares about — so the latch is asserted directly.

import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/router/first_run_gate.dart';

/// A reader that answers, and counts.
class _Reader {
  _Reader({this.answer = false, this.throws = false});

  bool answer;
  bool throws;
  int calls = 0;

  Future<bool> read() async {
    calls++;
    if (throws) {
      throw StateError('the preferences file could not be read');
    }
    return answer;
  }
}

void main() {
  tearDown(clearStartupGate);

  group('§ 3.1, three branches, and only three', () {
    test('⚠️ branch 2: never seen → `/onboarding`', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      expect(
        await gate.resolve(AppRoutes.library),
        AppRoutes.onboarding,
        reason:
            'first run. E11 needs the disclosure before anything can be lost, and the first '
            'launch is the only moment the app can put it in front of the reader alone.',
      );
      expect(reader.calls, 1);
    });

    test('branch 3: already seen → no opinion', () async {
      final _Reader reader = _Reader(answer: true);
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      expect(
        await gate.resolve(AppRoutes.library),
        isNull,
        reason:
            'the reader has read the disclosure; sending them to it again would be a '
            'product that cannot remember two sentences',
      );
    });

    test('⚠️ branch 1: the read FAILS → `/onboarding`, NEVER `/library`', () async {
      final _Reader reader = _Reader(answer: true, throws: true);
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      final String? location = await gate.resolve(AppRoutes.library);

      expect(
        location,
        AppRoutes.onboarding,
        reason:
            'the failure of a FLAG must not skip a DISCLOSURE. Showing two sentences to a '
            'reader who has already read them costs ten seconds; never showing them to one '
            'who has not costs data nobody warned them about.',
      );
      expect(
        location,
        isNot(AppRoutes.library),
        reason:
            'the acceptance criterion is the negative: a failed read must never open the '
            'library, because the library looks like a working app with nothing in it',
      );
    });

    test('a `true` that arrives alongside a failure is not believed', () async {
      // The reader is constructed with `answer: true` precisely so a row cannot pass by
      // accident on the answer rather than on the failure.
      final OnboardingStartupGate gate = OnboardingStartupGate(
        _Reader(answer: true, throws: true).read,
      );
      expect(await gate.resolve(AppRoutes.library), AppRoutes.onboarding);
    });
  });

  group('⚠️ the gate LATCHES, and § 3.3 branch 5 is why', () {
    test('a second navigation is NEVER redirected', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      expect(await gate.resolve(AppRoutes.library), AppRoutes.onboarding);

      // ⚠️ **THE FLAG WRITE FAILED, SO THE READER IS ON `/library` WITH `seen == false`.** A
      // gate without the latch sends them back to onboarding on the next tab press — a
      // reader who cannot use the app because a preference would not save.
      reader.answer = false;
      for (final String location in <String>[
        AppRoutes.library,
        AppRoutes.browse,
        AppRoutes.more,
        AppRoutes.library,
      ]) {
        expect(
          await gate.resolve(location),
          isNull,
          reason:
              '$location is an ordinary navigation and must not be intercepted',
        );
      }
      expect(
        reader.calls,
        1,
        reason:
            'the flag is read once per process. A second read could answer differently from '
            'the first — after a write, for instance — and two answers to one question is '
            'how a disclosure ends up skipped.',
      );
    });

    test('the latch is also set when the reader is already ON `/onboarding`', () async {
      // ⚠️ **THE HOLE A NAIVE LATCH LEAVES.** If the latch were set only when a decision was
      // taken, the push from Settings — which lands on `/onboarding?step=disclosure` — would
      // leave the gate armed. The reader then presses *Start reading*, the flag write fails,
      // and the very navigation meant to end the flow would redirect straight back into the
      // disclosure.
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      expect(
        await gate.resolve(AppRoutes.onboardingDisclosurePath()),
        isNull,
        reason: 'the gate never redirects away from the disclosure',
      );
      expect(gate.hasDecided, isTrue, reason: 'and the decision is now spent');

      expect(
        await gate.resolve(AppRoutes.library),
        isNull,
        reason:
            'the reader left the disclosure on purpose; intercepting the arrival at the '
            'library would be the trap',
      );
      expect(reader.calls, 0, reason: 'and the flag was never read at all');
    });

    test('⚠️ `/onboarding` is never redirected to itself, query or not', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);

      for (final String location in <String>[
        AppRoutes.onboarding,
        AppRoutes.onboardingDisclosurePath(),
        '/onboarding?step=promise',
      ]) {
        expect(
          await gate.resolve(location),
          isNull,
          reason:
              '$location is the disclosure itself. A redirect here would be a loop, and '
              'go_router answers a loop with its redirectLimit and then an error page.',
        );
      }
    });
  });

  group('the installation, and what a missing one must NOT do', () {
    test('a null gate means "no opinion", never "show onboarding"', () {
      clearStartupGate();
      expect(
        installedStartupGate,
        isNull,
        reason:
            'an uninstalled gate must be absent, not "fails open". Failing OPEN belongs to '
            'the flag READ (branch 1); a missing installation is a wiring mistake, and '
            'letting one decide a first run would mean the disclosure appears or not '
            'depending on a line that was never written.',
      );
    });

    test(
      '`installStartupGate` is what `main()` calls, and it is observable',
      () {
        final OnboardingStartupGate gate = OnboardingStartupGate(
          _Reader(answer: true).read,
        );
        installStartupGate(gate);
        expect(installedStartupGate, same(gate));
      },
    );
  });

  group('the location the gate hands back is the one `AppRoutes` names', () {
    test('⚠️ it is `AppRoutes.onboarding`, and the replay form is distinct', () {
      // Two locations, one route. A gate that redirected to the *replay* form would open a
      // first run on step 2 and give the reader a disclosure as their first sight of the app,
      // with no promise above it — which is not a re-read, it is a scare.
      expect(AppRoutes.onboarding, '/onboarding');
      expect(
        AppRoutes.onboardingDisclosurePath(),
        '/onboarding?step=disclosure',
      );
      expect(
        AppRoutes.onboardingDisclosurePath(),
        startsWith(AppRoutes.onboarding),
        reason:
            'the replay form must stay ON the onboarding route — a second route would put a '
            'sixteenth row in `design-system.md` § 3.5 for one screen',
      );
    });
  });
}
