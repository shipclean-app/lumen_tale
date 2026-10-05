#!/usr/bin/env python3
"""Sabotage-verify the load-bearing rules of slices 5-2 and 5-3.

Why this is a committed `tool/` script
--------------------------------------
`AGENTS.md` § "Every helper script goes in `tool/` — always": the moment a script exists to
make the work easier **or to route around a limitation**, it is a file in `tool/`.

And there is a real limitation here. Every sabotage is "break one line, run one test file,
put the line back" — done by hand, that is twenty minutes of edits in which a restore can be
forgotten and a broken implementation quietly becomes the committed one. This script makes each
sabotage **reversible by construction**: the file is read, the patch is applied to the text in
memory, the patch is written, the named tests are run, and the ORIGINAL BYTES ARE PUT BACK
whatever the outcome. A `finally` that restores is the whole reason this is not a shell loop.

What it asserts
---------------
⚠️ **THAT EACH SABOTAGE MAKES THE NAMED TEST FAIL.** That is the row that matters: a rule
whose test still passes after the implementation is broken is a row that cannot see its own
defect, and two sabotages in this project "passed" for exactly that reason. A sabotage that
does not fail its test is reported as `NOT DETECTED` and is a defect in the TEST, not a pass.

Usage
-----
    python3 tool/sabotage_5_2_5_3.py            # run all of them
    python3 tool/sabotage_5_2_5_3.py 5-2-a     # one of them, by id
"""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

# id, slice, file, old, new, test file, test name fragment, what the rule is
SABOTAGES: list[tuple[str, str, str, str, str, str, str, str]] = [
    (
        "5-2-a",
        "5-2",
        "lib/data/downloads/serial_download_queue_runner.dart",
        "      if (_gate?.blocksNext ?? false) {",
        "      if (false) {",
        "test/features/downloads/download_queue_control_test.dart",
        "the chapter in flight FINISHES, and nothing after it is fetched",
        "B19 — the pause gate is read BEFORE `pending()`, so no further chapter is fetched",
    ),
    (
        "5-2-b",
        "5-2",
        "lib/features/downloads/providers/download_queue_control_provider.dart",
        "    if (!ref.read(connectionProbeProvider).hasConnection) {",
        "    if (false) {",
        "test/features/downloads/download_queue_control_test.dart",
        "offline *Resume*",
        "E5/E7 — *Resume* offline is `stopped` + `no_connection`, not a silent no-op",
    ),
    (
        "5-2-c",
        "5-2",
        "lib/data/downloads/drift_download_queue_repository.dart",
        "          const QueueItemsCompanion(\n"
        "            state: Value<DownloadState>(DownloadState.queued),\n"
        "            startedAt: Value<DateTime?>(null),\n"
        "          ),",
        "          QueueItemsCompanion(\n"
        "            state: const Value<DownloadState>(DownloadState.queued),\n"
        "            startedAt: const Value<DateTime?>(null),\n"
        "            attempts: const Value<int>(0),\n"
        "          ),",
        "test/data/downloads/queue_recovery_test.dart",
        "`attempts` is KEPT",
        "E15/B20 — `attempts` survives the session reset",
    ),
    (
        "5-2-d",
        "5-2",
        "lib/domain/downloads/queue_run_state_deriver.dart",
        "  if (downloading.isNotEmpty) {\n"
        "    return QueueRun(\n"
        "      state: QueueRunState.interrupted,",
        "  if (false) {\n"
        "    return QueueRun(\n"
        "      state: QueueRunState.interrupted,",
        "test/domain/downloads/queue_run_state_deriver_test.dart",
        "ORDER: `downloading` + `!isRunning` is `interrupted`",
        "E15 — a `downloading` row with no loop running IS an interruption, not a pause",
    ),
    (
        "5-2-e",
        "5-2",
        "lib/features/downloads/providers/download_queue_control_provider.dart",
        "    } on AppException {",
        "    } on Never {",
        "test/features/downloads/download_queue_control_test.dart",
        "a FAILED delete restarts the loop and returns `null`",
        "B19/§ 3.5 — a failed cancellation RESTARTS the loop and reports the failure",
    ),
    (
        "5-3-a",
        "5-3",
        "lib/domain/downloads/queue_stop_policy.dart",
        "    QueueFailureCode.noConnection => true,",
        "    QueueFailureCode.noConnection => false,",
        "test/data/downloads/serial_download_queue_runner_error_test.dart",
        "`no_connection` stops it",
        "E7/B19 — a lost connection stops the queue instead of producing N more failures",
    ),
    (
        "5-3-b",
        "5-3",
        "lib/domain/downloads/queue_stop_policy.dart",
        "    QueueFailureCode.noRealText => false,",
        "    QueueFailureCode.noRealText => true,",
        "test/data/downloads/serial_download_queue_runner_error_test.dart",
        "`no_real_text` → `failed`, **no file**, and the queue carries on",
        "E18/E22 — a short chapter is a failure with a retry and never ends the queue",
    ),
    (
        "5-3-c",
        "5-3",
        "lib/core/utils/reader_cleanliness.dart",
        "  final bool hasStructure = markdown.contains('\\n');",
        "  final bool hasStructure = markdown.contains('\\n\\n');",
        "test/core/utils/reader_cleanliness_test.dart",
        "a ONE-LINE 140-character author note",
        "E22 — a legitimate one-line chapter is NOT rejected by the threshold",
    ),
    (
        "5-3-d",
        "5-3",
        "lib/data/downloads/queue_progress_tracker.dart",
        "    final DateTime? last = _lastEmittedAt;\n"
        "    if (last == null || now.difference(last) >= kDownloadProgressCadence) {\n"
        "      _emit(next, now);\n"
        "    }",
        "    _emit(next, now);",
        "test/features/downloads/queue_progress_stream_test.dart",
        "twelve byte counts inside one window",
        "prd.md § 7.1 / 15-performance.md — at most one CHANGED value per 500 ms window",
    ),
    (
        "5-3-e",
        "5-3",
        "lib/data/downloads/serial_download_queue_runner.dart",
        "          _gate?.storageFull(full.bytesNeeded);\n"
        "          full.logStoppedWriting(item.id);\n"
        "          return true;",
        "          await _queue.markFailed(item.id, QueueFailureCode.storageFull);\n"
        "          _gate?.storageFull(full.bytesNeeded);\n"
        "          full.logStoppedWriting(item.id);\n"
        "          return true;",
        "test/data/downloads/serial_download_queue_runner_error_test.dart",
        "the item stays `downloading`",
        "E20/B22 — a full disk stops the QUEUE and never judges the CHAPTER",
    ),
    (
        "5-3-f",
        "5-3",
        "lib/features/downloads/widgets/failed_row.dart",
        "    final bool replayable = entry.state == DownloadState.failed;",
        "    final bool replayable = true;",
        "test/features/downloads/downloads_screen_test.dart",
        "`downloading` and `done` rows carry NO *Retry*",
        "B33 / Read-only — a stored chapter gets no Retry, and not a disabled one either",
    ),
]


