// Lumen Tale — resolving a stored `sourceId` back to the source that produced it.
//
// `architecture.md` § 2. The one question a stored novel asks on every read, and B3's
// reason for caring: **a novel whose source id no longer resolves is a chapter the reader
// can no longer refresh.**
//
// ## Why the collision guard is an `assert` and not a throw
//
// A duplicate id can only arrive from two sources declaring the same name and language,
// because the id is an MD5 of exactly those three things. That is a bug in a list a human
// edits, and a test catches it. Making it a **runtime throw** would mean a release build
// refuses to start over a registry typo, and the reader's library — every novel, every
// reading position — goes with it. The assert is the guard; release keeps the first
// entry, which is degraded rather than fatal.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:lumen_tale/domain/sources/source.dart';

/// Sources by id.
final class SourceManager {
  SourceManager(List<Source> sources) : _byId = _indexById(sources);

  final Map<String, Source> _byId;

  static Map<String, Source> _indexById(List<Source> sources) {
    final Map<String, Source> index = <String, Source>{};
    for (final Source source in sources) {
      assert(
        !index.containsKey(source.id),
        'two sources declare the id ${source.id}; the second is ${source.name}',
      );
      index.putIfAbsent(source.id, () => source);
    }
    return index;
  }

  /// Every id, in registration order.
  Iterable<String> get ids => _byId.keys;

  /// Every source, in registration order.
  Iterable<Source> get sources => _byId.values;

  /// The source with [sourceId], or `null`.
  ///
  /// ⚠️ **`null` and not a throw.** A stored novel naming a source that no longer exists
  /// is a *real* state — a source was withdrawn, or the id derivation moved with a
  /// version bump — and the screen's answer is *"this novel can no longer be refreshed"*,
  /// not a crash. B22 applies to source resolution as much as to a page read.
  Source? byId(String sourceId) => _byId[sourceId];

  @visibleForTesting
  int get length => _byId.length;
}
