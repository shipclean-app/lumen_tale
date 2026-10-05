// Lumen Tale — the three derived identifiers, and nothing else.
//
// `03-source-system.md` rule 1: an id is **derived** from
// `name/lang/versionId` and never hand-written. B3 is the same rule with its
// reason: nothing here reads a clock, a counter or an RNG, so the same novel
// yields the same id after a restart and after an update.
//
// ⚠️ **One derivation, one place.** The plan for `2-1` § 3.1 pins three
// constants into the tests, and a second implementation of `md5` anywhere would
// be free to disagree with this one while every test still passed — because a
// test that recomputes the expected value with the same code as the code under
// test verifies nothing (`SKILL.md` § Discipline de vérification, rule 5).
//
// Pure Dart. MD5 is **not** a security choice here: it is the transposed
// convention from `source-api`, and it buys the two properties `2-3` relies on
// (see [SourceId.forNovel]) — an id containing no `/`, no `.` and no space, so
// it is safe as a filename and as a path segment (C5).

import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Derives the three stable identifiers.
///
/// Pure functions on purpose: `Source.id` is read at startup, by the registry,
/// by tests, and by nothing that has to be async.
abstract final class SourceId {
  const SourceId._();

  /// `md5('<name.toLowerCase()>/<lang>/<versionId>')` — 32 lowercase hex chars.
  ///
  /// `versionId` is part of the input **on purpose** (`03-source-system.md`
  /// rule 1): when a site's URLs break, the source bumps `versionId`, the id
  /// changes, and a stored novel whose source no longer resolves is a *visible,
  /// recorded event* rather than a silent 404. That is
  /// `18-external-contracts.md` rule 1's whole point.
  static String of({
    required String name,
    required String lang,
    required int versionId,
  }) {
    return md5Hex('${name.toLowerCase()}/$lang/$versionId');
  }

  /// `md5('<sourceId>/<relativePath>')` — `2-1` § 3.1's frozen novel id.
  ///
  /// [relativeUrl] is `path + query` per `03-source-system.md` rule 3, never an
  /// absolute URL. That is also why the `/` separator is written here and is part
  /// of the frozen constant: a stored absolute URL would change this string, and
  /// therefore every novel id, on the day the host changed.
  ///
  /// ⚠️ **Leading slashes are stripped, and that is load-bearing.** The `/` above
  /// is the separator, so a `relativeUrl` that also opens with `/` would
  /// contribute a second one — and `2-1` § 3.1 is *written* with
  /// `md5('f321cc5e…31//novel/ke383028.html')`, two slashes, while the constant
  /// pinned beside it (`90db9662…`) is the digest of **one**. Stripping here is
  /// what makes both shapes of the same URL yield the same id, instead of
  /// silently minting two ids for one novel — `SKILL.md` § Discipline de
  /// vérification, rule 10. The frozen constant is the authority; see the
  /// finding recorded in `SESSION_LOG.md`.
  static String forNovel({
    required String sourceId,
    required String relativeUrl,
  }) {
    return md5Hex('$sourceId/${_canonicalPath(relativeUrl)}');
  }

  /// `md5('<novelId>/<relativePath>')`.
  ///
  /// B2 falls out of the chain rather than being enforced anywhere: `sourceId` is
  /// an input to [forNovel], so two identically titled novels from two sites
  /// cannot collide, and two novels of the same title on the same site cannot
  /// either because their urls differ.
  static String forChapter({
    required String novelId,
    required String relativeUrl,
  }) {
    return md5Hex('$novelId/${_canonicalPath(relativeUrl)}');
  }

  /// [relativeUrl] with its leading slashes removed and nothing else changed.
  ///
  /// ⚠️ **Leading only.** No trimming, no case folding, no query reordering, no
  /// normalisation of `.`/`..`: each of those would merge two ids that must stay
  /// distinct, and a merge is invisible.
  static String _canonicalPath(String relativeUrl) {
    var index = 0;
    while (index < relativeUrl.length && relativeUrl[index] == '/') {
      index++;
    }
    return relativeUrl.substring(index);
  }

  /// 32 lowercase hexadecimal characters, UTF-8 encoded.
  ///
  /// ⚠️ The input is used **verbatim**: not trimmed, not case-folded, not
  /// re-ordered. Every normalisation that could merge two distinct inputs belongs
  /// at the caller, named and tested, because a silent one here would make two
  /// ids that must differ equal — and nothing would report it.
  static String md5Hex(String input) {
    return md5.convert(utf8.encode(input)).toString();
  }
}
