// Lumen Tale — B18's six choices, and the reason there is no seventh.
//
// `5-1` § 2.2 / § 3.1. Pure Dart, sealed, and every leaf carries the rule it exists for.
//
// ## ⚠️ THERE IS NO "EVERY CHAPTER INCLUDING THE ONES ALREADY READ"
//
// B18 says so in as many words: *"There is no 'download every chapter including ones
// already read' shortcut — that is reachable only by selecting every chapter
// deliberately."* `architecture.md` § 4.5 does not say *next N*; the PRD does. So the
// only path to a chapter the reader has already opened is `HandPicked`, which is
// literally "selected by hand", and `novel-details.md` § 11.3 forbids the *select all*
// affordance that would turn the sixth choice back into the forbidden shortcut.
//
// A seventh case added here — `AllChaptersIncludingRead`, an `enum` value, a bool —
// would be the shortcut with one more line of code on it, and § 10's criterion *"no
// means in the interface to ask for it"* is what makes that unrepresentable rather
// than merely discouraged.

// ## ⚠️ `NextChapter` AND `AllUnopened` ARE DIFFERENT CHOICES, ON PURPOSE
//
// `NextChapter` / `NextChapters(n)` filter on **not stored**; `AllUnopened` filters on
// **not read AND not stored**. The first family says nothing about whether the reader
// has opened the chapter: `novel-details.md` § 11.1 keeps *Next chapter* available on a
// novel whose chapters have all been opened, and a choice that required
// `isRead == false` would be unavailable exactly there — which is why "the next
// chapter" would have meant "the next chapter you have never seen", a different offer.

/// The six things B18 lets a reader ask for, as a closed set.
sealed class BulkChoice {
  const BulkChoice();
}

/// "The next chapter" — the first chapter with no stored copy.
///
/// ⚠️ **It does not filter on `isRead`.** See the file header.
final class NextChapter extends BulkChoice {
  const NextChapter();
}

/// "The next 5 / 10 / 25 chapters" — [count] is one of [allowedCounts] and nothing else.
final class NextChapters extends BulkChoice {
  /// ⚠️ **Three counts, and the assertion is the rule.** B18 names 5, 10 and 25, so a
  /// `NextChapters(7)` is a choice nobody offered. Refusing it **at construction** is
  /// what makes it unrepresentable rather than merely unlisted: the sheet computes its
  /// displayed count through the same resolver that enqueues, so a seventh count would
  /// have been a number a reader saw and a queue that refused to honour.
  const NextChapters(this.count)
    : assert(
        count == 5 || count == 10 || count == 25,
        'B18 offers 5, 10 or 25 chapters, and no other count is a choice a reader '
        'was ever offered',
      );

  /// The only three counts `novel-details.md` § 11.1 lists.
  static const List<int> allowedCounts = <int>[5, 10, 25];

  final int count;
}

/// "All the chapters you have not opened" — the **only** choice that filters on `isRead`.
///
/// ⚠️ **AND NOT STORED, as well as not read.** A chapter the reader opened and then
/// downloaded must not be fetched again (`07-downloads-offline.md` rule 3, *do not
/// refetch*), so the predicate is `!isRead && !isStored`.
final class AllUnopened extends BulkChoice {
  const AllUnopened();
}

/// "The chapters you chose" — **and the order given is the queue's order**.
///
/// ⚠️ **NO REORDERING.** B18 wants a set the reader selected, and `novel-details.md`
/// § 11.3 declares there is **no reordering gesture** in the selection bar. So the
/// reader's insertion order *is* the reading order for this queue, and a resolver that
/// sorted by `ordinal` would discard the only thing the reader expressed.
final class HandPicked extends BulkChoice {
  HandPicked(List<String> chapterIds)
    : chapterIds = List<String>.unmodifiable(chapterIds),
      assert(
        chapterIds.isNotEmpty,
        'B18: an empty selection is a mistap, not a choice — the selection bar only '
        'offers Download while at least one chapter is selected',
      );

  /// Unmodifiable, because a choice is a value and a caller that mutates one has turned
  /// a read into an edit.
  final List<String> chapterIds;
}

/// Every choice, in the order `novel-details.md` § 11.1 lists the six radio rows.
///
/// ⚠️ **Six rows and no more.** `HandPicked` appears **last** because it is not reached
/// from this sheet: § 11.1 says *"the sixth choice is reached by long-pressing tiles,
/// not from this sheet, so that 'a set the user selected by hand' is literally
/// hand-selected"*. It is listed here so the sheet can show what it will hand to the
/// queue — and so a row that counted seven would be caught by a test rather than by a
/// reader.
const List<BulkChoice> kBulkChoices = <BulkChoice>[
  NextChapter(),
  NextChapters(5),
  NextChapters(10),
  NextChapters(25),
  AllUnopened(),
];
