// Lumen Tale — a novel as a site presents it.
//
// `03-source-system.md` § Models, field for field, **and no more**: a field
// invented here becomes a column somebody adds later because "the model already
// had it". `local-store` owns the columns (`novels`, `core/database/`); this
// type owns what a *read* produced, and `2-5`/`6-4` are the writers.
//
// Pure Dart — `02-architecture.md`: `domain/` carries no Flutter import.

import 'package:lumen_tale/domain/sources/source_id.dart';

/// Rule 8 — the shared status enum. A site-specific string is mapped into one of
/// these, and [unknown] is what "the site did not say" becomes.
///
/// ⚠️ **`unknown` is not `ongoing`.** `novels.status` defaults to `''`, and the
/// architecture's mapper example maps `''` to `unknown`, not to `ongoing`: a
/// novel whose status was never published is not an ongoing novel, it is an
/// unanswered question, and the two render differently.
enum NovelStatus {
  /// The site published no status. **Distinct from every value below.**
  unknown,

  ongoing,
  completed,

  /// B10-adjacent: the author has licensed the work away. It is a *state*, not
  /// an error, and it is why `browse-genre.md` can offer a `Licensed` filter
  /// without the platform interpreting a site's word.
  licensed,

  /// Published to a platform that will carry it no further.
  publishingFinished,

  cancelled,
  onHiatus,
}

/// `03-source-system.md` § Models — how often the update checker should revisit
/// a novel.
///
/// Two values, because two answers exist: a serial the reader follows to its end
/// benefits from being re-read, and a finished work does not. `6-4` owns the
/// decision; the enum exists so the decision has a name.
enum UpdateStrategy {
  /// Re-check every sweep.
  alwaysUpdate,

  /// Fetch once. A completed or cancelled novel stops costing requests.
  onlyFetchOnce,
}

/// A novel, as read from a source.
///
/// Immutable by construction: `08-coding-standards.md` forbids a mutable field on
/// a value type, and a `Novel` is a value — a caller that mutates one has turned
/// a read into an edit.
final class Novel {
  Novel({
    required this.id,
    required this.sourceId,
    required this.url,
    required this.title,
    required this.author,
    required this.description,
    required this.status,
    required this.coverUrl,
    required this.genres,
    this.initialized = false,
    this.updateStrategy = UpdateStrategy.alwaysUpdate,
    this.memo = const <String, Object?>{},
  });

  /// B3 — never hand-written. Derived by [SourceId.forNovel] from [sourceId] and
  /// [url].
  final String id;

  /// B2 — the one site this came from. Part of the identity, never nullable.
  final String sourceId;

  /// `03-source-system.md` rule 3 — **relative** (`path + query`), never a full
  /// URL. Hosts change; a stored absolute URL breaks silently.
  final String url;

  /// Rule 8 of `03-source-system.md` mapped onto B10: the site's own text,
  /// verbatim. Never title-cased, never trimmed beyond surrounding whitespace.
  final String title;

  /// **Nullable, and that is the point.** ADR-024: the author is *displayed*,
  /// never searched. The site may publish none, and `library.md` says an absent
  /// author collapses the subtitle line rather than showing an em dash — so `''`
  /// here would assert a value nobody gave us.
  final String? author;

  /// **Plain text, never markup.** B44: the converter drops the tags before this
  /// is stored, so there is no HTML in the database to sanitise later.
  final String? description;

  /// Mapped into [NovelStatus] by the source that read it (rule 8).
  final NovelStatus status;

  /// **Nullable means "this novel has no cover"**, never "we failed to fetch
  /// one" — a failed cover is a read failure, and B22 says a failure is not
  /// rendered as a value.
  final String? coverUrl;

  /// The site's own genre slugs, verbatim. Rule 5: the platform never maps them.
  final List<String> genres;

  /// Whether the detail page has been read. Distinct from `coverUrl == null`,
  /// which says the novel has none.
  final bool initialized;

  /// See [UpdateStrategy]. `6-4` reads it; nothing here decides it.
  final UpdateStrategy updateStrategy;

  /// Rule 7 — small, source-internal, never shown to a reader. A `Map` because
  /// the keys are the source's own, not ours.
  final Map<String, Object?> memo;

  /// Copies this novel with selected fields replaced.
  Novel copyWith({
    String? author,
    String? description,
    NovelStatus? status,
    String? coverUrl,
    List<String>? genres,
    bool? initialized,
    UpdateStrategy? updateStrategy,
    Map<String, Object?>? memo,
  }) {
    return Novel(
      id: id,
      sourceId: sourceId,
      url: url,
      title: title,
      author: author ?? this.author,
      description: description ?? this.description,
      status: status ?? this.status,
      coverUrl: coverUrl ?? this.coverUrl,
      genres: genres ?? this.genres,
      initialized: initialized ?? this.initialized,
      updateStrategy: updateStrategy ?? this.updateStrategy,
      memo: memo ?? this.memo,
    );
  }

  /// **The id and nothing else.**
  ///
  /// ⚠️ Not the title. A `toString` is the most likely accidental carrier of site
  /// text into a log, and `2-1`'s own acceptance criterion for the dropped-row
  /// path is that the site's title never reaches one. Printing it here would
  /// make that criterion true of the source's logger and false of the model,
  /// which is worse than the defect it fixes.
  @override
  String toString() => 'Novel($id)';
}
