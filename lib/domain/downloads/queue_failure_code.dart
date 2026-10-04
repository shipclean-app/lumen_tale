// Lumen Tale — the codes `queue_items.error_code` may hold, and never a free string.
//
// `5-1` § 6.3 C12: *"a message that can be read aloud and reported back"* — and a
// borrowed-device reader cannot send anything back, so the app has to be able to *name*
// what happened. A column holding `"error 3"` cannot.
//
// ## ⚠️ AN ENUM, AND NOT A `String`, AT EVERY CALL SITE
//
// The column is `TextColumn`, because `DownloadStateConverter` is a name-based
// `TypeConverter` and § 7 forbids storing an ordinal — the same argument applies here.
// The difference is that this enum is **closed at the type level**: `markFailed` takes
// the enum, so "somebody passed an arbitrary string" is not a code review question.
//
// ## ⚠️ THE TWO QUEUE-ONLY CODES ARE NOT `SourceFailure`s
//
// `source_empty` and `no_real_text` are answers this queue reaches without a site
// having refused anything: the first is `BrowseEmpty` (the site's own signal, B22/E8)
// and the second is E18 — a chapter that converted to nothing. Neither is a transport
// cause, and inventing one would let a `BrowseFailed` claim the disk was full.

import 'package:lumen_tale/core/error/source_failure.dart';

/// Everything `queue_items.error_code` can say.
enum QueueFailureCode {
  /// E8 / B22 — the site was read and it genuinely published nothing. **Not a failure
  /// of the transport and not an empty chapter**; it is the site's own statement.
  sourceEmpty('source_empty'),

  /// E18 — the page arrived and converted to no real prose. Refused rather than stored:
  /// an empty `.md` marked as downloaded is the state B6 exists to make unreachable.
  noRealText('no_real_text'),

  /// B3 — the novel names a source this build no longer contains. A **typed** failure,
  /// because "this novel can no longer be refreshed" is a sentence the reader can be
  /// shown, not a crash.
  sourceUnavailable('source_unavailable'),

  /// `architecture.md` § 5.2 — the transport failed. Later, on its own.
  noConnection('no_connection'),

  /// § 5.2 — the site asked us to wait. Wait, then ask again.
  rateLimited('rate_limited'),

  /// § 5.2 — E4/E8/SC-6. The page arrived and held nothing this build looks for.
  sourceLayoutChanged('source_layout_changed'),

  /// § 5.2 / E9 — the site says the chapter is gone. The rest of the queue is
  /// unaffected; this chapter is not coming back.
  itemRemovedAtSource('item_removed_at_source'),

  /// § 5.2 / B22 — the body did not survive parsing.
  parseFailed('parse_failed'),

  /// `CauseUnknown` — **a claim, not a default.** Telling a reader "this app cannot
  /// read its own record" and nothing else is weaker than any of the others and is the
  /// only one that is true.
  causeUnknown('cause_unknown');

  const QueueFailureCode(this.stored);

  /// What the column holds: the enum's own `name`, so a second spelling of a code is
  /// not possible.
  final String stored;

  /// The code for a typed transport cause — **exhaustive, with no `default`.**
  ///
  /// ⚠️ **A `switch` over a sealed hierarchy, not a `toString()` and not a lookup.**
  /// A seventh `SourceFailure` added to `core/error/` without a case here is a compile
  /// error in this file, which is the only place that can notice it.
  static QueueFailureCode of(SourceFailure failure) => switch (failure) {
    NoConnection() => QueueFailureCode.noConnection,
    RateLimited() => QueueFailureCode.rateLimited,
    SourceLayoutChanged() => QueueFailureCode.sourceLayoutChanged,
    SourceUnavailable() => QueueFailureCode.sourceUnavailable,
    ItemRemovedAtSource() => QueueFailureCode.itemRemovedAtSource,
    ParseFailed() => QueueFailureCode.parseFailed,
    CauseUnknown() => QueueFailureCode.causeUnknown,
  };

  /// The code a stored string names, or `null` when it names none of these.
  ///
  /// ⚠️ **`null`, never a fallback to [causeUnknown].** A column written by an older
  /// build is not "unknown" — it is unreadable, and pretending otherwise would report a
  /// cause nobody observed. The caller decides what an unreadable code means.
  static QueueFailureCode? parse(String stored) {
    for (final QueueFailureCode code in QueueFailureCode.values) {
      if (code.stored == stored) {
        return code;
      }
    }
    return null;
  }
}
