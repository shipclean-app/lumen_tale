// forge:slice 3-4
// Lumen Tale — `3-4` § 3.1, the three branches of the cold-start decision, and the latch
// that makes it a **cold start** rather than a permanent rule.
//
// ## ⚠️ WHY THE GATE ANSWERS **SYNCHRONOUSLY**
//
// `GoRouter.redirect` may return a `Future`, and go_router **awaits it before building the
// first page** — so an async redirect costs the reader a microtask even when it reads
// nothing. `test/app/shell/app_shell_test.dart` measures the cost exactly: *"outside the
// shell the reader has no transition in — § 3.4"* pumps **once** and asserts the shell's tab
// bar is already gone, and `test/widget_test.dart`'s bootstrap rows failed the same way.
//
// So the decision is made **once, at the bootstrap**, and `resolveNow` is a lookup. Both
// entry points below assert the same three branches, because a redirect with two copies of
// its rules is two sets of rules — which is exactly the drift the single `decide` exists to
// prevent.

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

/// An installed, seeded gate: the shape `main()` produces, so every row below exercises the
/// router's real call (`resolveNow`) rather than the async fallback.
Future<OnboardingStartupGate> _installed(_Reader reader) async {
  final OnboardingStartupGate gate = OnboardingStartupGate(reader.read);
  await installStartupGate(gate);
  return gate;
}

