// Lumen Tale — the typed exception hierarchy.
//
// `13-error-handling.md`, word for word. Canonical path is `core/error/` per the
// layer table in `02-architecture.md`: `core/` is a leaf layer, so an exception
// that `domain/` must catch cannot live under `core/utils/`, which is internal
// to `core`. It moved here from `core/utils/errors/` on 2026-10-02.
//
// The hierarchy is `sealed`, so `catch (e)` over `AppException` is exhaustive at
// compile time and a new member breaks every caller that must decide about it.

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
