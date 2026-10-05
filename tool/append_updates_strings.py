"""Add the update pipeline's copy to both ARB files, in both languages.

Three slices' copy in one pass — `6-4` (the manual check), `6-6` (the library's
title-only search and its badges) and `6-10` (the foreground job's notification
and its ten stop reasons). They are one pass because the plans make them one
unit: `6-4`'s progress line, `6-6`'s `Could not check` chip and `6-10`'s
notification all say the same two facts, and writing them separately would let
three phrasings of one sentence into the corpus.

**⚠️ NO NEW KEY FOR A SENTENCE THAT ALREADY EXISTS.** The project already owns
the six failure sentences (`errorNoConnection`, `errorRateLimited`,
`errorSourceLayoutChanged`, `errorSourceUnavailable`, `errorItemRemovedAtSource`,
`errorParseFailed`), the `downloaded / total` pair (`libraryTileProgress`), the
`new chapters` plural (`libraryTileUnopened`), `checkCancelled`,
`warningNotifications`, `libraryEmptyTitle`/`libraryEmptyBody`,
`historyEmptyActionBrowse` and `navUpdates`. `design-system.md` § 2.12 says why:
*"two lists of the same values in two places is two truths about how long history
lasts, and nothing in a dependency graph or a design token would notice."* So
`CheckFailureKind`'s six phrases are **a mapping onto existing keys**, not six new
strings, and the check's own sentences are the only keys added here.

**The ten stop reasons are ten keys, never one key with a code in it.** C12 is
the reason: a reader on a borrowed phone must be able to say in words what
happened, and `check stopped (reason 9)` is not a sentence. They are also why
`notificationPermissionWarning` names the *consequence* rather than the cause —
the reader cannot act on "the permission is denied", only on "nothing will tell
you when it finishes".

Run:  python3 tool/append_updates_strings.py
"""

import json

