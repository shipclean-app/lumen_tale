// Lumen Tale — the notification permission, as a question with an honest default answer.
//
// `6-10` § 2.2's four values and § 3.1's four branches.
//
// ## ⚠️ MARKED CLAIM: `POST_NOTIFICATIONS` CANNOT BE READ WITHOUT A PLUGIN OR NATIVE CODE,
// AND NEITHER IS AVAILABLE TO THIS SLICE
//
// Reading or requesting `POST_NOTIFICATIONS` needs `PackageManager.checkPermission` or
// `NotificationManagerCompat.areNotificationsEnabled()`. Reaching either from Dart requires
// either a permission plugin (v1 adds no dependency — ADR-021 kept `workmanager`, and
// `17-security.md` rule 13 requires an ADR for anything native) or a hand-written
// `MethodChannel` with a Kotlin handler in `android/app/src/main/kotlin/`. `workmanager`
// 0.10.10 itself exposes no permission API — read its `workmanager.dart`, there is none.
//
// So the shipped answer is [UndeclaredNotificationPermissionProbe], and **it is a report,
// not a guess**: it says the app cannot observe the permission, and `6-10` § 3.1 branch 3
// shows what that costs — the pass still runs (B37 says *visible*, not *blocking*), and
// `settings.md` § 4's warning row cannot know to appear. The four branches above it are
// implemented and exercised against a fake probe, so the day a reader arrives they need a
// new **implementation**, not new logic.
//
// ## ⚠️ WHY NOT `granted`?
//
// Because `granted` is a claim about the phone, and this app has just admitted it cannot
// read the phone. Returning `granted` would render `settings.md` § 4's warning row absent
// on the strength of a value nothing measured — the same defect as the stale second copy of
// a number that `invalidateLibraryProviders`'s header calls out. `notApplicable` is the
// only one of the four that is *also true on a platform where the permission exists*: it
// asserts that no dialog will be asked, which is exactly what happens.

import 'package:lumen_tale/domain/updates/check_job.dart';

/// The notification permission, as the app can observe it.
abstract interface class NotificationPermissionProbe {
  /// What the system reports now. Never throws for an unanswerable question — see the
  /// header.
  Future<NotificationPermission> read();

  /// Shows the system dialog **once** and reports what the reader answered.
  ///
  /// ⚠️ **NEVER CALLED TWICE FOR ONE PASS.** `6-10` § 3.1 branch 2: re-asking
  /// immediately after a refusal is the fastest way to earn a permanent refusal, and a
  /// permanent refusal is the one state with no dialog left in it.
  Future<NotificationPermission> request();
}

/// The shipped probe: it cannot read the permission, so it says so.
///
/// ⚠️ **`notApplicable` IS REPORTED, NOT GUESSED, AND THE NAME IS THE DOCUMENTATION.** It
/// is the only value that is true both on Android 12 and earlier (where the permission does
/// not exist) and on a phone where the app has no way to ask — no dialog is ever shown
/// through this path, and `6-10` § 3.1 branches 1, 3 and 4 all converge on *run the pass
/// anyway*, which is B37's actual requirement.
final class UndeclaredNotificationPermissionProbe
    implements NotificationPermissionProbe {
  const UndeclaredNotificationPermissionProbe();

  @override
  Future<NotificationPermission> read() async =>
      NotificationPermission.notApplicable;

  @override
  Future<NotificationPermission> request() async =>
      NotificationPermission.notApplicable;
}
