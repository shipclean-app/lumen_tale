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
    this.capturedBy = '0-1',
  });

  final String site;
  final String baseUrl;
  final Directory dir;
  final List<FixtureEntry> entries;

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
    return FixtureManifest(
      site: site,
      baseUrl: decoded['baseUrl'] as String? ?? '',
      dir: dir,
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
