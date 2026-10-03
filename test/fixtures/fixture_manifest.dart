// Lumen Tale — reads one site's fixture manifest and the fixtures it names.
//
// Pure Dart: no Flutter import. It is loaded from `test/`, never from `lib/` — a
// manifest is evidence about a website, not part of the product.
// `10-testing.md` rule 5 requires the fixtures to be usable without the app.
//
// Plan `0-1` § 2.3.

import 'dart:convert';
import 'dart:io';

final class FixtureManifest {
  const FixtureManifest({
    required this.site,
    required this.baseUrl,
    required this.dir,
    required this.entries,
    this.pagination = const <PaginationRecord>[],
    this.capturedBy = '0-1',
  });

  final String site;
  final String baseUrl;
  final Directory dir;
  final List<FixtureEntry> entries;

  /// What the capture learned about pagination, one record per list kind. `0-3`.
  final List<PaginationRecord> pagination;

  /// Which slice captured these fixtures — always `0-1`.
  ///
  /// A re-captured fixture keeps `0-1` plus a new date; it is never re-labelled as
  /// a later slice, because `capturedAt` is the provenance and `capturedBy` is the
  /// method.
  final String capturedBy;

  /// Loads `<repo>/test/fixtures/sources/<site>/manifest.json`.
  ///
  /// A **static method**, not a named constructor: this reads from the filesystem,
  /// which a constructor cannot do, and the lint that asks for a constructor here is
  /// asking for a shape that would have to be a wrapper doing the same IO.
  ///
  /// Throws [FixtureManifestException] — never returns a partial manifest. A
  /// manifest that silently drops half its fixtures is a manifest that lets a test
  /// pass against a file nobody declared.
  // ignore: prefer_constructors_over_static_methods
  static FixtureManifest load(String site) {
    final Directory dir = Directory('test/fixtures/sources/$site');
    final File file = File('${dir.path}/manifest.json');
    if (!file.existsSync()) {
      throw FixtureManifestException('$site: no manifest at ${file.path}');
    }
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw FixtureManifestException('$site: manifest is not a JSON object');
    }
    if (decoded['site'] != site) {
      throw FixtureManifestException(
        '$site: manifest declares site "${decoded['site']}"',
      );
    }
    final Object? rawEntries = decoded['entries'];
    if (rawEntries is! List<Object?>) {
      throw FixtureManifestException('$site: manifest has no entries array');
    }
    // ⚠️ `pagination[]` is loaded, not skipped.
    //
    // A top-level key the loader ignores is a key nobody reads: it would sit in the
    // JSON looking measured while nothing in the test suite could fail if it were
    // wrong. The first version of this loader ignored it for exactly that long.
    final Object? rawPagination = decoded['pagination'];
    final List<PaginationRecord> pagination = <PaginationRecord>[];
    if (rawPagination != null) {
      if (rawPagination is! List<Object?>) {
        throw FixtureManifestException('$site: pagination is not an array');
      }
      for (final Object? row in rawPagination) {
        if (row is! Map<String, dynamic>) {
          throw FixtureManifestException(
            '$site: a pagination row is not an object',
          );
        }
        pagination.add(PaginationRecord.fromJson(row, site));
      }
    }

    return FixtureManifest(
      site: site,
      baseUrl: decoded['baseUrl'] as String? ?? '',
      dir: dir,
      pagination: pagination,
      entries: rawEntries
          .map((Object? e) {
            if (e is! Map<String, dynamic>) {
              throw FixtureManifestException(
                '$site: an entry is not an object',
              );
            }
            return FixtureEntry.fromJson(e, dir);
          })
          .toList(growable: false),
    );
  }

  /// The single [pageKind] pagination record. Throws when absent.
  ///
  /// `0-3` § 10: a **missing** entry for a page kind is a silence, and a silence on
  /// B9 is not an absence of pagination — it is an absence of evidence, which is a
  /// different and much more expensive thing.
  PaginationRecord requirePagination(String pageKind) {
    for (final PaginationRecord r in pagination) {
      if (r.pageKind == pageKind) return r;
    }
    throw FixtureManifestException(
      '$site: no pagination record for pageKind "$pageKind"',
    );
  }

  /// The single entry with [key]. Throws when absent — a fixture lookup that
  /// returns null turns a missing capture into a skipped assertion.
  FixtureEntry require(String key) {
    for (final FixtureEntry e in entries) {
      if (e.key == key) return e;
    }
    throw FixtureManifestException('$site: no fixture with key "$key"');
  }

  /// Every entry whose [FixtureEntry.kind] is [kind].
  List<FixtureEntry> ofKind(String kind) =>
      entries.where((FixtureEntry e) => e.kind == kind).toList(growable: false);
}

