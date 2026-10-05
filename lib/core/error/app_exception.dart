// Lumen Tale — the typed exception hierarchy.
//
// `13-error-handling.md`, word for word. Canonical path is `core/error/` per the
// layer table in `02-architecture.md`: `core/` is a leaf layer, so an exception
// that `domain/` must catch cannot live under `core/utils/`, which is internal
// to `core`. It moved here from `core/utils/errors/` on 2026-10-02.
//
// The hierarchy is `sealed`, so `catch (e)` over `AppException` is exhaustive at
// compile time and a new member breaks every caller that must decide about it.
//
// ⚠️ **`5-3`'s `StorageFullException` IS **NOT** IN THIS HIERARCHY, AND IT WAS.** See
// `storage_full_exception.dart`'s header: a `sealed` base charges every addition to every
// exhaustive `switch` over it, and two of them live in files this slice does not own. A full
// disk is a *write* failure and never arrives as a `BrowseFailed` — the same argument
// `ChapterStoreException` makes.

/// The root of every named application error.
sealed class AppException implements Exception {
  const AppException(this.message, {this.cause});

  /// **For a developer, never for the reader.** The UI does not display it: it
  /// maps the *type* to a localized message (`13-error-handling.md` rule 5,
  /// B28). C12 additionally requires that message to be readable aloud to
  /// someone who has to describe the failure to the owner.
  final String message;

  /// The primitive error underneath, kept for on-device diagnosis.
  ///
  /// This is where the `DioException` lives. B29 forbids transmitting it, so
  /// nobody does: it is carried, never sent.
  final Object? cause;

  @override
  String toString() => '$runtimeType: $message';
}

/// A network failure — timeouts, DNS, TLS, socket, and the 5xx family.
///
/// A 5xx arrives here as a *transport* failure even though a response was
/// received, because `HttpResponse.outcome` is what decides the difference and
/// this type only records what can be diagnosed.
final class NetworkException extends AppException {
  const NetworkException(super.message, {super.cause, this.host, this.status});

  /// The hostname, never a path and never a query. C5 / `17-security.md` rule 1:
  /// a cause crossing an error layer does not carry a URL, so it can never
  /// carry the string the reader typed.
  final String? host;

  /// The status, or `null` when no response arrived at all.
  final int? status;
}

/// The reader cancelled. `13-error-handling.md` rule 7: the caller distinguishes
/// "cancelled" from "failed" and **shows no error at all**.
final class CancelledException extends AppException {
  const CancelledException({super.cause})
    : super('the request was cancelled by the reader');
}

/// A site could not be read the way this source reads it.
///
/// ⚠️ **This is not `SourceFailure`, and the two must not be merged.**
/// `SourceFailure` is what a **read returns** — `BrowseFailed(reason)` carries it,
/// nothing throws it, and it is sealed over the seven causes of
/// `architecture.md` § 5.2. This is what a **repository or an interactor throws**
/// when it needed a page and the page did not arrive, and a caller catches it
/// specifically to offer "try again".
///
/// Two representations of one fact is the shape this project has been bitten by
/// twice already (`SKILL.md` § Discipline de vérification, rule 10), so the
/// distinction is written down rather than left to be re-derived: reads return,
/// writes throw, and the two travel in opposite directions.
final class SourceException extends AppException {
  const SourceException(
    super.message, {
    super.cause,
    this.sourceId,
    this.status,
  });

  /// The site, when the failure is attributable to one. **Never** the site that
  /// hosts the *file* — this is a network read, not a disk read.
  final String? sourceId;

  /// The HTTP status, or `null` when no response arrived.
  ///
  /// C7: a status is **evidence**, and evidence a screen can show. It is not free
  /// text, and it is not a sentence: the sentence lives in the ARB.
  final int? status;
}

/// A storage operation failed — drift, or the filesystem under it.
///
/// `13-error-handling.md` rule 2: a primitive `IOException` or `SqliteException`
/// is wrapped here so a caller never sees the driver.
final class DatabaseException extends AppException {
  const DatabaseException(super.message, {super.cause, this.operation});

  /// What was being attempted (`'read library'`, `'delete queue row'`). Present
  /// because a bare "storage error" is not something a reader can describe, and
  /// C12 asks for a failure state they can describe **in words**.
  final String? operation;
}

/// A chapter's body is not available — not downloaded, absent at the site, or
/// removed.
///
/// Distinct from `SourceException`: a missing body is not a broken site, and the
/// two produce different screens. Catching them together would show a reader
/// "the site changed" for a chapter they simply never downloaded.
final class ChapterNotAvailableException extends AppException {
  const ChapterNotAvailableException(
    super.message, {
    super.cause,
    this.chapterId,
  });

  /// The chapter, by id. Present so the failure is traceable to one row; it is
  /// **never** displayed — B44: no chapter prose, and a title is site text.
  final String? chapterId;
}
