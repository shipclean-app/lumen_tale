"""Add the /history screen's copy to both ARB files, in both languages.

B28: *every user-visible string exists in French and in English.* `history.md` § 4
specifies nine states, three with a second rendering, and this is the copy for all
of them.

Kept as a script rather than a hand edit because the two files have to stay key-for-key
identical, and `arb_completeness_test.dart` checks that they are — a script that writes
both from one table cannot leave them out of step, where two hand edits can.

Run:  python3 tool/append_history_strings.py
"""

import json

STRINGS = {
    "en": {
        "historyTitle": "History",
        "historyUntitledChapter": "Untitled",
        "historyUntitledNovel": "Untitled",
        "historyLoadingTitle": "Loading history",
        "historyEmptyTitle": "Nothing read yet",
        "historyEmptyBody": (
            "The chapters you open appear here, newest first."
        ),
        "historyEmptyActionBrowse": "Browse a source",
        "historyEmptyActionLibrary": "Open your library",
        "historyClearedTitle": "History cleared",
        "historyClearedBody": (
            "Your library, your downloads and every remembered position were kept."
        ),
        "historyAgedOutTitle": "Everything older than one year was dropped",
        "historyAgedOutBody": "Your reading positions were kept.",
        "historyLoadErrorTitle": "Your history could not be read",
        "historyLoadErrorBody": (
            "Your library, your downloaded chapters and every remembered reading "
            "position are unaffected."
        ),
        "historyNoticeTitle": "History is bounded by time",
        "historyNoticeBody": (
            "Clearing it never moves a remembered reading position."
        ),
        "historyRetentionLabel": "Keep history for",
        "historyRetentionChange": "Change",
        "historyClearAction": "Clear history",
        "historyClearDialogTitle": "Clear history?",
        "historyClearDialogBody": (
            "{count, plural, =0{No entries will be removed.} "
            "=1{One entry will be removed.} "
            "other{{count} entries will be removed.}} "
            "Your library, your downloads and every remembered reading position "
            "will be kept."
        ),
        "historyClearDialogConfirm": "Clear history",
        "historyTerminalLine": (
            "This is the oldest entry kept. Entries older than {window} are "
            "dropped, oldest first."
        ),
        "historySheetTitle": "Keep history for",
        "historySheetWarning": (
            "Entries older than {window} will be dropped, oldest first. Your "
            "reading positions are never affected."
        ),
        "historySheetWarningNone": (
            "No entries will be dropped. Your reading positions are never "
            "affected."
        ),
        "historySnackCleared": (
            "History cleared. Your reading positions were kept."
        ),
        "historySnackNotCleared": "History was not cleared.",
        "historySnackWindowChanged": "History is now kept for {window}.",
        "historyWindowOneWeek": "one week",
        "historyWindowOneMonth": "one month",
        "historyWindowThreeMonths": "three months",
        "historyWindowOneYear": "one year",
        "historyWindowTwoYears": "two years",
        "historyDayToday": "Today",
        "historyDayYesterday": "Yesterday",
        "historyDayOn": "{date}",
        "historyJustNow": "Just now",
        "historyMinutesAgo": "{count, plural, =1{1 minute ago} other{{count} minutes ago}}",
        "historyHoursAgo": "{count, plural, =1{1 hour ago} other{{count} hours ago}}",
    },
    "fr": {
        "historyTitle": "Historique",
        "historyUntitledChapter": "Sans titre",
        "historyUntitledNovel": "Sans titre",
        "historyLoadingTitle": "Chargement de l'historique",
        "historyEmptyTitle": "Rien de lu pour l'instant",
        "historyEmptyBody": (
            "Les chapitres que vous ouvrez apparaissent ici, du plus récent au "
            "plus ancien."
        ),
        "historyEmptyActionBrowse": "Parcourir une source",
        "historyEmptyActionLibrary": "Ouvrir votre bibliothèque",
        "historyClearedTitle": "Historique effacé",
        "historyClearedBody": (
            "Votre bibliothèque, vos téléchargements et toutes vos positions de "
            "lecture ont été conservés."
        ),
        "historyAgedOutTitle": (
            "Tout ce qui datait de plus d'un an a été supprimé"
        ),
        "historyAgedOutBody": "Vos positions de lecture ont été conservées.",
        "historyLoadErrorTitle": "Votre historique n'a pas pu être lu",
        "historyLoadErrorBody": (
            "Votre bibliothèque, vos chapitres téléchargés et toutes vos "
            "positions de lecture ne sont pas affectés."
        ),
        "historyNoticeTitle": "L'historique est borné par le temps",
        "historyNoticeBody": (
            "Effacer l'historique ne déplace jamais une position de lecture "
            "retenue."
        ),
        "historyRetentionLabel": "Durée de conservation",
        "historyRetentionChange": "Changer",
        "historyClearAction": "Effacer l'historique",
        "historyClearDialogTitle": "Effacer l'historique ?",
        "historyClearDialogBody": (
            "{count, plural, =0{Aucune entrée ne sera supprimée.} "
            "=1{Une entrée sera supprimée.} "
            "other{{count} entrées seront supprimées.}} "
            "Votre bibliothèque, vos téléchargements et toutes vos positions de "
            "lecture seront conservés."
        ),
        "historyClearDialogConfirm": "Effacer l'historique",
        "historyTerminalLine": (
            "Voici l'entrée la plus ancienne conservée. Les entrées de plus de "
            "{window} seront supprimées, les plus anciennes d'abord."
        ),
        "historySheetTitle": "Durée de conservation",
        "historySheetWarning": (
            "Les entrées de plus de {window} seront supprimées, les plus "
            "anciennes d'abord. Vos positions de lecture ne sont jamais "
            "affectées."
        ),
        "historySheetWarningNone": (
            "Aucune entrée ne sera supprimée. Vos positions de lecture ne sont "
            "jamais affectées."
        ),
        "historySnackCleared": (
            "Historique effacé. Vos positions de lecture ont été conservées."
        ),
        "historySnackNotCleared": "L'historique n'a pas été effacé.",
        "historySnackWindowChanged": (
            "L'historique est désormais conservé {window}."
        ),
        "historyWindowOneWeek": "une semaine",
        "historyWindowOneMonth": "un mois",
        "historyWindowThreeMonths": "trois mois",
        "historyWindowOneYear": "un an",
        "historyWindowTwoYears": "deux ans",
        "historyDayToday": "Aujourd'hui",
        "historyDayYesterday": "Hier",
        "historyDayOn": "{date}",
        "historyJustNow": "À l'instant",
        "historyMinutesAgo": "{count, plural, =1{Il y a 1 minute} other{Il y a {count} minutes}}",
        "historyHoursAgo": "{count, plural, =1{Il y a 1 heure} other{Il y a {count} heures}}",
    },
}