STRINGS = {
    "en": {
        # ── 6-4: the manual check ──────────────────────────────────────────
        "checkNowAction": "Check for new chapters",
        "checkActionSemantics": "Checking, {done} of {total} novels",
        "checkProgress": "Checking {done} of {total} novels",
        "checkProgressNothingDownloaded": (
            "Checking {done} of {total} novels · nothing is downloaded"
        ),
        "checkCancelAction": "Stop the check",
        "checkTerminalComplete": "All {total} novels checked · none skipped.",
        "checkTerminalInterrupted": "Check stopped at {done} of {total} novels.",
        "checkTerminalWithFailures": (
            "Checked {checked} of {total} novels · {failed} could not be checked."
        ),
        "checkDiscoveredNothing": "Checked {total} novels · nothing you had not opened",
        "checkDiscovered": (
            "Checked {total} novels · {discovered} you had not opened"
        ),
        "checkNeedsConnection": "Checking needs a connection.",
        "checkQueuedNotice": (
            "The check needs to be started again from here — the phone closed the job."
        ),
        # ── 6-6: title-only search, and the row's own state ────────────────
        "librarySearchHint": "Search by title",
        "librarySearchResults": (
            "{count, plural, =0{No novel} =1{1 novel} other{{count} novels}}"
        ),
        "librarySearchNoMatchTitle": 'No kept novel matches "{query}"',
        "librarySearchClearAction": "Clear search",
        "libraryEmptyBrowseAction": "Browse a source",
        "libraryNoDataTitle": "No kept novel matches the filters",
        "libraryNoDataClearFilters": "Clear filters",
        "libraryLoadErrorBody": (
            "Chapters already downloaded are still on this phone and still readable."
        ),
        "libraryRowNeverChecked": "Never checked",
        "libraryRowCouldNotCheck": "Could not check",
        "libraryRowStopped": "Stopped",
        "libraryRowStoppedConnection": "Stopped · no connection",
        "libraryRowStoppedStorage": "Stopped · storage full",
        "libraryRowDownloadComplete": "All chapters downloaded",
        "librarySortTitle": "Sort and filter",
        "librarySortLastRead": "Last read",
        "librarySortRecentlyAdded": "Recently added",
        "librarySortTitleAz": "Title A–Z",
        "librarySortUnopened": "Unopened chapters",
        "librarySortSite": "Site",
        "libraryScopeLine": (
            "Titles only — the app does not keep authors, genres or descriptions "
            "as searchable fields."
        ),
        "libraryFacetGroup": "Show",
        "libraryFacetDownloaded": "Downloaded",
        "libraryFacetNotDownloaded": "Not downloaded",
        "libraryFacetHasUnopened": "Has unopened chapters",
        "libraryFacetSite": "Site",
        "libraryFilterCount": "{count} filters on",
        "libraryUnopenedBadgeSemantics": "{count} chapters you have not opened",
        "librarySearchSemantics": "Search your library by title",
        # ── 6-10: the foreground job ────────────────────────────────────────
        "checkNotificationChannelName": "Library checks",
        "checkNotificationTitle": "Checking your library",
        "checkNotificationPermissionWarning": (
            "The check will run, but Android will not show its notification: "
            "nothing will tell you when it finishes."
        ),
        "checkNotificationSettingsAction": "Open notification settings",
        "checkCancelledByReader": "Check cancelled · your library is unchanged",
        "checkFinishedAfterCancel": "Check finished after you cancelled it.",
        "checkStoppedUnknown": (
            "Check stopped — Android did not say why. Tap check to finish."
        ),
        "checkStoppedTimeout": (
            "Check took longer than Android allows and was stopped. Try again."
        ),
        "checkStoppedPreempt": (
            "Check stopped — Android gave the phone to something else."
        ),
        "checkStoppedCancelledByApp": "Check cancelled · your library is unchanged",
        "checkStoppedSystemIgnoredCancel": "Check finished after you cancelled it.",
        "checkStoppedBackgroundRestriction": (
            "Check stopped — Android paused it. Tap check to finish."
        ),
        "checkStoppedGpuLimit": (
            "Check stopped — the phone ran out of memory for it. Try again."
        ),
        "checkStoppedDeviceState": (
            "Check stopped — the phone is saving power. Try again."
        ),
        "checkStoppedAppStandby": (
            "Check stopped — the phone put the app to sleep. Try again."
        ),
        "checkStoppedDeviceIdle": (
            "Check stopped — the phone put the app to sleep. Try again."
        ),
    },
    "fr": {
        "checkNowAction": "Vérifier les nouveaux chapitres",
        "checkActionSemantics": "Vérification en cours, {done} sur {total} romans",
        "checkProgress": "Vérification : {done} sur {total} romans",
        "checkProgressNothingDownloaded": (
            "Vérification : {done} sur {total} romans · rien n'est téléchargé"
        ),
        "checkCancelAction": "Arrêter la vérification",
        "checkTerminalComplete": (
            "{total} romans vérifiés, aucun ignoré."
        ),
        "checkTerminalInterrupted": (
            "Vérification arrêtée à {done} romans sur {total}."
        ),
        "checkTerminalWithFailures": (
            "{checked} romans vérifiés sur {total} · {failed} n'ont pas pu être "
            "vérifiés."
        ),
        "checkDiscoveredNothing": (
            "{total} romans vérifiés · rien que vous n'ayez pas ouvert"
        ),
        "checkDiscovered": (
            "{total} romans vérifiés · {discovered} que vous n'aviez pas ouverts"
        ),
        "checkNeedsConnection": "La vérification nécessite une connexion.",
        "checkQueuedNotice": (
            "La vérification doit être relancée depuis ici : le téléphone a fermé "
            "la tâche."
        ),
        "librarySearchHint": "Rechercher par titre",
        "librarySearchResults": (
            "{count, plural, =0{Aucun roman} =1{1 roman} other{{count} romans}}"
        ),
        "librarySearchNoMatchTitle": 'Aucun roman gardé ne correspond à « {query} »',
        "librarySearchClearAction": "Effacer la recherche",
        "libraryEmptyBrowseAction": "Parcourir un site",
        "libraryNoDataTitle": "Aucun roman gardé ne correspond aux filtres",
        "libraryNoDataClearFilters": "Effacer les filtres",
        "libraryLoadErrorBody": (
            "Les chapitres déjà téléchargés sont toujours sur ce téléphone et "
            "restent lisibles."
        ),
        "libraryRowNeverChecked": "Jamais vérifiée",
        "libraryRowCouldNotCheck": "Vérification impossible",
        "libraryRowStopped": "Arrêté",
        "libraryRowStoppedConnection": "Arrêté · pas de connexion",
        "libraryRowStoppedStorage": "Arrêté · stockage plein",
        "libraryRowDownloadComplete": "Tous les chapitres sont téléchargés",
        "librarySortTitle": "Tri et filtres",
        "librarySortLastRead": "Dernière lecture",
        "librarySortRecentlyAdded": "Ajoutés récemment",
        "librarySortTitleAz": "Titre A–Z",
        "librarySortUnopened": "Chapitres non ouverts",
        "librarySortSite": "Site",
        "libraryScopeLine": (
            "Titres uniquement — l'application ne conserve ni auteurs, ni genres, "
            "ni descriptions comme champs cherchables."
        ),
        "libraryFacetGroup": "Afficher",
        "libraryFacetDownloaded": "Téléchargés",
        "libraryFacetNotDownloaded": "Non téléchargés",
        "libraryFacetHasUnopened": "Avec des chapitres non ouverts",
        "libraryFacetSite": "Site",
        "libraryFilterCount": "{count} filtres actifs",
        "libraryUnopenedBadgeSemantics": (
            "{count} chapitres que vous n'avez pas ouverts"
        ),
        "librarySearchSemantics": "Rechercher dans votre bibliothèque par titre",
        "checkNotificationChannelName": "Vérifications de la bibliothèque",
        "checkNotificationTitle": "Vérification de votre bibliothèque",
        "checkNotificationPermissionWarning": (
            "La vérification s'exécutera, mais Android n'affichera pas sa "
            "notification : rien ne vous dira quand elle se termine."
        ),
        "checkNotificationSettingsAction": "Ouvrir les paramètres de notification",
        "checkCancelledByReader": (
            "Vérification annulée · votre bibliothèque n'est pas modifiée"
        ),
        "checkFinishedAfterCancel": (
            "La vérification s'est terminée après votre annulation."
        ),
        "checkStoppedUnknown": (
            "Vérification arrêtée — Android n'a pas dit pourquoi. Relancez-la pour "
            "terminer."
        ),
        "checkStoppedTimeout": (
            "La vérification a dépassé le temps accordé par Android et a été "
            "arrêtée. Réessayez."
        ),
        "checkStoppedPreempt": (
            "Vérification arrêtée — Android a donné le téléphone à autre chose."
        ),
        "checkStoppedCancelledByApp": (
            "Vérification annulée · votre bibliothèque n'est pas modifiée"
        ),
        "checkStoppedSystemIgnoredCancel": (
            "La vérification s'est terminée après votre annulation."
        ),
        "checkStoppedBackgroundRestriction": (
            "Vérification arrêtée — Android l'a mise en pause. Relancez-la pour "
            "terminer."
        ),
        "checkStoppedGpuLimit": (
            "Vérification arrêtée — le téléphone n'a plus de mémoire pour elle. "
            "Réessayez."
        ),
        "checkStoppedDeviceState": (
            "Vérification arrêtée — le téléphone économise son énergie. Réessayez."
        ),
        "checkStoppedAppStandby": (
            "Vérification arrêtée — le téléphone a mis l'application en veille. "
            "Réessayez."
        ),
        "checkStoppedDeviceIdle": (
            "Vérification arrêtée — le téléphone a mis l'application en veille. "
            "Réessayez."
        ),
    },
}

