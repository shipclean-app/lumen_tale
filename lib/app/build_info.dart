// Lumen Tale — the INSTALLED build's identity.
//
// ADR-011: the version is overridden from the git tag and the Actions run number,
// so `pubspec.yaml` and the installed APK disagree from the first CI build onward.
// `3-5`'s About screen (B43) must report what is on the phone, which is why this
// is Dart at all: `pubspec.yaml` is not readable from an installed APK.
//
// Plan `apk-pipeline` § 2.3.

/// The version **as the OS reports it**.
///
/// **Three states, not two.** [buildName] can be absent, [buildNumber] can be
/// absent, and both being absent must render `Version —` and **never** an invented
/// number. `settings.md` § 8 says it outright: *"Absent → the About row reads
/// `Version —` and never an invented number"*.
final class AppBuildInfo {
  const AppBuildInfo({required this.buildName, required this.buildNumber});

  /// `versionName` on Android. `null` when the OS does not report it.
  final String? buildName;

  /// `versionCode` on Android — the `+build` from `pubspec.yaml`, or the Actions
  /// run number when ADR-011 overrides it. `null` when the OS does not report it.
  final String? buildNumber;

  /// `true` when **nothing** could be read. The About screen then renders
  /// `Version —` and nothing else: no date, no branch name, no substitute string.
  bool get isUnknown => buildName == null && buildNumber == null;

  /// The displayable line.
  ///
  /// Exactly one case produces anything other than a dash: **both** values known.
  /// Showing `1.0.0` without the build number would be a partial identifier, and
  /// B31's promise is about **two** identifiers — the owner has to be able to say
  /// which build is installed.
  ///
  /// ⚠️ The dash covers **either** value being absent, not only both. The plan
  /// spells out the `buildNumber`-absent case (`1.0.0` must not appear alone) and
  /// leaves the mirror case to be inferred, so the first draft tested only that one
  /// and `AppBuildInfo(buildName: '1.0.0', buildNumber: null)` rendered
  /// **`1.0.0 (null)`** — a fabricated literal, in the exact place B43 forbids one.
  /// The absence test caught it. `isUnknown` is therefore the wrong guard for this
  /// getter: it is true only when BOTH are absent, while this line needs either.
  String get displayLine => buildName == null || buildNumber == null
      ? '—'
      : '$buildName ($buildNumber)';
}

/// The single source of truth for the installed version, and it is the OS.
///
/// ⚠️ **There is deliberately no implementation of this in the repository.** B43
/// needs the version at RUNTIME and the only correct source is the OS, so it needs
/// `package_info_plus` — which is **not** in `pubspec.yaml`. `apk-pipeline` § 7
/// records this as an open question, and `17-security.md` rule 13 requires a new
/// dependency to go through review.
///
/// Reading `pubspec.yaml` at runtime was rejected for a reason worth keeping: it
/// reads the SOURCE file of the compilation rather than the INSTALLED version, and
/// the two diverge from the first `--build-name` override — that is, from the first
/// CI build. The About screen would report a version the phone does not have.
///
/// `3-5` owns the concrete implementation; until it lands, `main.dart` does not call
/// this, and nothing in the app displays a build line.
abstract interface class BuildInfoReader {
  Future<AppBuildInfo> readInstalledBuild();
}

/// What the pipeline must guarantee to `3-5`, and what is checkable **without** a
/// phone: an artefact's build number is unique per run. Two builds of the same
/// commit must never produce the same `buildName`/`buildNumber` pair, or a bug
/// report naming a version names two different artefacts.
///
/// B31 and ADR-011. Compare both identifiers, because either alone can repeat:
/// `buildName` repeats across runs by design, and `buildNumber` could be reused if
/// the run counter were ever reset.
bool isDistinguishable(
  String buildNameA,
  String buildNumberA,
  String buildNameB,
  String buildNumberB,
) => buildNumberA != buildNumberB || buildNameA != buildNameB;