def run(cmd: list[str]) -> tuple[int, str]:
    result = subprocess.run(  # noqa: S603
        cmd, cwd=ROOT, capture_output=True, text=True
    )
    return result.returncode, result.stdout + result.stderr


def sabotage(entry: tuple[str, str, str, str, str, str, str, str]) -> str:
    sid, slice_id, rel, old, new, test_file, test_name, rule = entry
    path = ROOT / rel
    original = path.read_text(encoding="utf-8")
    if old not in original:
        return "%-6s %-4s NOT APPLIED — the anchor text is not in %s" % (
            sid, slice_id, rel,
        )

    path.write_text(original.replace(old, new, 1), encoding="utf-8")
    try:
        code, out = run(
            ["flutter", "test", test_file, "--plain-name", test_name]
        )
    finally:
        # ⚠️ **THE RESTORE IS IN A `finally`, AND IT RESTORES THE ORIGINAL BYTES.** A sabotage
        # that left its break in place would be indistinguishable from an implementation.
        path.write_text(original, encoding="utf-8")

    if code == 0:
        return (
            "%-6s %-4s ⚠️  NOT DETECTED — the test still passed with the rule broken.\n"
            "                      rule: %s\n"
            "                      THIS ROW IS THE DEFECT, not the sabotage." % (sid, slice_id, rule)
        )
    return "%-6s %-4s ✅ detected — %s" % (sid, slice_id, rule)


def main(argv: list[str]) -> int:
    wanted = argv[1] if len(argv) > 1 else ""
    entries = [e for e in SABOTAGES if not wanted or e[0] == wanted]
    if not entries:
        print("no sabotage with id %r" % wanted)
        return 1
    for entry in entries:
        print(sabotage(entry))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))