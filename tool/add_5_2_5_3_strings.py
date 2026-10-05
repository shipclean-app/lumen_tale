#!/usr/bin/env python3
"""Declare slices 5-2 and 5-3's ARB entries, in both languages, hash-guarded.

Why this is a committed `tool/` script and not an inline edit
--------------------------------------------------------------
Two reasons, and the second one has already cost this project twenty-one messages.

1. `AGENTS.md` § "Every helper script goes in `tool/` — always": the moment a script
   exists to make the work easier or to route around a limitation, it is a file in
   `tool/`, committed.

2. **`lib/l10n/app_*.arb` is a SHARED file and other agents were editing it at the same
   time.** `6-7` lost twenty-one of `3-3`'s messages to exactly that: two writers read
   `app_*.arb`, each computed its own full document, and the second write discarded the
   first's keys. A read-modify-write done as a heredoc has no protection against it.

So this writer:

  * **inserts textually** — never `json.dumps` — so a diff is one added line per key and
    every other byte of an 86 KB file is left alone;
  * **re-hashes immediately before writing** and refuses if the file moved;
  * **re-reads after writing** and fails if any key it was asked to add is not there.

B28 is checked here rather than in review
----------------------------------------
⚠️ **A TRANSLATED PLACEHOLDER NAME DOES NOT RENAME A PARAMETER — IT ADDS ONE.** This project
has shipped that bug twice. The writer therefore refuses to emit a key whose EN and FR
placeholder **sets** differ, and the refusal happens before anything is written.

Usage
-----
    python3 tool/add_5_2_5_3_strings.py            # write
    python3 tool/add_5_2_5_3_strings.py --check    # exit 1 if anything is missing
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB = ROOT / "lib" / "l10n"
FILES = ("app_en.arb", "app_fr.arb")

# key -> (description, en, fr). Placeholders are part of the strings and MUST match.
#
# ⚠️ **ONE TABLE, BOTH LANGUAGES, FOR THE REASON IN THE MODULE DOCSTRING.** A key added to
# one file and not the other is a defect, not a fallback (`16-i18n.md` rule 2).
STRINGS: dict[str, tuple[str, str, str]] = {
    # ── 5-2 · the standing notice and the queue's own words ────────────────────
    "downloadsTitle": (
        "The screen's title. `downloads.md` § 3: a title bar back to /more.",
        "Downloads",
        "Téléchargements",
    ),
    "downloadsInProcessNotice": (
        "E7, and the reason it is the FIRST line under the title in EVERY state. "
        "`flows.md` § 4.4 calls this 'the single most likely over-promise in the product': "
        "every competing reader ships a background download service, so the default "
        "expectation is that closing the app just moves the bar somewhere invisible.",
        "Downloads continue only while the app is open.",
        "Les téléchargements ne continuent que tant que l'application est ouverte.",
    ),
    "downloadsQueueSectionLabel": (
        "The `DOWNLOAD QUEUE` overline. `--text-overline`, 600, letter-spaced.",
        "DOWNLOAD QUEUE",
        "FILE DE TÉLÉCHARGEMENT",
    ),
    "downloadsFailedSectionLabel": (
        "`downloads.md` § 3's `COULD NOT DOWNLOAD` overline, and § 4: the section is NOT "
        "rendered at all when empty.",
        "COULD NOT DOWNLOAD",
        "TÉLÉCHARGEMENT IMPOSSIBLE",
    ),
    "downloadsHeaderCounts": (
        "C8: both numbers EXACT. `downloaded` is `count(state='done')`, never 13 after a "
        "failure and never 11 after a cancellation. Declared with `placeholders` because a "
        "translated placeholder NAME would ADD a parameter rather than rename one (B28).",
        "{downloaded} of {total} downloaded",
        "{downloaded} sur {total} téléchargés",
    ),
    "downloadsInProgressSuffix": (
        "The `· 1 in progress` half of the header. B18 makes it at most one, so the string "
        "carries the number and the row carries the chapter.",
        "· {count} in progress",
        "· {count} en cours",
    ),
    "downloadsPauseAction": (
        "B19: 'Stop before the next chapter'. C11: 48dp, and no gesture — a swipe that "
        "stopped a queue would be a swipe nobody asked for.",
        "Pause",
        "Pause",
    ),
    "downloadsResumeAction": (
        "B21: continue FROM the chapter it stopped at, never from chapter one.",
        "Resume",
        "Reprendre",
    ),
    "downloadsCancelAction": (
        "B19's cancellation, and the only destructive control on the screen — hence the "
        "confirmation dialog rather than a button.",
        "Cancel download",
        "Annuler le téléchargement",
    ),
    "downloadsPausedLabel": (
        "E7/B19. `--color-warning` PLUS this word PLUS an icon: "
        "`14-design-tokens.md` § Accessibility forbids a colour-only state.",
        "Paused",
        "En pause",
    ),
    "downloadsStoppedLabel": (
        "E7's state. C12: the reader must be able to say 'the downloads stopped' aloud to "
        "whoever owns the phone.",
        "Stopped",
        "Arrêté",
    ),
    "downloadsRunningLabel": (
        "The status word while the loop is moving. Shown as a word and not only as a bar, "
        "for the same reason as Paused.",
        "Downloading",
        "Téléchargement en cours",
    ),
    "downloadsStoppedNoConnection": (
        "E7/E5. `downloads.md` § 4 *Offline*: the reason in WORDS, not an icon alone — "
        "C11 is a one-handed, often-glanced context at night.",
        "No connection",
        "Aucune connexion",
    ),
    "downloadsStoppedRateLimited": (
        "`17-security.md` rule 6 and `5-3` § 3.2: the site sent 429 with Retry-After, and "
        "the answer is to WAIT for the time the site named — never a guessed one.",
        "The site asked us to wait until {time}.",
        "Le site nous a demandé d'attendre jusqu'à {time}.",
    ),
    "downloadsStoppedSourceUnreadable": (
        "B22: ONE line for a broken site, not one per chapter. C12 needs the sentence to be "
        "sayable, and it names the SITE.",
        "Lumen Tale could not read {source}.",
        "Lumen Tale n'a pas pu lire {source}.",
    ),
    "downloadsStoppedOutOfStorage": (
        "E20. `downloads.md` § 9 refuses to DISPLAY free space — the app has no honest way "
        "to read it without a platform channel it has not earned — so the honest sentence is "
        "the fact and the action, and no figure.",
        "The phone is out of storage. Free up some space, then resume.",
        "Le téléphone n'a plus de stockage. Libérez de l'espace, puis reprenez.",
    ),
    "downloadsWillNotContinueOnItsOwn": (
        "E7, and the sentence that closes the trap. `downloads.md` § 4 says it goes on the "
        "line BELOW the reason, in the stopped state — the reader is most likely to wonder "
        "exactly here.",
        "It will not continue on its own when the signal comes back.",
        "Il ne reprendra pas tout seul quand le signal reviendra.",
    ),
    "downloadsCancelledKept": (
        "B19: the reader needs to know what SURVIVED. A cancellation that reported nothing "
        "would leave them wondering whether chapter 12 was deleted.",
        "Download cancelled — {kept} chapters kept.",
        "Téléchargement annulé — {kept} chapitres conservés.",
    ),
    "downloadsCancelFailedSnackbar": (
        "`downloads.md` § 4 *Submit error (a)*, verbatim in substance: the ONE submission "
        "in the app whose failure must INVERT the display, because a queue shown as "
        "cancelled while it keeps writing chapters is what B19 forbids.",
        "Could not cancel. The download is still running.",
        "Impossible d'annuler. Le téléchargement est toujours en cours.",
    ),
    "downloadsEmptyTitle": (
        "`downloads.md` § 4 *Empty — never visited*. The body states the BENEFIT in the "
        "reader's terms, because that is the one thing a download queue is for.",
        "Nothing is downloaded yet",
        "Rien n'est encore téléchargé",
    ),
    "downloadsEmptyBody": (
        "The body's sentence. `downloads.md` § 4: 'Downloaded chapters read with no signal "
        "at all' — the benefit, not the mechanism.",
        "Downloaded chapters read with no signal at all. Start one from any novel's page.",
        "Les chapitres téléchargés se lisent sans aucune connexion. Lancez-en un depuis la "
        "page d'un roman.",
    ),
    "downloadsEmptyActionBrowse": (
        "The one action an empty state offers: the discover loop, not an explanation.",
        "Browse sources",
        "Parcourir les sources",
    ),
    "queueCancelTitle": (
        "B19's confirmation. `downloads.md` § 7: 'Destructive actions are confirmed and "
        "named' — a generic 'Are you sure?' is a statement about nothing.",
        "Cancel this download?",
        "Annuler ce téléchargement ?",
    ),
    "queueCancelBody": (
        "The confirmation WITHOUT a chapter in flight. `{kept}` is the number that survives, "
        "and it is a count rather than a pre-built phrase so no caller can decorate it.",
        "The {kept} chapters already downloaded are kept. Nothing else is fetched.",
        "Les {kept} chapitres déjà téléchargés sont conservés. Aucun autre n'est récupéré.",
    ),
    "queueCancelBodyWithChapter": (
        "The confirmation WITH a chapter in flight. `downloads.md` § 5: the dialog names the "
        "chapter, so the confirmation is about a specific thing — and `{name}` is the site's "
        "own title (B10), not a placeholder this app invented.",
        "'{name}' is being downloaded. It will be discarded. The {kept} chapters already "
        "downloaded are kept.",
        "« {name} » est en cours de téléchargement. Il sera abandonné. Les {kept} chapitres "
        "déjà téléchargés sont conservés.",
    ),
    "queueCancelConfirm": (
        "The filled button. `commonCancel` is the other one, and the pair is the whole "
        "dialogue: two exits, no dead end, no silent consent.",
        "Cancel the download",
        "Annuler le téléchargement",
    ),
    # ── 5-3 · per-chapter failure, retry and the storage refusal ───────────────
    "downloadsFailedRowTitle": (
        "The failed row's chapter name — the SITE's own title (B10). `downloads.md` § 3: "
        "'Every failed row names the chapter, not just the novel'.",
        "Chapter: {name}",
        "Chapitre : {name}",
    ),
    "downloadsAttemptCount": (
        "`downloads.md` § 9 (E18): 'The attempt count is shown, because a threshold being "
        "applied is a thing the reader deserves to know about' — and C12, because 'it failed "
        "twice' and 'it failed once' are not described the same way.",
        "Tried {count} times",
        "Tenté {count} fois",
    ),
    "downloadsRetryAction": (
        "B24/B5: 'Re-fetch that chapter alone, and only that one.' NOT a retry-everything "
        "control — one chapter's typed failure says nothing about the other 47.",
        "Retry this chapter",
        "Réessayer ce chapitre",
    ),
    "downloadsStorageNeeded": (
        "E20's ONE measured figure: what the chapter the app was writing needs. It is NOT "
        "free space, which `downloads.md` § 9 refuses to display at all — a stale number is "
        "worse than none.",
        "This chapter needs {bytes}.",
        "Ce chapitre nécessite {bytes}.",
    ),
    "downloadsSemanticsChapterProgress": (
        "`downloads.md` § 7: the determinate bar's SPOKEN value, 'Chapter 13 of 50, 41 per "
        "cent'. `14-design-tokens.md` § Accessibility and `16-i18n.md` rule 7: a semantics "
        "label is localized like any other string. A percentage inside a ring is unreadable "
        "by a screen reader and useless at 2dp — this is the alternative.",
        "Chapter {position} of {total}, {percent} per cent",
        "Chapitre {position} sur {total}, {percent} pour cent",
    ),
    "downloadsSemanticsProgressUndetermined": (
        "The same spoken value with NO percentage, and `downloads.md` § 8 is explicit that "
        "`0` must never stand in for one: a bar at zero that never moves is a bar that lies.",
        "Chapter {position} of {total}, downloading",
        "Chapitre {position} sur {total}, téléchargement en cours",
    ),
    "downloadsLoadErrorTitle": (
        "`downloads.md` § 4 *Load error*: a real failure with a consequence worth stating "
        "precisely — the records could not be read, which is not the same as there being "
        "none.",
        "Lumen Tale could not read its download records",
        "Lumen Tale n'a pas pu lire ses enregistrements de téléchargement",
    ),
    "downloadsLoadErrorBody": (
        "The reassurance, and it is load-bearing: with no backup (ADR-010) the reader's first "
        "assumption is data loss. Nothing was deleted, and nothing can be fetched until the "
        "records can be read.",
        "Nothing has been deleted. This app cannot see what it has already stored, and "
        "nothing can be fetched until it can.",
        "Rien n'a été supprimé. Cette application ne voit pas ce qu'elle a déjà enregistré, "
        "et rien ne peut être récupéré tant qu'elle ne le voit pas.",
    ),
    "downloadsOpenNovelAction": (
        "E9's action for a chapter the site says is gone. NOT a retry \u2014 the site has "
        "confirmed the item is not coming back, so re-fetching it would fail identically. "
        "Navigation is honest: the reader can look at the novel's chapter list.",
        "Open the novel",
        "Ouvrir le roman",
    ),
    "downloadsLoadErrorRetry": (
        "B24: 'Any action that can fail shows an error the user can read and act on, together "
        "with a way to try again.'",
        "Try again",
        "Réessayer",
    ),
    # ── 5-3 · the eight typed causes, one sentence and one action each ──────────
    "queueCauseNoConnection": (
        "B24/C12 for `no_connection`: a sentence a borrowed-device reader can read aloud to "
        "the owner, and an action they can take.",
        "The connection dropped while this chapter was being downloaded.",
        "La connexion a été interrompue pendant le téléchargement de ce chapitre.",
    ),
    "queueCauseRateLimited": (
        "B24 for `rate_limited`. `17-security.md` rule 6: the answer is to wait, never to "
        "hammer — and the sentence must not sound like the site is broken.",
        "The site asked us to slow down.",
        "Le site nous a demandé de ralentir.",
    ),
    "queueCauseSourceLayoutChanged": (
        "B22 for `source_layout_changed`, E4. 'this app cannot read this site any more' is a "
        "report the owner can act on; 'download failed' is not.",
        "This site has changed its layout, so this app can no longer read it.",
        "Ce site a changé de mise en page : l'application ne peut plus le lire.",
    ),
    "queueCauseSourceEmpty": (
        "E8/B22 for `source_empty`. The distinction from 'the app has nothing' is the whole "
        "point: the SITE said so itself.",
        "The site published nothing for this chapter.",
        "Le site n'a rien publié pour ce chapitre.",
    ),
    "queueCauseNoRealText": (
        "E18 for `no_real_text`, and E22's half of the bargain: a short chapter must never "
        "be mistaken for a broken one, so the sentence is about THIS chapter.",
        "This chapter had no readable text on the page.",
        "Ce chapitre n'avait aucun texte lisible sur la page.",
    ),
    "queueCauseStorageFull": (
        "E20 for `storage_full`. NEVER a free-space figure — `downloads.md` § 9 — and never "
        "'try again', which would send the reader round the same loop.",
        "The phone ran out of storage.",
        "Le téléphone n'a plus de stockage.",
    ),
    "queueCauseParseFailed": (
        "B22 for `parse_failed`: the app's own failure, named as its own. `C5` says a failure "
        "the reader cannot report is a failure nobody will fix.",
        "This chapter's text could not be built.",
        "Le texte de ce chapitre n'a pas pu être composé.",
    ),
    "queueCauseUnknown": (
        "The only honest sentence for an unreadable code. `queue_run_state_deriver.dart` maps "
        "one to `QueueStopReason.unknown` and this is what the reader is shown — it does not "
        "guess, and C12 accepts a true 'the app cannot say' over a plausible fiction.",
        "This app cannot say what went wrong.",
        "L'application ne peut pas dire ce qui a échoué.",
    ),
    "queueCauseSourceUnavailable": (
        "B3 for `source_unavailable`: the novel names a site this build no longer contains, "
        "which is a statement about the app rather than about the chapter.",
        "This novel's site is not in this version of the app.",
        "Le site de ce roman n'est pas dans cette version de l'application.",
    ),
    "queueCauseItemRemovedAtSource": (
        "E9 for `item_removed_at_source`. The site's own answer, so the reader is not asked "
        "to retry something the site has confirmed is gone.",
        "The site says this chapter has been removed.",
        "Le site indique que ce chapitre a été supprimé.",
    ),
}

PLACEHOLDER = re.compile(r"\{(\w+)[,}]")


def placeholders(text: str) -> set[str]:
    return set(PLACEHOLDER.findall(text))


def digest(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def check_pairs() -> list[str]:
    """B28 — EN and FR must name the SAME placeholders."""
    problems: list[str] = []
    for key, (_description, en, fr) in STRINGS.items():
        if placeholders(en) != placeholders(fr):
            problems.append(
                "%s: en=%s fr=%s — a translated placeholder name ADDS a parameter rather "
                "than renaming one" % (key, sorted(placeholders(en)), sorted(placeholders(fr)))
            )
    return problems


def render_entry(key: str, description: str, value: str, with_metadata: bool) -> str:
    """One JSON value, plus its `@key` block when the file carries metadata blocks.

    ⚠️ **HAND-BUILT TEXT, NOT `json.dumps(..., indent=2)` OF A DICT.** The first version
    wrapped an already-braced `json.dumps` output in braces a second time and produced a file
    `json.loads` refused — which is why each line here is built by hand. The house style is
    two spaces of indent, no trailing comma on a metadata object's last property, and the
    value itself on one line.
    """
    names = sorted(placeholders(value))
    value_json = json.dumps(value, ensure_ascii=False)
    if not with_metadata:
        return '  %s: %s' % (json.dumps(key), value_json)

    properties = ['    "description": %s' % json.dumps(description, ensure_ascii=False)]
    if names:
        properties.append(
            '    "placeholders": {%s}' % ", ".join('"%s": {}' % n for n in names)
        )
    # ⚠️ **THE JOIN IS THE ONLY SOURCE OF COMMAS BETWEEN PROPERTIES.** The first version also
    # appended one to `description`, and the two together produced `",,` — a file `json.loads`
    # refused, i.e. an ARB with no localisations at all.
    block = ",\n".join(properties)
    # ⚠️ **`key: "value"` IS A PLAIN STRING AND `@key: { … }` IS THE METADATA.** The second
    # version of this line wrapped the VALUE in braces as well, and `flutter gen-l10n`
    # answered `The value of "downloadsAttemptCount" is not a string.` An ARB is JSON, and a
    # key whose value is an object is not a message — the `@` prefix is what makes it
    # metadata.
    return '  %s: %s,\n  "@%s": {\n%s\n  }' % (
        json.dumps(key),
        value_json,
        key,
        block,
    )


def insert(text: str, entries: list[str], with_metadata: bool) -> str:
    """⚠️ **A SURGICAL INSERT BEFORE THE FINAL `}`, NEVER A RE-SERIALISED DOCUMENT.**

    `json.dumps` of an 86 KB ARB re-quotes every description and produces a diff of several
    thousand lines in a file two other agents are writing. This adds one block per key and
    leaves every other byte untouched.
    """
    close = text.rstrip().rfind("}")
    if close < 0:
        raise SystemExit("no closing brace — is this an ARB?")
    head = text[:close].rstrip()
    tail = text[close:]
    if not head.endswith(","):
        head += ","
    return head + "\n" + ",\n".join(entries) + "\n" + tail


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="report and exit; write nothing")
    args = parser.parse_args()

    problems = check_pairs()
    for line in problems:
        print("PLACEHOLDER MISMATCH %s" % line)
    if problems:
        return 1

    for name in FILES:
        path = ARB / name
        before = path.read_text(encoding="utf-8")
        data = json.loads(before)
        # ⚠️ **`app_en.arb` CARRIES `@key` METADATA BLOCKS AND `app_fr.arb` DOES NOT.**
        # Both files are sorted with `@key` immediately after its key, and adding to the
        # wrong one of the two shapes would produce a file `gen-l10n` warns about.
        with_metadata = '"@' in before

        missing = [k for k in STRINGS if k not in data]
        if args.check:
            print("%s: %d key(s) missing%s" % (name, len(missing), (": " + ", ".join(missing)) if missing else ""))
            problems.extend(missing)
            continue
        if not missing:
            print("%s: nothing to add" % name)
            continue

        entries = [
            render_entry(key, STRINGS[key][0], STRINGS[key][1 + (0 if name.endswith("_en.arb") else 1)], with_metadata)
            for key in sorted(missing)
        ]
        after = insert(before, entries, with_metadata)

        # ⚠️ **THE WRITE WINDOW.** Another agent may have written between the read above and
        # here; re-hashing immediately before writing is the only guard there is.
        if digest(path.read_text(encoding="utf-8")) != digest(before):
            print("%s: CHANGED UNDER US — refusing to write. Re-run." % name)
            return 2
        path.write_text(after, encoding="utf-8")

        written = json.loads(path.read_text(encoding="utf-8"))
        for key in missing:
            if key not in written:
                print("%s: %s did not survive the write" % (name, key))
                return 2
        print("%s: added %d message(s)" % (name, len(missing)))

    if args.check and problems:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())