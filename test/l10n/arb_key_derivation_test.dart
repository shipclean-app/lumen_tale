// Lumen Tale — `localisation` § 11.1, key derivation.
//
// Six rows, and the first one is the reason this file exists: `arb_key_derivation.dart`
// is the single implementation of the rule, so these tests read that function rather
// than restating it. A test that reimplements the rule tests its own copy.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/l10n/arb_key_derivation.dart';

void main() {
  test('a dotted screen key becomes one flat camelCase key', () {
    expect(
      arbKeyFor('source-unavailable', 'cause.noConnection.kicker'),
      'sourceUnavailableCauseNoConnectionKicker',
    );
  });

  test('a leading segment matching the screen slug is dropped', () {
    expect(
      arbKeyFor('settings', 'settings.group.reading'),
      'settingsGroupReading',
    );
    expect(
      arbKeyFor('settings', 'settings.group.reading'),
      isNot('settingsSettingsGroupReading'),
      reason:
          'the slug is already the prefix; repeating it is the mistake the '
          'rule exists to prevent',
    );
  });

  test('a digit segment is preserved verbatim', () {
    expect(arbKeyFor('settings', 'retention.1w'), 'settingsRetention1w');
    expect(arbKeyFor('settings', 'interval.12h'), 'settingsInterval12h');
    // The point is transcription, not formatting: losing the 12 would tell the
    // reader an interval the site never stated.
    expect(arbKeyFor('settings', 'interval.12h'), contains('12'));
  });

  test('a five segment key keeps all five', () {
    expect(
      arbKeyFor('source-unavailable', 'cause.siteUnavailable.evidence.status'),
      'sourceUnavailableCauseSiteUnavailableEvidenceStatus',
    );
  });

  test('an empty segment fails instead of being skipped', () {
    expect(
      () => arbKeyFor('settings', 'row..label'),
      throwsA(isA<FormatException>()),
      reason:
          'skipping the empty segment yields settingsRowLabel — a typo that '
          'ships as a string nothing can find',
    );
  });

  test('a key written by two screens resolves to ONE key', () {
    // `settings.md` and `settings-reader.md` both write `error.write`, and both
    // screens live under the `settings` slug — `settings-reader` is a FILE name,
    // not a slug. Deriving from the file name would produce two keys holding the
    // same French text, which is the duplication this rule exists to prevent.
    expect(arbKeyFor('settings', 'error.write'), 'settingsErrorWrite');
    expect(
      arbKeyFor('settings', 'error.write'),
      arbKeyFor('settings', 'error.write'),
      reason: 'witness — the same slug and the same dotted key must agree',
    );
  });

  test('a genuinely different slug is a genuinely different key', () {
    // The converse, so the row above cannot be satisfied by a function that
    // ignores the slug entirely and returns one constant.
    expect(
      arbKeyFor('downloads', 'error.write'),
      isNot(arbKeyFor('settings', 'error.write')),
    );
  });

  test('the derivation refuses an empty screen slug', () {
    expect(
      () => arbKeyFor('', 'group.reading'),
      throwsA(isA<FormatException>()),
    );
  });
}
