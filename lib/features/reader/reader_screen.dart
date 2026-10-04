// Lumen Tale — `/reader/:novelId/:chapterId`, and only what is already on the phone.
//
// ## Three rules this screen is built around
//
// **1. It never fetches.** `2-4` § 3.2: the guarantee is structural — the repository's type
// has no network capability to call. An unstored chapter offers "Download this chapter" and
// emits the intent; `3-3` executes it.
//
// **2. The position is written at a scroll SETTLE, and nowhere else.** B16. A
// `NotificationListener` filtered on `ScrollEndNotification` and on a
// `UserScrollNotification` whose direction is `idle` — **not** a `Timer`. A timer fires
// during a finger-driven scroll and writes an offset the reader has not reached. `jumpTo`
// and `animateTo` also produce a settle, and they *must* write: the position after a
// programmatic jump is a real position.
//
// **3. `markOpened` fires once, on first DISPLAY.** B13 and `2-4` § 3.4. A reader can open a
// chapter from the reading-zone tap, from the chapter sheet, from history or from
// "Continue"; marking inside one tile's `onTap` catches one of the four. Display is the only
// moment all of them share, and the only moment it is true that the reader has seen it.
//
// ## ⚠️ Nothing is written on the way back
//
// `reader.md` § 5: "le retour ne doit rien enregistrer". The position was already written at
// the last settle, and a back press that writes is a write on the hot path.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:lumen_tale/app/router/app_routes.dart';
import 'package:lumen_tale/app/theme/theme_providers.dart';
import 'package:lumen_tale/domain/reader/chapter_document.dart';
import 'package:lumen_tale/features/reader/domain/reader_typography.dart';
import 'package:lumen_tale/features/reader/mark_opened_once.dart';
import 'package:lumen_tale/features/reader/reader_providers.dart';
import 'package:lumen_tale/features/reader/widgets/chapter_prose.dart';
import 'package:lumen_tale/features/reader/widgets/reader_controls.dart';
import 'package:lumen_tale/features/reader/widgets/reader_states.dart';