/// One list kind's pagination, as recorded at capture time by `0-3`.
///
/// [isConfirmed] is the load-bearing field and it is **not** a matter of taste: an
/// unconfirmed parameter is decoration, and `2-1` must treat it as decoration rather
/// than follow it and read page 1 forever.
final class PaginationRecord {
  const PaginationRecord({
    required this.site,
    required this.pageKind,
    required this.parameterName,
    required this.exampleHref,
    required this.oneBased,
    required this.isConfirmed,
    required this.confirmationBasis,
    required this.notes,
  });

  factory PaginationRecord.fromJson(Map<String, dynamic> json, String site) {
    for (final String field in requiredFields) {
      if (!json.containsKey(field)) {
        throw FixtureManifestException(
          '$site: pagination "$pageKindFieldName(json)" is missing "$field"',
        );
      }
    }
    final String pageKind = json['pageKind'] as String;
    final Object? parameter = json['discoveredParameter'];

    // `exampleHref` sits beside the name, on the parameter, because it is evidence
    // FOR the parameter: a name with no href is a guess and a href with no name is
    // an observation. Keeping them apart would let the manifest record one without
    // the other, which is the shape of an unbacked claim.
    final Object? exampleHref = json['exampleHref'];

    // ⚠️ An unconfirmed record may declare a parameter — that is the hypothesis it
    // failed to confirm. But it may NOT claim confirmation with no parameter, and it
    // may NOT claim confirmation with no basis. Both are the same mistake: asserting
    // a fact and supplying nothing to check it against.
    final bool isConfirmed = json['isConfirmed'] as bool;
    if (parameter is Map<String, dynamic> &&
        !parameter.containsKey('exampleHref')) {
      final Object? sibling = exampleHref;
      if (sibling is String) parameter['exampleHref'] = sibling;
    }
    if (isConfirmed) {
      if (parameter is! Map<String, dynamic>) {
        throw FixtureManifestException(
          '$site: pagination "$pageKind" is confirmed with no discoveredParameter',
        );
      }
      final Object? basis = json['confirmationBasis'];
      if (basis is! String || basis.trim().isEmpty) {
        throw FixtureManifestException(
          '$site: pagination "$pageKind" is confirmed with no confirmationBasis',
        );
      }
    }

    return PaginationRecord(
      site: site,
      pageKind: pageKind,
      parameterName: parameter is Map<String, dynamic>
          ? parameter['name'] as String?
          : null,
      exampleHref: exampleHref is String
          ? exampleHref
          : (parameter is Map<String, dynamic>
                ? parameter['exampleHref'] as String?
                : null),
      oneBased: parameter is Map<String, dynamic>
          ? parameter['oneBased'] as bool? ?? false
          : false,
      isConfirmed: isConfirmed,
      confirmationBasis: json['confirmationBasis'] as String?,
      notes: (json['notes'] as String? ?? '').trim(),
    );
  }

  static String pageKindFieldName(Map<String, dynamic> json) =>
      json['pageKind'] as String? ?? '(unnamed)';

  final String site;
  final String pageKind;

  /// `page`, `reviews`, … read off a real href. `null` when the list is not paged.
  final String? parameterName;
  final String? exampleHref;
  final bool oneBased;
  final bool isConfirmed;
  final String? confirmationBasis;
  final String notes;

  /// `true` for a list the capture proved is **not** paginated.
  bool get isKnownUnpaged => parameterName == null && !isConfirmed;

  /// Every field a pagination row must carry.
  static const List<String> requiredFields = <String>[
    'pageKind',
    'discoveredParameter',
    'isConfirmed',
    'notes',
  ];

  @override
  String toString() =>
      'pagination[$pageKind] $parameterName '
      'confirmed=$isConfirmed';
}