ORDER = [
    ("checkNowAction", "The button `library.md`, `updates.md` and `settings.md` share"),
    (
        "checkActionSemantics",
        "B37/C12 — the loading button's SPOKEN label, which is the only thing a "
        "screen-reader user gets while the visible label is hidden",
    ),
    ("checkProgress", "6-4 § 3.4 — the counter alone"),
    (
        "checkProgressNothingDownloaded",
        "6-4 § 3.4 and 6-10's notification text. ⚠️ **BOTH facts in one sentence** "
        "(B39's counter and B38's promise), and 6-10 reuses this key rather than "
        "writing a notification string of its own",
    ),
    ("checkCancelAction", "ADR-025 — cancellation is the in-app gesture"),
    ("checkTerminalComplete", "6-4 § 3.4, the complete pass"),
    ("checkTerminalInterrupted", "6-4 § 3.4 and `6-10` § 3.3 branch 2 — C8's two numbers"),
    ("checkTerminalWithFailures", "6-4 § 3.4 — B22: the failures are never folded into the successes"),
    (
        "checkDiscoveredNothing",
        "A complete pass that found nothing the reader had not opened. ⚠️ It says "
        "what was *checked*, never 'nothing is new' for a novel that was not looked at",
    ),
    ("checkDiscovered", "A complete pass and its discovered figure — what the run FOUND"),
    ("checkNeedsConnection", "6-10 § 11.2 — the disabled action says this, and the row stays visible"),
    (
        "checkQueuedNotice",
        "Written when a pass ends in a state no reader can act on at this moment",
    ),
    ("librarySearchHint", "B45 — the placeholder NAMES the scope, because it is the whole promise"),
    ("librarySearchResults", "B45 — the helper count, which equals the list's length"),
    ("librarySearchNoMatchTitle", "B22/B45 — a local search has no failure state, so never '0 results'"),
    ("librarySearchClearAction", "The action that empties the field"),
    ("libraryEmptyBrowseAction", "The empty-library button — `library.md` § 4 *Empty — never visited*"),
    ("libraryNoDataTitle", "The OTHER empty state — filters excluded everything"),
    ("libraryNoDataClearFilters", "Its button, and it says what it clears"),
    ("libraryLoadErrorBody", "C8 — the reassurance beside *Your library could not be read*"),
    ("libraryRowNeverChecked", "B49 — in words, never an epoch"),
    ("libraryRowCouldNotCheck", "B22 — the chip, and it is NOT 'no new chapters'"),
    ("libraryRowStopped", "E6 — a partial download presented as a partial one"),
    ("libraryRowStoppedConnection", "E7 — distinguishable from a plain stop, because the reader must know whether to press Resume"),
    ("libraryRowStoppedStorage", "E20 — the label names the storage"),
    ("libraryRowDownloadComplete", "B6 — the only state that may say 'complete'"),
    ("librarySortTitle", "The sheet's title"),
    ("librarySortLastRead", "Sort key 1 of 5 — by `reading_positions`, never by history"),
    ("librarySortRecentlyAdded", "Sort key 2 of 5"),
    ("librarySortTitleAz", "Sort key 3 of 5"),
    ("librarySortUnopened", "Sort key 4 of 5"),
    ("librarySortSite", "Sort key 5 of 5 — then by title"),
    (
        "libraryScopeLine",
        "B45/ADR-024 — the sheet says the limit out loud, because the app holds "
        "author and description and refuses to search them",
    ),
    ("libraryFacetGroup", "The facets' group label"),
    ("libraryFacetDownloaded", "Facet 1 of 4"),
    ("libraryFacetNotDownloaded", "Facet 2 of 4"),
    ("libraryFacetHasUnopened", "Facet 3 of 4"),
    ("libraryFacetSite", "Facet 4 of 4 — B2: the site is a filter, never a merge key"),
    ("libraryFilterCount", "How many facets are on, so the reader can see the filter is not empty"),
    ("libraryUnopenedBadgeSemantics", "B14/C11 — the badge carries its NUMBER in the label"),
    ("librarySearchSemantics", "The field's own accessible name"),
    ("checkNotificationChannelName", "B37 — the channel the system groups the notification under"),
    ("checkNotificationTitle", "B37 — names what is happening, not a brand"),
    (
        "checkNotificationPermissionWarning",
        "settings.md § 4 — it names the CONSEQUENCE, because the reader can act on "
        "'nothing will tell you when it finishes' and not on 'the permission is denied'",
    ),
    ("checkNotificationSettingsAction", "The link into Android's own screen"),
    ("checkCancelledByReader", "6-10 branch 2"),
    ("checkFinishedAfterCancel", "6-10 branch 6 — ⚠️ NOT 'cancelled': the reader has results they did not ask for"),
    ("checkStoppedUnknown", "StopReason.unknown"),
    ("checkStoppedTimeout", "StopReason.timeout"),
    ("checkStoppedPreempt", "StopReason.preempt"),
    ("checkStoppedCancelledByApp", "StopReason.cancelledByApp"),
    ("checkStoppedSystemIgnoredCancel", "StopReason.systemIgnoredCancelledByApp"),
    ("checkStoppedBackgroundRestriction", "StopReason.backgroundRestriction"),
    ("checkStoppedGpuLimit", "StopReason.estimatedAppGpuLimit"),
    ("checkStoppedDeviceState", "StopReason.deviceState"),
    ("checkStoppedAppStandby", "StopReason.appStandby"),
    (
        "checkStoppedDeviceIdle",
        "StopReason.deviceIdle. ⚠️ The FRENCH copy is deliberately the same as "
        "`checkStoppedAppStandby`: both are 'the phone put the app to sleep', and "
        "a reader who is told two different things for one cause learns to distrust both",
    ),
]

