"""Add the Settings screen's copy to both ARB files, in both languages.

`settings.md` § 4.1 is the source, and it is read with its own instructions:

**Struck rows are not written.** § 4.1's own note: *"a string that is not on this
screen is not the v1 ARB inventory"*. So `row.sources.*` (slice `6-9` withdrawn),
`row.check.*` and `interval.*` (B35 withdrawn, ADR-023) and `error.load` (the Load-error
state declined in § 4) are absent — twenty-six keys the table still shows.

**`retention.1w` … `retention.2y` are NOT written either, and that is the interesting
one.** They are unstruck, so § 4.1 wants them — and they are a *second spelling of the
same five values* `6-5` already has as `historyWindowOneWeek` … `historyWindowTwoYears`.
`design-system.md` § 2.12 exists to stop exactly that:

    *"Two lists of the same values in two places is two truths about how long history
    lasts, and nothing in a dependency graph or a design token would notice."*

`6-5` owns the names (its sheet renders them and § 2.12 names `6-5` as the owner), and
`6-5` spells them `1 week` / `1 an` where `settings.md` spells them `one week` / `un an`.
**One set of strings has to lose**, and the one that loses is `settings.md`'s: a key that
another slice already owns must not acquire a twin. This is raised as finding **F-013**.

**`row.checkNow.*`, `error.noConnection`, `warning.notifications.*` are not written
either.** They are unstruck and § 4.1 wants them, but `Check now` is B36's update check
and no `8-*` slice has built one. A row whose tap reports nothing it did would be the
"fake control" defect; its copy goes with the row. This is finding **F-012**.

Run:  python3 tool/append_settings_strings.py
"""

import json

STRINGS = {
    "en": {
        "settingsTitle": "Settings",
        "settingsLanguageEnglish": "English",
        "settingsLanguageFrench": "Français",
        "settingsGroupReading": "READING",
        "settingsGroupHistory": "HISTORY",
        "settingsGroupApp": "APP",
        "settingsRowAppearanceLabel": "Reader appearance",
        "settingsRowAppearanceValue": "{theme} · {size} ({pt} pt)",
        "settingsThemeDay": "Day",
        "settingsThemeNight": "Night",
        "settingsThemeSystem": "Follow the phone",
        "settingsSizeSm": "Small",
        "settingsSizeMd": "Medium",
        "settingsSizeLg": "Large",
        "settingsSizeXl": "Larger",
        "settingsSizeXxl": "Largest",
        "settingsRowHistoryLabel": "Reading history",
        "settingsRowHistoryValue": "{count} entries · oldest {relative}",
        "settingsRowHistoryValueEmpty": "0 entries",
        "settingsRowRetentionLabel": "Keep history for",
        "settingsRowClearHistoryLabel": "Clear reading history",
        "settingsDialogClearHistoryTitle": "Clear {count} entries?",
        "settingsDialogClearHistoryBody": (
            "Reading positions are not part of this list and will not be touched."
        ),
        "settingsDialogClearHistoryConfirm": "Clear",
        "settingsSnackHistoryCleared": (
            "Reading history cleared. Your reading positions were kept."
        ),
        "settingsRowLanguageLabel": "Language",
        "settingsRowLanguageHint": (
            "Follows your phone. Change it in Android's language settings."
        ),
        "settingsRowOnboardingLabel": "How this app works",
        "settingsRowOnboardingValue": "Show the two introduction screens again",
        "settingsRowAboutLabel": "About Lumen Tale",
        "settingsRowAboutValue": "Version {buildName} · build {buildNumber}",
        "settingsDisclosureE11": (
            "Nothing here is backed up. If you uninstall Lumen Tale or lose this "
            "phone, your library, your downloads and your reading positions are "
            "gone, and no copy exists anywhere."
        ),
        "settingsDisclosureE11Footer": (
            "The app cannot warn you at the moment you uninstall — the phone does "
            "that, outside the app. So it is said here, before, rather than after."
        ),
        "settingsDisclosureAboutLink": "What survives an update",
        "settingsErrorWrite": "This setting could not be saved. Nothing was changed.",
        "settingsErrorCountUnavailable": "Count unavailable",
        "settingsButtonRetry": "Try again",
        "settingsButtonCancel": "Cancel",
    },
    "fr": {
        "settingsTitle": "Réglages",
        "settingsLanguageEnglish": "English",
        "settingsLanguageFrench": "Français",
        "settingsGroupReading": "LECTURE",
        "settingsGroupHistory": "HISTORIQUE",
        "settingsGroupApp": "APPLICATION",
        "settingsRowAppearanceLabel": "Apparence du lecteur",
        "settingsRowAppearanceValue": "{theme} · {size} ({pt} pt)",
        "settingsThemeDay": "Jour",
        "settingsThemeNight": "Nuit",
        "settingsThemeSystem": "Suivre le téléphone",
        "settingsSizeSm": "Petit",
        "settingsSizeMd": "Moyen",
        "settingsSizeLg": "Grand",
        "settingsSizeXl": "Plus grand",
        "settingsSizeXxl": "Le plus grand",
        "settingsRowHistoryLabel": "Historique de lecture",
        "settingsRowHistoryValue": (
            "{count} entrées · la plus ancienne {relative}"
        ),
        "settingsRowHistoryValueEmpty": "0 entrée",
        "settingsRowRetentionLabel": "Conserver l'historique pendant",
        "settingsRowClearHistoryLabel": "Effacer l'historique de lecture",
        "settingsDialogClearHistoryTitle": "Effacer {count} entrées ?",
        "settingsDialogClearHistoryBody": (
            "Les positions de lecture ne font pas partie de cette liste et ne "
            "seront pas touchées."
        ),
        "settingsDialogClearHistoryConfirm": "Effacer",
        "settingsSnackHistoryCleared": (
            "Historique de lecture effacé. Vos positions de lecture ont été "
            "conservées."
        ),
        "settingsRowLanguageLabel": "Langue",
        "settingsRowLanguageHint": (
            "Suit votre téléphone. Changez-la dans les paramètres de langue "
            "d'Android."
        ),
        "settingsRowOnboardingLabel": "Comment fonctionne cette application",
        "settingsRowOnboardingValue": (
            "Revoir les deux écrans d'introduction"
        ),
        "settingsRowAboutLabel": "À propos de Lumen Tale",
        "settingsRowAboutValue": "Version {buildName} · build {buildNumber}",
        "settingsDisclosureE11": (
            "Rien ici n'est sauvegardé. Si vous désinstallez Lumen Tale ou perdez "
            "ce téléphone, votre bibliothèque, vos téléchargements et vos "
            "positions de lecture sont perdus, et aucune copie n'existe ailleurs."
        ),
        "settingsDisclosureE11Footer": (
            "L'application ne peut pas vous avertir au moment où vous "
            "désinstallez : c'est le téléphone qui le fait, en dehors de "
            "l'application. C'est donc dit ici, avant, plutôt qu'après."
        ),
        "settingsDisclosureAboutLink": "Ce qui survit à une mise à jour",
        "settingsErrorWrite": (
            "Ce paramètre n'a pas pu être enregistré. Rien n'a été modifié."
        ),
        "settingsErrorCountUnavailable": "Nombre indisponible",
        "settingsButtonRetry": "Réessayer",
        "settingsButtonCancel": "Annuler",
    },
}