# (key, why the key exists) — the order they are written in, so a reader of the ARB
# sees the states in the order `history.md` § 4 lists them.
ORDER = [
    ("historyTitle", "Screen title"),
    ("historyUntitledChapter", "Chapter title empty at the source"),
    ("historyUntitledNovel", "Novel title empty in storage"),
    ("historyLoadingTitle", "Accessibility label while the list loads"),
    ("historyEmptyTitle", "Empty - never visited"),
    ("historyEmptyBody", "Empty - never visited"),
    ("historyEmptyActionBrowse", "Empty action when the library is EMPTY"),
    ("historyEmptyActionLibrary", "Empty action when the library is NOT empty"),
    ("historyClearedTitle", "Empty - no data (a), cleared by the reader"),
    ("historyClearedBody", "Empty - no data (a)"),
    ("historyAgedOutTitle", "Empty - no data (b), everything aged out"),
    ("historyAgedOutBody", "Empty - no data (b)"),
    ("historyLoadErrorTitle", "Load error"),
    ("historyLoadErrorBody", "Load error"),
    ("historyNoticeTitle", "Bound notice"),
    ("historyNoticeBody", "Bound notice"),
    ("historyRetentionLabel", "Retention row"),
    ("historyRetentionChange", "Retention row action"),
    ("historyClearAction", "Clear action"),
    ("historyClearDialogTitle", "Clear confirmation"),
    ("historyClearDialogBody", "Clear confirmation"),
    ("historyClearDialogConfirm", "Clear confirmation"),
    ("historyTerminalLine", "Terminal line, after the last row"),
    ("historySheetTitle", "SettingsChoiceSheet"),
    ("historySheetWarning", "SettingsChoiceSheet"),
    ("historySheetWarningNone", "SettingsChoiceSheet"),
    ("historySnackCleared", "Success SnackBar"),
    ("historySnackNotCleared", "Submit error SnackBar"),
    ("historySnackWindowChanged", "Success SnackBar"),
    ("historyWindowOneWeek", "Retention window names - DATA"),
    ("historyWindowOneMonth", "Retention window names - DATA"),
    ("historyWindowThreeMonths", "Retention window names - DATA"),
    ("historyWindowOneYear", "Retention window names - DATA"),
    ("historyWindowTwoYears", "Retention window names - DATA"),
    ("historyDayToday", "Day group header"),
    ("historyDayYesterday", "Day group header"),
    ("historyDayOn", "Day group header, older than yesterday"),
    ("historyJustNow", "Row trailing time, under a minute"),
    ("historyMinutesAgo", "Row trailing time"),
    ("historyHoursAgo", "Row trailing time"),
]