DESCRIPTIONS = {
    "checkProgressNothingDownloaded": (
        "⚠️ **THE SENTENCE `6-10`'s NOTIFICATION AND `6-4`'s STATUS LINE SHARE.** B39's "
        "counter and B38's promise in one clause, and one key rather than two: a "
        "notification that says 'checking 7 of 23' and a status line that says "
        "'checking 7 of 23 · nothing is downloaded' are two claims about one run."
    ),
    "checkTerminalWithFailures": (
        "B22 in one line: the failure count is **beside** the success count and never "
        "inside it. 'Checked 23 of 23 novels' when four sites could not be read is the "
        "exact presentation B22 exists to forbid."
    ),
    "checkDiscoveredNothing": (
        "⚠️ **NOT 'nothing is new'.** The distinction B49 is about: this sentence may "
        "only be said when the app actually looked. `libraryTileUnopened`'s `=0` arm "
        "says 'No new chapters' for a single novel, and it is allowed there because "
        "that row carries the novel's own verification chip beside it."
    ),
    "librarySearchNoMatchTitle": (
        "B22 and B19: a **local** search has no failure state, so its empty list must "
        "not borrow the vocabulary of a failed site query. 'No results' would tell a "
        "reader a source had gone unreadable when the library is simply on this phone."
    ),
    "libraryScopeLine": (
        "B45 made structural rather than asserted (ADR-024: `author` and `description` "
        "are stored and unindexed), and this line is where the reader is told. A limit "
        "the app does not state is a limit a reader discovers by searching for a pen "
        "name and getting nothing."
    ),
    "checkNotificationPermissionWarning": (
        "B37 says *visible*, not *blocking* — so a denied permission must NOT stop the "
        "check. The line therefore names what the reader loses (the notification) and "
        "not the state of a permission they cannot see."
    ),
    "checkFinishedAfterCancel": (
        "⚠️ **Never 'cancelled'.** `StopReason.systemIgnoredCancelledByApp` means the work "
        "**finished**: the reader now holds results they did not ask for, and telling "
        "them 'cancelled' would make them look for changes that are already saved."
    ),
    "checkStoppedDeviceIdle": (
        "Same French sentence as `checkStoppedAppStandby` **on purpose**: Doze and App "
        "Standby are one thing to a reader — the phone put the app to sleep — and two "
        "different sentences for one cause is two truths about one phone's state."
    ),
}

