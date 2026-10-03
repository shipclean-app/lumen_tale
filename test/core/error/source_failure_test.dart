// Lumen Tale — the six causes, sealed and inert.
//
// `failure-discriminator` § 11.1, second file. Three rows there and three more
// here, because a sealed hierarchy has properties worth asserting that a single
// case cannot show.

import 'package:flutter_test/flutter_test.dart';
import 'package:lumen_tale/core/error/source_failure.dart';

void main() {
  group('Causes', () {
    test('the six causes are distinct and sealed', () {
      // Exhaustive by construction: adding a seventh cause to the hierarchy turns
      // this into a compile error, which is the point of `sealed`.
      const List<SourceFailure> all = <SourceFailure>[
        NoConnection(host: 'www.royalroad.com'),
        RateLimited(retryAfter: Duration(seconds: 30)),
        SourceUnavailable(status: 503),
        SourceLayoutChanged(failedSelector: '.x', status: 200),
        ItemRemovedAtSource(itemId: 'novel-1', status: 404),
        ParseFailed(path: '/novel/1.html'),
      ];

      expect(all, hasLength(6));
      expect(
        all.map((SourceFailure c) => c.runtimeType).toSet(),
        hasLength(6),
        reason: 'no two causes are the same type',
      );

      final Set<String> descriptions = <String>{
        for (final SourceFailure cause in all)
          switch (cause) {
            NoConnection() => 'the phone has no connection',
            RateLimited() => 'the site asked us to wait',
            SourceUnavailable() => 'the site refused or is down',
            SourceLayoutChanged() =>
              'the site answered and we could not read it',
            ItemRemovedAtSource() => 'the site says the item is gone',
            ParseFailed() => 'we could not turn the page into elements',
          },
      };
      expect(descriptions, hasLength(6));
    });

    test('a host is never a path', () {
      // C5 / `17-security.md` rule 1: a cause crossing an error layer carries a
      // host, so it can never carry the string the reader typed.
      const NoConnection cause = NoConnection(host: 'www.fanmtl.com');
      expect(cause.host, isNot(contains('/')));
      expect(cause.host, isNot(contains('?')));
      expect(cause.host, isNot(contains('#')));
      expect(cause.host, isNot(contains('://')));
    });

    test('a parsed path is never absolute', () {
      // `17-security.md` rule 4 — an absolute path in a diagnostic is a filesystem
      // layout leak, and it is also meaningless to whoever reads it.
      const ParseFailed cause = ParseFailed(
        path: '/fiction/21220/the-runesmith/chapter/1/glossary',
      );
      expect(cause.path, startsWith('/'));
      // Site-relative: a leading slash with no authority and no drive letter.
      expect(cause.path, isNot(contains('://')));
      expect(cause.path, isNot(matches(RegExp('^[A-Za-z]:'))));
    });

    test('an item id is never a URL', () {
      const ItemRemovedAtSource cause = ItemRemovedAtSource(
        itemId: 'royalroad:21220',
        status: 404,
      );
      expect(cause.itemId, isNot(contains('://')));
      expect(cause.itemId, isNot(contains('/')));
    });

    test('a RateLimited cause has no host to disagree with', () {
      // The host is already a key in the limiter's slot table. A second copy of a
      // fact that exists is a second thing free to diverge, so the cause does not
      // have one.
      const RateLimited cause = RateLimited(retryAfter: Duration(seconds: 1));
      expect(cause, isNot(isA<NoConnection>()));
      expect(cause.retryAfter.isNegative, isFalse);
    });

    test('SourceLayoutChanged defaults its signal to absent', () {
      const SourceLayoutChanged cause = SourceLayoutChanged(
        failedSelector: '.x',
        status: 200,
      );
      expect(cause.siteSuppliedSignal, isNull);
      expect(cause.status, 200);
    });

    test('SourceUnavailable defaults isChallenge to false', () {
      // A plain 403 and a challenge are different facts and get different
      // wording, so the default must be the ordinary one — inferring a challenge
      // from a status alone is exactly the guess ADR-014 rejected.
      expect(const SourceUnavailable(status: 403).isChallenge, isFalse);
      expect(
        const SourceUnavailable(status: 403, isChallenge: true).isChallenge,
        isTrue,
      );
    });
  });
}