ORDER = [
    ("settingsTitle", "Screen title"),
    # ⚠️ These two are IDENTICAL in both files on purpose. The row reports what the
    # PHONE is set to, so an English UI with a French phone must read "Français". They
    # live here rather than as an ordinary pair because a translator would helpfully
    # localize them into something wrong — see `language_label.dart`.
    ("settingsLanguageEnglish", "The phone's language, named in that language"),
    ("settingsLanguageFrench", "The phone's language, named in that language"),
    ("settingsGroupReading", "Group label"),
    ("settingsGroupHistory", "Group label"),
    ("settingsGroupApp", "Group label"),
    ("settingsRowAppearanceLabel", "READING group, row 1"),
    ("settingsRowAppearanceValue", "READING group, row 1 value line"),
    ("settingsThemeDay", "Theme name — design-system.md settings-reader.md's segments"),
    ("settingsThemeNight", "Theme name"),
    ("settingsThemeSystem", "Theme name"),
    ("settingsSizeSm", "Size step name"),
    ("settingsSizeMd", "Size step name"),
    ("settingsSizeLg", "Size step name"),
    ("settingsSizeXl", "Size step name"),
    ("settingsSizeXxl", "Size step name"),
    ("settingsRowHistoryLabel", "HISTORY group, row 1"),
    ("settingsRowHistoryValue", "HISTORY group, row 1 value line"),
    ("settingsRowHistoryValueEmpty", "HISTORY group, row 1 value line at zero"),
    ("settingsRowRetentionLabel", "HISTORY group, row 2 — opens the sheet"),
    ("settingsRowClearHistoryLabel", "HISTORY group, row 3 — the danger row"),
    ("settingsDialogClearHistoryTitle", "The confirm dialog's title"),
    ("settingsDialogClearHistoryBody", "The confirm dialog's body — B46"),
    ("settingsDialogClearHistoryConfirm", "The confirm dialog's destructive button"),
    ("settingsSnackHistoryCleared", "Success SnackBar"),
    ("settingsRowLanguageLabel", "APP group, row 1 — READ-ONLY"),
    ("settingsRowLanguageHint", "APP group, row 1 hint"),
    ("settingsRowOnboardingLabel", "APP group, row 2"),
    ("settingsRowOnboardingValue", "APP group, row 2 value line"),
    ("settingsRowAboutLabel", "APP group, row 3"),
    ("settingsRowAboutValue", "APP group, row 3 value line — the version"),
    ("settingsDisclosureE11", "E11, in the disclosure block"),
    ("settingsDisclosureE11Footer", "E11's footer line"),
    ("settingsDisclosureAboutLink", "Ghost link into the About page"),
    ("settingsErrorWrite", "Submit error, beside a control"),
    ("settingsErrorCountUnavailable", "A count that could not be obtained — never 0"),
    ("settingsButtonRetry", "Retry"),
    ("settingsButtonCancel", "Dialog cancel"),
]