PLACEHOLDERS = {
    "checkActionSemantics": {
        "done": {"type": "String", "example": "7"},
        "total": {"type": "String", "example": "23"},
    },
    "checkProgress": {
        "done": {"type": "String", "example": "7"},
        "total": {"type": "String", "example": "23"},
    },
    "checkProgressNothingDownloaded": {
        "done": {"type": "String", "example": "7"},
        "total": {"type": "String", "example": "23"},
    },
    "checkTerminalComplete": {"total": {"type": "String", "example": "23"}},
    "checkTerminalInterrupted": {
        "done": {"type": "String", "example": "7"},
        "total": {"type": "String", "example": "23"},
    },
    "checkTerminalWithFailures": {
        "checked": {"type": "String", "example": "19"},
        "total": {"type": "String", "example": "23"},
        "failed": {"type": "String", "example": "4"},
    },
    "checkDiscoveredNothing": {"total": {"type": "String", "example": "23"}},
    "checkDiscovered": {
        "total": {"type": "String", "example": "23"},
        "discovered": {"type": "String", "example": "12"},
    },
    "librarySearchResults": {
        "count": {"type": "int", "example": "3"},
    },
    "librarySearchNoMatchTitle": {"query": {"type": "String", "example": "vow"}},
    "libraryFilterCount": {"count": {"type": "int", "example": "2"}},
    "libraryUnopenedBadgeSemantics": {"count": {"type": "int", "example": "12"}},
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
    for key, value in existing.items():
        if key.startswith("@") and key != "@@locale":
            continue
        if key in strings:
            continue
        out[key] = value

    for key, _ in ORDER:
        out[key] = strings[key]

    for key, value in existing.items():
        if key.startswith("@") and key != "@@locale" and key not in out:
            out[key] = value

    for key, _ in ORDER:
        out["@" + key] = {"description": DESCRIPTIONS.get(key, "")}
        if key in PLACEHOLDERS:
            out["@" + key]["placeholders"] = PLACEHOLDERS[key]

    with open(path, "w", encoding="utf-8") as handle:
        json.dump(out, handle, ensure_ascii=False, indent=2)
        handle.write("\n")
    return len(out)


def main():
    for locale in ("en", "fr"):
        print("%s: %d keys" % (locale, build(locale)))


if __name__ == "__main__":
    main()
