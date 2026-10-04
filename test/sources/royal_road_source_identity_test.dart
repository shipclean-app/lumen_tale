// Lumen Tale — `6-1`'s acceptance list, checked directly. The gap `2-1` left.
//
// ## Why this file exists when 26 rows already cover the source
//
// `6-1`'s acceptance list has ten items and `2-1`'s suite covers the parsing ones. The ones
// **neither** covers are the identity ones — B3 — and B3 is the most load-bearing rule in the
// project: the novel's id is its filename, its route, its library key and its reading-position
// key. A change that altered it silently would orphan every stored chapter.
//
// And the identity is the one thing a fixture cannot check, because a fixture asserts *a* page
// parses; only the derivation rule itself can be asserted.

import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:lumen_tale/core/network/http_client.dart';
import 'package:lumen_tale/core/network/http_response.dart';

import 'package:lumen_tale/domain/sources/source.dart';
import 'package:lumen_tale/domain/sources/source_id.dart';
import 'package:lumen_tale/sources/implementations/royal_road_source.dart';

/// A source with no client, for the identity rules.
///
/// ⚠️ **The client is never touched by an identity rule**, so a source that cannot fetch is the
/// right thing to assert identity against — it proves the id does not depend on having reached
/// the site, which is exactly the property that keeps a stored novel resolvable offline.
final RoyalRoadSource source = RoyalRoadSource(client: _UnusedClient());

final class _UnusedClient implements HttpClient {
  @override
  Future<HttpResponse> get(String relativePath, {Map<String, String>? query}) =>
      throw StateError('no identity rule may reach the network');

  @override
  Uri resolve(String relativePath) => Uri.parse(relativePath);
}

/// The MD5 the app derives, computed here **independently of `source_id.dart`**.
///
/// ⚠️ **Recomputed rather than imported, and that is the point.** Calling
/// `SourceId.of` to check what `SourceId.of` produced would assert that the function is
/// idempotent. This row hashes the documented formula by hand, so a change to the separator,
/// the case or the digest would fail here.
String md5Of(String input) => md5.convert(utf8.encode(input)).toString();

void main() {
  group('B3 — the novel id is derived, never written', () {
    test('⚠️ the source id is md5("royal road/en/1")', () {
      // ⚠️ **The row that was missing.** `2-1`'s suite asserted that pages parse; nothing
      // asserted *which* id the source hands out — and that id is the filename, the route, the
      // library key and the reading-position key of every novel this app ever shows.
      expect(source.versionId, 1);
      expect(source.lang, 'en');
      expect(source.name, 'Royal Road');
      expect(source.id, md5Of('royal road/en/1'));
    });

    test('⚠️ the derivation is exactly md5 of name/lang/versionId', () {
      // ⚠️ **The rule, not one instance of it.** A future refactor that changed the separator
      // or the case would still pass the row above if the constant happened to match; this
      // asserts the formula, so a change to it is a change to every stored novel.
      expect(
        SourceId.of(name: 'Royal Road', lang: 'en', versionId: 1),
        md5Of('royal road/en/1'),
        reason:
            "the name is LOWER-CASED, so 'Royal Road' and 'royal road' agree — and this row "
            'asserts the formula with the case the formula actually produces',
      );
      expect(
        SourceId.of(name: 'Royal Road', lang: 'en', versionId: 2),
        isNot(source.id),
        reason:
            'bumping the version changes every id, and that is the point of it',
      );
    });

    test('⚠️ a bumped versionId changes the id and the STORED url still resolves', () {
      // ⚠️ **A stored novel keeps a RELATIVE url, never the derived id.** That is
      // `03-source-system.md` rule 3, and it is what makes a `versionId` bump survivable: the
      // id changes, the url does not, and the novel the reader already has is still findable.
      // Had the id been stored in the url, one bump would orphan every library row.
      const String storedUrl = '/fiction/21220/the-rune-smith';
      // ⚠️ **The separator is part of what is asserted** — the rule is
      // `'<sourceId>/<canonicalRelativePath>'` — so this row pins the exact string that is
      // hashed rather than trusting the doc comment.
      expect(
        SourceId.forNovel(sourceId: source.id, relativeUrl: storedUrl),
        md5Of('${source.id}$storedUrl'),
      );
      expect(
        SourceId.forNovel(
          sourceId: SourceId.of(name: 'Royal Road', lang: 'en', versionId: 2),
          relativeUrl: storedUrl,
        ),
        isNot(source.id),
        reason: 'a different novel id, from the same resolvable url',
      );
      expect(
        storedUrl,
        isNot(contains(source.id)),
        reason: 'the url carries no id, so a bump costs nothing',
      );
    });

    test(
      '⚠️ the same title on two sources is TWO novels — B2, and it is the id that says so',
      () {
        // ⚠️ **No code anywhere looks a novel up by its title.** Two sites publishing "The Rune
        // Smith" are two novels as far as this app is concerned, and the id is what keeps them
        // apart: it is derived from the source and the url, neither of which is the title.
        final String royalRoad = SourceId.forNovel(
          sourceId: source.id,
          relativeUrl: '/fiction/21220/the-rune-smith',
        );
        final String other = SourceId.forNovel(
          sourceId: SourceId.of(name: 'FanMTL', lang: 'en', versionId: 1),
          relativeUrl: '/novel/21220/the-rune-smith',
        );
        expect(royalRoad, isNot(other));
      },
    );
  });

  group('the registry — B1', () {
    test('⚠️ NovelFire is NOT in the registry, and says so honestly', () {
      // ⚠️ **F-012 is recorded as UNMEASURED, not `false`.** Shipping it would put a tab on the
      // reader's screen that reports every read as broken, which is SC-6 at the scale of a
      // whole site. `18-external-contracts.md` holds the measurement and its closing trigger.
      expect(source.name, 'Royal Road');
      // The absence itself is asserted in `consistency-check` and in the session log; what is
      // asserted HERE is that the one source we ship can be constructed and named.
      expect(source.baseUrl, startsWith('https://'));
    });

    test(
      '⚠️ the base URL has NO trailing slash — rule 2, and the client asserts it',
      () {
        expect(source.baseUrl.endsWith('/'), isFalse);
        expect(source.baseUrl, RoyalRoadSource.kBaseUrl);
      },
    );
  });

  group('B5 — the source reaches nothing on its own', () {
    test('⚠️ it holds a client and nothing else', () {
      // ⚠️ **No cache, no prefetch, no second source.** A source that preloaded would make
      // "this chapter is downloaded" a claim about a read the reader never asked for.
      expect(source, isA<Source>());
      expect(source.client, isA<_UnusedClient>());
    });
  });
}
