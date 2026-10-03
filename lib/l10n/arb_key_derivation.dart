// Lumen Tale — how a screen/dotted key becomes one flat camelCase ARB key.
//
// `localisation` § 2.5. The derivation is a *rule*, and a rule that lives only in
// prose cannot be tested — so it lives here, once, and the tests read this
// function rather than reimplementing it.
//
// Why the rule exists at all: the same string is needed by more than one screen
// (`settings.md` and `settings-reader.md` both write `error.write`), and a key
// invented per screen would be two keys holding the same French text. Deriving
// the key from the screen slug is what makes "one key" enforceable rather than
// hoped for.

/// The separator a screen file uses between its own key segments.
const String arbKeySegmentSeparator = '.';

/// Derives the flat camelCase ARB key for a screen and one of its dotted keys.
///
/// [screenSlug] is the screen's own identifier (`settings`), and [dottedKey] is
/// what the screen file writes (`settings.group.reading`).
///
/// **The one rule with a decision in it**: when the first segment of [dottedKey]
/// repeats [screenSlug], that segment is dropped. `settings.group.reading`
/// becomes `settingsGroupReading`, never `settingsSettingsGroupReading` — the
/// slug is already the key's prefix, and repeating it is the mistake the rule
/// exists to prevent. Every other segment is kept, including digits.
///
/// Throws [FormatException] on an empty segment rather than skipping it: a
/// skipped empty segment turns `row..label` into `rowLabel`, which ships a typo
/// as a string nothing can find.
String arbKeyFor(String screenSlug, String dottedKey) {
  if (screenSlug.isEmpty) {
    throw const FormatException('an ARB key needs a screen slug');
  }

  final dotted = dottedKey.split(arbKeySegmentSeparator);
  for (final segment in dotted) {
    if (segment.isEmpty) {
      throw FormatException(
        'the ARB key "$dottedKey" has an empty segment; a skipped empty segment '
        'is how a typo becomes a string nobody can find',
      );
    }
  }

  final segments = <String>[
    screenSlug,
    // The repeated slug is dropped, and only a repeated slug.
    if (dotted.first != screenSlug) dotted.first,
    ...dotted.skip(1),
  ];

  // Joined with an upper-cased head after the first: segments are authored in
  // lower case (`cause`, `noConnection`, `group`), and the boundary BETWEEN two
  // segments is a real word boundary that has to be marked. Without this the key
  // comes out `sourceUnavailablecausenoConnectionkicker` — one word, and nothing
  // can grep it.
  final cased = segments.map(_camelSegment).toList();
  final buffer = StringBuffer(cased.first);
  for (final segment in cased.skip(1)) {
    buffer.write(_capitalize(segment));
  }
  return buffer.toString();
}

/// Upper-cases the first character, leaving an existing hump alone.
String _capitalize(String segment) {
  if (segment.isEmpty) return segment;
  return segment[0].toUpperCase() + segment.substring(1);
}

/// camelCases one segment, preserving digits and existing camel humps.
///
/// `retention` -> `retention`, `noConnection` -> `noConnection`,
/// `1w` -> `1w`, `12h` -> `12h`, `site-unavailable` -> `siteUnavailable`.
///
/// The digit rule is not cosmetic: these segments transcribe a retention period
/// or an interval, and `interval.12h` losing its `12` would tell the reader
/// something the site never said.
String _camelSegment(String segment) {
  final buffer = StringBuffer();
  var upperNext = false;

  for (final rune in segment.runes) {
    final char = String.fromCharCode(rune);
    if (char == '-' || char == '_' || char == ' ') {
      upperNext = true;
      continue;
    }
    if (upperNext) {
      buffer.write(char.toUpperCase());
      upperNext = false;
    } else if (buffer.isEmpty) {
      // Only the FIRST character is lowercased, so `noConnection` keeps its hump
      // while `NoConnection` becomes `noConnection`.
      buffer.write(char.toLowerCase());
    } else {
      buffer.write(char);
    }
  }

  return buffer.toString();
}
