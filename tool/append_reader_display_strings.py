"""Add `2-8`'s copy to both ARB files: the reader-settings inventory and the reader's chrome.

`settings-reader.md` § 4.1 is the source for the first block, and it is read with its own
instructions:

**The inventory is CLOSED (§ 7.3 of the plan).** Nothing is invented and nothing is
omitted — `16-i18n.md` rule 2: *"an entry present in one file and missing in the other is
a defect, not a fallback"*.

**`size.sm` … `size.xxl`, `theme.*`, `error.write` and `button.retry` are NOT re-declared.**
They already exist under the same derived keys (`settingsSizeSm`, `settingsThemeDay`,
`settingsErrorWrite`, `settingsButtonRetry`) because `3-7`'s value line reads them, and
`arb_key_derivation.dart` exists precisely so two screens writing `error.write` resolve to
ONE key. Re-declaring them here would be a second copy of the same French text.

**The block below that is `2-8`'s own chrome**, and it is keyed on the `reader` slug —
`readerSizeSheetTitle` is the reader's sheet, and `/more/settings/reader`'s copy belongs to
the `settings` slug. A key invented per screen for the same string is the duplication the
derivation rule exists to prevent.

## ⚠️ The `deferred.*` block has EIGHT entries, and the prose says seven

`settings-reader.md` § 3 says `DeferredItem × 7`, and the plan repeats "seven absences"
four times. **§ 4.1 lists eight `deferred.*` keys and § 11 lists eight absent controls** —
reading modes, swipe page-turn, orientation lock, colour filters, justification, paragraph
spacing, line-height, custom font. The copy table is the authority § 7.3 points at, so all
eight are declared; a `DeferredList` that shows seven would drop `deferred.fonts` and
silently forget the font picker's absence, which is the one absence a reader who has used
another reader is most likely to notice. Recorded, not silently reconciled.

## ⚠️ Two spellings of the pixel figure, on purpose

The step shows **20pt** (the figure the reader compares against their phone's own font
slider) while the screen reader hears **20 pixels** (`settings-reader.md` § 5's announcement,
*"Large, 20 pixels, not selected"*). One number, two renderings, two keys: an abbreviation
is an eye convention and a spoken abbreviation is not one.

Run:  python3 tool/append_reader_display_strings.py
"""

import json