void main() {
  tearDown(clearStartupGate);

  group('§ 3.1, three branches, and only three', () {
    test('⚠️ branch 2: never seen → `/onboarding`', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);

      expect(
        gate.resolveNow(AppRoutes.library),
        AppRoutes.onboarding,
        reason:
            'first run. E11 needs the disclosure before anything can be lost, and the first '
            'launch is the only moment the app can put it in front of the reader alone.',
      );
      expect(
        reader.calls,
        1,
        reason:
            'the flag is read ONCE per process — by `installStartupGate`, before `runApp`. A '
            'second read could answer differently from the first and produce two answers to '
            'one question.',
      );
    });

    test('branch 3: already seen → no opinion', () async {
      final _Reader reader = _Reader(answer: true);
      final OnboardingStartupGate gate = await _installed(reader);

      expect(
        gate.resolveNow(AppRoutes.library),
        isNull,
        reason:
            'the reader has read the disclosure; sending them to it again would be a '
            'product that cannot remember two sentences',
      );
    });

    test('⚠️ branch 1: the read FAILS → `/onboarding`, NEVER `/library`', () async {
      final _Reader reader = _Reader(answer: true, throws: true);

      // ⚠️ **`installStartupGate` IS WHERE BRANCH 1 IS TAKEN**, because the answer has to be
      // held before the router is asked — a synchronous `resolveNow` cannot read. The reader
      // is built with `answer: true` so the row cannot pass by accident on the flag: the
      // ONLY reason to show onboarding is the failure.
      await installStartupGate(OnboardingStartupGate(reader.read));
      final OnboardingStartupGate gate = OnboardingStartupGate(reader.read)
        ..seed(seen: false);

      final String? location = gate.resolveNow(AppRoutes.library);

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

    test('⚠️ an UNSEEDED gate fails OPEN, because `_answer ?? false`', () {
      // ⚠️ **THE THIRD BRANCH OF THE SAME RULE.** A gate installed without `seed` has no
      // answer and cannot read one synchronously — and "no answer" must read as `false`, not
      // as `true`. Defaulting the other way would make an unseeded gate silently skip the
      // disclosure, which is the one failure E11 exists to prevent.
      final OnboardingStartupGate gate = OnboardingStartupGate(
        () async => true,
      );
      expect(gate.resolveNow(AppRoutes.library), AppRoutes.onboarding);
    });
  });

  group('⚠️ the gate LATCHES, and § 3.3 branch 5 is why', () {
    test('a second navigation is NEVER redirected', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);

      expect(gate.resolveNow(AppRoutes.library), AppRoutes.onboarding);

      // ⚠️ **THE FLAG WRITE FAILED, SO THE READER IS ON `/library` WITH `seen == false`.** A
      // gate without the latch sends them back to onboarding on the next tab press — a
      // reader who cannot use the app because a preference would not save.
      for (final String location in <String>[
        AppRoutes.library,
        AppRoutes.browse,
        AppRoutes.more,
        AppRoutes.library,
      ]) {
        expect(
          gate.resolveNow(location),
          isNull,
          reason:
              '$location is an ordinary navigation and must not be intercepted',
        );
      }
      expect(
        reader.calls,
        1,
        reason:
            'the flag is read once per process, and the latch means it is not re-asked',
      );
    });

    test('the latch is also set when the reader is already ON `/onboarding`', () async {
      // ⚠️ **THE HOLE A NAIVE LATCH LEAVES.** If the latch were set only when a decision was
      // taken, the push from Settings — which lands on `/onboarding?step=disclosure` — would
      // leave the gate armed. The reader then presses *Start reading*, the flag write fails,
      // and the very navigation meant to end the flow would redirect straight back into the
      // disclosure.
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);

      expect(
        gate.resolveNow(AppRoutes.onboardingDisclosurePath()),
        isNull,
        reason: 'the gate never redirects away from the disclosure',
      );
      expect(gate.hasDecided, isTrue, reason: 'and the decision is now spent');

      expect(
        gate.resolveNow(AppRoutes.library),
        isNull,
        reason:
            'the reader left the disclosure on purpose; intercepting the arrival at the '
            'library would be the trap',
      );
    });

    test('⚠️ `/onboarding` is never redirected to itself, query or not', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);

      for (final String location in <String>[
        AppRoutes.onboarding,
        AppRoutes.onboardingDisclosurePath(),
        '/onboarding?step=promise',
      ]) {
        expect(
          gate.resolveNow(location),
          isNull,
          reason:
              '$location is the disclosure itself. A redirect here would be a loop, and '
              'go_router answers a loop with its redirectLimit and then an error page.',
        );
      }
    });

    test('⚠️ and the READER is never captured either', () async {
      // ⚠️ **A THIRD EXEMPTION, AND IT IS A REAL ONE.** `/reader/…` is reached by `push` from
      // four places and is the one destination a reader asked for by name. A cold-start gate
      // that captured it would answer *"start reading"* with the disclosure — and because the
      // gate latches, the chapter would then open anyway: the reader watches the disclosure
      // flash in front of the chapter they tapped, on the screen that is supposed to be the
      // promise being kept.
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);

      expect(
        gate.resolveNow(AppRoutes.readerFor('n1', 'c1')),
        isNull,
        reason: 'opening a chapter is not a first run',
      );
      expect(gate.hasDecided, isTrue, reason: 'and the question is now spent');
    });

    test('the async entry point reaches the SAME three branches', () async {
      // ⚠️ **BOTH ENTRY POINTS, ASSERTED SEPARATELY.** `resolve` is not called by the router
      // — it is the fallback for a caller that installed a gate without seeding it — and a
      // fallback that disagreed with the live path would be a rule that only sometimes holds.
      final OnboardingStartupGate unseen = OnboardingStartupGate(
        () async => false,
      );
      expect(await unseen.resolve(AppRoutes.library), AppRoutes.onboarding);
      expect(await unseen.resolve(AppRoutes.browse), isNull, reason: 'latched');

      final OnboardingStartupGate seen = OnboardingStartupGate(
        () async => true,
      );
      expect(await seen.resolve(AppRoutes.library), isNull);

      final OnboardingStartupGate broken = OnboardingStartupGate(
        () async => throw StateError('unreadable'),
      );
      expect(
        await broken.resolve(AppRoutes.library),
        AppRoutes.onboarding,
        reason: 'branch 1 through the async path as well',
      );
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

    test('⚠️ `main()` INSTALLS it, and the call is AWAITED', () async {
      final _Reader reader = _Reader();
      final OnboardingStartupGate gate = await _installed(reader);
      expect(installedStartupGate, same(gate));

      // ⚠️ **AND THE SEED IS WHAT MAKES THE ROUTER'S CALL SYNCHRONOUS.** A gate that is
      // installed but not seeded forces `resolveNow` onto the `_answer ?? false` branch, which
      // is the fail-open direction and would show onboarding on every cold start.
      expect(gate.resolveNow(AppRoutes.library), AppRoutes.onboarding);
      expect(
        reader.calls,
        1,
        reason:
            'and exactly one read, which is what "read once per process" means',
      );
    });
  });

  group('the location the gate hands back is the one `AppRoutes` names', () {
    test('⚠️ it is `AppRoutes.onboarding`, and the replay form is distinct', () {
      // ⚠️ **NOT THE REPLAY FORM.** A gate that redirected to `/onboarding?step=disclosure`
      // would open a first run on step 2 and give the reader a disclosure as their first sight
      // of the app, with no promise above it — which is not a re-read, it is a scare.
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