/// One captured or manufactured fixture, as declared by the manifest.
final class FixtureEntry {
  factory FixtureEntry.fromJson(Map<String, dynamic> json, Directory dir) {
    for (final String field in requiredFields) {
      if (!json.containsKey(field)) {
        throw FixtureManifestException(
          '${dir.path}: entry "${json['key']}" is missing "$field"',
        );
      }
    }
    // `kind` is enforced HERE rather than left to a caller to check.
    //
    // § 2.2 says the list is closed because "a free string becomes a taxonomy
    // nobody maintains" — and that is only true if the read path refuses one.
    // Declaring the constant and never testing against it is a comment, and the
    // first draft of this file did exactly that: `kinds` existed, was complete,
    // and a `kind: "whatever"` entry loaded happily.
    final kind = json['kind'] as String;
    if (!kinds.contains(kind)) {
      throw FixtureManifestException(
        '${dir.path}: entry "${json['key']}" declares kind "$kind", which is '
        'not in the closed list $kinds',
      );
    }
    return FixtureEntry(
      dir: dir,
      key: json['key'] as String,
      file: json['file'] as String,
      url: json['url'] as String,
      httpStatus: json['httpStatus'] as int,
      contentType: json['contentType'] as String,
      capturedAt: json['capturedAt'] as String,
      bytes: json['bytes'] as int,
      sha256: json['sha256'] as String,
      kind: json['kind'] as String,
      expected: json['expected'] as Map<String, dynamic>,
      notes: json['notes'] as String,
    );
  }

  /// [dir] is carried so [fileOnDisk] can resolve, and so a missing-field error
  /// can name the directory it was reading.
  const FixtureEntry({
    required this.dir,
    required this.key,
    required this.file,
    required this.url,
    required this.httpStatus,
    required this.contentType,
    required this.capturedAt,
    required this.bytes,
    required this.sha256,
    required this.kind,
    required this.expected,
    required this.notes,
  });

  /// The fields § 2.2 makes mandatory. A field nothing reads is a promise nobody
  /// made, and a field that is mandatory but missing is a manifest that lied.
  static const List<String> requiredFields = <String>[
    'key',
    'file',
    'url',
    'httpStatus',
    'contentType',
    'capturedAt',
    'bytes',
    'sha256',
    'kind',
    'expected',
    'notes',
  ];

  /// `kind` is a CLOSED list (§ 2.2), never a free string: a free string becomes
  /// a taxonomy nobody maintains.
  static const Set<String> kinds = <String>{
    'robots',
    'genre-index',
    'catalogue',
    'novel-detail',
    'chapter-list',
    'chapter',
    'failure-page',
    'manufactured',
    // `6-11` — a search page, captured **with its control**: a positive query and a
    // query that cannot match. The pair is the unit, and a taxonomy that can hold only
    // the positive half is a taxonomy that invites recording a match count with
    // nothing to compare it against.
    //
    // ⚠️ **Adding a kind is not free**, and this comment is the price of it: the list
    // is closed so a free string cannot become a taxonomy nobody maintains, which means
    // every real new shape of capture needs this entry rather than a new `String`. That
    // is the intended cost — the alternative is `kind: "whatever"` loading happily, and
    // § 2.2's row for that is the test named `a kind outside the closed list is refused`.
    'search',
  };

  /// The directory the manifest was read from. Carried on every entry so
  /// [fileOnDisk] resolves without the caller re-deriving it.
  final Directory dir;

  final String key;
  final String file;
  final String url;
  final int httpStatus;
  final String contentType;
  final String capturedAt;
  final int bytes;
  final String sha256;
  final String kind;
  final Map<String, dynamic> expected;
  final String notes;

  /// The fixture's bytes. Relative to the manifest's directory, never absolute.
  File get fileOnDisk => File('${dir.path}/$file');

  /// Whether this fixture was really captured, as opposed to manufactured.
  bool get isCaptured => kind != 'manufactured';

  @override
  String toString() => 'FixtureEntry($key, $kind, $file)';
}

/// A manifest that cannot be trusted.
///
/// C1 and `18-external-contracts.md` rule 1: the provenance of a fixture is the
/// whole reason it exists, so a manifest that cannot state it is refused rather
/// than repaired.
final class FixtureManifestException implements Exception {
  const FixtureManifestException(this.message);

  final String message;

  @override
  String toString() => 'FixtureManifestException: $message';
}
