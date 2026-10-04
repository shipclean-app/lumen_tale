// Lumen Tale — the result of reading a chapter off this phone, as a TYPE.
//
// ## Why this is a sealed class and not a `String`
//
// "Not downloaded", "the file is gone", "the file is unreadable" and "here is the
// chapter" are four different claims about the world, and the reader acts differently on
// each. A `String` cannot carry that distinction: the empty string reads as "an empty
// chapter" whichever of the four it actually was, and `2-4`'s whole job is to keep them
// apart. So every branch of the decision returns one of these, and the widget switch on it
// is exhaustive by the compiler.
//
// ## The nine cases, and why none of them is an `ErrorState`
//
// | case | the fact it reports |
// |---|---|
// | [ChapterText] | the file is there and it is Markdown |
// | [ChapterNotStored] | the mark is null — never downloaded |
// | [ChapterOfflineAndAbsent] | the mark is null **and** there is no connection |
// | [ChapterFileMissing] | the mark is set and the file is gone |
// | [ChapterFileEmpty] | the file exists and is zero bytes |
// | [ChapterFileCorrupt] | the file exists and is not readable |
// | [ChapterRowGone] | the chapter row itself is gone |
// | [ChapterLoading] | the file is being read |
// | [ChapterReadFailed] | the read threw, so we do not know which of the above |
//
// Only the last one is an error *this app* had — a filesystem that refused. Everything else
// is a state of the world with its own sentence.

/// One branch of `2-4`'s decision.
sealed class ChapterDocument {
  const ChapterDocument();

  /// The chapter's own id, for every case that has one.
  ///
  /// [ChapterRowGone] has none — the row it would name is what is missing — so it returns
  /// `null` rather than a placeholder string that a caller might route with.
  String? get chapterId => switch (this) {
    ChapterText(:final chapterId) => chapterId,
    ChapterNotStored(:final chapterId) => chapterId,
    ChapterOfflineAndAbsent(:final chapterId) => chapterId,
    ChapterFileMissing(:final chapterId) => chapterId,
    ChapterFileEmpty(:final chapterId) => chapterId,
    ChapterFileCorrupt(:final chapterId) => chapterId,
    ChapterLoading(:final chapterId) => chapterId,
    ChapterReadFailed() => null,
    ChapterRowGone() => null,
  };

  /// ⚠️ **Never logged, and the getter exists to make the attempt visible.**
  ///
  /// B44 keeps chapter prose on the device: a log is one of the ways it leaves. A
  /// `toString()` that returned the Markdown would be a quiet leak, so there is no
  /// `toString()` at all and this is what a stray interpolation produces.
  String get forbidLogging => 'chapter prose is never logged (B44)';
}

/// The normal case: the file is there, it is Markdown, and nothing was fetched.
final class ChapterText extends ChapterDocument {
  const ChapterText({
    required this.chapterId,
    required this.chapterName,
    required this.number,
    required this.ordinal,
    required this.markdown,
    required this.byteLength,
  });

  @override
  final String chapterId;

  /// B10 — the site's title, verbatim. A 120-character title is shown whole here; the
  /// library row and the chapter sheet are where truncation happens, and they mark it with
  /// an ellipsis.
  final String chapterName;

  /// B10 — `null` means **unreadable**, and that is not the same as `0`. An extra, an
  /// omake and an author's note all carry the number zero, and `03-source-system.md` rule
  /// 9 is explicit that `-1` must render as an em dash and never as `0`.
  final double? number;

  /// B9 — the site's own order. `2-7` needs it to know whether a next chapter exists.
  final int ordinal;

  final String markdown;

  /// The **measured** size. `2-7` reads it to decide whether the column needs a virtualised
  /// list, and `downloads.md` shows it as a true figure rather than an estimate.
  final int byteLength;
}

/// The mark is null: **this chapter was never downloaded**.
///
/// Not an error. It is the ordinary state of a chapter opened from a novel the reader did
/// not download whole, and it has its own render **with an action** — US-05 asks the reader
/// to be able to *see* that this is different from empty and from failed.
final class ChapterNotStored extends ChapterDocument {
  const ChapterNotStored({required this.chapterId});

  @override
  final String chapterId;
}

/// The mark is null **and** there is no connection.
///
/// ⚠️ **Two facts, two words.** "Not downloaded" alone leaves the reader wondering whether
/// the button will work; "offline" alone leaves them wondering whether the chapter is
/// theirs. B24 asks for the one sentence that names both, and each is on its own
/// insufficient.
final class ChapterOfflineAndAbsent extends ChapterDocument {
  const ChapterOfflineAndAbsent({required this.chapterId});