DESCRIPTIONS = {
    "settingsLanguageEnglish": (
        "⚠️ **Identical in the French file.** The `Language` row reports the phone's "
        "language, not the app's, and a reader on an English UI with a French phone "
        "must see \"Français\". B28: the app follows the phone."
    ),
    "settingsLanguageFrench": (
        "⚠️ **Identical in the English file**, for the same reason. A value that "
        "changes with the ARB would be the app naming the phone's language in the "
        "app's language, which is a different claim."
    ),
    "settingsRowAppearanceValue": (
        "Both halves on one line: `{theme}` and `{size}` are the two values the "
        "reader set, and `{pt}` is the resolved point size. ⚠️ **The value line "
        "truncates, not the label** — § 4.1 says so, and it is a consequence of "
        "French running longer than English, not a defect."
    ),
    "settingsThemeSystem": (
        "B26's `system` value, named for what it does. NOT 'Automatic': a reader "
        "who reads *Automatic* does not learn that the app follows the phone."
    ),
    "settingsRowHistoryValue": (
        "`{count}` and `{relative}`. ⚠️ **Never a zero here** — `settingsRowHistoryValueEmpty` "
        "is a separate key, because `{count} entries · oldest {relative}` with a "
        "zero has no oldest to name."
    ),
    "settingsRowHistoryValueEmpty": (
        "The zero. French takes the singular on zero ('0 entrée'), which is a "
        "plural-rule difference and not a typo."
    ),
    "settingsDialogClearHistoryTitle": (
        "⚠️ **The count is in the TITLE**, not the body. This dialog's one job is to "
        "say how much is about to be destroyed, and a title is what a reader reads "
        "before they read anything else. `3-7`'s Loading state exists only for the "
        "COUNT this sentence waits on."
    ),
    "settingsDialogClearHistoryBody": (
        "B46, and the second clause is the whole sentence: reading positions are "
        "not in this list. `clearAll()` deletes exactly one table and a row asserts "
        "the positions survive."
    ),
    "settingsDialogClearHistoryConfirm": (
        "⚠️ **`Clear`, not `OK`, and not `Delete`** — it names the object. And § 4 "
        "(Empty — no data) forbids the dialog opening at all when the count is zero, "
        "so a reader is never asked to confirm destroying nothing."
    ),
    "settingsSnackHistoryCleared": (
        "The second clause is **mandatory and is the entire success message**, "
        "because B46 makes position the thing the reader must believe survived. A "
        "generic 'History cleared' leaves the reader fearing they lost their place, "
        "which is the app's core promise (B16)."
    ),
    "settingsRowLanguageLabel": (
        "**Read-only, and visibly so**: no chevron, no ripple, no pressed state. B28 "
        "forbids an in-app language picker — the platform owns this value and a "
        "second source of truth for it is a bug waiting to happen."
    ),
    "settingsRowLanguageHint": (
        "Tells the reader where the control actually is, because there isn't one here. "
        "A read-only row with no explanation reads as a disabled control."
    ),
    "settingsRowAboutValue": (
        "The same `{buildName}` · build `{buildNumber}` pair `3-5` shows, from the "
        "same `AppRoutes`-level source. Two spellings of the version on two pages "
        "would be two truths about which build is installed (C9)."
    ),
    "settingsDisclosureE11Footer": (
        "The footer, and it exists because of what it admits: the app cannot detect "
        "an uninstall as it happens, so the disclosure has to happen **before** "
        "rather than after. A disclosure that says 'you cannot undo this' without "
        "saying why is read as an apology."
    ),
    "settingsDisclosureAboutLink": (
        "The ghost link into About, and its label is the QUESTION it answers "
        "(B31's guarantee). A link labelled 'About' would compete with the row above "
        "it."
    ),
    "settingsErrorCountUnavailable": (
        "A count that could not be obtained, and **never `0`** (B48). § 4 (Load "
        "error, declined) scopes the failure to the one row that owns it: a failed "
        "`COUNT` renders this word on its own line and disables the clear row, "
        "rather than blanking eight correct rows."
    ),
    "settingsErrorWrite": (
        "A failed write, shown **beside** the control and never by tinting it — a "
        "red control reads as 'this setting is now off' rather than 'this setting "
        "could not be saved'."
    ),
}

PLACEHOLDERS = {
    "settingsRowAppearanceValue": {
        "theme": {"type": "String", "example": "Day"},
        "size": {"type": "String", "example": "Medium"},
        "pt": {"type": "String", "example": "18"},
    },
    "settingsRowHistoryValue": {
        "count": {"type": "String", "example": "1247"},
        "relative": {"type": "String", "example": "4 months ago"},
    },
    "settingsDialogClearHistoryTitle": {"count": {"type": "String", "example": "96"}},
    "settingsRowAboutValue": {
        "buildName": {"type": "String", "example": "0.9.0"},
        "buildNumber": {"type": "String", "example": "41"},
    },
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

    # Metadata for every PRE-EXISTING key, re-emitted. A script that overwrites a
    # file needs its OUTPUT counted, not its exit code — see the two sibling scripts
    # for the incident this comment exists because of.
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