DESCRIPTIONS = {
    "historyDayToday": (
        "The first day header. NOT concatenated from a month name and a number: "
        "'Today' is a word, it takes an article in some languages and an "
        "inflection in others, and a concatenation is wrong in both. E12 requires a "
        "language change to re-label the headers, which a concatenated string "
        "cannot do."
    ),
    "historyDayYesterday": (
        "The second day header, and a separate key for the same reason as "
        "historyDayToday."
    ),
    "historyDayOn": (
        "Every older day header. `{date}` arrives ALREADY localised from "
        "MaterialLocalizations.formatMediumDate - this key is a hole for a "
        "platform-formatted date, not a sentence, which is why the value is the "
        "same in both files."
    ),
    "historyJustNow": (
        "The row's trailing time under a minute old. Deliberately the only "
        "bucketing below an hour: a reader who opened four chapters in ten minutes "
        "sees the same word on all four, and a count that ticks upward every "
        "second would make the list move under them."
    ),
    "historyMinutesAgo": (
        "Minutes, with a French plural rule (`=1` vs `other`) - French has no "
        "singular-only form and a reader watching 'Il y a 1 minutes' learns to "
        "distrust the rest of the screen."
    ),
    "historyHoursAgo": (
        "Hours, same plural rule. There is deliberately NO days-ago key: past "
        "yesterday the DAY GROUP HEADER already carries the date, and repeating "
        "it in the row would say the same thing twice on every line."
    ),
    "historyUntitledChapter": (
        "B10 / E2: the site published no title for this chapter. Rendered here, "
        "NEVER as an index and never as a generated number - a fabricated title is "
        "a sentence the app invented and the reader would believe."
    ),
    "historyUntitledNovel": (
        "A novel whose stored title is empty. The same rule as the chapter: a "
        "placeholder, never an index."
    ),
    "historyLoadingTitle": (
        "Accessibility label while the list loads. Eight skeletons, no cover - the "
        "`history` variant of NovelRow declares no cover slot, and a loading state "
        "that shows one promises an image the filled rows will not have."
    ),
    "historyEmptyTitle": (
        "US-12 distinguishes 'never opened anything' from 'opened things and then "
        "cleared them'. This is the FIRST; the second is historyClearedTitle."
    ),
    "historyEmptyBody": (
        "Says what the screen is FOR, in the reader's terms, and states the order "
        "it will be in."
    ),
    "historyEmptyActionBrowse": (
        "The empty action depends on a LOCAL FACT: this one when the library is "
        "empty, historyEmptyActionLibrary when it is not. A fixed string would point "
        "at a library the reader does not have."
    ),
    "historyEmptyActionLibrary": (
        "The other half of the same local fact. Deciding by what is already on the "
        "phone is the difference between 'where do I go next' and 'here is a button'."
    ),
    "historyClearedTitle": (
        "Empty - no data (a). history.md § 4 splits this state in two because being "
        "cleared BY THE READER and being AGED OUT are different events with "
        "different emotional weight."
    ),
    "historyClearedBody": (
        "B46 said out loud, on the screen where the fear lives. Repeated in the "
        "clear confirmation, in this state, and in the store-failure sentence - "
        "four times, because it is the thing a reader on a device with no backup is "
        "actually afraid of."
    ),
    "historyAgedOutTitle": (
        "Empty - no data (b). Distinct from historyClearedTitle because nobody did "
        "this on purpose."
    ),
    "historyAgedOutBody": (
        "Both empty-no-data states say WHAT SURVIVED. An empty list after a "
        "destructive action that says nothing is the moment a reader goes looking "
        "for what else just disappeared."
    ),
    "historyLoadErrorTitle": (
        "Load error. The only failure this screen can have is its own local store - "
        "nothing on it ever needed a network (C14)."
    ),
    "historyLoadErrorBody": (
        "Unusually specific because the fear here is data loss and this app has no "
        "backup (ADR-010). Naming the three survivals by name is what stops the "
        "reader assuming the worst."
    ),
    "historyNoticeTitle": (
        "B47 stated on the screen where the fear lives: the list is bounded, and "
        "something else is not."
    ),
    "historyNoticeBody": (
        "B46 in one line."
    ),
    "historyRetentionLabel": (
        "A row WITH this label goes somewhere - it opens the sheet. The absence of a "
        "chevron would say the value can be changed in place, which it cannot."
    ),
    "historyRetentionChange": (
        "The action that opens SettingsChoiceSheet. 'Change' rather than 'Keep for "
        "one year': the value is printed next to it, and a label repeating it would "
        "be two places to update on every window change."
    ),
    "historyClearAction": (
        "The only destructive action on the most read-only screen in the app, and it "
        "says exactly what it clears. Never 'OK', never 'Delete'."
    ),
    "historyClearDialogTitle": (
        "A question, not a statement. 'Clear history?' lets the reader cancel "
        "without reading the body."
    ),
    "historyClearDialogConfirm": (
        "The destructive button, in full. 'OK' on a dialog that empties a reader's "
        "log is a button asking them to trust a process they have just been told "
        "nothing about."
    ),
    "historyTerminalLine": (
        "B47's stated bound, at the END of the list, so a reader who scrolls to the "
        "bottom finds the limit rather than having it announced only at the top. "
        "There is no unbounded case, so this sentence is never absent: a screen "
        "that claimed a bound it was not applying is the exact failure B47 was "
        "written to avoid."
    ),
    "historySheetTitle": (
        "design-system.md § 2.12's SettingsChoiceSheet. `3-7` renders its rows from "
        "the SAME HistoryRetention enum, which is what makes 'the same five windows' "
        "a fact rather than a promise."
    ),
    "historySheetWarning": (
        "The sentence above the options, BEFORE the reader chooses. It names the "
        "window currently highlighted and promises positions are untouched."
    ),
    "historySheetWarningNone": (
        "The same sentence when the chosen window would drop nothing. A reader must "
        "not be told entries will be dropped when none will."
    ),
    "historySnackCleared": (
        "Success. It repeats the promise from the empty state, because a reader who "
        "has just emptied a list is exactly the reader who will wonder what else "
        "went with it."
    ),
    "historySnackNotCleared": (
        "Submit error: the list did NOT change. An optimistic empty list is a record "
        "of something that never happened."
    ),
    "historySnackWindowChanged": (
        "Success after a window change. It NAMES the new window, because a screen "
        "saying 'one year' in the notice and 'three months' in the snackbar is two "
        "lies."
    ),
    "historyWindowOneWeek": (
        "The five window names are DATA, not screen copy: HistoryRetention.cutoffFrom "
        "is computed from the enum's Duration, and this string is only what a reader "
        "reads. Two representations of one window, and a test asserts the enum has "
        "exactly these five members."
    ),
    "historyWindowOneMonth": "See historyWindowOneWeek.",
    "historyWindowThreeMonths": "See historyWindowOneWeek.",
    "historyWindowOneYear": (
        "The default window. HistoryRetention.defaultWindow is this member, and a "
        "test asserts it rather than trusting the string."
    ),
    "historyWindowTwoYears": (
        "The longest window the design offers. There is deliberately no sixth: "
        "design-system.md § 2.12 forbids a 'forever' option on any bounded list, "
        "because an unbounded value next to bounded ones teaches the reader the "
        "bounds are negotiable."
    ),
}