/// The reader, for one chapter.
class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.chapterId, super.key});

  /// ⚠️ **`chapterId` and nothing else.** The stored file is named from the row's ordinal,
  /// and the repository reads that from the row — so a URL carrying an ordinal would be a
  /// second copy of a fact with a second chance to be wrong.
  final String chapterId;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  /// Whether the reading chrome is revealed. **A `State`, not a provider** — it is
  /// ephemeral and must not survive leaving the chapter, or a reader who toggles it off
  /// would find it on again on return.
  bool _chromeVisible = false;

  /// B13 — `markOpened` runs **once** per mount. See [OnceGate] for why this is a class and
  /// not a `bool` on this `State`.
  final OnceGate _markedOpened = OnceGate();

  /// B13, once, on the first frame that shows prose.
  ///
  /// Called from `build`'s state branch rather than from an `initState` future, because
  /// "displayed" and "the widget exists" are different moments and only the first is what
  /// B13 means.
  void _markOpenedOnce() {
    _markedOpened.run(() {
      // ignore: discarded_futures
      ref.read(markReaderOpenedProvider)(widget.chapterId);
    });
  }

  /// B16 — a scroll settle, which is the only instant the position is known and stable.
  ///
  /// ⚠️ **The metrics come from the NOTIFICATION, not from a `ScrollController`.**
  ///
  /// The first version held a controller and read `controller.position` — and it silently
  /// wrote nothing, because the controller was never attached to the list it was reading
  /// about. Two defects in one line of code: a `hasClients` guard was **hiding** the
  /// mistake rather than surfacing it, and nothing in the type said which scrollable was
  /// meant.
  ///
  /// `ScrollNotification.metrics` is **the scroller that produced the notification**, so
  /// there is no second thing to keep in step, and the guard becomes unnecessary — a settle
  /// always carries metrics.
  void _onSettle(ScrollNotification notification) {
    final ScrollMetrics metrics = notification.metrics;
    // ignore: discarded_futures
    ref.read(writeReaderPositionProvider)(
      chapterId: widget.chapterId,
      offset: metrics.pixels,
      // ⚠️ **`maxScrollExtent` as measured right now**, and the store turns a `0` into
      // `null` — because `0` is not a measurement, and a stored `0` would re-anchor a
      // restore against a chapter that was never measured.
      contentHeight: metrics.maxScrollExtent,
    );
  }

  bool _isSettle(ScrollNotification notification) {
    return switch (notification) {
      ScrollEndNotification() => true,
      // ⚠️ **A `UserScrollNotification` whose direction is `idle`** is the thumb leaving the
      // screen; one still dragging is not a settle and must not write.
      UserScrollNotification(:final direction) =>
        direction == ScrollDirection.idle,
      _ => false,
    };
  }

  @override
  Widget build(BuildContext context) {
    final ReaderRequest request = ReaderRequest(chapterId: widget.chapterId);
    final AsyncValue<ChapterDocument> document = ref.watch(
      readerDocumentProvider(request),
    );

    return Scaffold(
      // ⚠️ **No `appBar`, and no title bar at all** while the prose is up (§ 3.5). The
      // controls live in the chrome `2-4` reveals on a tap.
      body: document.when(
        loading: () => const ReaderProseSkeleton(),
        error: (Object error, StackTrace stack) => ReaderStateView.forDocument(
          context,
          ChapterReadFailed(cause: error),
          _actions(context),
        ),
        data: (ChapterDocument value) => switch (value) {
          ChapterText() => _prose(value),
          _ => ReaderStateView.forDocument(context, value, _actions(context)),
        },
      ),
    );
  }

  Widget _prose(ChapterText text) {
    // ⚠️ **B13 fires HERE**, in the branch that means "the prose is on screen". § 3.4 is
    // explicit that the alternative — marking in a tile's `onTap` — catches one of the four
    // ways a reader reaches a chapter.
    _markOpenedOnce();

    final bool offline = !ref.watch(hasConnectionProvider);

    // ⚠️ **THE PROSE IS DERIVED HERE, and nowhere else.** `2-8` § 5: the `TextStyle` is a
    // pure derivation of three inputs, recomputed by Flutter on each build, and storing it
    // would be a second source of truth that diverges the moment the phone's font size
    // changes — which is E14. Two `ReaderProse.fromContext` calls on this screen would be two
    // objects free to disagree about the same chapter's type.
    final ReaderProse prose = ReaderProse.fromContext(
      context,
      ref.watch(readerTextScaleProvider),
    );

    return GestureDetector(
      // ⚠️ **A tap on the reading zone toggles the chrome and does NOTHING else.** No
      // `onTap` here may fetch, save or mark: this is the tap that most tempts an
      // implementation to do work.
      onTap: () => setState(() => _chromeVisible = !_chromeVisible),
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: <Widget>[
          // ⚠️ **ALWAYS IN THE TREE, revealed by an animation rather than inserted.**
          // Building the chrome conditionally is what `2-4` did, and it cannot fade —
          // there is no previous frame to fade *from*. `ReaderControls` owns the reveal
          // because § 2.6 gives it three states and `hidden` is one of them.
          ReaderControls(
            visible: _chromeVisible,
            onBack: () => Navigator.of(context).maybePop(),
          ),
          if (offline) const ReaderOfflineNote(visible: true),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (_isSettle(notification)) {
                  _onSettle(notification);
                }
                return false;
              },
              child: ChapterProse(
                document: text,
                prose: prose,
                // ⚠️ **The measure comes from the SAME prose**, so the cap is computed on the
                // RESOLVED size — the step times the phone's scale. A cap computed on the
                // step's nominal size would let the column reach ~95 characters at 200%,
                // which is the whole defect E14 describes.
                layout: prose.measureLayout(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// ⚠️ **The four intents are wired to nothing here**, because `2-4` emits and `3-3`
  /// executes. A screen that enqueued its own download would need the queue, and the queue
  /// would then be reachable from the reader — which is how the "local only" guarantee grows
  /// a second path.
  ReaderActions _actions(BuildContext context) => ReaderActions(
    downloadChapter: () => debugPrint(
      '2-4 emits downloadChapter(${widget.chapterId}); 3-3 executes it',
    ),
    openDownloads: () => GoRouter.of(context).go(AppRoutes.downloads),
    goBack: () => Navigator.of(context).maybePop(),
    retry: () => ref.invalidate(readerDocumentProvider),
  );
}