STRINGS = {
    "en": {
        # ── `settings-reader.md` § 4.1, under the `settings` slug ──────────
        "settingsGroupSize": "TEXT SIZE",
        "settingsGroupTheme": "THEME",
        "settingsGroupDeferred": "NOT IN THIS VERSION",
        "settingsSpecimenCredit": 'From "{novel}" · {chapter}',
        "settingsSpecimenEmptyNote": (
            "You have not downloaded anything yet — this is what the reader "
            "will look like."
        ),
        "settingsSpecimenSeedFailed": (
            "A chapter saved on this phone could not be read. Showing a sample "
            "instead."
        ),
        "settingsDeferredModes": (
            "No reading modes — reading is one continuous scroll."
        ),
        "settingsDeferredSwipe": "No swipe or tap page-turn.",
        "settingsDeferredOrientation": "No orientation or rotation lock.",
        "settingsDeferredFilters": (
            "No colour filters — sepia, greyscale, inverted."
        ),
        "settingsDeferredJustification": (
            "No text justification. Justified prose at this measure creates "
            "rivers, and rivers are worse than a ragged edge."
        ),
        "settingsDeferredParagraphSpacing": (
            "No paragraph spacing control — the 1.72 line-height already sets "
            "the rhythm."
        ),
        "settingsDeferredLineHeight": (
            "No line-height control. It is held at 1.72 at every size on "
            "purpose, so the rhythm does not change when the size does."
        ),
        "settingsDeferredFonts": (
            "No font picker — the reader uses a serif, decided once. A reading "
            "face you can choose is a v2 candidate, not a v1 control."
        ),
        # ── `2-8`'s own chrome, under the `reader` slug ─────────────────────
        "readerSizeSheetTitle": "Text size",
        "readerSizeStepPoints": "{px}pt",
        "readerSizePixelsSpoken": "{px} pixels",
        "readerSizeStepSemantics": "{name}, {pixels}, {state}",
        "readerSizeStepSelected": "selected",
        "readerSizeStepNotSelected": "not selected",
        "readerSizeButtonTooltip": "Text size: {name}",
        "readerThemeButtonTooltip": "Theme: {name}",
    },
    "fr": {
        "settingsGroupSize": "TAILLE DU TEXTE",
        "settingsGroupTheme": "THÈME",
        "settingsGroupDeferred": "PAS DANS CETTE VERSION",
        "settingsSpecimenCredit": 'Extrait de « {roman} » · {chapitre}',
        "settingsSpecimenEmptyNote": (
            "Vous n'avez encore rien téléchargé : c'est ainsi que le lecteur "
            "se comportera."
        ),
        "settingsSpecimenSeedFailed": (
            "Un chapitre enregistré sur ce téléphone n'a pas pu être lu. Un "
            "exemple est affiché à la place."
        ),
        "settingsDeferredModes": (
            "Pas de mode de lecture : la lecture est un défilement continu "
            "unique."
        ),
        "settingsDeferredSwipe": (
            "Pas de changement de page par balayage ou toucher."
        ),
        "settingsDeferredOrientation": "Pas de verrouillage d'orientation.",
        "settingsDeferredFilters": (
            "Pas de filtres de couleur : sépia, niveaux de gris, inversé."
        ),
        "settingsDeferredJustification": (
            "Pas de justification du texte. Un texte justifié à cette "
            "longueur de ligne crée des rivières, bien pires qu'une bordure "
            "irrégulière."
        ),
        "settingsDeferredParagraphSpacing": (
            "Pas de réglage de l'espacement des paragraphes : l'interligne de "
            "1,72 fixe déjà le rythme."
        ),
        "settingsDeferredLineHeight": (
            "Pas de réglage d'interligne. Il est maintenu à 1,72 à toutes les "
            "tailles, volontairement, pour que le rythme ne change pas avec "
            "la taille."
        ),
        "settingsDeferredFonts": (
            "Pas de choix de police : le lecteur utilise un serif, décidé une "
            "fois. Une face de lecture au choix est une candidate pour la v2, "
            "pas un contrôle de la v1."
        ),
        "readerSizeSheetTitle": "Taille du texte",
        "readerSizeStepPoints": "{px} pt",
        "readerSizePixelsSpoken": "{px} pixels",
        "readerSizeStepSemantics": "{name}, {pixels}, {state}",
        "readerSizeStepSelected": "sélectionné",
        "readerSizeStepNotSelected": "non sélectionné",
        "readerSizeButtonTooltip": "Taille du texte : {name}",
        "readerThemeButtonTooltip": "Thème : {name}",
    },
}

# The order they are appended in, with the reason each exists. Grouped as the design's
# anatomy reads, not alphabetically — an ARB file is read by a human during review.
ORDER = [
    ("settingsGroupSize", "TEXT SIZE group label"),
    ("settingsGroupTheme", "THEME group label"),
    ("settingsGroupDeferred", "The seven/eight absences' group label"),
    ("settingsSpecimenCredit", 'SpecimenFootnote — "From {novel} · {chapter}"'),
    ("settingsSpecimenEmptyNote", "Empty — never visited: the app's stand-in note"),
    ("settingsSpecimenSeedFailed", "Load error — the seed, in --color-warning"),
    ("settingsDeferredModes", "Absent control 1 of 8"),
    ("settingsDeferredSwipe", "Absent control 2 of 8"),
    ("settingsDeferredOrientation", "Absent control 3 of 8"),
    ("settingsDeferredFilters", "Absent control 4 of 8"),
    ("settingsDeferredJustification", "Absent control 5 of 8"),
    ("settingsDeferredParagraphSpacing", "Absent control 6 of 8"),
    ("settingsDeferredLineHeight", "Absent control 7 of 8"),
    ("settingsDeferredFonts", "Absent control 8 of 8 — ⚠️ § 3 says seven, § 4.1 says eight"),
    ("readerSizeSheetTitle", "The reader's size sheet title"),
    ("readerSizeStepPoints", "The figure printed under a step — an EYE convention"),
    ("readerSizePixelsSpoken", "The same figure SPOKEN — not an abbreviation"),
    ("readerSizeStepSemantics", "One focusable node: name, figure, selection"),
    ("readerSizeStepSelected", "The selection half of the announcement"),
    ("readerSizeStepNotSelected", "The absence half — ⚠️ never inferred from the first"),
    ("readerSizeButtonTooltip", "The size button's accessible label"),
    ("readerThemeButtonTooltip", "The theme button's accessible label, naming the VALUE"),
]