  @override
  final String chapterId;
}

/// The mark is set and the file is gone.
///
/// ⚠️ **Unreachable by this application and reachable from outside it** — ADR-022 makes
/// "file without mark" the only direction a crash can leave, so the application cannot get
/// here. A system clean-up, a restore from a backup elsewhere, or a moved support
/// directory can.
///
/// So it has a render and a way out, and the words say that **the download succeeded and
/// the file is what is missing**. "This chapter is unavailable" would tell the reader the
/// download failed, which is false — and a reader who re-downloads on that sentence is
/// doing the right thing for the wrong reason, which is how a second bug hides.
final class ChapterFileMissing extends ChapterDocument {
  const ChapterFileMissing({required this.chapterId, required this.markedAt});

  @override
  final String chapterId;

  /// When the mark was written. It is not decoration: it is the fact that distinguishes
  /// "the download succeeded" from "the download never happened", and the render says so.
  final DateTime markedAt;
}

/// The file exists and is **zero bytes**.
///
/// ⚠️ **A distinct case, and it must stay one.** Zero bytes is the signature of an
/// interrupted write, so the sentence is "the recording was interrupted" and the action is
/// to download again. [ChapterFileCorrupt] also re-downloads, but the word the reader reads
/// is different, and E18/E22 are about *short legitimate* chapters — this is not short,
/// it is absent.
final class ChapterFileEmpty extends ChapterDocument {
  const ChapterFileEmpty({required this.chapterId});

  @override
  final String chapterId;
}

/// The file exists and cannot be read: bad bytes, a truncated multi-byte character, or
/// content that is not Markdown at all.
///
/// ⚠️ **Never rendered as an empty chapter.** "The chapter is empty at the source" and "the
/// stored file is corrupt" are opposite claims, and in each case exactly one of them is
/// false. Rendering both as emptiness tells the reader nothing and hides the fault.
final class ChapterFileCorrupt extends ChapterDocument {
  const ChapterFileCorrupt({
    required this.chapterId,
    required this.reason,
    this.byteLength = 0,
  });

  @override
  final String chapterId;

  /// A **typed** reason, never a message. `13-error-handling.md` forbids a bare reason
  /// string: the reader's sentence comes from this enum's own copy, and a sentence that
  /// lives in two places drifts.
  final ReaderFileFailure reason;

  final int byteLength;
}

/// The chapter row itself is not in the database: a stale deep link, a restored navigation
/// stack.
///
/// ⚠️ **Not a failure.** A stale identifier is a state of the world, and it gets its own
/// render with a way back — not an `ErrorState`, which would report *this app* as broken for
/// a link the user followed.
final class ChapterRowGone extends ChapterDocument {
  const ChapterRowGone();
}

/// The file is being read.
///
/// ⚠️ **Its own case rather than a nullable [ChapterDocument].** A `null` that means
/// "loading" and a `null` that means "failed" are the pair of states a nullable invites to
/// confuse, and `2-4` has both.
final class ChapterLoading extends ChapterDocument {
  const ChapterLoading({required this.chapterId});

  @override
  final String chapterId;
}

/// The read itself threw, so **which** of the above it is remains unknown.
///
/// ⚠️ **Distinct from [ChapterFileCorrupt],** and the difference is that corruption is a
/// *conclusion* while this is the absence of one. `ChapterFileCorrupt` claims the file is
/// bad; this says the app could not find out. The action differs too — retry versus
/// re-download — and picking one here would be a guess.
final class ChapterReadFailed extends ChapterDocument {
  const ChapterReadFailed({this.cause});

  /// Developer-facing. Never shown, never logged with prose attached.
  final Object? cause;
}

/// How a stored file came to be unreadable, and what a reader can do about it.
///
/// ⚠️ **Not `SourceFailure`.** That enum is the vocabulary of **sites**; a local file is not
/// a site, and reusing it would make the reader's sentence say "the site changed" about a
/// file on their phone.
enum ReaderFileFailure {
  /// B18 / E18 — the file is there and holds no readable prose. The only action is to
  /// download it again.
  notMarkdown,

  /// Truncated mid-character: an interrupted write whose final file was still renamed. The
  /// only action is to download it again.
  truncatedUtf8,

  /// The file could not be opened — permissions, I/O. The action is to **try again**, and
  /// offering a re-download for it would suggest the copy is at fault when it may not be.
  unreadableIo,
}
