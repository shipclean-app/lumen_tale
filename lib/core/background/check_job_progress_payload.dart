// Lumen Tale — the integer wire format, and the one place C2 is enforced.
//
// `6-10` § 10's C2 row: *`reportProgress` carries only integers; a test fails if a `String`
// appears in the progress map.* This file is that test's subject and its enforcement.
//
// ## ⚠️ MARKED CLAIM: THE MAP IS BUILT HERE AND NOWHERE ELSE
//
// `workmanager`'s `reportProgress` takes a `Map<String, dynamic>`, which is a shape that
// can hold anything. There are three ways to keep a string out of it, and only one of them
// holds: a comment in the caller, a lint, or **the single builder function**. This file
// provides one builder per payload and a parser per payload, so the values that cross the
// isolate boundary are enumerable — a test can iterate all three builders and assert every
// value is an `int`, which is a row that can actually fail.
//
// The parser is equally strict in the other direction: it accepts `num` and nothing else,
// and **returns `null`** for a payload it does not recognise rather than guessing. A
// malformed map must not become a counter that moves on its own (C8).

import 'package:lumen_tale/domain/updates/check_job.dart';
import 'package:lumen_tale/domain/updates/check_stop_reason.dart';

/// The counter payload: exactly two keys, both integers.
///
/// ⚠️ **NO `phase` KEY, AND THAT IS A DEVIATION FROM `6-10` § 3.2.** The plan's pseudocode
/// writes `{'phase': 'started'}` and `{'phase': 'novels', …}` — a `String`, which its own
/// § 10 C2 row forbids in the same document. A phase is also redundant: the presence of
/// `stopped` or `finished` already distinguishes a terminal payload from a progress one,
/// and a `phase` string would be a fourth vocabulary to keep in step.
Map<String, dynamic> checkJobProgressPayload(CheckJobProgress progress) =>
    <String, dynamic>{'done': progress.done, 'total': progress.total};

/// The terminal payload for a finished pass.
///
/// ⚠️ **THE THREE COUNTS ARE INTEGERS, AND `finished` IS A MARKER RATHER THAN A PHASE.**
/// `'finished': 1` distinguishes this from an interruption without inventing an enum whose
/// values a `String` would then carry. § 10's B37 row wants the reader to hear *what was
/// found*, and *what was found* is three numbers.
Map<String, dynamic> checkJobSucceededPayload(
  CheckJobSucceeded outcome,
  CheckJobProgress progress,
) => <String, dynamic>{
  'done': progress.done,
  'total': progress.total,
  'finished': 1,
  'checked': outcome.checkedNovelCount,
  'failed': outcome.failedNovelCount,
  'discovered': outcome.discovered,
};

/// The terminal payload for a stopped pass.
///
/// ⚠️ **A PLATFORM REASON CROSSES AS ITS INDEX** (`CheckStopReason.wireValue`), for the
/// same reason `finished` is a `1` rather than a word: an Android notification is drawn on
/// a locked screen, so this map is a surface `17-security.md` rule 4 governs, and the
/// smallest legal alphabet on it is the integers.
///
/// ⚠️ **`null` IS THE READER'S OWN GESTURE, AND IT GETS ITS OWN KEY.** `cancel()` releases
/// the interlock before asking WorkManager to stop, so the pass usually ends at its own next
/// cancellation gate with no platform reason at all. Collapsing that into `unknown` would
/// tell the reader *"Android did not say why"* about a cancellation they performed — and
/// `13-error-handling.md` rule 7 requires the two to be distinguishable.
Map<String, dynamic> checkJobInterruptedPayload(
  CheckStopReason? reason,
  CheckJobProgress progress,
) => <String, dynamic>{
  'done': progress.done,
  'total': progress.total,
  if (reason == null) 'cancelled': 1 else 'stopped': reason.wireValue,
};

/// The counter read back out, or `null` when the payload carries no usable pair.
///
/// ⚠️ **`num`, NOT `int`, ON THE WAY IN — AND `toInt()` ON THE WAY OUT.** Android's
/// pigeon codec can hand a `double` for a whole number, and a progress line that refused
/// to render because `7` arrived as `7.0` would be a line that fails exactly when a phone
/// is least cooperative.
CheckJobProgress? parseCheckJobProgress(Map<Object?, Object?> raw) {
  if (!_carriesOnly(raw, _progressKeys)) {
    return null;
  }
  return _progressFrom(raw);
}