# Keys that take a placeholder, and what it is. `arb_completeness_test.dart` checks
# that both files declare the same placeholders for the same keys.
PLACEHOLDERS = {
    "historyClearDialogBody": {
        "count": {"type": "int", "example": "96"},
    },
    "historyTerminalLine": {
        "window": {"type": "String", "example": "one year"},
    },
    "historySheetWarning": {
        "window": {"type": "String", "example": "three months"},
    },
    "historySnackWindowChanged": {
        "window": {"type": "String", "example": "three months"},
    },
}

WINDOW_PLACEHOLDER_EXAMPLE = {"en": "one year", "fr": "un an"}

# `historyDayOn` takes a date the PLATFORM formatted, so both files declare the same
# placeholder type and the same example. The string itself is the same in both
# languages on purpose: the date arrives already localised from `MaterialLocalizations`,
# so the ARB value is a hole, not a sentence.
EXTRA_PLACEHOLDERS = {
    "historyDayOn": {"date": {"type": "String", "example": "3 October"}},
    "historyMinutesAgo": {"count": {"type": "int", "example": "7"}},
    "historyHoursAgo": {"count": {"type": "int", "example": "3"}},
}


def build(locale):
    path = "lib/l10n/app_%s.arb" % locale
    with open(path, encoding="utf-8") as handle:
        existing = json.load(handle)

    strings = STRINGS[locale]
    missing = [key for key, _ in ORDER if key not in strings]
    if missing:
        raise SystemExit("%s is missing: %s" % (locale, ", ".join(missing)))

    out = {"@@locale": locale}
    # Every pre-existing key, in its order, minus the ones this script owns.
    for key, value in existing.items():
        if key.startswith("@") and key != "@@locale":
            continue
        if key in strings:
            continue
        out[key] = value

    for key, _ in ORDER:
        out[key] = strings[key]

    # Metadata for every PRE-EXISTING key, re-emitted.
    #
    # ⚠️ A first version omitted this and reported success. It dropped **every** `@`
    # block the file already had, so `chapterCount` and `coverSemanticsLabel` lost the
    # placeholders only they declared, and `arb_completeness_test` caught it. A script
    # that overwrites a file needs its OUTPUT counted, not its exit code.
    for key, value in existing.items():
        if key.startswith('@') and key != '@@locale' and key not in out:
            out[key] = value

    for key, why in ORDER:
        meta = {"description": DESCRIPTIONS.get(key, why)}
        if key in PLACEHOLDERS or key in EXTRA_PLACEHOLDERS:
            placeholders = dict(
                PLACEHOLDERS.get(key) or EXTRA_PLACEHOLDERS[key]
            )
            if "window" in placeholders:
                placeholders["window"] = {
                    "type": "String",
                    "example": WINDOW_PLACEHOLDER_EXAMPLE[locale],
                }
            meta["placeholders"] = placeholders
        out["@" + key] = meta

    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return len(out)


def main():
    for locale in ("en", "fr"):
        count = build(locale)
        print("%s: %d keys" % (locale, count))


if __name__ == "__main__":
    main()