DESCRIPTIONS = {
    "settingsSpecimenCredit": (
        "⚠️ **Under the specimen only, and `null` when the stand-in is shown.** B44: the "
        "seed is site content displayed as published, so naming the book it came from is "
        "the only way the reader knows they are looking at their own download and not at "
        "marketing copy."
    ),
    "settingsSpecimenEmptyNote": (
        "B28's honest empty. It is `--text-caption`, it is ONE line, and it names the "
        "sample as a sample — a specimen that pretends to be content would be the "
        "misrepresentation § 2.1 exists to prevent."
    ),
    "settingsSpecimenSeedFailed": (
        "⚠️ **`--color-warning`, never `--color-error`.** Nothing failed that the reader "
        "asked for: the setting saved, only the seed is unreadable. An error here reads as "
        "*the setting did not save*, which is false."
    ),
    "settingsDeferredFonts": (
        "⚠️ **The eighth, and the prose says seven.** `settings-reader.md` § 3 counts "
        "`DeferredItem × 7` while § 4.1 and § 11 both list eight absences. The copy table "
        "wins, and dropping this one would forget the font picker — the absence a reader "
        "who has used another reader is most likely to look for."
    ),
    "readerSizeStepPoints": (
        "⚠️ **The EYE's figure.** `settings-reader.md` § 6: it is the one thing the reader "
        "can check against the phone's own font slider, so it must never truncate and "
        "never be a bare number."
    ),
    "readerSizePixelsSpoken": (
        "⚠️ **The SPOKEN figure, and deliberately not the same string.** § 5's "
        "announcement is *\"Large, 20 pixels, not selected\"*; `20pt` read aloud is an "
        "abbreviation a screen reader has to guess at. One number, two renderings, two "
        "keys — a translation cannot merge them."
    ),
    "readerSizeStepSemantics": (
        "One focusable node per step, announcing `{name}`, `{pixels}` and whether it is "
        "selected. ⚠️ **A single ICU sentence rather than three concatenated strings**: "
        "the order and the punctuation are the translator's, and `name, pixels, state` "
        "does not survive a language that does not use commas."
    ),
    "readerSizeStepNotSelected": (
        "⚠️ **Its own key, never the empty string.** \"Not selected\" is a claim, and a "
        "label that goes silent on the four unselected steps is indistinguishable from one "
        "that failed to render."
    ),
    "readerSizeStepSelected": (
        "The positive half of `readerSizeStepSemantics`. Never signalled by colour alone — "
        "`14-design-tokens.md` §Accessibility."
    ),
    "readerThemeButtonTooltip": (
        "⚠️ **Names the CURRENT value, not the next one.** The button cycles, so a label "
        "naming the result (\"Switch to night\") would be true for one press and false for "
        "the next two — and the reader mid-chapter cannot see which."
    ),
}

PLACEHOLDERS = {
    "settingsSpecimenCredit": {
        "novel": {"type": "String", "example": "The Runesmith's Apprentice"},
        "chapter": {"type": "String", "example": "Chapter 12"},
    },
    "readerSizeStepPoints": {"px": {"type": "String", "example": "20"}},
    "readerSizePixelsSpoken": {"px": {"type": "String", "example": "20"}},
    "readerSizeStepSemantics": {
        "name": {"type": "String", "example": "Large"},
        "pixels": {"type": "String", "example": "20 pixels"},
        "state": {"type": "String", "example": "not selected"},
    },
    "readerSizeButtonTooltip": {"name": {"type": "String", "example": "Large"}},
    "readerThemeButtonTooltip": {
        "name": {"type": "String", "example": "Follow the phone"}
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

    # ⚠️ **An existing key is REFUSED, never overwritten.** `settingsSizeSm` and friends
    # are shared with `3-7`'s value line; a script that rewrote them would be a second
    # source of truth for one string, wearing a builder's clothes.
    clashes = [key for key, _ in ORDER if key in existing]
    if clashes:
        raise SystemExit("%s already declares: %s" % (locale, ", ".join(clashes)))

    out = dict(existing)
    for key, _ in ORDER:
        out[key] = strings[key]
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