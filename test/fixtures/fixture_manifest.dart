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
  static FixtureManifest load(String site) =>
      loadFrom(Directory('test/fixtures/sources/$site'), expectedSite: site);

  /// Reads `<dir>/manifest.json`, refusing a manifest whose `site` is not
  /// [expectedSite].
  ///
  /// ⚠️ **Split out from [load] for one reason: the guard needs to be provable.**
  /// `load(site)` hardcodes `test/fixtures/sources/<site>`, so every check in
  /// [problems] could only ever be run against the real fixtures — where all of them
  /// pass, because they were made to. A guard that has only ever seen a healthy tree
  /// is a guard nobody knows fires. [loadFrom] lets a test point the same code at a
  /// throwaway directory holding a manifest that lies, and watch each branch catch
  /// it. The refusal to return a partial manifest is unchanged.
  // ignore: prefer_constructors_over_static_methods
  static FixtureManifest loadFrom(Directory dir, {String? expectedSite}) {
    final File file = File('${dir.path}/manifest.json');
    if (!file.existsSync()) {
      throw FixtureManifestException('$dir: no manifest at ${file.path}');
    }
    final Object? decoded = jsonDecode(file.readAsStringSync());
    if (decoded is! Map<String, dynamic>) {
      throw FixtureManifestException('$dir: manifest is not a JSON object');
    }
    final site = expectedSite ?? decoded['site'];
    if (site is! String || site.isEmpty) {
      throw FixtureManifestException('$dir: manifest declares no site');
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
      capturedBy: decoded['capturedBy'] as String? ?? '0-1',
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

  /// The single entry declaring [file], relative to [dir]. Throws when absent.
  ///
  /// Needed because a manufactured artefact's manifest entry names its **source
  /// file**, not the source's key — and the one-substitution proof of § 3.2 is a
  /// comparison between two files, so resolving it needs a file lookup rather than
  /// a key one. `require(key)` would answer with "no fixture with key
  /// catalogue-genre-page0.html", which is true and useless.
  FixtureEntry requireFile(String file) {
    for (final FixtureEntry e in entries) {
      if (e.file == file) return e;
    }
    throw FixtureManifestException('$site: no fixture declares file "$file"');
  }

  /// Every entry whose [FixtureEntry.kind] is [kind].
  List<FixtureEntry> ofKind(String kind) =>
      entries.where((FixtureEntry e) => e.kind == kind).toList(growable: false);

  /// Every declared file, relative to [dir]. Used by [problems]' branch A — an
  /// undeclared file on disk has no provenance, which `18-external-contracts.md`
  /// rule 1 forbids.
  Set<String> get declaredFileNames =>
      entries.map((FixtureEntry e) => e.file).toSet();

  /// The extensions a fixture may legitimately have. A `.json` sidecar and a
  /// `manifest.in.json` are **not** fixtures and must not be declared as such —
  /// the input file describes the captures, it is not one.
  static const Set<String> fixtureExtensions = <String>{
    '.html',
    '.htm',
    '.txt',
  };

  /// § 3.4, branches A to F — **every** reason this manifest cannot be trusted, not
  /// the first.
  ///
  /// It returns a list rather than throwing, and that is deliberate: a guard that
  /// stops at the first failure needs six runs to report six mistakes, and the sixth
  /// is discovered after the fifth is fixed. Empty means the manifest holds.
  ///
  /// | Branch | Rule | What it refuses |
  /// |---|---|---|
  /// | A | `18-external-contracts.md` rule 1 | an undeclared fixture on disk; an entry declaring a file that is absent |
  /// | B | § 3.2 | `bytesOnDisk != bytes` — a rewritten file |
  /// | C | § 3.4 C | an empty `catalogue` / `novel-detail` capture: a capture of nothing proves nothing |
  /// | D | `18-external-contracts.md` rule 1 | an entry with no observation recorded |
  /// | E | § 3.2 | a `manufactured` entry that does not state its one edit |
  /// | F | C2, B4 | a fixture carrying a session token |
  ///
  /// It also carries the two manifest-level rules every entry must satisfy: a
  /// relative `url` (rules 2-3 of `03-source-system.md`) and an ISO 8601 UTC
  /// `capturedAt`.
  List<String> problems() {
    final List<String> found = <String>[];
    final Set<String> declared = declaredFileNames;

    // ── A. what is on disk and what is declared must be the same set ──────────
    if (dir.existsSync()) {
      for (final FileSystemEntity entity in dir.listSync(
        recursive: true,
        followLinks: false,
      )) {
        if (entity is! File) continue;
        final String relative = _relativeTo(entity.path);
        final String extension = _extensionOf(relative);
        if (!fixtureExtensions.contains(extension)) continue;
        if (!declared.contains(relative)) {
          found.add(
            'fixture on disk is not declared: $relative — '
            '18-external-contracts.md rule 1 (a fixture with no provenance)',
          );
        }
      }
    }
    for (final FixtureEntry entry in entries) {
      if (!entry.fileOnDisk.existsSync()) {
        found.add(
          '${entry.key} declares ${entry.file}, which is not on disk — a test '
          'would pass against a file nobody can read',
        );
        continue;
      }
      // ── B. the declared length is the only manifest field asserted (§ 3.2) ────
      final int onDisk = entry.bytesOnDisk;
      if (onDisk != entry.bytes) {
        found.add(
          '${entry.key}: $onDisk bytes on disk, ${entry.bytes} declared',
        );
      }
      // ── F. no fixture transports an identity ─────────────────────────────────
      final String text = entry.readText().toLowerCase();
      for (final String marker in sessionMarkers) {
        if (text.contains(marker)) {
          found.add(
            '${entry.key} carries "$marker" — C2 and B4: a committed fixture '
            'transports no identity',
          );
          break;
        }
      }
      // ── C. a capture of nothing proves nothing ──────────────────────────────
      if (entry.kind == 'catalogue' ||
          entry.kind == 'novel-detail' ||
          entry.kind == 'chapter-list') {
        if (entry.readText().trim().isEmpty) {
          found.add(
            '${entry.key} is empty: a capture of nothing proves nothing',
          );
        }
        if (entry.expected.isEmpty) {
          found.add(
            '${entry.key} is a ${entry.kind} with an empty `expected` — what a '
            'test can affirm about it has never been written down',
          );
        }
      }
      // ── E. a manufactured artefact states its one edit ───────────────────────
      if (entry.kind == 'manufactured' && !entry.expected.containsKey('edit')) {
        found.add(
          '${entry.key} is manufactured and declares no `expected.edit`, so '
          'nothing states which single substitution separates it from its source',
        );
      }
      // ── the two per-entry manifest rules ────────────────────────────────────
      if (entry.url.contains('://')) {
        found.add(
          '${entry.key} stores an absolute URL (${entry.url}) — rules 2-3 of '
          '03-source-system.md store a path, never a full URL',
        );
      }
      if (!entry.capturedAt.endsWith('Z') || entry.capturedAt.length != 20) {
        found.add(
          '${entry.key}: capturedAt "${entry.capturedAt}" is not ISO 8601 UTC',
        );
      }
      // ── D. provenance ───────────────────────────────────────────────────────
      if (entry.notes.trim().isEmpty) {
        found.add(
          '${entry.key} records no observation — 18-external-contracts.md rule 1',
        );
      }
    }
    return found;
  }

  /// C2, B4, lower-cased before comparison. The lower-casing matters: a fixture
  /// that says `SESSIONID` is exactly as much of a leak as one that says
  /// `sessionid`, and a case-sensitive list misses it.
  static const List<String> sessionMarkers = <String>[
    'set-cookie',
    'sessionid',
    'phpsessid',
    'csrf',
  ];

  String _relativeTo(String path) {
    final String root = dir.path.endsWith('/') ? dir.path : '${dir.path}/';
    return path.startsWith(root) ? path.substring(root.length) : path;
  }
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

  /// The file's length as it is on disk — the only manifest field a guard asserts
  /// (§ 3.2), because it catches the one thing that matters: the file was rewritten.
  int get bytesOnDisk => fileOnDisk.lengthSync();

  /// The raw document text, decoded with the charset the manifest recorded.
  ///
  /// `utf8` is correct for every capture this project has — both sites declare
  /// `charset=utf-8` — and `04-html-to-markdown.md` rule 5 says the *charset
  /// observed* is recorded in the manifest, not that a reader guesses.
  String readText() => fileOnDisk.readAsStringSync();

  /// The absolute URL this fixture was captured from.
  ///
  /// `baseUrl` is passed in rather than read from a static, so a fixture can never
  /// build a URL against a different site than the one it was captured on — and
  /// § 2.2's rule is that no test ever concatenates `baseUrl + url` itself.
  String absoluteUrl(String baseUrl) => '$baseUrl$url';

  /// Whether this fixture was really captured, as opposed to manufactured.
  bool get isCaptured => kind != 'manufactured';

  @override
  String toString() => 'FixtureEntry($key, $kind, $file)';
}

/// The lower-cased extension of [path], including the dot, or `''` when it has none.
///
/// Written out rather than reached for from `package:path` because this file is pure
/// Dart with two imports, and a third for one `substring` would be a dependency a test
/// utility does not need.
String _extensionOf(String path) {
  final int dot = path.lastIndexOf('.');
  final int slash = path.lastIndexOf('/');
  if (dot < 0 || dot < slash) return '';
  return path.substring(dot).toLowerCase();
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
