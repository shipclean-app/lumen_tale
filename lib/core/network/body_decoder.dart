// Lumen Tale — body decoding, and why it is not dio's job.
//
// `04-html-to-markdown.md` rule 5: the charset comes from the RESPONSE, never
// from an assumed ASCII. A latin-1 chapter decoded as UTF-8 puts "Ã©" in the
// reader's text, and E18 counts characters — so a mis-decoded page can cross
// the 100-character threshold on the wrong side.
//
// This lives in `core/network` and not in each source: `2-1` and `6-1` need the
// same rule, and two charset implementations would be two answers to "what is a
// character?". `package:html`'s `parseDocument` stays the source's business
// (`2-1` § 2.3) — that is DOM, not transport.
//
// Plan `http-client` § 3.5.

import 'dart:convert';
import 'dart:typed_data';

import 'package:lumen_tale/core/error/app_exception.dart';

/// Decodes a response body, or refuses it.
///
/// Throws [NetworkException] when the body is over [limit]. The body is
/// **not** truncated: a truncated body is malformed HTML that "parses" and
/// yields zero expected elements, which would be reported as
/// `SourceLayoutChanged` — a FALSE diagnosis for a size problem. § 3.4: that is
/// a transport failure.
String decodeBody(
  List<int> bytes, {
  required String? contentType,
  required int limit,
}) {
  if (bytes.length > limit) {
    throw NetworkException(
      'body exceeds the transport ceiling',
      // The size, never the content: a 500 MB body is not evidence and must not
      // end up in an error a reader could be shown.
      status: bytes.length,
    );
  }

  final charset =
      _charsetFromContentType(contentType) ??
      _charsetFromMetaTag(bytes) ??
      _Charset.utf8;
  return _decodeWith(charset, bytes);
}

enum _Charset { utf8, latin1 }

_Charset? _charsetFromContentType(String? contentType) {
  if (contentType == null) return null;
  // `charset=iso-8859-1`, `charset="utf-8"`, any spacing, any case.
  final match = RegExp(
    r'charset\s*=\s*"?\s*([A-Za-z0-9_\-]+)\s*"?',
    caseSensitive: false,
  ).firstMatch(contentType);
  if (match == null) return null;
  return _charsetFromName(match.group(1)!);
}

_Charset? _charsetFromMetaTag(List<int> bytes) {
  // Only the first 2 KiB is inspected. A meta charset is a browser
  // compatibility shim and HTTP requires it in the first 1024 bytes; scanning
  // the whole body to find it would mean decoding the body to decode the body.
  final head = bytes.length > 2048 ? bytes.sublist(0, 2048) : bytes;
  final latin = latin1.decode(head, allowInvalid: true).toLowerCase();
  final match = RegExp(
    "<meta[^>]*charset\\s*=\\s*[\"']?\\s*([a-z0-9_\\-]+)",
  ).firstMatch(latin);
  if (match == null) return null;
  return _charsetFromName(match.group(1)!);
}

_Charset? _charsetFromName(String name) {
  final n = name.toLowerCase().replaceAll('-', '').replaceAll('_', '');
  return switch (n) {
    'utf8' => _Charset.utf8,
    // latin1 covers iso-8859-1 and every ASCII-superset Windows codepage that
    // real web novels actually serve.
    'latin1' ||
    'iso88591' ||
    'windows1252' ||
    'cp1252' ||
    'ascii' ||
    'usascii' => _Charset.latin1,
    _ => null,
  };
}

String _decodeWith(_Charset charset, List<int> bytes) {
  switch (charset) {
    case _Charset.utf8:
      // `allowMalformed` rather than throwing: a page with one bad byte is
      // still a page, and refusing it would turn a rendering blemish into a
      // transport failure. U+FFFD is visible in the text if it matters.
      return utf8.decode(bytes, allowMalformed: true);
    case _Charset.latin1:
      return latin1.decode(bytes);
  }
}

/// The bytes of a body as [Uint8List], used where dio hands back a typed list.
Uint8List asBytes(List<int> data) =>
    data is Uint8List ? data : Uint8List.fromList(data);
