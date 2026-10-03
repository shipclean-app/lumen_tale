// Lumen Tale — a response read, with the body that goes with it.
//
// The transport is the first producer of `FetchResult` — and the only owner of
// the file that assembles it. `FetchResult` itself carries three facts (a
// status, a host, a duration) and no body. What this file adds is the BODY,
// without which `ContentProbe`, `parseDocument` and `fetchChapterContent` have
// nothing to look at.

import 'package:lumen_tale/core/network/fetch_result.dart';

/// A response that has been read, with its body.
///
/// `FetchResult` cannot travel alone: it describes *what the transport did*,
/// not *what the site answered*. The two go together, and this type is the only
/// place they are assembled. Plan `2-1` § 2.3 returns **this** type, never
/// `FetchResult`: a source needs the status in order to classify **and** the body
/// in order to parse, and returning the bare discriminant would stop it reading
/// a page.
final class HttpResponse {
  const HttpResponse({
    required this.outcome,
    required this.status,
    required this.body,
    required this.contentType,
  });

  /// What classification consumes as-is. Never null.
  final FetchResult outcome;

  /// The HTTP status. `0` when no response arrived at all — and then [outcome]
  /// is a `FetchTransportFailed`, never a `FetchSucceeded(0)`.
  final int status;

  /// The **decoded** body. Empty when [status] is `0`: there was nothing to
  /// decode, and an empty body presented as a read body would be the mirror
  /// defect of E8.
  final String body;

  /// The response `Content-Type`, **raw** — it is evidence and it decides
  /// decoding (§ 3.5). Never localized, never rewritten.
  final String? contentType;

  /// `true` when a response actually arrived, whatever its status. This is the
  /// predicate `failure-discriminator` uses for its second arm.
  bool get hasResponse => status != 0;
}
