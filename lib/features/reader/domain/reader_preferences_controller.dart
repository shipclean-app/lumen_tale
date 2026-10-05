// forge:slice 2-8
// Lumen Tale — the reader's way of writing the two display values, and **only** that.
//
// ## ⚠️ This is a TEST SEAM, and it creates no second stack
//
// `theme-type` owns the whole pipeline end to end: `appThemePreferencesProvider`, the
// `SharedPreferences` behind it, the four `read…` / `write…`, and the two notifiers whose
// `select` writes **and then** mutates. This file adds none of that. It is an interface
// the reader's widgets program against, so a widget row can substitute a controller that
// refuses a write and watch the control snap back — which is the only way the failure
// state of § 3.4 is observable at all.
//
// The plan's § 2.2 records that an earlier draft of this interface returned
// `Future<bool> setScale` and never threw. That is not a different signature, it is a
// **different failure contract**: a `bool` a screen forgets to read is a preference that
// silently did not save, while `theme-type` throws and leaves the state untouched. Two
// semantics of failure for one preference is the defect, so the interface **propagates**
// and says so.
//
// ## ⚠️ No `SharedPreferencesReaderPreferences` exists, and must not
//
// § 2.2 strikes that row. It would be a second read/write path for two keys that already
// have one, and `05-state-management.md` rule 8 (`a preferences interface is a provider`)
// is the rule that forbids it. The provider below *is* the implementation.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:lumen_tale/app/theme/reader_scale.dart';
import 'package:lumen_tale/app/theme/theme_override.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';

/// What the reader's controls may ask for, and what they may read back.
abstract interface class ReaderPreferencesController {
  /// The stored step. **The stored one** — never the step a control is trying, because a
  /// reader that previews a value the app cannot keep is the exact failure § 3.4 names.
  ReaderTextScale get scale;

  /// The stored override.
  ThemeOverride get themeOverride;

  /// Writes [step] and then adopts it.
  ///
  /// ⚠️ **Propagates the write failure.** `ReaderTextScaleNotifier.select` writes before it
  /// mutates, so a throw leaves [scale] where it was and there is nothing to roll back.
  Future<void> selectScale(ReaderTextScale step);

  /// Writes [value] and then adopts it. Propagates, for the same reason.
  Future<void> selectOverride(ThemeOverride value);
}

/// The reader's controller: a **facade** over `theme-type`'s two providers.
///
/// ⚠️ **`keepAlive` is inherited, not declared.** Both underlying providers are
/// `NotifierProvider`s with no `autoDispose`, so the value survives leaving the reader — which
/// is what B27's *"the in-app choice survives closing the app"* needs on top of the storage
/// it is persisted through. A second `keepAlive` wrapper would be a claim about a lifetime
/// this file does not own.
final readerPreferencesControllerProvider = Provider<ReaderPreferencesController>((
  Ref ref,
) {
  // ⚠️ **Both providers are WATCHED, and neither value is kept.** Watching is what
  // makes a widget that `ref.watch`es this facade rebuild when the reader changes a
  // setting; discarding the value is what keeps [scale] from being a snapshot. An
  // earlier version captured them and stopped watching, and the chrome kept showing
  // the previous theme until something else happened to rebuild it.
  ref.watch(readerTextScaleProvider);
  ref.watch(themeOverrideProvider);
  return _ProviderBackedController(ref);
});

/// ⚠️ **Every value is READ ON DEMAND through the `Ref`, never captured into a field.**
///
/// The first version took the two values as constructor arguments, and it was wrong in a way
/// only a row could see: a caller holding a *previous* instance of the facade kept reading
/// the *previous* step — so a widget holding this object across a write displayed the size
/// the reader had just rejected. A facade that forwards each read to the provider it fronts
/// cannot go stale, and it is the reason this class holds no state rather than merely having
/// none to declare.
final class _ProviderBackedController implements ReaderPreferencesController {
  const _ProviderBackedController(this._ref);

  final Ref _ref;

  @override
  ReaderTextScale get scale => _ref.read(readerTextScaleProvider);

  @override
  ThemeOverride get themeOverride => _ref.read(themeOverrideProvider);

  @override
  Future<void> selectScale(ReaderTextScale step) =>
      _ref.read(readerTextScaleProvider.notifier).select(step);

  @override
  Future<void> selectOverride(ThemeOverride value) =>
      _ref.read(themeOverrideProvider.notifier).select(value);
}
