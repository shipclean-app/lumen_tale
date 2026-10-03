// Lumen Tale — the installed version, and how it fails to be readable.
//
// ADR-011: the version is **injected at build time** from `pubspec.yaml`, and this app
// adds no dependency to read it. `flutter build` passes `FLUTTER_BUILD_NAME` and
// `FLUTTER_BUILD_NUMBER` as Dart defines for exactly this purpose, so the version is a
// **constant** the compiler inlines and `package_info_plus` would only re-derive.

/// The two figures, and whether either could be read.
///
/// ⚠️ **A nullable pair, not a formatted string.** Formatting first would turn "missing"
/// into `"0.9.0 · build "` — a version that looks complete and is not, which is the
/// failure `settings-about.md` § 4 forbids by name: *"`Version —` is not used: an em
/// dash looks like a version, and C9 requires the owner to be able to determine which
/// version is installed."*
final class BuildVersion {
  const BuildVersion({required this.buildName, required this.buildNumber});

  /// From `String.fromEnvironment('FLUTTER_BUILD_NAME')`.
  ///
  /// **Empty in a plain `flutter test` and in an IDE run**, which is why the screen has
  /// a Load-error row rather than treating "no version" as a bug.
  final String buildName;

  /// From `String.fromEnvironment('FLUTTER_BUILD_NUMBER')`.
  final String buildNumber;

  /// Whether both figures are present.
  ///
  /// ⚠️ **Both, not either.** A name with no build number identifies a release line and
  /// not a build, and a build number with no name identifies a build of nothing. C9
  /// asks for *which version*, and half an answer is a question mark dressed as a fact.
  bool get isReadable => buildName.isNotEmpty && buildNumber.isNotEmpty;

  @override
  String toString() =>
      'BuildVersion($buildName, $buildNumber, readable: $isReadable)';
}

/// The version this binary was built as.
///
/// A **function**, not a top-level `final`: `String.fromEnvironment` is a compile-time
/// constant, and a `final` would freeze the value at library-initialisation time, which
/// is *also* the answer — but a function makes the read explicit at the call site and
/// lets a test pass its own pair. Two places in this project got that wrong once and
/// the comment is here so the next reader does not re-derive it.
BuildVersion readBuildVersion({
  String buildName = const String.fromEnvironment('FLUTTER_BUILD_NAME'),
  String buildNumber = const String.fromEnvironment('FLUTTER_BUILD_NUMBER'),
}) {
  return BuildVersion(buildName: buildName, buildNumber: buildNumber);
}