/// The terminal outcome read back out, or `null` when the payload is not a terminal one.
///
/// ⚠️ **`stopped` AND `cancelled` WIN OVER `finished`, AND THE ORDER IS DELIBERATE.** A
/// payload carrying both is not a shape any builder produces; if one appears, the
/// interruption is the honest reading because it is the one that must never be reported as
/// a success (C8).
CheckJobOutcome? parseCheckJobOutcome(Map<Object?, Object?> raw) {
  if (!_carriesOnly(raw, _outcomeKeys)) {
    return null;
  }
  final CheckJobProgress? progress = _progressFrom(raw);

  if (progress == null) {
    return null;
  }

  final int? stopped = _intOrNull(raw['stopped']);
  if (stopped != null) {
    final CheckStopReason? reason = CheckStopReason.fromWireValue(stopped);
    // ⚠️ **AN UNRECOGNISED REASON IS DROPPED, NOT SHOWN AS `unknown`.** See
    // `CheckStopReason.fromWireValue`: two different facts must not share one sentence.
    if (reason == null) {
      return null;
    }
    return CheckJobInterrupted(
      reason: reason,
      reachedNovelCount: progress.done,
      totalNovelCount: progress.total,
    );
  }

  if (raw['cancelled'] != null) {
    // ⚠️ **`reason: null`, WHICH IS THE READER.** Not `unknown`: this is the one ending
    // that is nobody's fault and no platform's doing.
    return CheckJobInterrupted(
      reason: null,
      reachedNovelCount: progress.done,
      totalNovelCount: progress.total,
    );
  }

  if (raw['finished'] != null) {
    return CheckJobSucceeded(
      checkedNovelCount: _intOrNull(raw['checked']) ?? 0,
      failedNovelCount: _intOrNull(raw['failed']) ?? 0,
      discovered: _intOrNull(raw['discovered']) ?? 0,
    );
  }

  return null;
}

/// The two numbers out of [raw], or `null` when either is missing or not a number.
///
/// ⚠️ **KEY VALIDATION IS NOT DONE HERE.** The caller decides which key set the payload is
/// allowed to carry — a progress payload and a terminal payload share `done`/`total` and
/// differ in their markers, so validating here would reject every terminal payload the
/// builders produce.
CheckJobProgress? _progressFrom(Map<Object?, Object?> raw) {
  final int? done = _intOrNull(raw['done']);
  final int? total = _intOrNull(raw['total']);
  if (done == null || total == null) {
    return null;
  }
  return CheckJobProgress(done: done, total: total);
}

/// `null` for anything that is not a number.
///
/// ⚠️ **A `String` IS NOT PARSED.** `"7"` is not `7`: a payload whose numbers arrived as
/// text came from a map this app did not write, and accepting it would make the type
/// system a suggestion.
int? _intOrNull(Object? value) => value is num ? value.toInt() : null;

/// The keys a progress payload may carry. Nothing else is a progress payload.
const Set<Object?> _progressKeys = <Object?>{'done', 'total'};

/// ⚠️ **THE TERMINAL MARKERS LIVE IN THE *OUTCOME* SET ALONE, AND THAT IS THE POINT.**
///
/// A progress payload that also carried `finished` would be a payload with two endings. The
/// parsers are strict so that the shape each builder produces is the only shape each parser
/// accepts — see [_carriesOnly].
const Set<Object?> _outcomeKeys = <Object?>{
  'done',
  'total',
  'finished',
  'checked',
  'failed',
  'discovered',
  'stopped',
  'cancelled',
};

/// `true` when every key of [raw] is in [allowed].
///
/// ⚠️ **AN UNKNOWN KEY REFUSES THE WHOLE PAYLOAD, AND THAT IS STRICTER THAN "THE NUMBERS
/// ARE FINE".** A map carrying `inFlightNovelId` proves it came from somewhere this app does
/// not control, and the safe reading of such a map is not *"the counter is probably still
/// right"* — it is *"nothing here can be trusted"*. C2 is about what may reach a locked
/// screen, and a counter that renders from a payload carrying a novel id is a counter driven
/// by data C2 forbids.
bool _carriesOnly(Map<Object?, Object?> raw, Set<Object?> allowed) =>
    raw.keys.every(allowed.contains);
