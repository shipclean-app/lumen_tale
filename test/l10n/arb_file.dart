// Lumen Tale — reading an ARB file, once, for the rows that need the FILE rather than the
// generated bundle.
//
// ## Why a parser at all
//
// `AppLocalizations` is the product's view of an ARB: getters, typed, no duplicates, no
// `@metadata`. It cannot answer "does this key exist in **both** files", "does the value use
// exactly the placeholders its `@key` declares", or "which keys are missing" — those are
// questions about the file, and asking them of the generated code is asking a compiled answer
// about its own source.
//
// `gen-l10n`'s own `untranslated-messages.json` covers ONE direction of one of them, which is
// why `16-i18n.md` rule 2 can say a French-only key *"is a defect, not a fallback"* while the
// toolchain stays quiet about it.
//
// ## Why this is shared and not private to one test
//
// `arb_completeness_test.dart` has its own private copy, written by `0-1` before this slice
// existed; that file is not this slice's to edit. Two rows in **this** slice's files need the
// same reader, and a second private copy inside a second file is how two parsers end up
// disagreeing about what a placeholder is.

import 'dart:convert';
import 'dart:io';

/// One ARB file, parsed.
class ArbFile {
  ArbFile(this.path, this.text);

  /// Reads [path] from the repository root.
  ///
  /// Synchronous on purpose: every row that uses this runs inside a plain `test()`, never
  /// inside `testWidgets()`. A real `dart:io` future never completes under fake async, so a
  /// `testWidgets()` that awaited one would hang the whole suite rather than fail one row —
  /// and a hung suite is a failure nobody can attribute.
  factory ArbFile.read(String path) {
    final File file = File(path);
    return ArbFile(path, file.readAsStringSync());
  }

  final String path;

  /// The raw file text. Kept because two rows must look at **bytes** rather than at the
  /// parsed tree: the "no class name leaked into a French sentence" grep, and the
  /// untranslated-report check, both of which would be answered wrongly by a re-serialisation.
  final String text;

  late final Map<String, dynamic> data =
      jsonDecode(text) as Map<String, dynamic>;

  /// Every key that is a **message** — `@@locale` and the `@metadata` entries excluded.
  Iterable<String> get messageKeys =>
      data.keys.where((String k) => !k.startsWith('@'));

  bool has(String key) => data.containsKey(key);

  Object? message(String key) => data[key];

  /// The `@key` metadata block for [key], or `null` when there is none.
  Map<String, dynamic>? meta(String key) {
    final Object? raw = data['@$key'];
    return raw is Map<String, dynamic> ? raw : null;
  }

  /// The placeholder names [key]'s **metadata** declares, sorted.
  List<String> declaredPlaceholders(String key) {
    final Object? declared = meta(key)?['placeholders'];
    if (declared is! Map) return const <String>[];
    final List<String> names = declared.keys.cast<String>().toList()..sort();
    return names;
  }

  /// The placeholder names [key]'s **value** interpolates, sorted.
  ///
  /// `{name}` and `{count, plural, …}` are both a name followed by `,` or `}`; the
  /// `[,}]` terminator is what keeps the body of a plural clause from being read as another
  /// name. The result is a SET, because `{count}` appears twice in a plural message and
  /// appearing twice is not a defect.
  List<String> valuePlaceholders(String key) {
    final Object? value = data[key];
    if (value is! String) return const <String>[];
    final Set<String> found = <String>{};
    for (final RegExpMatch match in RegExp(r'\{(\w+)[,}]').allMatches(value)) {
      found.add(match.group(1)!);
    }
    return found.toList()..sort();
  }

  /// The words in [key], counted the way a reader counts them.
  ///
  /// A `{placeholder}` counts as **one** word whatever it expands to: the question is
  /// whether the sentence has substance, and `{source}` is a name, not three words.
  int wordCount(String key) {
    final Object? value = data[key];
    if (value is! String) return 0;
    final String withoutPlaceholders = value.replaceAll(
      RegExp(r'\{[^{}]*\}'),
      ' ',
    );
    return RegExp(
      r'[\p{L}\p{N}]+',
      unicode: true,
    ).allMatches(withoutPlaceholders).length;
  }
}

/// Both ARB files, and the keys only one of them has.
///
/// ⚠️ **Both directions, returned separately.** `gen-l10n` reports a key missing from a
/// *translation*; it does not report a key that exists only in the template's absence, and a
/// key present only in French produces a getter that renders the English template string —
/// invisible until a French reader sees it. `16-i18n.md` rule 2 calls that *"a defect, not a
/// fallback"*, and the only way to hold the line is to check both directions mechanically.
({List<String> onlyEnglish, List<String> onlyFrench}) keyParity(
  ArbFile en,
  ArbFile fr,
) {
  final Set<String> english = en.messageKeys.toSet();
  final Set<String> french = fr.messageKeys.toSet();
  return (
    onlyEnglish: english.difference(french).toList()..sort(),
    onlyFrench: french.difference(english).toList()..sort(),
  );
}
