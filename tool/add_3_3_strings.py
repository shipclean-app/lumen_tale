#!/usr/bin/env python3
"""One-off builder for slice 3-3's ARB entries.

⚠️ IT IS A BUILDER, NOT AN EDIT, BECAUSE THE INVARIANT IS PAIRS.

Every key here exists in BOTH languages and its placeholders must have the
**same names** in both. That is B28, and this project has already shipped the
bug it describes: `settingsSpecimenCredit` read `{novel, chapter}` in EN and
`{roman, chapitre}` in FR, and a translated placeholder name does not rename a
parameter — it **adds** one, so the French file silently asked for two
arguments the English one does not.

So the strings live in ONE table, keyed by locale, and the writer refuses to
emit a key whose placeholders disagree. A second language added here gets the
placeholder check for free; one added by hand does not.
"""

from __future__ import annotations

import io
import json
import re
import sys
from pathlib import Path

ARB = Path(__file__).resolve().parent.parent / "lib" / "l10n"

# key -> (en, fr). Placeholders are part of the string and MUST match.
STRINGS: dict[str, tuple[str, str]] = {
    # ⚠️ `commonOk` is here rather than in a `common*` script because it arrived with 3-3's
    # space-refusal dialogue and the collection is the point: one table, one placeholder
    # check, both languages.
    "commonOk": ("OK", "OK"),
    "downloadAddedSnackbar": ("Download added", "Téléchargement ajouté"),
    "downloadAlreadyStoredSnackbar": (
        "This chapter is already downloaded",
        "Ce chapitre est déjà téléchargé",
    ),
    "downloadAlreadyQueuedSnackbar": (
        "This chapter is already in the queue",
        "Ce chapitre est déjà dans la file d'attente",
    ),
    "downloadNeedsConnectionSnackbar": (
        "Downloading requires a connection.",
        "Le téléchargement nécessite une connexion.",
    ),
    "downloadWriteFailedSnackbar": (
        "The download could not be added. Nothing was changed.",
        "Le téléchargement n'a pas pu être ajouté. Rien n'a été modifié.",
    ),
    "downloadSpaceRefusedBody": (
        "This download needs {requiredBytes}, and this phone has {freeBytes} free.",
        "Ce téléchargement nécessite {requiredBytes}, et ce téléphone dispose de "
        "{freeBytes} libres.",
    ),
    "downloadSpaceRefusedAction": (
        "Delete a downloaded chapter, then try again.",
        "Supprimez un chapitre téléchargé, puis réessayez.",
    ),
    "deleteStoredTitle": ("Delete chapter {ordinal}?", "Supprimer le chapitre {ordinal} ?"),
    "deleteStoredBody": (
        "This chapter's text will be erased from this phone.\n"
        "The {siblingCount} other chapters of this novel are not touched.\n"
        "{freedBytes} will be freed.",
        "Le texte de ce chapitre sera effacé de ce téléphone.\n"
        "Les {siblingCount} autres chapitres de ce roman ne sont pas touchés.\n"
        "{freedBytes} seront libérés.",
    ),
    "deleteStoredConfirm": ("Delete", "Supprimer"),
    "downloadDeletedSnackbar": (
        "Chapter deleted — {freedBytes} freed",
        "Chapitre supprimé — {freedBytes} libérés",
    ),
    "downloadNotStoredSnackbar": (
        "This chapter was not downloaded.",
        "Ce chapitre n'était pas téléchargé.",
    ),
    "deleteStoredFailedSnackbar": (
        "Could not delete this chapter. Nothing was changed.",
        "Impossible de supprimer ce chapitre. Rien n'a été modifié.",
    ),
    "downloadNotDownloadedLabel": ("Not downloaded", "Non téléchargé"),
    "unitBytes": ("{count} B", "{count} o"),
    "unitKilobytes": ("{count} KB", "{count} Ko"),
    "unitMegabytes": ("{count} MB", "{count} Mo"),
    "unitGigabytes": ("{count} GB", "{count} Go"),
    "chapterCountSingular": ("1 other chapter", "1 autre chapitre"),
    "chapterCountPlural": (
        "{count} other chapters",
        "{count} autres chapitres",
    ),
}

PLACEHOLDER = re.compile(r"\{(\w+)\}")


def placeholders(text: str) -> set[str]:
    return set(PLACEHOLDER.findall(text))


def main() -> int:
    for key, (en, fr) in STRINGS.items():
        if placeholders(en) != placeholders(fr):
            print(
                f"  MISMATCH {key}: en={sorted(placeholders(en))} fr={sorted(placeholders(fr))}",
                file=sys.stderr,
            )
            return 1

    for name, index in (("app_en.arb", 0), ("app_fr.arb", 1)):
        path = ARB / name
        data = json.loads(path.read_text(encoding="utf-8"))
        for key, pair in STRINGS.items():
            data[key] = pair[index]
            meta = data.get("@" + key)
            description = meta.get("description", "") if isinstance(meta, dict) else ""
            data["@" + key] = {
                "description": description,
                "placeholders": {
                    name_: {} for name_ in sorted(placeholders(pair[index]))
                },
            }
        ordered = {k: data[k] for k in sorted(data)}
        path.write_text(
            json.dumps(ordered, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
        )
        print(f"  wrote {len(STRINGS)} messages into {name}")

    # FR metadata blocks must exist for every key too, or `flutter gen-l10n` warns.
    return 0


if __name__ == "__main__":
    raise SystemExit(main())