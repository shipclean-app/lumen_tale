"""Add the About screen's copy to both ARB files, in both languages.

`settings-about.md` § 4.1 is the source, and it is **not** reproduced wholesale: § 4bis
removed `UpdateBlock` from v1, so `about.check.*`, `update.title`, `update.installed`,
`update.download`, `update.downloading`, `update.install`, `update.dismiss` and
`update.failed` are **not** written here. Eighteen keys that the design still lists
would be dead copy, and dead ARB keys are a defect.

What § 4bis keeps is stated in its own words: *"the version line (B43) and the
guarantee sentence — B31's promise, read out loud before the reader installs
anything."* So `update.guarantee` survives as `aboutGuarantee`, renamed because the
block it belonged to is gone and a key named after a removed block is a second way of
saying the block exists.

Same reason for being a script rather than a hand edit: B28 demands French AND English
for every user-visible string, and two hand edits can leave the files a key apart.

Run:  python3 tool/append_about_strings.py
"""

import json

STRINGS = {
    "en": {
        "aboutVersion": "Version {buildName} · build {buildNumber}",
        "aboutProvenance": (
            "Android phone · built automatically · no store"
        ),
        "aboutCopyVersion": "Copy version number",
        "aboutVersionUnreadable": (
            "The installed version number could not be read."
        ),
        "aboutSnackCopied": "Version number copied.",
        "aboutGuarantee": (
            "Installing a new version keeps your library, your downloads, your "
            "reading positions and your history. Nothing is replaced or "
            "re-downloaded."
        ),
        "aboutDataLabel": "YOUR DATA ON THIS DEVICE",
        "aboutDataLibrary": "Library",
        "aboutDataDownloaded": "Downloaded chapters",
        "aboutDataPositions": "Reading positions",
        "aboutDataCountUnavailable": "—",
        "aboutDataE11": (
            "Nothing here is backed up anywhere. If you uninstall Lumen Tale or "
            "lose this phone, all three numbers go to zero and no copy exists. "
            "Installing a new version over this one does not touch them — that is "
            "the only guarantee this app makes about your data."
        ),
        "aboutPrivacyLabel": "WHAT LEAVES THIS DEVICE",
        "aboutPrivacySent1": (
            "A chapter's page — but only after you asked for it."
        ),
        "aboutPrivacySent2": (
            "One request to check whether a newer version exists — only if you "
            "tap \"Check for a new version\"."
        ),
        "aboutPrivacyNever1": "Your library",
        "aboutPrivacyNever2": "Your reading positions",
        "aboutPrivacyNever3": "Your history",
        "aboutPrivacyNever4": "Your error logs",
        "aboutPrivacyNever5": "Crash reports",
        "aboutPrivacyNever6": "Analytics",
        "aboutPrivacyNever7": "A device identifier",
        "aboutPrivacyVerify": (
            "Check it yourself: switch the phone to airplane mode, then open the "
            "app. Your library, your downloads and your reading positions are all "
            "there. Nothing is missing, because nothing was ever sent."
        ),
        "aboutDeliveryBody": (
            "This app runs on Android phones only. A new build is produced every "
            "time a change is merged, and you install it from the file by hand. "
            "There is no app store and no store account."
        ),
    },
    "fr": {
        "aboutVersion": "Version {buildName} · build {buildNumber}",
        "aboutProvenance": (
            "Téléphone Android · compilé automatiquement · aucun magasin"
        ),
        "aboutCopyVersion": "Copier le numéro de version",
        "aboutVersionUnreadable": (
            "Le numéro de version installé n'a pas pu être lu."
        ),
        "aboutSnackCopied": "Numéro de version copié.",
        "aboutGuarantee": (
            "L'installation d'une nouvelle version conserve votre bibliothèque, "
            "vos téléchargements, vos positions de lecture et votre historique. "
            "Rien n'est remplacé ni retéléchargé."
        ),
        "aboutDataLabel": "VOS DONNÉES SUR CE TÉLÉPHONE",
        "aboutDataLibrary": "Bibliothèque",
        "aboutDataDownloaded": "Chapitres téléchargés",
        "aboutDataPositions": "Positions de lecture",
        "aboutDataCountUnavailable": "—",
        "aboutDataE11": (
            "Rien ici n'est sauvegardé nulle part. Si vous désinstallez Lumen "
            "Tale ou perdez ce téléphone, ces trois nombres tombent à zéro et "
            "aucune copie n'existe. Installer une nouvelle version par-dessus "
            "celle-ci n'y touche pas : c'est la seule garantie que cette "
            "application fait sur vos données."
        ),
        "aboutPrivacyLabel": "CE QUI QUITTE CE TÉLÉPHONE",
        "aboutPrivacySent1": (
            "La page d'un chapitre — mais seulement après que vous l'avez "
            "demandée."
        ),
        "aboutPrivacySent2": (
            "Une requête pour savoir si une nouvelle version existe — "
            "uniquement si vous touchez « Rechercher une nouvelle version »."
        ),
        "aboutPrivacyNever1": "Votre bibliothèque",
        "aboutPrivacyNever2": "Vos positions de lecture",
        "aboutPrivacyNever3": "Votre historique",
        "aboutPrivacyNever4": "Vos journaux d'erreurs",
        "aboutPrivacyNever5": "Rapports de plantage",
        "aboutPrivacyNever6": "Suivi d'audience",
        "aboutPrivacyNever7": "Un identifiant d'appareil",
        "aboutPrivacyVerify": (
            "Vérifiez vous-même : passez le téléphone en mode avion, puis "
            "ouvrez l'application. Votre bibliothèque, vos téléchargements et vos "
            "positions de lecture sont tous là. Il ne manque rien, parce que rien "
            "n'a jamais été envoyé."
        ),
        "aboutDeliveryBody": (
            "Cette application fonctionne uniquement sur les téléphones "
            "Android. Une nouvelle version est produite à chaque modification "
            "fusionnée, et vous l'installez depuis le fichier, à la main. Il "
            "n'y a ni magasin d'applications ni compte de magasin."
        ),
    },
}

