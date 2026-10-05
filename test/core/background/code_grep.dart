// Lumen Tale — reading `lib/` as text, for the structural rows.
//
// ⚠️ **NOT A TEST FILE.** No `// forge:slice` marker: the Forge guard resolves a slice's
// tests through that marker, and a file with no `test()` in it would otherwise count as a
// file that declares a slice and verifies nothing.
//
// ## ⚠️ WHY THE COMMENT FILTER IS NOT OPTIONAL
//
// `6-10` has to assert absences — no `registerPeriodicTask`, no `cancelAll`, no schedule in
// the request type — and this project writes long explanations of exactly those absences in
// the very files being grepped. A grep that searched comments would fail on its own
// documentation, and the tempting fix is to weaken the pattern until it passes, at which
// point it proves nothing. Comments are stripped first, exactly as
// `check_never_downloads_test.dart` does it.
//
// ## ⚠️ AND `codeOf` IS WHAT MAKES AN ABSENCE ASSERTABLE FOR A TYPE
//
// There is no `initialDelay` field on `CheckJobRequest`, and Dart has no reflection without
// mirrors — so a test cannot ask the type. Reading the declaration is the only way to fail
// when one is added.

import 'dart:io';

/// Every `.dart` file under [directory], recursively.
Iterable<File> dartFilesIn(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'));

/// The lines of [path] that are **code** rather than a comment.
///
/// ⚠️ **DELIBERATELY CRUDE, AND THE SAME SHAPE `6-4` USES.** Every comment style this
/// project uses is covered: `//`, `///` and a `/* … */` opener. A Dart parse would be more
/// precise and would also fail on the first syntax these files grow tomorrow.
List<String> codeLinesOf(String path) => codeLinesWithNumbers(
  path,
).map(((int, String) record) => record.$2).toList(growable: false);

/// [path]'s code lines with their **1-based line numbers in the file**.
///
/// ⚠️ **THE NUMBERS COME FROM THE FILE, NOT FROM THE FILTERED LIST.** A stripped list has
/// shorter indices, so reporting `i + 1` from it names a line the reader cannot find — and a
/// guard whose output is wrong is a guard nobody trusts when it fires.
List<(int, String)> codeLinesWithNumbers(String path) {
  final List<String> lines = File(path).readAsLinesSync();
  final List<(int, String)> out = <(int, String)>[];
  for (int i = 0; i < lines.length; i++) {
    final String trimmed = lines[i].trimLeft();
    if (trimmed.startsWith('//')) continue;
    if (trimmed.startsWith('*') || trimmed.startsWith('/*')) continue;
    out.add((i + 1, lines[i]));
  }
  return out;
}

/// The whole of [path] with its comments removed, joined by newlines.
///
/// ⚠️ **THE UNIT IS THE FILE, NOT THE LINE.** `dart format` breaks a call across three
/// lines, so a line-based grep for two tokens that belong together finds nothing and passes
/// vacuously — the strongest form this defect takes.
String codeOf(String path) => codeLinesOf(path).join('\n');