# (key, where `settings-about.md` § 4.1 puts it)
ORDER = [
    ("aboutVersion", "Version line — B43"),
    ("aboutProvenance", "Under the version line"),
    ("aboutCopyVersion", "Ghost button under the identity block"),
    ("aboutVersionUnreadable", "Load error, in place of the version line"),
    ("aboutSnackCopied", "SnackBar after the clipboard copy"),
    ("aboutGuarantee", "B31's promise, kept when UpdateBlock went (§ 4bis)"),
    ("aboutDataLabel", "DataBlock overline"),
    ("aboutDataLibrary", "Count row 1"),
    ("aboutDataDownloaded", "Count row 2"),
    ("aboutDataPositions", "Count row 3"),
    ("aboutDataCountUnavailable", "A count that could not be computed"),
    ("aboutDataE11", "E11, in full, stated here rather than pointed at"),
    ("aboutPrivacyLabel", "PrivacyBlock overline"),
    ("aboutPrivacySent1", "What leaves the device, item 1 — B5"),
    ("aboutPrivacySent2", "What leaves the device, item 2 — B34, C5"),
    ("aboutPrivacyNever1", "What never leaves, 1 of 7"),
    ("aboutPrivacyNever2", "What never leaves, 2 of 7"),
    ("aboutPrivacyNever3", "What never leaves, 3 of 7"),
    ("aboutPrivacyNever4", "What never leaves, 4 of 7"),
    ("aboutPrivacyNever5", "What never leaves, 5 of 7"),
    ("aboutPrivacyNever6", "What never leaves, 6 of 7"),
    ("aboutPrivacyNever7", "What never leaves, 7 of 7"),
    ("aboutPrivacyVerify", "The falsifiable check, in airplane mode"),
    ("aboutDeliveryBody", "DeliveryBlock — B34, C3, C9"),
]

DESCRIPTIONS = {
    "aboutVersion": (
        "B43: the reader can determine which version is installed. "
        "`buildName` and `buildNumber` arrive from Flutter's build-time Dart "
        "defines (`FLUTTER_BUILD_NAME` / `FLUTTER_BUILD_NUMBER`, ADR-011) — the "
        "app reads pubspec at build time and never parses a file at runtime."
    ),
    "aboutProvenance": (
        "How this build reached the reader. Three facts in one line, because a "
        "reader who installed a file by hand needs to know that is normal."
    ),
    "aboutCopyVersion": (
        "The clipboard button. C9 says the owner must be able to determine which "
        "version is installed, and pasting a version into a bug report is how "
        "that happens."
    ),
    "aboutVersionUnreadable": (
        "A real failure mode: the defines are absent in a plain `flutter test` "
        "and in an IDE run. **The rest of the screen renders completely** — "
        "`Version —` is forbidden, because an em dash looks like a version and "
        "C9 requires the version to be determinable."
    ),
    "aboutGuarantee": (
        "B31, and the one sentence § 4bis kept when it removed `UpdateBlock`. It "
        "is the only guarantee this app makes about the reader's data, so it is "
        "read out loud here rather than discovered after an upgrade."
    ),
    "aboutDataLabel": "The recessed block's overline. Read as a heading.",
    "aboutDataCountUnavailable": (
        "A count that could not be computed, and NOT a zero. The distinction is "
        "the whole reason the three figures are evidence for B31: a zero says "
        "'you have none' and a dash says 'we could not look', and a reader who "
        "took the first for the second would re-download a library they still "
        "have."
    ),
    "aboutDataE11": (
        "E11, in full and unhedged. This app has no backup (ADR-010), so the "
        "disclosure belongs on the page that shows what would be lost — and it "
        "names the exact operation that does NOT lose it, because a disclosure "
        "that only lists risks reads as an apology."
    ),
    "aboutPrivacySent2": (
        "⚠️ **Written for a control § 4bis removed.** The sentence is about a "
        "button this screen does not have. It is kept because the block's claim "
        "is about the APP's network posture rather than about the button: the "
        "app sends nothing on its own account, and if a version check returns the "
        "reader must already know that one request is the whole of it. If the "
        "check is ever built, this sentence is its first line and it is already "
        "true."
    ),
    "aboutPrivacyVerify": (
        "The falsifiable form of the privacy claim. A promise that cannot be "
        "tested by the reader is marketing; airplane mode is the test, and it "
        "takes thirty seconds."
    ),
    "aboutDeliveryBody": (
        "B34 + C3 + C9: the app IS the file. 'There is no app store' is not a "
        "limitation to apologise for — it is why there is no account and no "
        "server holding anything."
    ),
}

PLACEHOLDERS = {
    "aboutVersion": {
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

    # Metadata for every PRE-EXISTING key, re-emitted.
    #
    # ⚠️ A first version omitted this and reported success. It dropped **every** `@`
    # block the file already had, so `chapterCount` and `coverSemanticsLabel` lost the
    # placeholders only they declared, and `arb_completeness_test` caught it. A script
    # that overwrites a file needs its OUTPUT counted, not its exit code.
    for key, value in existing.items():
        if key.startswith('@') and key != '@@locale' and key not in out:
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